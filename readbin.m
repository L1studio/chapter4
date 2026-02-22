%% 批量读取文件夹中的 .bin 文件
clear; clc;

% 1. 设置路径与参数
% 根据你的项目结构，建议使用绝对路径
fileFolder = 'D:\SHENDU_data\检测数据\检测数据-1.26\101-校内\88-500MHz_0task20260126_111624\specdata\'; 
filePattern = fullfile(fileFolder, '*.bin');

% 获取所有 bin 文件列表
binFiles = dir(filePattern);

% 检查文件夹是否为空
if isempty(binFiles)
    error('未在指定路径下找到任何 .bin 文件，请检查路径： %s', fileFolder);
end

% 2. 遍历并处理文件
% 建议对文件名进行自然排序，防止 1.bin 后紧跟 10.bin 的情况
% 如果安装了工具箱，可以使用 natsortfiles，否则默认按 ASCII 排序
for k = 1:length(binFiles)
    baseFileName = binFiles(k).name;
    fullFileName = fullfile(fileFolder, baseFileName);
    
    fprintf('正在处理: %s (%d/%d)\n', baseFileName, k, length(binFiles));
    
    % 3. 打开文件并读取
    % 'r' 表示只读，'b' 通常指 Big-Endian，但大多数 PC 生成的是 Little-Endian ('l')
    fileID = fopen(fullFileName, 'r', 'l'); 
    
    if fileID == -1
        warning('无法打开文件: %s', fullFileName);
        continue;
    end
    
    try
        % --- 关键步骤：数据类型定义 ---
        % 根据你生成数据时的格式，选择 'float32' (single), 'double', 'int16' 等
        % 如果是实测频谱数据，通常是 'float32'
        data = fread(fileID, inf, 'float32'); 
        
        % --- 数据重组 (Reshape) ---
        % 如果你的 bin 文件是矩阵（例如：时间 x 频率），需要根据已知维度进行 reshape
        % 例如：rows = 1024; data = reshape(data, rows, []);
        
        % 4. 在此处插入你的处理逻辑
        % 例如：计算均值、绘图或保存为 .mat
        % plot(data); title(baseFileName); pause(0.1);
        
    catch ME
        fprintf('处理文件 %s 时出错: %s\n', baseFileName, ME.message);
    end
    
    % 务必关闭文件句柄，避免占用内存或导致后续读取失败
    fclose(fileID);
end

fprintf('所有文件处理完毕。\n');