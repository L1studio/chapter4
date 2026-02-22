function noise_complex= Gen_gaussiannoise(N)
noise_complex = (randn(1, N) + 1j * randn(1, N)) / sqrt(2);  % 零均值单位功率复高斯噪声
end

