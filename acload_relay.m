function results = acload_relay(deviceId, params)
%ACLOAD_RELAY 求解两台交流电子负载各组的最优继电器开合状态
%
% 用法：
%   results = acload_relay();          % 读取 acload_params.m，求解全部设备
%   results = acload_relay(1);         % 只求解设备 ID=1
%   results = acload_relay(2);         % 只求解设备 ID=2
%   p = acload_params();
%   results = acload_relay(p);         % 使用自定义参数，求解全部设备
%   results = acload_relay([], p);     % 使用自定义参数，求解全部设备
%   results = acload_relay(2, p);      % 使用自定义参数，只求解设备 ID=2
%
% 参数结构与 acload_params.m 一致：
%   params.devices(k).V_rms / f_Hz / I_target_A / PF_target
%   params.devices(k).groups(g).R0_ohm / R_ohm / Ls_H / L_H
%   可选字段：Rser_ohm、Lser_ohm
%
% 电路模型：
%   1) R0 固定接入；R1~R10 通过继电器并联投入。
%   2) L1~L11 串联；电感继电器 CLOSED 时，该节电感及其绕组电阻均被旁路。
%   3) Ls_H 是线路寄生电感，始终计入总电感，即使所有电感均被旁路。
%   4) 若存在 Lser_ohm，按实际投入的电感节累加绕组电阻；不再额外叠加
%      Rser_ohm，避免重复计算。Lser_ohm 的逐节分配目前是参数文件中的估算值。
%      若没有 Lser_ohm、但有 Rser_ohm，则将 Rser_ohm 作为恒定串联电阻近似。
%
% 优化目标（电流和功率因数等权）：
%   J = ((I-I_target)/I_target)^2 + ((PF-PF_target)/PF_target)^2
%
% 每组完整穷举 2^10 种电阻状态 × 2^11 种电感状态，共 2,097,152 种组合。
%
% 继电器状态语义：
%   resistorRelayClosed(j) = true  -> Rj 继电器闭合，电阻投入并联网络。
%   inductorRelayClosed(j) = true  -> Lj 继电器闭合，电感及其绕组电阻被短接。
%
% 输出：
%   results.devices(k).groups(g) 保存每组的继电器状态、预测电气量和目标函数。

    %% 解析输入参数
    if nargin < 1
        deviceId = [];
        params = acload_params();
    elseif nargin == 1
        % 兼容 acload_relay(params) 的调用方式。
        if isstruct(deviceId)
            params = deviceId;
            deviceId = [];
        else
            params = acload_params();
        end
    elseif isempty(params)
        params = acload_params();
    end

    validate_device_collection(params);

    allIds = [params.devices.id];
    if isempty(deviceId)
        selectedIndices = 1:numel(params.devices);
    else
        if ~isnumeric(deviceId) || ~isreal(deviceId) || ~isscalar(deviceId) || ...
                isnan(deviceId) || isinf(deviceId) || deviceId ~= fix(deviceId)
            error('acload_relay:InvalidDeviceId', ...
                'deviceId 必须是整数设备编号，或留空以求解全部设备。');
        end
        selectedIndices = find(allIds == deviceId, 1);
        if isempty(selectedIndices)
            error('acload_relay:UnknownDeviceId', ...
                '参数文件中不存在设备编号 %g。', deviceId);
        end
    end

    %% 预生成所有继电器状态组合
    nR = 10;
    nL = 11;
    nRComb = 2^nR;
    nLComb = 2^nL;

    % 电阻位为 true 表示继电器闭合、该电阻投入。
    rMask = uint16((0:nRComb-1)');
    rClosedBits = false(nRComb, nR);
    for k = 1:nR
        rClosedBits(:, k) = bitget(rMask, k) ~= 0;
    end

    % 电感位为 true 表示电感计入串联链（即对应继电器断开）。
    lMask = uint16((0:nLComb-1)');
    lIncludedBits = false(nLComb, nL);
    for k = 1:nL
        lIncludedBits(:, k) = bitget(lMask, k) ~= 0;
    end

    %% 结果结构体模板
    emptyGroup = struct( ...
        'name', '', ...
        'resistorRelayClosed', false(1, nR), ...
        'resistorRelayState', {cell(1, nR)}, ...
        'inductorRelayClosed', false(1, nL), ...
        'inductorRelayState', {cell(1, nL)}, ...
        'parallelResistanceOhm', NaN, ...
        'inductorWindingResistanceOhm', NaN, ...
        'equivalentResistanceOhm', NaN, ...
        'totalInductanceH', NaN, ...
        'inductiveReactanceOhm', NaN, ...
        'impedanceMagnitudeOhm', NaN, ...
        'currentRmsA', NaN, ...
        'powerFactor', NaN, ...
        'realPowerW', NaN, ...
        'objectiveJ', NaN);

    emptyDevice = struct( ...
        'deviceId', NaN, ...
        'name', '', ...
        'V_rms', NaN, ...
        'f_Hz', NaN, ...
        'I_target_A', NaN, ...
        'PF_target', NaN, ...
        'groups', repmat(emptyGroup, 1, 3));

    results = struct();
    results.parameters = params;
    results.selectedDeviceIds = allIds(selectedIndices);
    results.objectiveDescription = ...
        'J = ((I-I_target)/I_target)^2 + ((PF-PF_target)/PF_target)^2';
    results.devices = repmat(emptyDevice, 1, numel(selectedIndices));

    %% 逐台设备、逐组求最优继电器状态
    for outputIndex = 1:numel(selectedIndices)
        deviceIndex = selectedIndices(outputIndex);
        device = params.devices(deviceIndex);
        validate_one_device(device, deviceIndex);

        omega = 2 * pi * device.f_Hz;
        groupResults = repmat(emptyGroup, 1, 3);

        for groupIndex = 1:3
            g = device.groups(groupIndex);
            R_values = g.R_ohm(:);
            L_values = g.L_H(:);

            %% A. 计算所有电阻继电器组合的并联等效电阻
            % R_parallel = 1 / (1/R0 + sum(closed_Rj / Rj))
            conductanceAll = 1 / g.R0_ohm + double(rClosedBits) * (1 ./ R_values);
            R_parallel_all = 1 ./ conductanceAll;

            %% B. 计算所有电感组合的总电感和绕组串联电阻
            % lIncludedBits=true 表示该节线圈投入；其电感及铜阻均计入。
            L_active_all = double(lIncludedBits) * L_values;
            L_total_all = g.Ls_H + L_active_all;

            if isfield(g, 'Lser_ohm') && ~isempty(g.Lser_ohm)
                % 逐节模型：继电器短接哪一节，该节绕组电阻也同时旁路。
                R_winding_all = double(lIncludedBits) * g.Lser_ohm(:);
                windingModel = '逐节 Lser_ohm';
            elseif isfield(g, 'Rser_ohm') && ~isempty(g.Rser_ohm)
                % 退化近似：没有逐节电阻数据时，将整链内阻视为恒定串联电阻。
                R_winding_all = repmat(g.Rser_ohm, nLComb, 1);
                windingModel = '恒定 Rser_ohm 近似';
            else
                R_winding_all = zeros(nLComb, 1);
                windingModel = '未计入电感绕组电阻';
            end

            X_L_all = omega .* L_total_all;

            %% C. 穷举全部电阻×电感组合
            bestJ = inf;
            bestRIndex = 1;
            bestLIndex = 1;
            bestCurrent = NaN;
            bestPF = NaN;
            bestRTotal = NaN;
            bestZ = NaN;

            for rIndex = 1:nRComb
                % 总串联电阻 = 电阻并联网络等效电阻 + 当前投入电感的绕组电阻。
                R_total_all = R_parallel_all(rIndex) + R_winding_all;
                Z_abs_all = sqrt(R_total_all.^2 + X_L_all.^2);
                currentAll = device.V_rms ./ Z_abs_all;
                PF_all = R_total_all ./ Z_abs_all;

                J_all = ((currentAll - device.I_target_A) ./ device.I_target_A).^2 + ...
                        ((PF_all - device.PF_target) ./ device.PF_target).^2;

                [localBestJ, lIndex] = min(J_all);
                if localBestJ < bestJ
                    bestJ = localBestJ;
                    bestRIndex = rIndex;
                    bestLIndex = lIndex;
                    bestCurrent = currentAll(lIndex);
                    bestPF = PF_all(lIndex);
                    bestRTotal = R_total_all(lIndex);
                    bestZ = Z_abs_all(lIndex);
                end
            end

            %% D. 保存该组最优状态和预测结果
            resistorClosed = rClosedBits(bestRIndex, :);
            inductorClosed = ~lIncludedBits(bestLIndex, :); % CLOSED=短接
            bestRparallel = R_parallel_all(bestRIndex);
            bestRwinding = R_winding_all(bestLIndex);
            bestLtotal = L_total_all(bestLIndex);
            bestX = omega * bestLtotal;
            bestP = bestCurrent^2 * bestRTotal;

            oneGroup = emptyGroup;
            if isfield(g, 'name') && ~isempty(g.name)
                oneGroup.name = g.name;
            else
                oneGroup.name = sprintf('第%d组', groupIndex);
            end
            oneGroup.resistorRelayClosed = resistorClosed;
            oneGroup.resistorRelayState = relay_state_names(resistorClosed);
            oneGroup.inductorRelayClosed = inductorClosed;
            oneGroup.inductorRelayState = relay_state_names(inductorClosed);
            oneGroup.parallelResistanceOhm = bestRparallel;
            oneGroup.inductorWindingResistanceOhm = bestRwinding;
            oneGroup.equivalentResistanceOhm = bestRTotal;
            oneGroup.totalInductanceH = bestLtotal;
            oneGroup.inductiveReactanceOhm = bestX;
            oneGroup.impedanceMagnitudeOhm = bestZ;
            oneGroup.currentRmsA = bestCurrent;
            oneGroup.powerFactor = bestPF;
            oneGroup.realPowerW = bestP;
            oneGroup.objectiveJ = bestJ;
            groupResults(groupIndex) = oneGroup;

            fprintf('\n--- %s 第%d组计算完成（%s）---\n', ...
                get_device_name(device, deviceIndex), groupIndex, windingModel);
            fprintf('  预测电流 I       = %.9g A rms（目标 %.9g A）\n', ...
                bestCurrent, device.I_target_A);
            fprintf('  预测功率因数 PF  = %.9g（目标 %.9g）\n', ...
                bestPF, device.PF_target);
            fprintf('  并联电阻 Rparallel = %.9g ohm\n', bestRparallel);
            fprintf('  电感绕组电阻      = %.9g ohm\n', bestRwinding);
            fprintf('  总等效电阻 Rtotal = %.9g ohm\n', bestRTotal);
            fprintf('  总电感 Ltotal     = %.9g mH（含 Ls）\n', bestLtotal * 1e3);
            fprintf('  感抗 X_L           = %.9g ohm\n', bestX);
            fprintf('  阻抗幅值 |Z|       = %.9g ohm\n', bestZ);
            fprintf('  有功功率 P         = %.9g W\n', bestP);
            fprintf('  目标函数 J         = %.12g\n', bestJ);
            fprintf('  电阻继电器 R1~R10（CLOSED=投入）：%s\n', ...
                sprintf('%d ', resistorClosed));
            fprintf('  电感继电器 L1~L11（CLOSED=短接）：%s\n', ...
                sprintf('%d ', inductorClosed));
        end

        oneDevice = emptyDevice;
        oneDevice.deviceId = device.id;
        oneDevice.name = get_device_name(device, deviceIndex);
        oneDevice.V_rms = device.V_rms;
        oneDevice.f_Hz = device.f_Hz;
        oneDevice.I_target_A = device.I_target_A;
        oneDevice.PF_target = device.PF_target;
        oneDevice.groups = groupResults;
        results.devices(outputIndex) = oneDevice;
    end
end


function validate_device_collection(p)
% 检查设备集合结构，以及设备编号是否唯一。
    if ~isstruct(p) || ~isfield(p, 'devices') || ~isstruct(p.devices) || isempty(p.devices)
        error('acload_relay:InvalidParameters', ...
            '参数必须包含非空结构体数组 params.devices。');
    end
    if ~isfield(p.devices, 'id')
        error('acload_relay:MissingDeviceId', '每台设备必须设置 id。');
    end

    ids = zeros(1, numel(p.devices));
    for k = 1:numel(p.devices)
        id = p.devices(k).id;
        if ~is_positive_integer_scalar(id)
            error('acload_relay:InvalidDeviceId', '第%d台设备的 id 必须是正整数。', k);
        end
        ids(k) = id;
    end
    if numel(unique(ids)) ~= numel(ids)
        error('acload_relay:DuplicateDeviceId', 'params.devices 中的 id 不能重复。');
    end
end


function validate_one_device(d, deviceIndex)
% 检查单台设备的电源目标和三组器件参数。
    if ~isfield(d, 'V_rms') || ~is_positive_finite_scalar(d.V_rms)
        error('acload_relay:InvalidVoltage', ...
            '设备%d的 V_rms 必须是有限正数。', deviceIndex);
    end
    if ~isfield(d, 'f_Hz') || ~is_positive_finite_scalar(d.f_Hz)
        error('acload_relay:InvalidFrequency', ...
            '设备%d的 f_Hz 必须是有限正数。', deviceIndex);
    end
    if ~isfield(d, 'I_target_A') || ~is_positive_finite_scalar(d.I_target_A)
        error('acload_relay:InvalidTargetCurrent', ...
            '设备%d的 I_target_A 必须是有限正数。', deviceIndex);
    end
    if ~isfield(d, 'PF_target') || ~is_positive_finite_scalar(d.PF_target) || d.PF_target > 1
        error('acload_relay:InvalidTargetPF', ...
            '设备%d的 PF_target 必须满足 0 < PF_target <= 1。', deviceIndex);
    end
    if ~isfield(d, 'groups') || ~isstruct(d.groups) || numel(d.groups) ~= 3
        error('acload_relay:InvalidGroups', ...
            '设备%d的 groups 必须恰好包含3组参数。', deviceIndex);
    end

    for groupIndex = 1:3
        g = d.groups(groupIndex);
        if ~isfield(g, 'R0_ohm') || ~is_positive_finite_scalar(g.R0_ohm)
            error('acload_relay:InvalidR0', ...
                '设备%d第%d组的 R0_ohm 必须是有限正数。', deviceIndex, groupIndex);
        end
        if ~isfield(g, 'R_ohm') || ~is_positive_finite_vector(g.R_ohm, 10)
            error('acload_relay:InvalidResistors', ...
                '设备%d第%d组的 R_ohm 必须包含10个有限正数。', deviceIndex, groupIndex);
        end
        if ~isfield(g, 'L_H') || ~is_positive_finite_vector(g.L_H, 11)
            error('acload_relay:InvalidInductors', ...
                '设备%d第%d组的 L_H 必须包含11个有限正数（单位H）。', deviceIndex, groupIndex);
        end
        if ~isfield(g, 'Ls_H') || ~is_nonnegative_finite_scalar(g.Ls_H)
            error('acload_relay:InvalidLineInductance', ...
                '设备%d第%d组的 Ls_H 必须是有限非负数。', deviceIndex, groupIndex);
        end
        if isfield(g, 'Lser_ohm') && ~isempty(g.Lser_ohm) && ...
                ~is_nonnegative_finite_vector(g.Lser_ohm, 11)
            error('acload_relay:InvalidInductorResistance', ...
                '设备%d第%d组的 Lser_ohm 必须包含11个有限非负数。', deviceIndex, groupIndex);
        end
        if (~isfield(g, 'Lser_ohm') || isempty(g.Lser_ohm)) && ...
                isfield(g, 'Rser_ohm') && ~is_positive_finite_scalar(g.Rser_ohm)
            error('acload_relay:InvalidSeriesResistance', ...
                '设备%d第%d组的 Rser_ohm 必须是有限正数。', deviceIndex, groupIndex);
        end
    end
end


function tf = is_positive_finite_scalar(x)
    tf = isnumeric(x) && isreal(x) && isscalar(x) && ...
        ~isnan(x) && ~isinf(x) && x > 0;
end


function tf = is_nonnegative_finite_scalar(x)
    tf = isnumeric(x) && isreal(x) && isscalar(x) && ...
        ~isnan(x) && ~isinf(x) && x >= 0;
end


function tf = is_positive_integer_scalar(x)
    tf = is_positive_finite_scalar(x) && x == fix(x);
end


function tf = is_positive_finite_vector(x, expectedCount)
    tf = isnumeric(x) && isreal(x) && isvector(x) && numel(x) == expectedCount && ...
        all(~isnan(x(:))) && all(~isinf(x(:))) && all(x(:) > 0);
end


function tf = is_nonnegative_finite_vector(x, expectedCount)
    tf = isnumeric(x) && isreal(x) && isvector(x) && numel(x) == expectedCount && ...
        all(~isnan(x(:))) && all(~isinf(x(:))) && all(x(:) >= 0);
end


function states = relay_state_names(closedMask)
% 将逻辑继电器状态转换成 'CLOSED'/'OPEN' 字符单元数组。
    states = repmat({'OPEN'}, size(closedMask));
    states(closedMask) = repmat({'CLOSED'}, 1, nnz(closedMask));
end


function name = get_device_name(device, fallbackIndex)
    if isfield(device, 'name') && ~isempty(device.name)
        name = device.name;
    else
        name = sprintf('设备%d', fallbackIndex);
    end
end
