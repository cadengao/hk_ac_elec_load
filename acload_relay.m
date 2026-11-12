function results = acload_relay(deviceId, params)
%ACLOAD_RELAY 求解指定设备或全部设备的交流电子负载继电器组合
%
% 调用方式：
%   results = acload_relay();          % 读取参数文件，求解全部设备
%   results = acload_relay(1);         % 只求解设备1
%   results = acload_relay(2);         % 只求解设备2
%   p = acload_params();
%   results = acload_relay([], p);     % 使用自定义参数，求解全部设备
%   results = acload_relay(2, p);      % 使用自定义参数，只求解设备2
%
% 参数组织：每台设备有独立的 V、f、目标电流、目标PF及3组器件参数。
% 默认参数由 acload_params.m 提供。deviceId 是 params.devices 中的 id。
%
% 电路模型：R0固定接入，R1~R10按继电器状态并联投入；L1~L11串联，
% 每个电感可由继电器短接；并联电阻网络整体与电感链串联。
% 假设理想正弦交流电压源，忽略内阻、接触电阻和寄生参数。
%
% 优化目标（电流和PF等权）：
%   J = ((I-I_target)/I_target)^2 + ((PF-PF_target)/PF_target)^2
%
% 每组穷举 2^10 种电阻状态与 2^11 种电感状态，共 2,097,152 种组合。
%
% 结果：results.devices(k) 对应本次求解的第k个输出设备；其中 deviceId
% 保存原始设备编号。每台设备的 groups(1:3) 保存各组最优状态及预测值。
%
% 状态语义（打印与 relayState 字段中 1=闭合、0=断开）：
%   电阻继电器闭合(1) = Rj投入工作；断开(0) = Rj退出。
%   电感继电器断开(0) = Lj投入工作；闭合(1) = Lj被短接退出。

if nargin < 1
    deviceId = [];
end
if nargin < 2 || isempty(params)
    params = acload_params();
end

validate_device_collection(params);

allIds = [params.devices.id];
if isempty(deviceId)
    selectedIndices = 1:numel(params.devices);
else
    if ~isnumeric(deviceId) || ~isreal(deviceId) || ~isscalar(deviceId) || ...
            isnan(deviceId) || isinf(deviceId) || deviceId ~= fix(deviceId)
        error('acload_relay:InvalidDeviceId', 'deviceId 必须是设备编号对应的整数标量，或留空以求解全部设备。');
    end
    selectedIndices = find(allIds == deviceId, 1);
    if isempty(selectedIndices)
        error('acload_relay:UnknownDeviceId', '参数文件中不存在设备编号 %g。', deviceId);
    end
end

nR = 10;
nL = 11;
nRComb = 2^nR;
nLComb = 2^nL;

% 预生成全部电阻继电器状态。第k列对应Rk，true表示闭合投入。
rMask = uint16((0:(nRComb - 1))');
rClosedBits = false(nRComb, nR);
for k = 1:nR
    rClosedBits(:, k) = bitget(rMask, k) ~= 0;
end

% 预生成全部电感继电器状态。这里先生成电感是否计入链路的掩码；
% true表示继电器断开、电感计入串联链，最终闭合状态取反。
lMask = uint16((0:(nLComb - 1))');
lIncludedBits = false(nLComb, nL);
for k = 1:nL
    lIncludedBits(:, k) = bitget(lMask, k) ~= 0;
end

emptyGroup = struct( ...
    'groupId', NaN, ...
    'resistorRelayClosed', false(1, nR), ...
    'resistorRelayState', {cell(1, nR)}, ...
    'inductorRelayClosed', false(1, nL), ...
    'inductorRelayState', {cell(1, nL)}, ...
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
results.devices = repmat(emptyDevice, 1, numel(selectedIndices));
results.objectiveDescription = ...
    'J = ((I-I_target)/I_target)^2 + ((PF-PF_target)/PF_target)^2';

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

        %% 1. 计算1024种电阻组合的并联等效电阻
        % G_eq = 1/R0 + sum(继电器闭合的支路所对应的1/Rj)
        conductanceAll = 1 / g.R0_ohm + double(rClosedBits) * (1 ./ R_values);
        R_eq_all = 1 ./ conductanceAll;

        %% 2. 计算2048种电感组合的串联总电感
        % lIncludedBits=true表示继电器断开，对应电感计入串联链。
        L_total_all = double(lIncludedBits) * L_values;
        X_L_all = omega .* L_total_all.';

        %% 3. 对电阻和电感组合进行完整搜索
        bestJ = inf;
        bestRIndex = 1;
        bestLIndex = 1;
        bestCurrent = NaN;
        bestPF = NaN;

        for rIndex = 1:nRComb
            R_eq = R_eq_all(rIndex);
            Z_abs_all = sqrt(R_eq.^2 + X_L_all.^2);
            currentAll = device.V_rms ./ Z_abs_all;
            PF_all = R_eq ./ Z_abs_all;

            J_all = ((currentAll - device.I_target_A) ./ device.I_target_A).^2 + ...
                    ((PF_all - device.PF_target) ./ device.PF_target).^2;

            [localBestJ, lIndex] = min(J_all);
            % 严格小于：若多个组合并列，保留枚举顺序中最先出现的组合。
            if localBestJ < bestJ
                bestJ = localBestJ;
                bestRIndex = rIndex;
                bestLIndex = lIndex;
                bestCurrent = currentAll(lIndex);
                bestPF = PF_all(lIndex);
            end
        end

        %% 4. 还原继电器状态并计算输出量
        resistorClosed = rClosedBits(bestRIndex, :);
        inductorClosed = ~lIncludedBits(bestLIndex, :); % 闭合=短接
        bestR = R_eq_all(bestRIndex);
        bestL = L_total_all(bestLIndex);
        bestX = omega * bestL;
        bestZ = sqrt(bestR^2 + bestX^2);
        bestP = bestCurrent^2 * bestR;

        oneGroup = emptyGroup;
        if isfield(g, 'id') && ~isempty(g.id)
            oneGroup.groupId = g.id;
        else
            oneGroup.groupId = groupIndex;
        end
        oneGroup.resistorRelayClosed = resistorClosed;
        oneGroup.resistorRelayState = relay_state_names(resistorClosed);
        oneGroup.inductorRelayClosed = inductorClosed;
        oneGroup.inductorRelayState = relay_state_names(inductorClosed);
        oneGroup.equivalentResistanceOhm = bestR;
        oneGroup.totalInductanceH = bestL;
        oneGroup.inductiveReactanceOhm = bestX;
        oneGroup.impedanceMagnitudeOhm = bestZ;
        oneGroup.currentRmsA = bestCurrent;
        oneGroup.powerFactor = bestPF;
        oneGroup.realPowerW = bestP;
        oneGroup.objectiveJ = bestJ;
        groupResults(groupIndex) = oneGroup;
    end

    oneDevice = emptyDevice;
    oneDevice.deviceId = device.id;
    if isfield(device, 'name') && ~isempty(device.name)
        oneDevice.name = device.name;
    else
        oneDevice.name = sprintf('设备%g', device.id);
    end
    oneDevice.V_rms = device.V_rms;
    oneDevice.f_Hz = device.f_Hz;
    oneDevice.I_target_A = device.I_target_A;
    oneDevice.PF_target = device.PF_target;
    oneDevice.groups = groupResults;
    results.devices(outputIndex) = oneDevice;
end

print_results(results);

end


function validate_device_collection(p)
% 检查设备集合结构，以及设备编号是否唯一。
if ~isstruct(p) || ~isfield(p, 'devices') || ~isstruct(p.devices) || isempty(p.devices)
    error('acload_relay:InvalidParameters', '参数必须包含非空结构体数组 params.devices。');
end

if ~isfield(p.devices, 'id')
    error('acload_relay:MissingDeviceId', '每台设备必须设置正整数 id。');
end

ids = zeros(1, numel(p.devices));
for k = 1:numel(p.devices)
    id = p.devices(k).id;
    if ~isnumeric(id) || ~isreal(id) || ~isscalar(id) || isnan(id) || ...
            isinf(id) || id <= 0 || id ~= fix(id)
        error('acload_relay:InvalidDeviceId', '第%d台设备的 id 必须是正整数。', k);
    end
    ids(k) = id;
end
if numel(unique(ids)) ~= numel(ids)
    error('acload_relay:DuplicateDeviceId', 'params.devices 中的 id 不能重复。');
end
end


function validate_one_device(d, deviceIndex)
% 检查单台设备自己的交流源、目标值及三组器件参数。
if ~isfield(d, 'V_rms') || ~is_positive_finite_scalar(d.V_rms)
    error('acload_relay:InvalidVoltage', '设备%d的 V_rms 必须是有限正数。', deviceIndex);
end
if ~isfield(d, 'f_Hz') || ~is_positive_finite_scalar(d.f_Hz)
    error('acload_relay:InvalidFrequency', '设备%d的 f_Hz 必须是有限正数。', deviceIndex);
end
if ~isfield(d, 'I_target_A') || ~is_positive_finite_scalar(d.I_target_A)
    error('acload_relay:InvalidTargetCurrent', '设备%d的 I_target_A 必须是有限正数。', deviceIndex);
end
if ~isfield(d, 'PF_target') || ~is_positive_finite_scalar(d.PF_target) || d.PF_target > 1
    error('acload_relay:InvalidTargetPF', '设备%d的 PF_target 必须满足 0 < PF_target <= 1。', deviceIndex);
end
if ~isfield(d, 'groups') || ~isstruct(d.groups) || numel(d.groups) ~= 3
    error('acload_relay:InvalidGroups', '设备%d的 groups 必须恰好包含3组参数。', deviceIndex);
end

for groupIndex = 1:3
    g = d.groups(groupIndex);
    if ~isfield(g, 'R0_ohm') || ~is_positive_finite_scalar(g.R0_ohm)
        error('acload_relay:InvalidR0', '设备%d第%d组的 R0_ohm 必须是有限正数。', deviceIndex, groupIndex);
    end
    if ~isfield(g, 'R_ohm') || ~is_positive_finite_vector(g.R_ohm, 10)
        error('acload_relay:InvalidResistors', '设备%d第%d组的 R_ohm 必须包含10个有限正数。', deviceIndex, groupIndex);
    end
    if ~isfield(g, 'L_H') || ~is_positive_finite_vector(g.L_H, 11)
        error('acload_relay:InvalidInductors', '设备%d第%d组的 L_H 必须包含11个有限正数（单位H）。', deviceIndex, groupIndex);
    end
end
end


function tf = is_positive_finite_scalar(x)
tf = isnumeric(x) && isreal(x) && isscalar(x) && ~isnan(x) && ~isinf(x) && x > 0;
end


function tf = is_positive_finite_vector(x, expectedCount)
tf = isnumeric(x) && isreal(x) && isvector(x) && numel(x) == expectedCount && ...
     all(~isnan(x(:))) && all(~isinf(x(:))) && all(x(:) > 0);
end


function states = relay_state_names(closedMask)
% 返回cell数组，每个元素为 '1'（闭合）或 '0'（断开）。
states = repmat({'0'}, size(closedMask));
states(closedMask) = repmat({'1'}, 1, nnz(closedMask));
end


function print_results(results)
% 在命令窗口打印本次求解设备的目标、预测量和各继电器状态。
fprintf('\n============================================================\n');
fprintf('交流电子负载继电器求解结果\n');
fprintf('判据：%s\n', results.objectiveDescription);
fprintf('============================================================\n');

for deviceIndex = 1:numel(results.devices)
    d = results.devices(deviceIndex);
    fprintf('\n################ %s（ID=%g）################\n', d.name, d.deviceId);
    fprintf('V = %.6g Vrms, f = %.6g Hz, I_target = %.6g A, PF_target = %.6g\n', ...
        d.V_rms, d.f_Hz, d.I_target_A, d.PF_target);

    for groupIndex = 1:numel(d.groups)
        g = d.groups(groupIndex);
        fprintf('\n--- 第%g组 (id=%g) ---\n', groupIndex, g.groupId);
        fprintf('预测电流 I       = %.9g A rms\n', g.currentRmsA);
        fprintf('预测功率因数 PF  = %.9g\n', g.powerFactor);
        fprintf('预测有功功率 P   = %.9g W\n', g.realPowerW);
        fprintf('等效电阻 R_eq    = %.9g ohm\n', g.equivalentResistanceOhm);
        fprintf('总电感 L_total   = %.9g H\n', g.totalInductanceH);
        fprintf('感抗 X_L         = %.9g ohm\n', g.inductiveReactanceOhm);
        fprintf('阻抗幅值 |Z|     = %.9g ohm\n', g.impedanceMagnitudeOhm);
        fprintf('目标函数 J       = %.12g\n', g.objectiveJ);

        fprintf('电阻继电器（1=闭合=电阻投入工作，0=断开）：\n');
        for k = 1:numel(g.resistorRelayState)
            fprintf('  R%-2d: %s\n', k, g.resistorRelayState{k});
        end

        fprintf('电感继电器（0=断开=电感投入工作，1=闭合=电感被短接退出）：\n');
        for k = 1:numel(g.inductorRelayState)
            fprintf('  L%-2d: %s\n', k, g.inductorRelayState{k});
        end
    end
end
fprintf('\n');
end
