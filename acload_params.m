function params = acload_params()
%ACLOAD_PARAMS 两台交流电子负载的实测参数配置
%
% 单位：
%   V_rms、I_target_A：V、A
%   f_Hz：Hz
%   R0_ohm、R_ohm、Rser_ohm：ohm
%   Ls_H、L_H：H
%
% 说明：
%   R_ohm 为根据桥测等效值反算后的单只电阻实际值。
%   L_H 为单只电感测量值减去线路寄生电感 Ls_H 后的值。
%   Rser_ohm 为全部11只电感均投入时反算得到的总串联电阻。
%   当前按固定 Rser_ohm 近似处理；精确模型需要每只电感的直流电阻。
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
params.devices(1).groups(1).Rser_ohm = 0.8732639858;
params.devices(1).groups(1).Ls_H = 6.7e-6;
params.devices(1).groups(1).R_ohm = [406.69, 204.36, 102.64, 102.64, 102.52, 102.39, 22.10, 22.10, 22.10, 22.10];
params.devices(1).groups(1).L_H = [0.10460, 0.19830, 0.39830, 0.80380, 1.62330, 3.04330, 5.67830, 9.92030, 10.09330, 10.11330, 19.97130] * 1e-3;

% 设备1 - 第2组
params.devices(1).groups(2).id = 2;
params.devices(1).groups(2).R0_ohm = 998.5;
params.devices(1).groups(2).Rser_ohm = 0.5897840717;
params.devices(1).groups(2).Ls_H = 6.93e-6;
params.devices(1).groups(2).R_ohm = [405.16, 203.88, 102.56, 102.81, 102.56, 103.05, 22.40, 22.40, 22.40, 22.51];
params.devices(1).groups(2).L_H = [0.10457, 0.20847, 0.40107, 0.77577, 1.57207, 2.97107, 5.57807, 9.95307, 9.91307, 10.09307, 20.03307] * 1e-3;

% 设备1 - 第3组
params.devices(1).groups(3).id = 3;
params.devices(1).groups(3).R0_ohm = 992.2;
params.devices(1).groups(3).Rser_ohm = 0.5275754617;
params.devices(1).groups(3).Ls_H = 6.88e-6;
params.devices(1).groups(3).R_ohm = [404.74, 204.38, 103.19, 102.71, 102.95, 103.07, 22.42, 22.82, 22.55, 22.18];
params.devices(1).groups(3).L_H = [0.09242, 0.18872, 0.39052, 0.79372, 1.55562, 2.98012, 5.58812, 9.95812, 9.96812, 9.89612, 20.01312] * 1e-3;

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
params.devices(2).groups(1).Rser_ohm = 2.7470902233;
params.devices(2).groups(1).Ls_H = 6.7e-6;
params.devices(2).groups(1).R_ohm = [398.78, 200.62, 100.19, 100.07, 100.19, 100.19, 19.84, 19.94, 20.05, 19.74];
params.devices(2).groups(1).L_H = [0.09400, 0.18890, 0.38270, 0.78230, 1.56170, 2.95100, 5.97330, 10.00930, 9.94030, 10.01130, 19.99330] * 1e-3;

% 设备2 - 第2组
params.devices(2).groups(2).id = 2;
params.devices(2).groups(2).R0_ohm = 995.5;
params.devices(2).groups(2).Rser_ohm = 2.7586860180;
params.devices(2).groups(2).Ls_H = 6.65e-6;
params.devices(2).groups(2).R_ohm = [398.81, 200.00, 100.08, 99.72, 99.84, 99.96, 19.83, 19.78, 19.78, 19.93];
params.devices(2).groups(2).L_H = [0.09495, 0.19185, 0.38735, 0.77855, 1.59335, 2.98935, 5.57035, 9.97635, 9.92135, 9.88335, 19.73935] * 1e-3;

% 设备2 - 第3组
params.devices(2).groups(3).id = 3;
params.devices(2).groups(3).R0_ohm = 995.7;
params.devices(2).groups(3).Rser_ohm = 2.7395482413;
params.devices(2).groups(3).Ls_H = 6.9e-6;
params.devices(2).groups(3).R_ohm = [398.82, 200.16, 99.50, 100.23, 100.11, 100.11, 19.95, 20.06, 19.95, 19.85];
params.devices(2).groups(3).L_H = [0.09770, 0.19430, 0.38310, 0.78340, 1.57910, 2.96310, 5.52010, 10.03510, 9.77310, 10.02910, 20.01310] * 1e-3;

end