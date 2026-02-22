clc
clear
close all
point = 160001;
% 原始数据路径（修改成你的路径）
srcDir = 'fftmat_0905\train';
outDir = 'fftmat_floor_0905\train';if ~exist(outDir, 'dir'); mkdir(outDir); end

files = dir(fullfile(srcDir, '*.mat'));
nFiles = numel(files);

f_ori = 20e6;
f_ = 6250;
for i = 1:nFiles
    data = load(fullfile(srcDir,files(i).name));
    fft_mat = data.fft_mat;
    Rxobj = data.Rxobj;
    current_shuffled_signals = data.current_shuffled_signals;
    datalen  = size(fft_mat,2);

    [~, name, Ext] = fileparts(files(i).name);
    pattern = 'chapter4_(\d{5})';
    match = regexp(name,pattern,'tokens');
    number = match{1}{1};
    predict_floor = zeros(size(fft_mat,1),size(fft_mat,2));
    for xx = 1:4
        filename = "ori_matrix_(dBW)_"+"chapter4_"+number+"_"+string(xx)+Ext;
        d1 = load(fullfile("predict_floor_0905\train",filename));
        floor = d1.predict_noise_floor;
        spec = 10*log10(sum(10.^(fft_mat((xx-1)*30+1:xx*30,:)/10)));

        x = linspace(1,point,length(floor)); y = floor;
        valid = ~isnan(x) & ~isnan(y);
        x = x(valid); y = y(valid);

        % 去重：保留第一次出现的 y
        [~, ia] = unique(x, 'stable');     % stable = 保留首次
        x_u = x(ia); y_u = y(ia);

        % 升序排序（interp1 需要单调 x）
        [xu, ord] = sort(x_u, 'ascend');
        yu        = y_u(ord);

        % 至少需要两个不同的 x 才能插值
        if numel(xu) < 2
            floor_interp = repmat(yu(1), length(spec), 1);   % 退化为常数
        else
            floor_interp = interp1(xu, yu, 1:1:length(spec), 'linear', 'extrap');  % 线性插值+外推
        end
        predict_floor((xx-1)*30+1:xx*30,:) = (ones(30,1)*(floor_interp));
    end
    predict_floor = single(predict_floor);
    filename = "ori_matrix_with_floor_(dBW)"+"_"+"chapter4_"+number+Ext;
    save(fullfile(outDir, filename), "fft_mat","Rxobj","current_shuffled_signals","predict_floor");

end
