clear
close all
clc
% 获取融合结果矩形
fileID = fopen('E:\m_pro\博二\宽带信号检测\宽带检测\data_zy\103\0task20251030_092548\specdata\1_88000000_1088000000_6250_160000_40_SpecSave1.bin', 'rb');

rows = 40; % 行数
cols = 160000; % 列数
f_s = 6250;
f_start = 88e6;
data = fread(fileID, rows * cols, 'double');
% 关闭文件
step_ = 6250;
fclose(fileID);
f_ = f_start + (0:cols-1)*step_;
matrix = reshape(data, cols, rows)';

matrix11 = matrix;

fileID = fopen('E:\m_pro\博二\宽带信号检测\宽带检测\data_zy\101\0task20251027_103739\specdata\2_88000000_1088000000_6250_160000_40_SpecSave1.bin', 'rb');

rows = 40; % 行数
cols = 160000; % 列数
f_s = 6250;
f_start = 88e6;
data = fread(fileID, rows * cols, 'double');
% 关闭文件
step_ = 6250;
fclose(fileID);
f_ = f_start + (0:cols-1)*step_;
matrix = reshape(data, cols, rows)';

matrix11 = [matrix11;matrix];


fileID = fopen('E:\m_pro\博二\宽带信号检测\宽带检测\data_zy\101\0task20251027_103739\specdata\3_88000000_1088000000_6250_160000_40_SpecSave1.bin', 'rb');

rows = 40; % 行数
cols = 160000; % 列数
f_s = 6250;
f_start = 88e6;
data = fread(fileID, rows * cols, 'double');
% 关闭文件
step_ = 6250;
fclose(fileID);
f_ = f_start + (0:cols-1)*step_;
matrix = reshape(data, cols, rows)';

matrix11 = [matrix11;matrix];



figure
imagesc(f_,1:size(matrix11,1),(matrix11))
hold on

figure
plot(sum(matrix11))