function [band_noise, info] = Gen_bandnoise(K,N, fs, varargin)
% 复基带带限白噪声（多频段）
% N     : 输出长度
% fs    : 采样率 (Hz)
% 可选：结构体 opts 或 Name-Value：
%   'taper_ratio' (默认0.05)  边缘余弦渐变占该段bin比例（0~0.5）
%   'seed'         (默认NaN)  随机种子

% ---- 解析可选参数（兼容 struct 或 Name-Value）----
spans = rand_nonoverlap_spans(K, fs, 0.20, 0.60,20); 
K= size(spans,1);% 每段带宽∈[0.10,0.45]*fs，可跨0Hz
P = 0.1 + (1-0.1)*rand(1,K);         

if ~isempty(varargin)
    if numel(varargin)==1 && isstruct(varargin{1})
        s = varargin{1};
        if isfield(s,'taper_ratio'), taper_ratio = s.taper_ratio; end
        if isfield(s,'seed'),        seed        = s.seed;        end
    else
        p = inputParser;
        p.FunctionName = 'Gen_bandnoise';
        addParameter(p,'taper_ratio',0.05,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&x<=0.5);
        addParameter(p,'seed',NaN,@(x)isnumeric(x)&&isscalar(x));
        parse(p,varargin{:});
        taper_ratio = p.Results.taper_ratio;
        seed        = p.Results.seed;
    end
end
if ~isnan(seed), rng(seed); end

spans = double(spans);
P = double(P(:)).';
K = size(spans,1);
if numel(P) ~= K
    error('P 的长度必须与 spans 的行数一致。');
end
P = P / sum(P);  % 归一化功率占比

% 判定频率单位（归一化 or Hz）
if max(abs(spans(:))) <= 0.5 + eps
    spans_hz = spans * fs;   % 归一化频率 -> Hz
else
    spans_hz = spans;        % 已是 Hz
end

% 频率轴（与 fftshift/ifftshift 对齐）
f = (-N/2:N/2-1) * (fs/N);

band_noise = zeros(1,N);
info = struct('band',{},'target_power',{},'actual_power',{},'bins',{},'taper_bins',{});

for k = 1:K
    fk = sort(spans_hz(k,:));
    f1 = fk(1); f2 = fk(2);
    if ~(f1 < f2 && f1 >= -fs/2 && f2 <= fs/2)
        error('第 %d 段频带不合法：需满足 -fs/2 <= f1 < f2 <= fs/2。', k);
    end

    % 选中该段频率 bin
    idx = (f >= f1) & (f < f2);
    if ~any(idx)
        warning('第 %d 段对应的 FFT bin 为空，可能带宽太窄或 N 太小。', k);
        continue;
    end
    idx_list = find(idx);
    L = numel(idx_list);

    % 余弦渐变（taper）
    w = max(1, round(taper_ratio * L));
    shape = ones(1,L);
    if w > 1 && 2*w < L
        ramp = 0.5*(1 - cos(linspace(0,pi,w)));
        shape(1:w)           = ramp;         % 左侧 0->1
        shape(end-w+1:end)   = fliplr(ramp); % 右侧 1->0
    else
        w = 0; % 渐变被跳过（段太窄）
    end

    % 该段复高斯频谱
    S = zeros(1,N);
    W = (randn(1,L) + 1j*randn(1,L))/sqrt(2);
    S(idx_list) = shape .* W;

    % IFFT -> 时域
    nk = ifft(ifftshift(S), [], 2);

    % 单位功率 -> 目标功率占比
    pk = mean(abs(nk).^2);
    if pk > 0, nk = nk / sqrt(pk); end
    target_power = P(k);
    nk = nk * sqrt(target_power);

    % 叠加
    band_noise = band_noise + nk;

    % 记录
    info(k).band = [f1 f2];
    info(k).target_power = target_power;
    info(k).actual_power = mean(abs(nk).^2);
    info(k).bins = [idx_list(1) idx_list(end)];
    info(k).taper_bins = w;
end

% 总功率归一化至 1
totP = mean(abs(band_noise).^2);
if totP > 0
    band_noise = band_noise / sqrt(totP);
end

end


function spansHz = rand_nonoverlap_spans(K, fs, minBwFrac, maxBwFrac, maxTries)
% 生成 K 个互不重叠频带，带宽∈[minBwFrac,maxBwFrac]*fs，范围[-0.5,0.5]*fs
% 更随机版：允许很宽的带宽（例如最大 0.8*fs），若塞不下则返回尽可能多的段
    if nargin < 3, minBwFrac = 0.10; end      % 最小带宽比例
    if nargin < 4, maxBwFrac = 0.80; end      % 最大带宽比例（可设到 0.8）
    if nargin < 5, maxTries   = 500;  end

    % 合法性保护
    minBwFrac = max(0, min(minBwFrac, 1.0));
    maxBwFrac = max(minBwFrac, min(maxBwFrac, 1.0));  % 不能超过 1.0*fs 的总带宽

    spans = [];
    tries = 0;
    while size(spans,1) < K && tries < maxTries
        % 1) 随机带宽（归一化到 fs）
        bw = minBwFrac + (maxBwFrac - minBwFrac) * rand;

        % 2) 如果这段太宽导致没有中心可选，直接跳过
        if bw >= 1.0
            tries = tries + 1;
            continue
        end

        % 3) 在 [-0.5,0.5] 内随机一个中心，使得区间完全落在范围内
        cmin = -0.5 + bw/2; 
        cmax =  0.5 - bw/2;
        if cmin > cmax
            tries = tries + 1;
            continue
        end
        c = cmin + (cmax - cmin) * rand;

        % 4) 候选区间（归一化频率）
        cand = [c - bw/2, c + bw/2];

        % 5) 与已选区间检查是否重叠
        ok = true;
        for i = 1:size(spans,1)
            ex = spans(i,:);
            if ~(cand(2) <= ex(1) || cand(1) >= ex(2))  % 有交集则不行
                ok = false; break;
            end
        end

        % 6) 接受
        if ok
            spans = [spans; cand]; %#ok<AGROW>
        end
        tries = tries + 1;
    end

    % 排序并转换为 Hz
    if ~isempty(spans)
        spans = sortrows(spans,1);
    end
    spansHz = spans * fs;  % 直接给 Gen_bandnoise 使用
end