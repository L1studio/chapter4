function shuffled_signals = rand_except_baseallo(f_,band_step,min_freq,max_freq,shuffled_signals)


    shuffled_signals = shuffled_signals(randperm(length(shuffled_signals)));
band_data = [shuffled_signals.band];  % 这将提取所有 band 字段的数据
total_bandwidth_sum = sum(band_data);  % 按列求和
while(1)
    % 分配中心频率和计算起始频率、终止频率
    shuffled_signals(1).fc = min_freq + shuffled_signals(1).band/2+band_step;
    shuffled_signals(1).start_freq =shuffled_signals(1).fc-shuffled_signals(1).band/2;
    shuffled_signals(1).end_freq = shuffled_signals(1).fc+shuffled_signals(1).band/2;

    gap_ranges = [40e3, 60e3; 400e3, 600e3; 0.8e6, 1.2e6];
    signals_per_range = round(length(shuffled_signals) / 4); % 每个区间选择四分之一的信号数量

    % 用于存储信号间隔
    gaps = [];

    % 遍历每个区间并选择间隔
    for i = 1:size(gap_ranges, 1)
        min_gap = gap_ranges(i, 1);
        max_gap = gap_ranges(i, 2);

        % 从区间内生成信号间隔，步进为6250
        possible_gaps = min_gap:6250:max_gap;

        % 随机选择信号个数
        selected_gaps = randi([1, length(possible_gaps)], signals_per_range, 1);

        % 将选中的间隔加入到gaps数组
        gaps = [gaps  possible_gaps(selected_gaps)];
    end
    band_left = max_freq-shuffled_signals(1).end_freq-(total_bandwidth_sum-shuffled_signals(1).band)-sum(gaps)-band_step;
    num_left = length(shuffled_signals)-signals_per_range*3-1;

    max_n = floor(30e6 / f_);  % 最大允许的 n 值
    if max_n < 0
        continue;
    end
    success = false;
    while ~success
        % 从 [0, max_n] 中随机选取 num_vals 个整数
        rand_n = randi([0, max_n], 1, num_left);
        values = band_step + rand_n * f_;

        if sum(values) <= band_left
            success = true;
        else
            max_n = round(max_n/1.5);
        end
    end

    gaps = [gaps values];
    gaps = gaps(randperm(length(gaps)));

    % 计算信号的起始频率和终止频率，并确保信号间有间隔
    for i = 2:length(shuffled_signals)
        % 计算起始频率和终止频率
        shuffled_signals(i).start_freq = shuffled_signals(i-1).end_freq + gaps(i-1);
        shuffled_signals(i).end_freq = shuffled_signals(i).start_freq  + shuffled_signals(i).band;
        shuffled_signals(i).fc = shuffled_signals(i).start_freq  + shuffled_signals(i).band/2;
    end
    break;
end

% colors = lines(length(shuffled_signals));  % 使用 lines colormap 生成不同颜色
% 
% % 创建画布
% figure;
% hold on;
% 
% % 绘制每个信号的频段
% for i = 1:length(shuffled_signals)
%     % 随机高度以模拟“功率谱”感（也可以设置为固定高度）
%     power = rand() * 1 + 0.5;  % 可调节为更真实感
% 
%     % 使用 patch 绘制频谱块（模拟频谱图）
%     x = [shuffled_signals(i).start_freq, ...
%         shuffled_signals(i).start_freq + shuffled_signals(i).band, ...
%         shuffled_signals(i).start_freq + shuffled_signals(i).band, ...
%         shuffled_signals(i).start_freq];
% 
%     y = [0, 0, power, power];  % 频谱高度（功率）
% 
%     patch(x, y, colors(i,:), 'EdgeColor', 'k', 'FaceAlpha', 0.6);  % 透明度可调
% end
% 
% % 设置图形属性
% xlim([min_freq, max_freq]);
% ylim([0, 2]);  % 如果所有功率都在 [0.5, 1.5] 区间，这样设定合适
% xlabel('频率 (Hz)');
% ylabel('功率幅度 (相对值)');
% title('模拟频谱图');
% grid on;
% box on;
% end
% 
