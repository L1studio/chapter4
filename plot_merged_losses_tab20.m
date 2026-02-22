%% plot_merged_losses_tab20.m
% =========================================================================
% 功能：zlc
%   1. 读取 Python 生成的 "merged_all_losses.csv" (合成版数据)。
%   2. 使用 Matplotlib tab20 经典调色板。
%   3. 绘制两幅对比图：(a) 训练集 Loss, (b) 验证集 Loss。
%   编写时间: 2026-01-22 10:47
% =========================================================================
clear; clc; close all;

% ===== 1. 配置路径 =====
% 请修改为你存放 merged_all_losses.csv 的文件夹路径
rootDir = 'D:\SHENDU\p\chapter3\Compare\Ablation\2026_01_21_18_29_Full_Ablation_N0_15\Analysis_Result';
csvFile = fullfile(rootDir, 'merged_all_losses.csv');

if ~isfile(csvFile)
    error('未找到合并数据文件：%s\n请先运行 Python 代码生成该文件！', csvFile);
end

% ===== 2. 定义 Matplotlib tab20 调色板 (RGB 0-1) =====
% 这就是你觉得好看的那组颜色
tab20 = [ ...
    31, 119, 180;  174, 199, 232;
    255, 127, 14;  255, 187, 120;
    44, 160, 44;   152, 223, 138;
    214, 39, 40;   255, 152, 150;
    148, 103, 189; 197, 176, 213;
    140, 86, 75;   196, 156, 148;
    227, 119, 194; 247, 182, 210;
    127, 127, 127; 199, 199, 199;
    188, 189, 34;  219, 219, 141;
    23, 190, 207;  158, 218, 229] / 255.0;

% ===== 3. 读取数据 =====
opts = detectImportOptions(csvFile);
opts.VariableNamingRule = 'preserve'; % 保持原始列名 (如 Train_Loss_N00)
T = readtable(csvFile, opts);

epochs = T.epoch; % 公共横坐标

% 准备循环参数 (N=0 到 15)
max_n = 15; 

% ===== 4. 绘图函数封装调用 =====
% 绘制图1：训练集损失
plot_figure(T, epochs, max_n, tab20, 'Train', rootDir);

% 绘制图2：验证集损失
plot_figure(T, epochs, max_n, tab20, 'Val', rootDir);

fprintf('所有绘图完成！图片已保存至：%s\n', rootDir);


% =========================================================================
% 子函数：核心绘图逻辑
% =========================================================================
function plot_figure(T, epochs, max_n, colors, typeStr, saveDir)
    fig = figure('Color','w','Position',[100 100 1200 700]);
    ax = axes(fig);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    
    % 设置网格样式
    ax.GridAlpha = 0.3;
    ax.MinorGridAlpha = 0.1;
    
    if strcmp(typeStr, 'Train')
        prefix = 'Train_Loss_N';
        titleStr = 'Training Loss Comparison (N=0~15)';
        % yLabelStr = 'Training Loss (Log Scale)';
        yLabelStr = 'Training Loss';
        saveName = 'Matlab_Plot_Training_Loss_tab20.png';
    else
        prefix = 'Val_Loss_N';
        titleStr = 'Validation Loss Comparison (N=0~15)';
        yLabelStr = 'Validation Loss';
        saveName = 'Matlab_Plot_Validation_Loss_tab20.png';
    end
    
    has_plot = false;
    
    % 循环绘制 N00 - N15
    for n = 0:max_n
        % 构造列名，例如 Train_Loss_N00
        colName = sprintf('%s%02d', prefix, n);
        
        if ismember(colName, T.Properties.VariableNames)
            yData = T.(colName);
            
            % 过滤 NaN 数据
            validIdx = ~isnan(yData);
            if ~any(validIdx), continue; end
            
            % 获取对应颜色 (循环取色，防止溢出)
            colorIdx = mod(n, size(colors,1)) + 1;
            thisColor = colors(colorIdx, :);
            
            plot(ax, epochs(validIdx), yData(validIdx), ...
                'LineWidth', 1.5, ...
                'Color', thisColor, ...
                'DisplayName', sprintf('N=%d', n));
            
            has_plot = true;
        end
    end
    
    if has_plot
        set(ax, 'YScale', 'log'); % 对数坐标
        xlabel(ax, 'Epochs', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel(ax, yLabelStr, 'FontSize', 12, 'FontWeight', 'bold');
        title(ax, titleStr, 'FontSize', 14);
        
        % 图例设置
        lgd = legend(ax, 'Location', 'eastoutside');
        title(lgd, 'Depth');
        lgd.FontSize = 10;
        
        % 保存
        exportgraphics(fig, fullfile(saveDir, saveName), 'Resolution', 300);
        fprintf('  -> 已保存: %s\n', saveName);
    else
        warning('没有找到 %s 相关数据列', typeStr);
        close(fig);
    end
end