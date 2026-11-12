function params = acload_params()
%ACLOAD_PARAMS 两台交流电子负载的独立参数配置
%   实测参数只在本文件中修改，求解程序 acload_relay.m 无需修改。
%
% 数据组织：
%   params.devices(1)  -> 设备1的独立参数和目标值
%   params.devices(2)  -> 设备2的独立参数和目标值
%   每台设备包含3组负载通道（groups(k).id = k），每组有独立的 R0、R1~R10、L1~L11。
%
% 单位：
%   V_rms       电压有效值，V
%   f_Hz        频率，Hz
%   I_target_A  目标电流有效值，A
%   PF_target   目标功率因数，无量纲
%   R0_ohm/R_ohm 电阻，ohm
%   L_H         电感，H
%
% 继电器语义：
%   电阻继电器 CLOSED = 对应电阻投入并联网络；OPEN = 退出。
%   电感继电器 CLOSED = 对应电感被短接；OPEN = 对应电感计入串联链。

%% 设备1
params.devices(1).id = 1;
params.devices(1).name = '设备1';

% 设备1自己的交流源参数和优化目标（与设备2完全独立）
params.devices(1).V_rms      = 28;
params.devices(1).f_Hz       = 400;
params.devices(1).I_target_A = 0.25;
params.devices(1).PF_target  = 0.6;

% 设备1 - 第1组
params.devices(1).groups(1).id = 1;
params.devices(1).groups(1).R0_ohm = 1000;
params.devices(1).groups(1).R_ohm = [400, 200, 100, 100, 100, 100, 20, 20, 20, 20];
params.devices(1).groups(1).L_H = [0.1, 0.2, 0.4, 0.8, 1.6, 3.0, 5.6, 10, 10, 10, 20] * 1e-3;

% 设备1 - 第2组
params.devices(1).groups(2).id = 2;
params.devices(1).groups(2).R0_ohm = 1000;
params.devices(1).groups(2).R_ohm = [400, 200, 100, 100, 100, 100, 20, 20, 20, 20];
params.devices(1).groups(2).L_H = [0.1, 0.2, 0.4, 0.8, 1.6, 3.0, 5.6, 10, 10, 10, 20] * 1e-3;

% 设备1 - 第3组
params.devices(1).groups(3).id = 3;
params.devices(1).groups(3).R0_ohm = 1000;
params.devices(1).groups(3).R_ohm = [400, 200, 100, 100, 100, 100, 20, 20, 20, 20];
params.devices(1).groups(3).L_H = [0.1, 0.2, 0.4, 0.8, 1.6, 3.0, 5.6, 10, 10, 10, 20] * 1e-3;

%% 设备2
params.devices(2).id = 2;
params.devices(2).name = '设备2';

% 以下是设备2自己的交流源参数和优化目标。
% 当前先填理论默认值；设备2的实测值应独立填写，不要引用设备1的变量。
params.devices(2).V_rms      = 28;
params.devices(2).f_Hz       = 400;
params.devices(2).I_target_A = 0.25;
params.devices(2).PF_target  = 0.6;

% 设备2 - 第1组
params.devices(2).groups(1).id = 1;
params.devices(2).groups(1).R0_ohm = 1000;
params.devices(2).groups(1).R_ohm = [400, 200, 100, 100, 100, 100, 20, 20, 20, 20];
params.devices(2).groups(1).L_H = [0.1, 0.2, 0.4, 0.8, 1.6, 3.0, 5.6, 10, 10, 10, 20] * 1e-3;

% 设备2 - 第2组
params.devices(2).groups(2).id = 2;
params.devices(2).groups(2).R0_ohm = 1000;
params.devices(2).groups(2).R_ohm = [400, 200, 100, 100, 100, 100, 20, 20, 20, 20];
params.devices(2).groups(2).L_H = [0.1, 0.2, 0.4, 0.8, 1.6, 3.0, 5.6, 10, 10, 10, 20] * 1e-3;

% 设备2 - 第3组
params.devices(2).groups(3).id = 3;
params.devices(2).groups(3).R0_ohm = 1000;
params.devices(2).groups(3).R_ohm = [400, 200, 100, 100, 100, 100, 20, 20, 20, 20];
params.devices(2).groups(3).L_H = [0.1, 0.2, 0.4, 0.8, 1.6, 3.0, 5.6, 10, 10, 10, 20] * 1e-3;

end
