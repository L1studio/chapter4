function [base_sig] = BaseBand_CDMA(point0, mod_type,PN_type, pnGenPolyCoeffs,pnGenInitState,Shape, RolloffFactor, sps0,Fs0)
% 调用函数产生PN码
[PN, pnLength] = PnCode_Gen(PN_type,pnGenPolyCoeffs,pnGenInitState);
numBits = ceil(point0/sps0/pnLength);
switch mod_type
    case "BPSK"
        % 产生原始二进制数据
        bitstream = randi([0 1], 1, numBits);
        % 对原始数据进行 pnLength 倍重采样
        source = 2 * rectpulse(bitstream, pnLength) - 1;
        pnSequence = 2 * repmat(PN, 1, numBits) - 1;
        spreadData = source .* pnSequence;
    case "QPSK"
        bitstream_I = 2*randi([0 1], 1, numBits)-1;
        bitstream_Q = 2*randi([0 1], 1, numBits)-1;
        source_I =  rectpulse(bitstream_I, pnLength) ;
        source_Q =  rectpulse(bitstream_Q, pnLength) ;
        pnSequence = 2 * repmat(PN, 1, numBits) - 1;
        spreadData_I = source_I .* pnSequence;
        spreadData_Q = source_Q .* pnSequence;
        spreadData = spreadData_I +1j*spreadData_Q;
        % scatter(spreadData_I,spreadData_Q);
end

if(Shape == "RaisedCos")
    Shape = "Normal";
elseif(Shape == "RootRaisedCos")
    Shape = "Square root";
else
    Shape = "Square root";
end

rctFilt = comm.RaisedCosineTransmitFilter(...
    'Shape',                  Shape, ...           % 选择滤波器形状，Normal 或 Square root
    'RolloffFactor',          RolloffFactor, ...   % 滚降系数
    'FilterSpanInSymbols',    sps0, ...             % 滤波器的符号跨度
    'OutputSamplesPerSymbol', sps0);                % 每个符号的采样点数
yo=(rctFilt(spreadData.')).';
base_sig= yo(sps0*sps0/2+1:length(yo));              % 基带信号


% %%  画图,根据PN序列相关峰之间的距离，判断生成信号的准确性
% % 控制 p_max 的大小使 framelen 的长度小于5000大于2500
% base_sig_length = length(base_sig);
% p_max = ceil(base_sig_length / 2500); % 初始猜测值
% framelen = floor(base_sig_length / p_max);
% 
% while framelen > 5000
%     p_max = p_max + 1;
%     framelen = floor(base_sig_length / p_max);
% end
% N_fft = 2^(ceil(log2(framelen)));
% figure(1)
% f = (Fs0/N_fft:Fs0/N_fft:N_fft*Fs0/N_fft)-Fs0/2;
% plot(f,20*log10(fftshift(abs(fft(base_sig,N_fft)))));
% power_sec_FFT_all = zeros(1,N_fft); %二次处理结果
% 
% for p=1:p_max
%     temp = base_sig((p-1)*framelen+1:p*framelen);
%     power_secondary_FFT= sec_treat(temp,N_fft); %#ok<*SAGROW> %sec_treat函数用于获得DSSS的二次功率谱
%     power_sec_FFT_all = power_sec_FFT_all + power_secondary_FFT; %10次数据的处理累加
% end
% figure(2)
% plot(power_sec_FFT_all)
% pre_Nlenth = sps0*pnLength;
end


function [pnSequence,pnLength] = PnCode_Gen(PN_type,pnGenPolyCoeffs,pnGenInitState)

N = length(pnGenPolyCoeffs);
pnLength = 2^N - 1;
ployLimitTable = primpoly(N,'all','nodisplay');
pnGenInitState = flip(pnGenInitState);

switch PN_type
    case "M"
        decimalNumber = bin2dec(flip(num2str([1;pnGenPolyCoeffs].')));
        if(~ismember(ployLimitTable,decimalNumber))
            disp("非本原多项式，无法生成m序列！")
        end
        pnSequence = mseq_gen(pnGenPolyCoeffs,pnGenInitState); %左边最高位，右边最低位，去除常数项

    case "GOLD"
        decimalNumber = bin2dec(flip(num2str([1;pnGenPolyCoeffs].')));
        if(~ismember(ployLimitTable,decimalNumber))
            disp("非本原多项式，无法生成m序列！")
        end
        pnSequenceFirst = mseq_gen(pnGenPolyCoeffs,pnGenInitState);
        count = 1;
        while(count<=length(ployLimitTable))
            decimalNumber = ployLimitTable(count);
            pnGenPolyCoeffsSecond = flip(dec2bin(decimalNumber));
            pnGenPolyCoeffsSecond = dec2bin(bin2dec(pnGenPolyCoeffsSecond),length(pnGenPolyCoeffsSecond))-'0';
            pnSequenceSecond = mseq_gen(pnGenPolyCoeffsSecond(2:end).',pnGenInitState);
            if(check_msequence_pair(pnSequenceFirst, pnSequenceSecond))
                [xcr,~] = periodic_corr(2*pnSequenceFirst-1,2*pnSequenceSecond-1);
                randSt2 = randi(pnLength);
                pnSequenceSecond_shift = [pnSequenceSecond(randSt2:end)  pnSequenceSecond(1:randSt2-1)];
                pnSequence = mod(pnSequenceFirst+pnSequenceSecond_shift,2);
                break;
            elseif(count==ployLimitTable)
                disp("未搜索到优选对，无法生成Gold序列！")
                break;
            end
            count = count+1;
        end
end


end
function is_preferred_pair = check_msequence_pair(seq1, seq2)
% 检查序列长度
len1 = length(seq1);
len2 = length(seq2);

if len1 ~= len2
    error('两个序列的长度必须相同');
end
n = log2(len1 + 1);
if mod(n, 1) ~= 0
    error('序列的长度必须为 2^n - 1');
end
% 计算互相关
[cross_corr,~] = periodic_corr(2*seq1-1, 2*seq2-1);
% 计算阈值
if mod(n, 2) == 1
    threshold = 2^( (n+1) / 2 ) + 1;
elseif mod(n, 4) ~= 0
    threshold = 2^( n / 2 + 1 ) + 1;
else
    error('n 为偶数时必须不被 4 整除');
end

% 判断互相关函数的值是否符合阈值条件
is_preferred_pair = all(abs(cross_corr) <= threshold);
end

function [r,lags] = periodic_corr(x,y)
if size(x,2) == 1 && ~isscalar(x)
    x = x';
end
if size(y,2) == 1 && ~isscalar(y)
    y = y';
end
if size(x,2)~=size(y,2)
    error(message('x y dimension mismatch'));
end
L = size(x,2);
r = zeros(1,2*L-1);
for m = 1:L
    if m == 1
        r(L) = x*y';
    else
        r(L+m-1) = x*y';
        r(m-1) = x*y';
    end
    y = circshift(y,-1);
end
lags = -(L-1):L-1;
end
function [seq]=mseq_gen(coef,initial_state)
%m序列发生器
%coef 为生成多项式
m=length(coef);
len=2^m-1; % 得到序列的长度
seq=zeros(1,len); % 给生成的m序列预分配
% initial_state = [1  zeros(1, m-2) 1]; % 给寄存器分配初始结果
for i=1:len
    seq(i)=initial_state(m);
    backQ = mod(sum(coef.*initial_state) , 2);
    initial_state(2:length(initial_state)) = initial_state(1:length(initial_state)-1);
    initial_state(1)=backQ;
end
end
function [power_secondary_FFT] = sec_treat(data,N_fft)
if(length(data)<N_fft)
    data = [data zeros(1,N_fft-length(data))];
end
r = xcorr(data(1:N_fft));
power_data = fft(r,N_fft);
power_secondary_FFT=abs(fft(power_data ,N_fft)).^2/N_fft;
end