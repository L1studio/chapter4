close all
clear
clc

data1 = load("D:\SHENDU\宽带检测\data\fftmat_0905\test\ori_matrix_(dBW)_chapter4_00008");
data2 = load("D:\SHENDU\宽带检测\data\predict_floor_0905\test\ori_matrix_(dBW)_chapter4_00008_1");
data3 = load("D:\SHENDU\宽带检测\data\spec_0905\test\ori_matrix_(dBW)_chapter4_00008_1");
data4 = load("D:\SHENDU\宽带检测\data\submat_0905\test\sub_matrix_(dBW)_chapter4_00008_1");
data6 = load("D:\SHENDU\宽带检测\simu_data_gen\test_data\simu_20260115\ori_matrix_(dBW)_chapter4_00001.mat");
data5 = load("D:\SHENDU\宽带检测\data\submat_with_floor_0905\test\sub_matrix_with_floor_(dBW)_chapter4_00008_1");
data7 = load("D:\SHENDU\m\chapter3\data\spec_datasetss_0905\test\ori_matrix_(dBW)_chapter4_00008_1");

% D:\SHENDU\m\chapter3\data\spec_datasetss_0905\test\ori_matrix_(dBW)_chapter4_00008_1

% D:\SHENDU\宽带检测\data\fftmat_0905\test\ori_matrix_(dBW)_chapter4_00008
% D:\SHENDU\宽带检测\data\predict_floor_0905\test\ori_matrix_(dBW)_chapter4_00008_1
% D:\SHENDU\宽带检测\data\spec_0905\test\ori_matrix_(dBW)_chapter4_00008_1
% D:\SHENDU\宽带检测\data\submat_0905\test\sub_matrix_(dBW)_chapter4_00008_1
% D:\SHENDU\宽带检测\data\submat_with_floor_0905\test\sub_matrix_with_floor_(dBW)_chapter4_00008_1
% D:\SHENDU\宽带检测\simu_data_gen\test_data\simu_20260115\ori_matrix_(dBW)_chapter4_00001.mat

% current_shuffled_signals =data.shuffled_signals;
current_shuffled_signals =data.current_shuffled_signals;
Rxobj = data.Rxobj;
                    % spec=data.spec;
                    % fft_mat = con_fft_new((spec),Rxobj.nfft,Rxobj.nfft,round(Rxobj.nfft/4));  %
                    % fft_mat = single(fft_mat);
                    % f =  linspace(-Rxobj.fs/2 , Rxobj.fs/2 , length(spec))+Rxobj.freq_rf;
                    % t = 0:Rxobj.T_:Rxobj.ts-Rxobj.T_;
                    % figure()
                    % imagesc(f , t,10*log10(fft_mat)) % 绘制瀑布图
                    % axis xy;  
                    % % colorbar;          % 显示颜色条 (单位 dB)
                    % xlabel('Frequency (MHz)');
                    % ylabel('Time (s)');
% fft_mat = data.sub_fft_mat;
fft_mat = data.fft_mat;
% imagesc(fft_mat)
cut_point = 8192;
Rxobj.fs = Rxobj.sample_band;
Rxobj.F_ = Rxobj.fs/(Rxobj.nfft-1);
f = (0:Rxobj.F_:Rxobj.fs)-Rxobj.fs/2+Rxobj.freq_rf;% 频率向量

for i = 1:floor(Rxobj.nfft/cut_point)  %将瀑布图按cut_point分割
    figure()
    fft_son_mat = fft_mat(:,cut_point*(i-1)+1:cut_point*(i));
    imagesc(fft_son_mat) % 绘制瀑布图
    hold on;
    for k = 1:size(current_shuffled_signals,2)
        f1 = f(cut_point*(i-1)+1);
        f2 = f(cut_point*(i));
        % 条件1：信号开头在范围内
        % 条件2：信号结尾在范围内
        % 条件3：信号完全覆盖了当前范围 (跨越)
        if((current_shuffled_signals(k).start_freq >= f1 && current_shuffled_signals(k).start_freq <= f2) || ...
           (current_shuffled_signals(k).end_freq >= f1 && current_shuffled_signals(k).end_freq <= f2) || ...
           (current_shuffled_signals(k).start_freq <= f1 && current_shuffled_signals(k).end_freq >= f2))
            
            % --- [坐标转换] 物理频率 -> 局部矩阵索引 ---
            % 计算信号在当前图中的 像素列坐标 (spf)
            % 逻辑：(信号频率 - 当前图起始频率) / 分辨率 = 相对索引
            spf = [round((current_shuffled_signals(k).start_freq - f1)/Rxobj.F_) ...
                   round((current_shuffled_signals(k).end_freq - f1)/Rxobj.F_)];  %纵坐标
            spf(spf < 1) = 1;
            % spt = [1,120];  %无TDMA
            spt = current_shuffled_signals(k).hang; %横 坐标
            spf_total =[ round( (current_shuffled_signals(k).start_freq-f(1))/Rxobj.F_) round( (current_shuffled_signals(k).end_freq-f(1))/Rxobj.F_)];
            if(isempty(spt))
                spt = [1,size(fft_son_mat,2)];
            end
            
            for tt = 1:size(spt,1)
                plot([spf(1),spf(2)],[spt(tt,2),spt(tt,2)],'-r','LineWidth',1)
                hold on
                plot([spf(1),spf(1)],[spt(tt,2),spt(tt,1)],'-r','LineWidth',1)
                hold on
                plot([spf(2),spf(2)],[spt(tt,2),spt(tt,1)],'-r','LineWidth',1)
                hold on
                plot([spf(1),spf(2)],[spt(tt,1),spt(tt,1)],'-r','LineWidth',1)
                hold on
            end
            
        elseif(current_shuffled_signals(k).end_freq <=f1)
            continue;
        elseif(current_shuffled_signals(k).start_freq >=f2)
            break;
        end

    end
end