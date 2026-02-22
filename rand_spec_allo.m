function shuffled_signals = rand_spec_allo(total_bandwidth_limit,num_low,min_count,max_count,f_,band_step,min_freq,max_freq)
while(1)
    alpha_range = 0.2:0.02:0.5; % alpha 的随机范围，从 0.2 到 0.6，步进为 0.02
    low_rate = band_step * randi([1, 20], num_low, 1); % 从50k到1M随机选取100个速率，并确保是band_step的倍数

    % 初始化其他速率的分配
    rate_ranges = {[1e6, 5e6], [5e6, 10e6], [10e6, 15e6], [15e6, 30e6]}; % 各速率范围
    rate_counts = {}; % 各速率的个数
    % 迭代过程：分配其他速率，并确保总带宽不超过限制
    low_arfa = alpha_range(randi([1, length(alpha_range)], num_low, 1)).';
    low_band = (1 + low_arfa).* low_rate+50e3;
    total_bandwidth_sum = sum(low_band); % 初始带宽和
    for i = 1:length(rate_ranges)
        range = rate_ranges{i};

        num_count = randi([min_count, max_count]); % 随机选择速率个数
        % 使用范围的最小和最大值来生成随机速率，并确保是band_step的倍数
        rate_values = band_step * randi([range(1) / band_step, range(2) / band_step], num_count, 1);

        % 为每个速率随机选择一个alpha值
        alpha_values = alpha_range(randi([1, length(alpha_range)], num_count, 1)).'; % 随机选择每个信号的alpha值
        for j = 1:num_count
            % 将速率和对应的alpha值保存为结构体
            rate_counts{i}(j).rate = rate_values(j); % 保存速率
            rate_counts{i}(j).alpha = alpha_values(j); % 保存alpha值
            rate_counts{i}(j).band = (1 + alpha_values(j)) .* rate_values(j)+50e3; % 保存alpha值

        end
        % 累加带宽
        total_bandwidth_sum = total_bandwidth_sum + sum((1 + alpha_values) .* rate_values+50e3);
    end
    if(total_bandwidth_sum>total_bandwidth_limit)
        continue;
    end
    stop_flag = false;
    % 如果总带宽没有超过限制，则继续增加速率个数，直到接近最大个数
    while total_bandwidth_sum <= total_bandwidth_limit && ~stop_flag
        all_maxed = true; % 假设所有区间都已达到最大值
        for i = 1:length(rate_counts)
            if length(rate_counts{i}) < max_count % 如果该区间的速率个数小于最大数量15
                all_maxed = false; % 如果有区间未达到最大数量，则设置为false
                range = rate_ranges{i};
                % 增加一个新的速率，并确保是band_step的倍数
                new_rate = band_step * randi([range(1) / band_step, range(2) / band_step], 1, 1);
                new_alpha = alpha_range(randi([1, length(alpha_range)], 1, 1)); % 随机选择alpha值
                % 计算新添加速率后的带宽
                new_bandwidth = (1 + new_alpha) * new_rate+50e3;
                % 检查增加后是否超出带宽限制
                if total_bandwidth_sum + new_bandwidth <= total_bandwidth_limit
                    % 如果不超限，保存新的速率和alpha值为结构体
                    new_entry = struct('rate', new_rate, 'alpha', new_alpha, 'band',new_bandwidth);
                    rate_counts{i} = [rate_counts{i}, new_entry]; % 增加新的结构体到rate_counts
                    % 更新带宽
                    total_bandwidth_sum = total_bandwidth_sum + new_bandwidth;
                else
                    stop_flag = true; % 如果超限，设置停止标志
                    break; % 退出当前的for循环
                end
            end
        end
        % 如果所有区间都已达到最大数量，或者总带宽超限，停止增加速率
        if all_maxed || stop_flag
            break;
        end
    end
    rate_counts{end+1} = [];
    for i = 1:num_low
        new_entry = struct('rate',low_rate(i) , 'alpha', low_arfa(i), 'band',low_band(i));
        rate_counts{5} = [rate_counts{5}, new_entry];
    end
    % 合并rate_counts中的所有信号到一个数组并打乱
    all_signals = [];
    for i = 1:length(rate_counts)
        all_signals = [all_signals, rate_counts{i}]; % 合并所有信号
    end
    % 打乱信号的顺序
    shuffled_signals = all_signals(randperm(length(all_signals)));
    % 步骤：为每个信号分配中心频率 fc，并计算起始频率和终止频率
 
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
end
