function params = acload_params()
%ACLOAD_PARAMS 两台交流电子负载的实测参数配置
%
% 单位：
%   V_rms、I_target_A：V、A
%   f_Hz：Hz
%   R0_ohm、R_ohm、Rser_ohm、Lser_ohm：ohm
%   Ls_H、L_H：H
%
% 实测工况（数字电桥；对应表内行标题）：
%   R0        ：固定电阻单独测量。
%   R1~R10    ：电感全接（11 节全部串入）、只接一只电阻 → 读数 = R0∥Ri + 电感链内阻。
%   Rs        ：电阻全接、电感全接 → 读数 = R0∥R1∥…∥R10 + 电感链内阻。
%   Ls        ：电阻全接、电感全断（全部被短接）→ 仅剩线路寄生电感。
%   L1~L11    ：电阻全接、只接一只电感 → 读数 = Lj + Ls。
%
% 反推（记 d = 11 节电感全部投入时的总线内阻）：
%   由单只电阻读数：1/Ri = 1/(Ri_meas-d) - 1/R0
%   代入 Rs：Rs = d + 1/( Σ 1/(Ri_meas-d) - 9/R0 )
%   其中 Σ 为 i=1,...,10。
%   注意：每项 1/(Ri_meas-d) 已经包含一份 1/R0；10 项求和后包含 10/R0，
%         实际电路中固定电阻 R0 只出现一次，因此应减去 9/R0。
%         不能再额外加 1/R0，否则会重复计入 R0。
%   电感：Lj = Lj_meas - Ls（Ls 只减一次，且始终在回路里，求解时再加回一次）。
%   电阻：Ri = 1/( 1/(Ri_meas-d) - 1/R0 )。
%   校验：Rser 由未四舍五入的原始测量值反求；文件中的 R_ohm 保留两位小数，
%         因此直接用本文件数组回算 Rs 会有舍入误差（六组最大约 0.0006 ohm）。
%         六组实测 Rs 分别为：5.070 / 4.833 / 4.780 / 6.600 / 6.600 / 6.600 ohm。
%
% Lser_ohm（逐节电感自身的内阻，1×11）：
%   电感继电器闭合会把该节线圈连同其铜阻一起旁路，所以回路里真正存在的串联内阻
%   是 Σ(投入那几节的内阻)，不是整条链的 d。逐节值按 r_j ∝ L_j 由 d 分摊，和为 d，
%   因此"全接"时复现 Rs、"全断"时只剩线路/触点等未建模电阻（此处忽略）。
%   这仍是对 r_j 的假设；若日后用万用表测得每节电感的直流电阻，直接替换该数组即可，
%   求解程序无需改动。删掉 Lser_ohm 则退化为"整链 d 恒定串联"的近似。
%
% 继电器语义：
%   电阻继电器 CLOSED：对应电阻投入并联网络。
%   电感继电器 CLOSED：对应电感被短接；OPEN：对应电感计入串联链。

%% 设备1
params.devices(1).id = 1;
params.devices(1).name = '设备1';
params.devices(1).V_rms = 28;
params.devices(1).f_Hz = 400;
params.devices(1).I_target_A = 0.25;
params.devices(1).PF_target = 0.6;

% 设备1 - 第1组
params.devices(1).groups(1).id = 1;
params.devices(1).groups(1).R0_ohm = 1005.0;
params.devices(1).groups(1).Rser_ohm = 0.6519527417;
params.devices(1).groups(1).Ls_H = 6.7e-6;
params.devices(1).groups(1).R_ohm = [407.12, 204.68, 102.91, 102.91, 102.78, 102.66, 22.33, 22.33, 22.33, 22.33];
params.devices(1).groups(1).L_H = [0.10460, 0.19830, 0.39830, 0.80380, 1.62330, 3.04330, 5.67830, 9.92030, 10.09330, 10.11330, 19.97130] * 1e-3;
params.devices(1).groups(1).Lser_ohm = [0.00110083, 0.00208694, 0.00419178, 0.00845933, 0.0170839, 0.0320282, 0.0597594, 0.104403, 0.106224, 0.106434, 0.210181];

% 设备1 - 第2组
params.devices(1).groups(2).id = 2;
params.devices(1).groups(2).R0_ohm = 998.5;
params.devices(1).groups(2).Rser_ohm = 0.3620498265;
params.devices(1).groups(2).Ls_H = 6.93e-6;
params.devices(1).groups(2).R_ohm = [405.61, 204.21, 102.84, 103.08, 102.84, 103.33, 22.64, 22.64, 22.64, 22.74];
params.devices(1).groups(2).L_H = [0.10457, 0.20847, 0.40107, 0.77577, 1.57207, 2.97107, 5.57807, 9.95307, 9.91307, 10.09307, 20.03307] * 1e-3;
params.devices(1).groups(2).Lser_ohm = [0.000614569, 0.0012252, 0.00235713, 0.00455929, 0.00923923, 0.0174613, 0.0327829, 0.0584953, 0.0582602, 0.0593181, 0.117737];

% 设备1 - 第3组
params.devices(1).groups(3).id = 3;
params.devices(1).groups(3).R0_ohm = 992.2;
params.devices(1).groups(3).Rser_ohm = 0.2972979542;
params.devices(1).groups(3).Ls_H = 6.88e-6;
params.devices(1).groups(3).R_ohm = [405.19, 204.72, 103.47, 102.99, 103.23, 103.35, 22.66, 23.06, 22.79, 22.42];
params.devices(1).groups(3).L_H = [0.09242, 0.18872, 0.39052, 0.79372, 1.55562, 2.98012, 5.58812, 9.95812, 9.96812, 9.89612, 20.01312] * 1e-3;
params.devices(1).groups(3).Lser_ohm = [0.000447316, 0.000913412, 0.00189013, 0.00384163, 0.00752926, 0.0144239, 0.0270467, 0.0481977, 0.0482461, 0.0478976, 0.0968643];

%% 设备2
params.devices(2).id = 2;
params.devices(2).name = '设备2';
params.devices(2).V_rms = 28;
params.devices(2).f_Hz = 400;
params.devices(2).I_target_A = 0.25;
params.devices(2).PF_target = 0.6;

% 设备2 - 第1组
params.devices(2).groups(1).id = 1;
params.devices(2).groups(1).R0_ohm = 998.3;
params.devices(2).groups(1).Rser_ohm = 2.559091505;
params.devices(2).groups(1).Ls_H = 6.7e-6;
params.devices(2).groups(1).R_ohm = [399.15, 200.90, 100.42, 100.30, 100.42, 100.42, 20.04, 20.14, 20.24, 19.93];
params.devices(2).groups(1).L_H = [0.09400, 0.18890, 0.38270, 0.78230, 1.56170, 2.95100, 5.97330, 10.00930, 9.94030, 10.01130, 19.99330] * 1e-3;
params.devices(2).groups(1).Lser_ohm = [0.00388693, 0.00781107, 0.0158248, 0.0323483, 0.0645768, 0.122025, 0.246998, 0.413888, 0.411034, 0.41397, 0.826729];

% 设备2 - 第2组
params.devices(2).groups(2).id = 2;
params.devices(2).groups(2).R0_ohm = 995.5;
params.devices(2).groups(2).Rser_ohm = 2.571286619;
params.devices(2).groups(2).Ls_H = 6.65e-6;
params.devices(2).groups(2).R_ohm = [399.18, 200.27, 100.31, 99.95, 100.07, 100.19, 20.02, 19.97, 19.97, 20.13];
params.devices(2).groups(2).L_H = [0.09495, 0.19185, 0.38735, 0.77855, 1.59335, 2.98935, 5.57035, 9.97635, 9.92135, 9.88335, 19.73935] * 1e-3;
params.devices(2).groups(2).Lser_ohm = [0.0039941, 0.00807022, 0.016294, 0.0327499, 0.0670247, 0.125748, 0.234318, 0.419658, 0.417344, 0.415746, 0.830341];

% 设备2 - 第3组
params.devices(2).groups(3).id = 3;
params.devices(2).groups(3).R0_ohm = 995.7;
params.devices(2).groups(3).Rser_ohm = 2.550334502;
params.devices(2).groups(3).Ls_H = 6.9e-6;
params.devices(2).groups(3).R_ohm = [399.19, 200.44, 99.73, 100.46, 100.33, 100.33, 20.15, 20.25, 20.15, 20.05];
params.devices(2).groups(3).L_H = [0.09770, 0.19430, 0.38310, 0.78340, 1.57910, 2.96310, 5.52010, 10.03510, 9.77310, 10.02910, 20.01310] * 1e-3;
params.devices(2).groups(3).Lser_ohm = [0.00406001, 0.00807431, 0.0159201, 0.0325549, 0.0656209, 0.123134, 0.229393, 0.417017, 0.40613, 0.416768, 0.831662];

end
