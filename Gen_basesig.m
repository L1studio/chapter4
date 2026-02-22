function [Bw,base] = Gen_basesig(Frame_len,Fs,Id,txorjs,txobj)
% 函数 Gen_basesig 生成基带信号
% 输入参数：
%   Frame_len - 数据长度
%   Fs - 采样频率
%   Fd - 符号速率
%   mod_type - 调制类型
%   arfa - 滚降系数
%   shaping_type - 成形类型
%   mod_depth - 调制深度
%   conttype - 连续相位类型
% 输出参数：
%   Bw - 带宽
%   base - 基带信号
if(txorjs == 1)
    x = find(Id == txobj.txId_V);
    Fd = txobj.symbolRate_V(x);
    mod_type = txobj.modType_V(x);
    arfa = txobj.arfa_V(x);
    shaping_type = txobj.shapingType_V(x);
    mod_depth = txobj.modDepth_V(x);
    conttype = txobj.contPhase_V(x);
    multiplexingType = txobj.multiplexingType_V(x);
    % sig_power=10^(txobj.transmitPower_V(x)/10);
else
    % x = find(Id == Jsobj.jsId_V);
    % Fd = Jsobj.NBI_symbolRate_V(x);
    % mod_type = Jsobj.NBI_modType_V(x);
    % arfa = Jsobj.NBI_arfa_V(x);
    % shaping_type = Jsobj.NBI_shapingType_V(x);
    % mod_depth = Jsobj.NBI_modDepth_V(x);
    % conttype = Jsobj.NBI_contPhase_V(x);
    % multiplexingType = Jsobj.NBI_multiplexingType_V(x);
    % sig_power=10^(Jsobj.transmitPower_V(x)/10);
end
%%
modulationTypes = categorical(["BPSK", "QPSK","PI/4DQPSK","OQPSK","8PSK","16PSK" ,...
    "16QAM","32QAM","64QAM","128QAM","256QAM","512QAM","1024QAM","16APSK","32APSK",...
    "2ASK","4ASK","2FSK","4FSK","8FSK","MSK","GMSK"]);
type = find(modulationTypes == mod_type);
sps  = Fs / Fd ;%码元（符号）个数

%%
switch multiplexingType
    case "NONE"
        if(type<=find(modulationTypes=="32APSK"))
            sps = round(sps/2)*2;   %%第一次过采样
            Fd = Fs/sps;
            base = BaseBand_QPA(ceil(Frame_len*1.005),sps,arfa,shaping_type,modulationTypes(type));%%基带信号生成
            Bw = Fd*(1+arfa)+50e3;%因为使用滤波器所以引入了滚降系数
            base  = overlap_retention(base,Fs,Bw);

            if(length(base)<Frame_len)
                base  = [base,zeros(1,Frame_len-length(base))];
            else
                base  = base(1:Frame_len);
            end

        elseif modulationTypes(type)=="2FSK"||modulationTypes(type)=="4FSK"||modulationTypes(type)=="8FSK"
            sps0  = 16;   %%第一次过采样
            Frame_len0 = Frame_len/sps*sps0; %%第一次输出点数
            Fs0 = Fd*sps0;
            M =  double(extract(string(modulationTypes(type)),1));
            Bw = ((M-1)*mod_depth+2)*Fd;    % ???????????????????不理解
            if(Bw>=Fs)
                mod_depth = (Fs/Fd-2)/(M-1);% ???????????????????不理解
            end
            [Bw,base0] = BaseBand_AFM(ceil(Frame_len0*1.05),Fd,sps0,arfa,shaping_type,modulationTypes(type),mod_depth,conttype);
            if(Fs0~=Fs)
                base0 = overlap_retention(base0,Fs0,Bw);
                base  = resample(base0,Fs,Fs0,256);
            else
                base  = overlap_retention(base0,Fs,Bw);
            end
            if(length(base)<Frame_len)
                base  = [base,zeros(1,Frame_len-length(base))];
            else
                base  = base(1:Frame_len);
            end
        elseif modulationTypes(type)=="2ASK"||modulationTypes(type)=="4ASK"
            sps0  = 8;                       %%第一次过采样
            Frame_len0 = Frame_len/sps*sps0; %%第一次输出点数
            Fs0 = Fd*sps0;
            [~,base0] = BaseBand_AFM(ceil(Frame_len0*1.05),Fd,sps0,arfa,shaping_type,modulationTypes(type),mod_depth,conttype);
            Bw = Fd*(1+arfa);
            if(Fs0~=Fs)
                base0 = overlap_retention(base0,Fs0,Bw);
                base  = resample(base0,Fs,Fs0,256);
            else
                base  = overlap_retention(base0,Fs,Bw);
            end
            if(length(base)<Frame_len)
                base  = [base,zeros(1,Frame_len-length(base))];
            else
                base  = base(1:Frame_len);
            end
        elseif modulationTypes(type)=="MSK"||modulationTypes(type)=="GMSK"
            sps0  = 8;                       %% 第一次过采样
            Frame_len0 = Frame_len/sps*sps0; %% 第一次输出点数
            Fs0 = Fd*sps0;
            [Bw,base0] = BaseBand_AFM(ceil(Frame_len0*1.05),Fd,sps0,arfa,shaping_type,modulationTypes(type),mod_depth,conttype);
            if(Fs0~=Fs)
                base0 = overlap_retention(base0,Fs0,Bw);
                base  = resample(base0,Fs,Fs0,256);
            else
                base  = overlap_retention(base0,Fs,Bw);
            end
            if(length(base)<Frame_len)
                base  = [base,zeros(1,Frame_len-length(base))];
            else
                base  = base(1:Frame_len);
            end
        end

    case "CDMA"
        [PN_type,pnGenPolyCoeffs,pnGenInitState] = Get_CDMA('CDMA.json',node_id) ;
        if(modulationTypes(type) == "BPSK" || modulationTypes(type) == "QPSK" )
            sps0  = 8;                       %% 第一次过采样
            Frame_len0 = Frame_len/sps*sps0; %% 第一次输出点数
            Fs0 = Fd*sps0;
            base0 = BaseBand_CDMA(ceil(Frame_len0*1.05),modulationTypes(type), PN_type, pnGenPolyCoeffs,pnGenInitState,shaping_type, arfa, sps0,Fs0);
            Bw = Fd*(1+arfa);
            if(Fs0~=Fs)
                base0 = overlap_retention(base0,Fs0,Bw);
                base  = resample(base0,Fs,Fs0,256);
            else
                base  = overlap_retention(base0,Fs,Bw);
            end
            if ( length(base) <Frame_len )
                base  = [base,zeros(1,Frame_len-length(base))];
            else
                base  = base(1:Frame_len);
            end
        else
            disp("CDMA只有BPSK、QPSK两种调制方式！")
        end


        case "TDMA"
        
        %     case "OFDM"

end

% 对信号进行归一化处理，使得信号的平均幅度为 1。
base = base/sqrt(mean(abs(base).^2));
% base=base*sqrt(sig_power);%将信号功率转为指定的功率
% time_power=mean(abs(base).^2);
% fft_power=sum(abs(fft(base)/length(base)).^2);

end

