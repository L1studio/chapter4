function [out,water_m] = con_fft_new(sig, part_len, nfft,offset_point)
% sig输入数据 
% part_len做fft信号点数（窗的长度）
% nfft做fft点数 （做fft的点数）
% offset_point偏移点数
if(offset_point == 0)
    hang = floor(length(sig)/part_len);
    offset_point = part_len;
else
    hang = floor((length(sig)-part_len)/offset_point)+1;    %有几个窗

end
st = 1;                 %窗的起始位置
ed = st + part_len-1;   %窗的结束位置
ii = 1;
fft_water_m = zeros(hang,nfft);
window = hann(part_len).';  %创建一个汉宁窗(列=>行)
while(ed<=length(sig))
    water_m = sig(st : ed);
    fft_water_m(ii,:) = fftshift(abs(fft(water_m.*window,nfft)/nfft));
    ii = ii+1;
    st = st+offset_point;
    ed = st +part_len-1;
end
out = fft_water_m.^2;

end