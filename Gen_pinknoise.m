function [pink_noise_spec,pink_noise_time] = Gen_pinknoise(min_freq,max_freq,N)
f_physical = linspace(min_freq, max_freq, N);   
idx_range = find(f_physical >= min_freq & f_physical <= max_freq);
pink_noise_spec = zeros(1, N);
vals = 1.1:0.1:1.9;
r = vals(randi(numel(vals), 1, 1));
amplitude = 1 ./ ((f_physical(idx_range) + 1).^(r/2));  % 粉红衰减
random_phase = exp(1j * 2 * pi * rand(1, length(idx_range)));
% 频谱赋值
pink_noise_spec(idx_range) = amplitude .* random_phase;
pink_noise_time = ifft(ifftshift(pink_noise_spec));
% 计算平均功率
power = sum(abs(pink_noise_time).^2) / N;

% 功率归一化（使得归一化后功率为 1）
pink_noise_time = pink_noise_time / sqrt(power);
end

