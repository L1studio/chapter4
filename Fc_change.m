function y = Fc_change(sig, f0)
% sig: M×N（M通道，N采样）或 1×N
% f0 : 归一化频偏 = fc/fs（单位：cycles/sample）
% 作用：y[n] = sig[n] * exp(j2π f0 n)

    N = size(sig, 2);         % 时间沿列
    n = 0:N-1;                % 从0开始，避免额外相位
    w = exp(1j*2*pi*f0*n);    % 1×N
    y = sig .* w;             % 隐式扩展：每行乘同一序列
    % 老版本MATLAB可用 bsxfun(@times, sig, w)
end
