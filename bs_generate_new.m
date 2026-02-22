clc;clear;clear global;
close all;

% ===================== 1. 并行计算环境配置 =====================

num_cores = feature('numcores');
maxNumCompThreads(num_cores); 
setenv('OMP_NUM_THREADS', num2str(num_cores)); 
setenv('MKL_NUM_THREADS', num2str(num_cores)); 
setenv('MKL_DYNAMIC', 'FALSE'); 

% 设置并行池 (Parallel Pool)
p = gcp('nocreate');                    % 获取当前并行池，如果不存在则不创建
if isempty(p)
    parpool('local', num_cores);  % 如果没有并行池，则启动一个新的，使用所有核心
end

% 配置每个 worker 只用 1 个线程 (防止并行池里的 worker 再开多线程导致资源竞争死锁)
parfevalOnAll(@setenv, 0, 'OMP_NUM_THREADS', '1');
parfevalOnAll(@setenv, 0, 'MKL_NUM_THREADS', '1');

global Txobj Rxobj 

% ===================== 2. 外层循环：场景规划 (70 轮) =====================
% 每一轮代表一种全新的频谱布局（频率规划方案）
for sh = 1:70
    rng("shuffle");                      % 重置随机数种子
    waterfall_raws = 10;            % 设定生成的时频图的时间轴行数 (帧数)
    
    % 读取初始配置
    Get_Tx('Tx_para.json');        % 读取发射机参数模板
    Get_Rx('Rx_para.json');       % 读取接收机参数
    
    % 随机生成新的频谱场景配置 (规划信号的频率、带宽、速率)
    % 并将结果写回 Tx_para.json
    if(1)
        shuffled_signals = rand_json(Rxobj.freq_rf, Rxobj.sample_band);
        Get_Tx('Tx_para.json');   % 重新读取刚刚生成的配置到全局变量 Txobj
    end
    
    %% ===================== 3. 基础参数计算与预分配 =====================
    % 信号生成参数计算
    Rxobj.fs = Rxobj.sample_band;          % 采样率等于观测带宽 (Hz)
    Rxobj.F_ = Rxobj.fs/(Rxobj.nfft-1);    % 频率分辨率 (Hz/bin)
    Rxobj.offset = round(Rxobj.nfft/4);    % STFT 帧移 (Hop Size)，75% 重叠
    Rxobj.T_ = Rxobj.offset/Rxobj.fs;      % 时间分辨率 (秒/帧)
    
    % 计算所需生成的总采样点数 dataLen
    % 公式：(帧数-1)*步长 + 窗口长度
    dataLen = (waterfall_raws-1)*Rxobj.offset + Rxobj.nfft;
    Rxobj.ts = dataLen/Rxobj.fs;           % 总时长 (秒)
    dataLen = round(Rxobj.ts*Rxobj.fs);    % 再次取整确保采样点数是整数
    
    % --------- 预分配内存 (优化性能) ---------
    numTx   = Txobj.Num;                   % 发射机总数
    txIds   = Txobj.txId_V;                % 提取发射机 ID 列表
    band    = zeros(1, numTx);             % 预分配带宽数组
    BaseSig = zeros(numTx, dataLen);       % 预分配基带信号矩阵 [信号数 x 长度]
    fs = Rxobj.fs;
    
    % 初始化 shuffled_signals 的 'number' 字段，防止后续赋值报错
    if ~isfield(shuffled_signals, 'number')
        [shuffled_signals(1:numTx).number] = deal(0);
    end
    
    %% ===================== 4. 基带信号生成 (Baseband Generation) =====================
    % 这一步生成纯净的、未加噪、未变频的基带波形
    txobj = Txobj; % 创建局部副本
    
    % 遍历每个发射机生成基带信号
    % 注意：这里虽然写的是 for，但因为之前配置了并行池，如果改成 parfor 会更快
    for x = 1:numTx
        % Gen_basesig: 生成复基带信号
        % 输入: 长度, 采样率, ID, 类型(1=Tx), 参数对象
        % 输出: 带宽 bx, 信号序列 sigx
        [bx, sigx] = Gen_basesig(dataLen, fs, txIds(x), 1, txobj);
        band(x)    = bx;              % 记录该信号的实际占用带宽
        BaseSig(x,:) = sigx;          % 存储基带波形
    end
    
    % 更新辅助信息
    for x = 1:numTx
        shuffled_signals(x).number = x; % 给每个信号打上索引标签
    end
    Txobj.band = band;                % 将计算出的实际带宽回写到全局配置 Txobj (修正了之前的bug)
    
    %% ===================== 5. 内层循环：增强与合成 (10 次) =====================
    % 复用上面的基带波形，但改变调制方式、SNR、TDMA模式，以此扩充数据集
    for ss = 1:10
        tic                           % 开始计时
        stringx = "第"+num2str(sh)+"轮"+"，"+"第"+num2str(ss)+"次";
        disp([stringx sh]);           % 打印进度
        close all;                    % 关闭所有绘图窗口
        
        rfSig = zeros(numTx, dataLen);% 预分配射频信号矩阵
        
        % 基于现有的 shuffled_signals，随机改变调制方式和 SNR，但不改变频率位置
        % rand_except_basejson: 这是一个“微调”函数
        shuffled_signals = rand_except_basejson(Rxobj.freq_rf, Rxobj.sample_band, shuffled_signals);
        Get_Tx('Tx_para.json');       % 重新加载参数 (因为 mod_type 和 snr 变了)
        
        freqC_V = Txobj.freqC_V;      % 载波频率列表
        freq_rf = Rxobj.freq_rf;      % 接收机中心频率
        idx = [shuffled_signals.number]; % 获取索引映射
        BaseSig_perm = BaseSig(idx, :);  % 按新顺序排列基带信号
        
        % --- 上变频 (Up-Conversion) ---
        for x = 1:numTx
            % Fc_change: 将基带信号搬移到指定的频偏位置
            % 频偏 = (载波频率 - 接收中心频率) / 采样率
            rfSig(x,:)  = Fc_change(BaseSig_perm(x,:) ,(freqC_V(x) - freq_rf)/fs);
        end
        
        % --- 混合噪声生成 (Complex Noise Environment) ---
        f = (0:Rxobj.F_:Rxobj.fs)-Rxobj.fs/2+Rxobj.freq_rf; % 频率轴向量
        t = 0:Rxobj.T_:Rxobj.ts-Rxobj.T_;
        
        [~,pink_noise] = Gen_pinknoise(f(1), f(end), length(rfSig)); % 生成粉红噪声 (1/f 噪声)
        gaussian_noise = Gen_gaussiannoise(length(rfSig));           % 生成高斯白噪声
        
        % 生成带通噪声 (Band-limited Noise)，模拟特定频段的干扰背景
        opts = struct('taper_ratio', 0.1 + (0.3-0.1)*rand, 'seed', randi(1e9));
        band_noise = Gen_bandnoise(randi([0,3]), length(rfSig), Rxobj.fs, opts);
        
        % 随机加权混合三种噪声
        base = 0.05;                  % 基础权重
        v = rand(1,3); v = v/sum(v);  % 生成归一化的随机权重
        w = base + (1-3*base)*v;      % 调整权重分布
        % 混合噪声 = w1*高斯 + w2*粉红 + w3*带通
        noise = w(1)*gaussian_noise + w(2)*pink_noise + w(3)*band_noise;
        
        % 计算全频段噪声的功率谱 (用于后续 SNR 计算)
        spec = fftshift(abs(fft(noise, length(rfSig))/length(rfSig)).^2);
        
        f_= linspace(-Rxobj.fs/2, Rxobj.fs/2, length(rfSig)) + Rxobj.freq_rf; % 基带频率轴
        
        % --- 信号功率缩放与 TDMA 处理 ---
        for i = 1:length(shuffled_signals)
            % 1. 计算该信号所在频段内的噪声功率 (P_noise)
            idx = find(f_ >= shuffled_signals(i).start_freq & f_ <= shuffled_signals(i).end_freq);
            P_noise(i) = sum((spec(idx))); 
            
            % 2. 计算当前信号的功率 (P_sig)
            P_sig = sum(abs(rfSig(i,:)).^2) / length(rfSig(i,:));
            
            % 3. 根据目标 SNR 计算所需的信号功率 (target_Psig)
            target_snr = 10^(shuffled_signals(i).receive_snr / 10);
            target_Psig = target_snr * P_noise(i);
            
            % 4. 计算缩放系数并应用 (Scale)
            scale = sqrt(target_Psig / P_sig);
            rfSig(i,:) = rfSig(i,:) * scale;
            
            % 5. 随机 TDMA (时分多址) 模拟
            % 以 50% 的概率将连续信号切成断续的 TDMA 信号
            if(rand() < 0.5)
                % tdma_allo: 生成 TDMA 掩码并应用到信号上
                [rfSig(i,:), info] = tdma_allo(rfSig(i,:), Rxobj.fs);
                on = info.on_iv; % 获取开启时段 [开始点, 结束点]
                
                % 将时域采样点映射到时频图的“行号” (Label转换)
                hang = zeros(size(on,1), 2);
                for x = 1:size(on,1)
                    hang(x,1) = round((on(x,1)-1)/ Rxobj.offset); % 起始行
                    hang(x,2) = round((on(x,2)-1)/ Rxobj.offset); % 结束行
                    
                    % 边界限制 (防止越界)
                    if(hang(x,2) > 120) hang(x,2) = 120; end
                    if(hang(x,1) < 1)   hang(x,1) = 1; end
                end
                
                % 将 TDMA 的起止行号记录到标签中
                shuffled_signals(i).hang = hang;
            end
        end
        
        % --- 最终信号合成 ---
        % 接收信号 = 所有发射信号之和 + 混合噪声
        RxSig = sum(rfSig, 1) + noise;
        
        % --- 时频图生成 (STFT) ---
        % con_fft_new: 自定义的 STFT 函数 (推测)
        % 输入: 信号, 窗长, FFT点数, 步长
        fft_mat = con_fft_new((RxSig), Rxobj.nfft, Rxobj.nfft, round(Rxobj.nfft/4));
        fft_mat = single(fft_mat); % 转为单精度节省存储空间
        


        % ===================== 调试可视化代码区（默认为注释状态） =====================
        % 功能：绘制全频段噪声功率谱、标注信号位置、以及分段查看时频图
        
        % plot(f,10*log10(spec))
        % % 绘制全频段的噪声功率谱密度图（dB单位）。
        % % 'f'是频率轴，'spec'是之前计算的混合噪声的功率谱。
        
        % hold on
        % % 保持绘图状态，允许在噪声谱上叠加绘制信号的频带范围。
        
        % colors = lines(length(shuffled_signals));  
        % % 生成一个颜色矩阵，为每一个信号分配一种独特的颜色，用于区分不同信号。
        
        % for i = 1:length(shuffled_signals)
        %     % 遍历每一个生成的信号
        
        %     outline = round((shuffled_signals(i).start_freq-f(1))/Rxobj.F_):round((shuffled_signals(i).end_freq-f(1))/Rxobj.F_);
        %     % [关键索引计算]：计算该信号在频率数组 f 中的索引范围。
        %     % 公式含义：(信号频率 - 起始频率) / 频率分辨率 = 数组下标偏移量
        
        %     plot(f(outline),10*log10(spec(outline)),'-r','LineWidth',1);
        %     % 在噪声谱图上，用红色实线高亮显示出“该信号所在的频段”。
        %     % 目的：检查信号的 start_freq 和 end_freq 是否正确对应到了频率轴上。
        
        %     hold on
        % end
        
        cut_point = 2048;
        % % 定义“切片宽度”。这通常对应深度学习模型的输入尺寸（例如模型一次只看2048个频点）。
        
        % for i = 1:floor(length(spec)/cut_point)
        %     % 循环计算需要切多少刀（把总带宽切成若干个 2048 点的子带）
        
        %     line([f(cut_point*(i)), f(cut_point*(i))], [10*log10(min(spec)), 10*log10(max(spec))], 'Color', 'r', 'LineStyle', '--') ;
        %     % 在频谱图上画红色的虚线竖线。
        %     % 目的：直观地看到大带宽信号是被怎么切割成小块的，检查是否会有信号正好被切在两半。
        
        %     hold on
        % end

        % for i = 1:floor(Rxobj.nfft/cut_point)
        %     % 遍历每一个切片（子带）
        
        %     figure()
        %     % 为每个切片弹出一个新的图形窗口
        
        %     fft_son_mat = fft_mat(:,cut_point*(i-1)+1:cut_point*(i));
        %     % [数据切片]：从总的时频矩阵 fft_mat 中，提取出当前的 2048 个频点宽度的子矩阵。
        %     % 行是时间，列是频率。
        
        %     imagesc(f(cut_point*(i-1)+1:cut_point*(i)), t, 10*log10(fft_son_mat)) 
        %     % 绘制该子带的“瀑布图”（Spectrogram）。
        %     % X轴：当前子带的频率范围
        %     % Y轴：时间 t
        %     % C轴（颜色）：功率强度 (dB)
        % end







        % (中间注释掉的绘图代码略过...)
        
        % --- 数据保存 ---
        save_path = "F:\xd\rf\M\第四章\data";          % 基础路径
        timestamp = datestr(now, 'yyyymmdd');      % 时间戳
        save_fold = save_path + "\" + "simu_" + timestamp; % 创建当天的子文件夹
        
        % 检查并创建文件夹
        if ~exist(save_fold, 'dir')
            mkdir(save_fold);
        end
        
        % 生成文件名编号 (例如 00001, 00002)
        count = length(dir(save_fold)) - 2 + 1;    % 计算已有文件数 (. 和 .. 占了2个)
        count = sprintf('%05d', count);            % 格式化
        
        filename = "ori_matrix_(dBW)_chapter4" + "_" + count; % 构造文件名
       
        % 取对数 (dBW)，作为最终保存的图像数据（特征）
        fft_mat = 10*log10(fft_mat);
        
        % 保存 .mat 文件
        % 包含: 特征(fft_mat), 接收机参数(Rxobj), 标签(shuffled_signals)
        save(fullfile(save_fold, filename), "fft_mat", "Rxobj", "shuffled_signals");
        toc % 结束计时
    end
end