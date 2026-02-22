clc;clear;clear global;
close all;
% % 设置 MATLAB 使用所有核心
% num_cores = feature('numcores');  % 查看系统的核心数（逻辑核心）
% 
% maxNumCompThreads(num_cores);
% setenv('OMP_NUM_THREADS', num2str(num_cores));
% setenv('MKL_NUM_THREADS', num2str(num_cores));
% setenv('MKL_DYNAMIC', 'FALSE');
% 
% % 设置并行池
% p = gcp('nocreate');
% if isempty(p)
%     parpool('local', num_cores);  % 启动并行池
% end
% 
% % 配置每个 worker 只用 1 个线程
% parfevalOnAll(@setenv, 0, 'OMP_NUM_THREADS', '1');
% parfevalOnAll(@setenv, 0, 'MKL_NUM_THREADS', '1');
% global Txobj Rxobj
global Txobj Rxobj

for sh = 1:1
   rng("shuffle");
   waterfall_raws = 120;%瀑布图行数
   Rxobj = Get_Rx('Rx_para.json');

   shuffled_signals = rand_json_bs(Rxobj.freq_rf,Rxobj.sample_band);
   Txobj = Get_Tx('Tx_para.json');

    %%
    % 信号生成
    Rxobj.fs = Rxobj.sample_band;
    Rxobj.F_ = Rxobj.fs/(Rxobj.nfft-1);
    Rxobj.offset = round(Rxobj.nfft/4);
    Rxobj.T_ = Rxobj.offset/Rxobj.fs;
    dataLen = (waterfall_raws-1)*Rxobj.offset+Rxobj.nfft;
    Rxobj.ts = dataLen/Rxobj.fs;
    dataLen = round(Rxobj.ts*Rxobj.fs);

    % --------- 预分配（用普通数组承接 parfor 输出） ---------
    
    numTx   = Txobj.Num;
    txIds   = Txobj.txId_V;           % 先取出需要的向量，避免在 parfor 里索引 Txobj
    band    = zeros(1, numTx);        % 原来是 Txobj.band，用数组替代
    BaseSig = zeros(numTx, dataLen);
    fs = Rxobj.fs;
    % 如果你想在 parfor 内写 shuffled_signals(x).number，
    % 必须保证该字段已存在（先统一创建）
    if ~isfield(shuffled_signals, 'number')
        [shuffled_signals(1:numTx).number] = deal(0);
    end
    
    %% 接收信号生成  噪声
    %% 产生信号源
    txobj = Txobj;
    
    for x = 1:numTx
        [bx, sigx] = Gen_basesig(dataLen, fs, txIds(x), 1,txobj);
        band(x)    = bx;              % 只写普通数组
        BaseSig(x,:) = sigx;
    end
    
    for x = 1:numTx
        shuffled_signals(x).number = x;
    end
    Txobj.band = band;

%% 
    for ss = 1:10
        tic
        stringx = "第"+num2str(sh)+"轮"+"，"+"第"+num2str(ss)+"次";
        disp([stringx sh]);
        % close all;
        rfSig = zeros(numTx,dataLen);
        shuffled_signals = rand_except_basejson(Rxobj.freq_rf,Rxobj.sample_band,shuffled_signals);
        Txobj = Get_Tx('Tx_para.json');
        freqC_V = Txobj.freqC_V;
        freq_rf = Rxobj.freq_rf;
        idx = [shuffled_signals.number];
        BaseSig_perm = BaseSig(idx, :);

        for x = 1:numTx
            rfSig(x,:)  = Fc_change(BaseSig_perm(x,:) ,(freqC_V(x) - freq_rf)/fs);
        end

        f = (0:Rxobj.F_:Rxobj.fs)-Rxobj.fs/2+Rxobj.freq_rf; % 频率向量 代表一个 FFT 窗口（单帧）的频率轴。
        t = 0:Rxobj.T_:Rxobj.ts-Rxobj.T_;

        [~,pink_noise] = Gen_pinknoise(f(1),f(end),length(rfSig));
        
        gaussian_noise = Gen_gaussiannoise(length(rfSig));
        opts = struct('taper_ratio', 0.1 + (0.3-0.1)*rand, 'seed', randi(1e9));
        
        band_noise = Gen_bandnoise(randi([0,3]),length(rfSig),Rxobj.fs,opts);
        base = 0.05;
        v = rand(1,3); v = v/sum(v);
        w = base + (1-3*base)*v;            % w = [w_gauss, w_pink, w_band]
        noise = w(1)*gaussian_noise + w(2)*pink_noise + w(3)*band_noise;
        
        spec = fftshift(abs(fft(noise,length(rfSig))/length(rfSig)).^2);
        
        f_= linspace(-Rxobj.fs/2, Rxobj.fs/2, length(rfSig))+Rxobj.freq_rf;     % 基带频率 [-fs/2, +fs/2] , 代表整段仿真信号做完 FFT 后的频率轴。
        
        for i = 1:length(shuffled_signals)
            idx = find(f_ >= shuffled_signals(i).start_freq & f_ <= shuffled_signals(i).end_freq);
            P_noise(i) = sum((spec(idx))) ;  % 带内噪声功率
            P_sig = sum(abs(rfSig(i,:)).^2) / length(rfSig(i,:));     % 带内信号功率
            % target_snr = 10^(shuffled_signals(i).receive_snr / 10);
            target_snr = 10^(50 / 10); % 强制改为 50dB！亮瞎眼的强度
            target_Psig = target_snr * P_noise(i);
            scale = sqrt(target_Psig / P_sig);
            rfSig(i,:) = rfSig(i,:) * scale;

            if(rand()<0.5)
                [rfSig(i,:),info] = tdma_allo(rfSig(i,:), Rxobj.fs);
                on = info.on_iv;
                hang = zeros(size(on,1),2);
                for x = 1:size(on,1)
                    hang(x,1) = round((on(x,1)-1)/ Rxobj.offset);
                    hang(x,2) = round((on(x,2)-1)/ Rxobj.offset);
                    %  与 waterfall_raws 有关 ， 1 大于等于  hang  小于等于 waterfall
                    if(hang(x,2)>waterfall_raws)
                        hang(x,2) = waterfall_raws;
                    end
                    if(hang(x,1)<1)
                        hang(x,1) = 1;
                    end
                end
                shuffled_signals(i).hang = hang;
                if isempty(hang) || all(hang(:) == 0)
                    shuffled_signals(i).is_valid = false; % 标记为无效（静默）
                else
                    shuffled_signals(i).is_valid = true;  % 标记为有效
                end
            else
                shuffled_signals(i).hang = [1, waterfall_raws]; 
                shuffled_signals(i).is_valid = true; 
            end
        end
        
        RxSig = sum(rfSig,1)+noise;
        % RxSig = sum(rfSig,1);
        fft_mat = con_fft_new((RxSig),Rxobj.nfft,Rxobj.nfft,round(Rxobj.nfft/4));  %
        fft_mat = single(fft_mat);

% ===================== 综合可视化模块 =====================

% % --- [模块 A]：背景噪声与信号频段分配图 ---
%  cut_point = 8192; % 切片宽度定义
% 
% figure('Name', 'Noise Spectrum & Allocation');
% plot(f_, 10*log10(spec));   % 噪声
% xlabel('Frequency (Hz)'); ylabel('PSD (dB)');
% title('Background Noise Spectrum & Signal Allocation');
% hold on;
% 
% for i = 1:length(shuffled_signals)
%     % 高亮显示信号占用的频段
%     idx = f_ >= shuffled_signals(i).start_freq & f_ <= shuffled_signals(i).end_freq;
%     if any(idx)
%         plot(f_(idx), 10*log10(spec(idx) + eps), '-r', 'LineWidth', 1.5);
%     end
% end
% 
% % --- [模块 B]：频段切分辅助线 ---
% y_limits = ylim; % 获取当前Y轴范围
% for i = 1:floor(length(spec)/cut_point)
%     idx = cut_point * i;
%     line([f_(idx), f_(idx)], y_limits);
% end
% hold off;
% % --- [模块 C]：全频段时频图 ---
% figure()
% imagesc(f , t,10*log10(fft_mat)) % 绘制瀑布图
% axis xy;  
% % colorbar;          % 显示颜色条 (单位 dB)
% title(['RxSig 全频段时频图 (信号数: ' num2str(numTx) ')']);
% xlabel('Frequency (MHz)');
% ylabel('Time (s)');

%%
        % plot(f,10*log10(spec))
        % hold on
        % colors = lines(length(shuffled_signals));  % 使用 lines colormap 生成不同颜色
        % for i = 1:length(shuffled_signals)
        %     outline = round((shuffled_signals(i).start_freq-f(1))/Rxobj.F_):round((shuffled_signals(i).end_freq-f(1))/Rxobj.F_);
        %     plot(f(outline),10*log10(spec(outline)),'-r','LineWidth',1);
        %     hold on
        % end
        % cut_point = 2048;
        % 
        % for i = 1:floor(length(spec)/cut_point)-1
        %     line([f(cut_point*(i)), f(cut_point*(i))], [10*log10(min(spec)), 10*log10(max(spec))], 'Color', 'r', 'LineStyle', '--') ;
        %     hold on
        % end
        % for i = 1:floor(Rxobj.nfft/cut_point)-1
        %     figure()
        %     fft_son_mat = fft_mat(:,cut_point*(i-1)+1:cut_point*(i));
        %     imagesc(f(cut_point*(i-1)+1:cut_point*(i)), t,10*log10(fft_son_mat)) % 绘制瀑布图
        % end



        save_path = "D:\SHENDU\宽带检测\simu_data_gen\test_data";  % 确保 save_path 是 string 类型
        timestamp = datestr(now, 'yyyymmdd');  % 获取当前日期（年月日格式）
        save_fold = save_path + "\" + "simu_" + timestamp;  % 使用 + 拼接路径，确保是 string 类型
        
        % 检查文件夹是否存在，不存在则创建
        if ~exist(save_fold, 'dir')  % 使用 'dir' 参数，明确检查文件夹
            mkdir(save_fold);  % 创建文件夹
        end
        count = length(dir(save_fold))-2+1;
        count = sprintf('%05d', count);  % 格式1化为5位数字，不足前面补零
        
        filename = "ori_matrix_(dBW)_chapter4"+"_"+count;
       
        fft_mat = 10*log10(fft_mat);
        save(fullfile(save_fold, filename), "fft_mat","Rxobj","shuffled_signals");
        toc
    
    end
end