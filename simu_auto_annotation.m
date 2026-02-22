clc
clear
close all

folder = "data\simu_20250829";
files = dir(fullfile(folder, '*.mat'));  % 获取文件夹内所有 .mat 文件

for fi = 1:length(files)
    filename = fullfile(folder, files(fi).name);
    fprintf('正在处理: %s\n', filename);

    mat = load(filename);

    image = mat.image;
    sig_info = mat.shuffled_signals;

    f_start = mat.F_start;
    f_ = mat.F_resolution;

    [Nt, Nf] = size(image);
    win = 100;  % 每 x 个频点做一次平均

    % 1) 将每个信号的起止频率转换为索引
    sig_num = length(sig_info);
    seg = zeros(sig_num, 2);
    for i = 1:sig_num
        f_st = sig_info(i).start_freq;
        f_ed = sig_info(i).end_freq;
        idx_st = floor((f_st - f_start)/f_) + 1;
        idx_ed = floor((f_ed - f_start)/f_) + 1;
        idx_st = max(1, min(Nf, idx_st));
        idx_ed = max(1, min(Nf, idx_ed));
        if idx_st > idx_ed, [idx_st, idx_ed] = deal(idx_ed, idx_st); end
        seg(i,:) = [idx_st, idx_ed];
    end

    % 2) 合并信号段
    seg = sortrows(seg, 1);
    merged = [];
    cs = seg(1,1); ce = seg(1,2);
    for i = 2:size(seg,1)
        if seg(i,1) <= ce + 1
            ce = max(ce, seg(i,2));
        else
            merged = [merged; cs, ce];
            [cs, ce] = deal(seg(i,1), seg(i,2));
        end
    end
    merged = [merged; cs, ce];

    % 3) 找出空隙区间
    gaps = [];
    if merged(1,1) > 1
        gaps = [gaps; 1, merged(1,1)-1];
    end
    for i = 1:size(merged,1)-1
        a = merged(i,2) + 1;
        b = merged(i+1,1) - 1;
        if a <= b
            gaps = [gaps; a, b];
        end
    end
    if merged(end,2) < Nf
        gaps = [gaps; merged(end,2)+1, Nf];
    end

    % 4) 只在空隙里每 win 个点取均值
    anno = [];
    for gi = 1:size(gaps,1)
        a = gaps(gi,1); b = gaps(gi,2);
        c = a;
        while c <= b
            d = min(c + win - 1, b);
            mid_idx = floor((c + d)/2);
            m = mean(image(:, c:d), 'all');
            anno = [anno; mid_idx, m];
            c = d + 1;
        end
    end
    mat.annotation = anno;

    % 5) 插值
    N = numel(image);
    x_image = (1:N).';
    y_image = image;
    x = anno(:,1); y = anno(:,2);
    valid = ~isnan(x) & ~isnan(y);
    x = x(valid); y = y(valid);
    [~, ia] = unique(x, 'stable');
    x_u = x(ia); y_u = y(ia);
    [xu, ord] = sort(x_u, 'ascend');
    yu = y_u(ord);
    if numel(xu) < 2
        anno_interp = repmat(yu(1), N, 1);
    else
        anno_interp = interp1(xu, yu, x_image, 'linear', 'extrap');
    end

    % 可选：画图
    figure;
    plot(x_image, y_image, 'b'); hold on;
    plot(x_image, anno_interp, 'g');
    title(files(fi).name);

    % 6) 保存
    save(filename, '-struct', 'mat');
end
