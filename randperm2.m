% 随机划分 mat 文件到 train / val / test (比例 7:2:1)
clear; clc;
rng(42);
% 原始数据路径（修改成你的路径）
srcDir = 'spec_0905';

% 目标文件夹路径
trainDir = fullfile("fftmat_datasetss_0905\", 'train');
valDir   = fullfile("fftmat_datasetss_0905\", 'val');
testDir  = fullfile("fftmat_datasetss_0905\", 'test');

% 创建目标文件夹（如果不存在）
if ~exist(trainDir, 'dir'); mkdir(trainDir); end
if ~exist(valDir, 'dir'); mkdir(valDir); end
if ~exist(testDir, 'dir'); mkdir(testDir); end

% 获取所有 mat 文件
files = dir(fullfile(srcDir, '*.mat'));
nFiles = numel(files);

if nFiles == 0
    error('在 %s 中没有找到 mat 文件', srcDir);
end
% ======= 随机打乱文件顺序 =======
randIdx = randperm(nFiles);
% ======= 按比例划分 =======
nTrain = round(0.7 * nFiles);
nVal   = round(0.15 * nFiles);
nTest  = nFiles - nTrain - nVal;

% ======= 拷贝到 train =======
for i = 1:nTrain
    srcFile = fullfile(files(randIdx(i)).folder, files(randIdx(i)).name);
    copyfile(srcFile, trainDir);
end

% ======= 拷贝到 val =======
for i = nTrain+1 : nTrain+nVal
    srcFile = fullfile(files(randIdx(i)).folder, files(randIdx(i)).name);
    copyfile(srcFile, valDir);
end

% ======= 拷贝到 test =======
for i = nTrain+nVal+1 : nFiles
    srcFile = fullfile(files(randIdx(i)).folder, files(randIdx(i)).name);
    copyfile(srcFile, testDir);
end

fprintf('完成：%d 个文件 => %d(train) / %d(val) / %d(test)\n', ...
    nFiles, nTrain, nVal, nTest);