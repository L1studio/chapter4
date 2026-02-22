function shuffled_signals = snr_annotate(spec,f_,shuffled_signals)
 
for i = 1:length(shuffled_signals)
    idx = find(f_ >= shuffled_signals(i).start_freq & f_ <= shuffled_signals(i).end_freq);
    peak_percentage = 0.9; 
    signal_powers_in_band = spec(idx);
    sorted_powers = sort(signal_powers_in_band, 'descend');
    num_to_take = ceil(length(sorted_powers) * peak_percentage);
    
    % 确保至少取一个值（除非没有数据）
    if num_to_take == 0 && ~isempty(sorted_powers)
        num_to_take = 1; 
    end

    if isempty(sorted_powers) || num_to_take == 0
        warning('Signal %d 频带内无有效功率数据。跳过 SNR 计算。', i);
        shuffled_signals(i).snr_anno = NaN;
        continue;
    end

    % 取前 num_to_take 个最大值并计算平均
    P_sig = mean(sorted_powers(1:num_to_take)); % 带内信号功率，取前20%最大值

    if(i>1 && i<length(shuffled_signals))
        idx1 = find((f_ >= shuffled_signals(i-1).end_freq+15e3) & (f_ <= shuffled_signals(i).start_freq-15e3));
        idx2 = find((f_ >= shuffled_signals(i).end_freq+15e3) & (f_ <= shuffled_signals(i+1).start_freq-15e3));
    elseif i== 1
        idx1 = find((f_ >= f_(1)) & (f_ <= shuffled_signals(i).start_freq-15e3));
        idx2 = find((f_ >= shuffled_signals(i).end_freq+15e3) & (f_ <= shuffled_signals(i+1).start_freq-15e3));
    elseif i == length(shuffled_signals)
        idx1 = find((f_ >= shuffled_signals(i-1).end_freq+15e3) & (f_ <= shuffled_signals(i).start_freq-15e3));
        idx2 = find((f_ >= shuffled_signals(i).end_freq+15e3) & (f_ <= f_(end)));
    end
    P_noise = mean([spec(idx1) spec(idx2)]);  % 带间噪声功率
    snr(i) =  10*log10((P_sig-P_noise)/P_noise);
    shuffled_signals(i).snr_anno = snr(i);
end
end

