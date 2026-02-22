clc;clear;clear global;
close all;

% --- 1. 获取系统核心数并确认 ---
num_cores = feature('numcores');
fprintf('系统检测到的逻辑核心数: %d\n', num_cores);

% --- 2. 明确配置并行池 ---
p = gcp('nocreate'); % 尝试获取当前并行池
if isempty(p)
    % 如果没有并行池，则创建一个新的
    % 当 'local' 作为第一个参数时，第二个参数直接就是 worker 数量
    % 增加 IdleTimeout，避免长时间不活动自动关闭
    fprintf('启动新的并行池...\n');
    parpool('local', num_cores, 'IdleTimeout', 120);
    fprintf('已启动新的并行池，NumWorkers: %d\n', num_cores);
else
    % 如果已有并行池，检查其配置是否符合要求
    if p.NumWorkers ~= num_cores
        fprintf('现有并行池的 NumWorkers (%d) 与系统核心数 (%d) 不符，关闭并重新创建。\n', p.NumWorkers, num_cores);
        delete(p); % 关闭现有并行池
        parpool('local', num_cores, 'IdleTimeout', 120); % 重新创建
    else
        fprintf('现有并行池已配置为 %d 个 worker。\n', p.NumWorkers);
    end
end

% 再次获取并行池对象，确认状态
p = gcp();
fprintf('当前并行池状态：NumWorkers = %d, Cluster = %s\n', p.NumWorkers, p.Cluster.Type);

% --- 3. 配置每个 worker 只用 1 个线程 (防止过度订阅) ---
parfevalOnAll(@setenv, 0, 'OMP_NUM_THREADS', '1');
parfevalOnAll(@setenv, 0, 'MKL_NUM_THREADS', '1');
parfevalOnAll(@maxNumCompThreads, 0, 1);

% --- 4. 主 MATLAB 进程的线程配置 (可选) ---
maxNumCompThreads(num_cores);
setenv('OMP_NUM_THREADS', num2str(num_cores));
setenv('MKL_NUM_THREADS', num2str(num_cores));
setenv('MKL_DYNAMIC', 'FALSE');

tic

Rxobj = Get_Rx('Rx_para.json');
total_num = 500;
waterfall_raws = 120;

rng("shuffle");
Rxobj.fs = Rxobj.sample_band;
Rxobj.F_ = Rxobj.fs/(Rxobj.nfft-1);
Rxobj.offset = round(Rxobj.nfft/4);
Rxobj.T_ = Rxobj.offset/Rxobj.fs;
dataLen = (waterfall_raws-1)*Rxobj.offset+Rxobj.nfft;
Rxobj.ts = dataLen/Rxobj.fs;
dataLen = round(Rxobj.ts*Rxobj.fs);
fs = Rxobj.fs;

timestamp = datestr(now, 'yyyymmdd');
save_path = "F:\xd\rf\M\第四章\data";
save_fold = fullfile(save_path, "simu_" + timestamp); % 使用 fullfile 更稳健

if ~exist(save_fold, 'dir')
    mkdir(save_fold);
end

% --- 预分配 ---
txobj_all = cell(1, total_num);
shuffled_signals_all = cell(1, total_num);
for sh = 1:total_num
    shuffled_signals_all{sh} = rand_json(Rxobj.freq_rf, Rxobj.sample_band, sh);
    txobj_all{sh} = Get_Tx("Tx_para_"+string(sh)+".json");
end

% --- 核心仿真循环 (使用外层 parfor) ---
% 将主循环并行化，每个 worker 独立处理一个或多个 sh 迭代
% 这是典型的“粗粒度并行”，通常效率更高

tic % 重新开始计时，衡量核心并行部分
parfor sh = 1:total_num
    % fprintf 在 parfor 中行为可能不一致，可以考虑在循环外打印总进度
    % 或者使用 parfor 的进度条 (需要 Parallel Computing Toolbox R2020a 或更高版本)
    
    % --- 每个 worker 获取自己负责的 sh 数据 ---
    % txobj_all 和 shuffled_signals_all 是切片变量，可以直接索引
    current_txobj = txobj_all{sh};
    current_shuffled_signals = shuffled_signals_all{sh};
    
    numTx = current_txobj.Num;
    txIds = current_txobj.txId_V;
    freqC_V = current_txobj.freqC_V;
    freq_rf = Rxobj.freq_rf;
    
    % --- 串行部分: 噪声生成 ---
    % 这部分代码现在在每个 worker 内部为各自的 sh 迭代独立运行
    noise_len = dataLen;
    [~, pink_noise] = Gen_pinknoise(Rxobj.freq_rf-Rxobj.fs/2, Rxobj.freq_rf+Rxobj.fs/2, noise_len);
    gaussian_noise = Gen_gaussiannoise(noise_len);
    
    % 注意：parfor 中的 rand 是安全的，每个 worker 有独立的随机数种子
    opts = struct('taper_ratio', 0.1 + (0.3-0.1)*rand, 'seed', randi(1e9));
    band_noise = Gen_bandnoise(randi([0,3]), noise_len, Rxobj.fs, opts);
    base = 0.05;
    v = rand(1,3); v = v/sum(v);
    w = base + (1-3*base)*v;
    noise = w(1)*gaussian_noise + w(2)*pink_noise + w(3)*band_noise;
    
    spec = fftshift(abs(fft(noise, noise_len) / noise_len).^2);
    f_ = linspace(-Rxobj.fs/2, Rxobj.fs/2, noise_len) + Rxobj.freq_rf;
    
    % --- 内部信号处理循环 (现在是普通 for 循环) ---
    RxSig_sum_local = zeros(1, dataLen);
    % temp_shuffled_signals 现在是每个 worker 的本地临时变量
    temp_shuffled_signals = current_shuffled_signals;
    
    % =================================================================
    %                   *** 内层循环必须是 for ***
    % =================================================================
    for i = 1:numTx
        % --- 第一部分：生成原始信号 ---
        [~, sigx] = Gen_basesig(dataLen, fs, txIds(i), 1, current_txobj);
        local_rfSig_row = Fc_change(sigx, (freqC_V(i) - freq_rf) / fs);

        % --- 第二部分：信号缩放与处理 ---
        idx = (f_ >= temp_shuffled_signals(i).start_freq) & (f_ <= temp_shuffled_signals(i).end_freq);
        P_noise_i = sum(spec(idx));
        P_sig = sum(abs(local_rfSig_row).^2) / length(local_rfSig_row);
        
        if P_sig > 1e-12
            target_snr = 10^(temp_shuffled_signals(i).receive_snr / 10);
            target_Psig = target_snr * P_noise_i;
            scale = sqrt(target_Psig / P_sig);
            local_rfSig_row = local_rfSig_row * scale;
        else
            local_rfSig_row = zeros(1, dataLen);
        end
        
        if(rand() < 0.5)
            [local_rfSig_row, info] = tdma_allo(local_rfSig_row, Rxobj.fs);
            on = info.on_iv;
            hang = zeros(size(on,1), 2);
            for x = 1:size(on,1)
                hang(x,1) = floor((on(x,1)-1) / Rxobj.offset);
                hang(x,2) = ceil((on(x,2)-1) / Rxobj.offset);
                if(hang(x,2) > waterfall_raws)
                    hang(x,2) = waterfall_raws;
                end
                if(hang(x,1) < 1)
                    hang(x,1) = 1;
                end
            end
            temp_shuffled_signals(i).hang = hang; 
        end
        
        % 累加到 worker 的本地变量中
        RxSig_sum_local = RxSig_sum_local + local_rfSig_row;
    end
    
    % 将修改后的 shuffled_signals 赋值，准备保存
    current_shuffled_signals = temp_shuffled_signals;

    % --- 后续处理 (在每个 worker 内部独立完成) ---
    RxSig = RxSig_sum_local + noise;
    fft_mat = con_fft_new(RxSig, Rxobj.nfft, Rxobj.nfft, round(Rxobj.nfft/4));
    fft_mat = 10*log10(single(fft_mat));
    
    count = sprintf('%05d', sh);
    filename = "ori_matrix_(dBW)_chapter4_" + count;
    
      % =======================================================================
    %                       *** 核心修改点 *** 
    % 1. 将要保存的变量打包到一个结构体中
    data_to_save = struct();
    data_to_save.fft_mat = fft_mat;
    data_to_save.Rxobj = Rxobj; % Rxobj 是广播变量，可以访问
    data_to_save.current_shuffled_signals = current_shuffled_signals;
    
    % 2. 调用辅助函数 parsave
    parsave(fullfile(save_fold, filename), data_to_save);
    % =======================================================================
    
    % 使用 gcp().NumWorkers 来获取 worker 数量，避免广播 num_cores
    p = gcp('nocreate');
    if ~isempty(p)
        worker_id = p.NumWorkers; % 这只是一个示例，获取 worker ID 比较复杂
    end
    % 可以考虑使用 diary 来记录每个 worker 的日志
end

toc % 结束计时
disp('所有并行仿真任务已完成。');
function parsave(fname, data_struct)
    % PARSAVE saves the fields of a structure to a .mat file.
    % This function is a wrapper for SAVE to be used inside PARFOR loops.
    %
    %   parsave(FILENAME, DATA_STRUCT) saves the fields of the scalar 
    %   structure DATA_STRUCT as individual variables in the file FILENAME.
    
    save(fname, '-struct', 'data_struct');
end
