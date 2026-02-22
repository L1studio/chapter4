clc;
clear;
clear global;
close all;

% --- 1. 获取系统核心数并确认 ---
num_cores = feature('numcores');
fprintf('系统检测到的逻辑核心数: %d\n', num_cores);

% --- 2. 明确配置并行池 ---
p = gcp('nocreate'); 

if isempty(p)
    fprintf('启动新的并行池...\n');
    % 启动本地并行池 ('local')
    % num_cores: 指定开启的 worker (工作进程) 数量等于核心数，充分利用算力
    % 'IdleTimeout', 120: 设置空闲超时时间为 120 分钟，防止跑长任务时池子自动关闭
    parpool('local', num_cores, 'IdleTimeout', 120);
    fprintf('已启动新的并行池，NumWorkers: %d\n', num_cores);
else
    % 如果已有并行池，检查其 Worker 数量是否与当前核心数一致
    if p.NumWorkers ~= num_cores
        fprintf('现有并行池的 NumWorkers (%d) 与系统核心数 (%d) 不符，关闭并重新创建。\n', p.NumWorkers, num_cores);
        delete(p); % 关闭旧池
        parpool('local', num_cores, 'IdleTimeout', 120); % 开启新池
    else
        fprintf('现有并行池已配置为 %d 个 worker。\n', p.NumWorkers);
    end
end

% 再次获取并行池对象，确认状态
p = gcp();
% 打印最终确认的 Worker 数量和集群类型
fprintf('当前并行池状态：NumWorkers = %d, Cluster = %s\n', p.NumWorkers, p.Cluster.Type);

% --- 3. 配置每个 worker 只用 1 个线程 (防止过度订阅) ---
% 并行计算中，每个 Worker 是一个独立的 MATLAB 进程。
% 如果 Worker 内部再自动进行多线程运算（如矩阵乘法），会导致 CPU 争抢（Over-subscription），
% 反而降低总效率。因此强制每个 Worker 只用单线程。

% 设置 OpenMP 环境变量为 1 线程
parfevalOnAll(@setenv, 0, 'OMP_NUM_THREADS', '1');
% 设置 Intel MKL 数学库环境变量为 1 线程
parfevalOnAll(@setenv, 0, 'MKL_NUM_THREADS', '1');
% 设置 MATLAB 内部计算引擎最大线程数为 1
parfevalOnAll(@maxNumCompThreads, 0, 1);

% --- 4. 主 MATLAB 进程的线程配置 (可选) ---
% 主进程（负责调度和汇总）可以使用多线程，因为它不参与循环内的繁重计算
maxNumCompThreads(num_cores);
setenv('OMP_NUM_THREADS', num2str(num_cores));
setenv('MKL_NUM_THREADS', num2str(num_cores));
% 禁用 MKL 的动态线程调整，保证配置生效
setenv('MKL_DYNAMIC', 'FALSE');