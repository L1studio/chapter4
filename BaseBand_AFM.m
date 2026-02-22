function [dk,base_sig] = BaseBand_AFM(point0,Fd,sps,beta,shape,modType,h,conttype)
bit_lenmin = ceil(point0/sps);
if(conttype == "discont")
    ContinuousPhase = false;
else
    ContinuousPhase = true;
end
switch modType
    case "2FSK"
        bitdata = randi([0,1],1,bit_lenmin);
        % base_sig = Fsk2Modulator(bitdata,sps,rctFilt,h,conttype);
        x = comm.FSKModulator(2,"FrequencySeparation",Fd*h,'ContinuousPhase',ContinuousPhase,"BitInput",true,"SymbolRate",Fd,"SamplesPerSymbol",sps);
        base_sig = x(bitdata.').';
        dk = Fd*2+Fd*h;
    case "4FSK"
        bitdata =  randi([0,3],1,bit_lenmin);
        % base_sig = Fsk4Modulator(bitdata,sps,fs,f_div,conttype);
        x = comm.FSKModulator(4,"FrequencySeparation",Fd*h,'ContinuousPhase',ContinuousPhase,"BitInput",false,"SymbolRate",Fd,"SamplesPerSymbol",sps);
        base_sig = x(bitdata.').';
        dk = Fd*2+Fd*h*3;
    case "8FSK"
        bitdata =  randi([0,7],1,bit_lenmin);
        x = comm.FSKModulator(8,"FrequencySeparation",Fd*h,'ContinuousPhase',ContinuousPhase,"BitInput",false,"SymbolRate",Fd,"SamplesPerSymbol",sps);
        base_sig = x(bitdata.').';
        dk = Fd*2+Fd*h*7;
    case "MSK"
        bitdata =  randi([0,1],1,bit_lenmin);
        base_sig = MskModulator(bitdata,sps);
        dk = Fd*1.5;
    case "GMSK"
        bitdata =  randi([0,1],1,bit_lenmin);
        base_sig = GmskModulator(bitdata,sps);
        dk = Fd*3;
    case "2ASK"
        bitdata =  randi([0,1],1,bit_lenmin);
        mod_data = ASK2Modulator(bitdata,beta,sps,h);
    case "4ASK"
        bitdata =  randi([0,3],1,bit_lenmin);
        mod_data = ASK4Modulator(bitdata,beta,sps,h);
end
if(modType == "2ASK"||modType == "4ASK")
    dk = Fd*(1+beta*1.2);
    if(shape == "RaisedCos")
        shape = "Normal";
    elseif(shape == "RootRaisedCos")
        shape = "Square root";
    else
        shape = "Square root";
    end
    rctFilt = comm.RaisedCosineTransmitFilter(...
        'Shape',                 shape, ...
        'RolloffFactor',         beta, ...
        'FilterSpanInSymbols',    sps, ...
        'OutputSamplesPerSymbol', sps);
    yo=(rctFilt(mod_data.')).';
    base_sig= yo(sps*sps/2+1:length(yo));% 基带信号;
end

end

function mod_data = ASK2Modulator(msg,beta,sample,AM_md)
msg(msg==0) = 1-AM_md;
mod_data= msg;
end

function mod_data = ASK4Modulator(msg,beta,sample,AM_md)
msg(msg==0) = 3-3*AM_md;
msg(msg==1) = 3-2*AM_md;
msg(msg==2) = 3-AM_md;
mod_data= msg;

end
function mod_data = Fsk2Modulator(msg,sps,rctFilt,h,conttype)

signal_rcos = rctFilt(msg.').';
figure()
plot(10*log10(fftshift(abs(fft(signal_rcos)))))
model_index = pi*h/2;
if(conttype=="cont")
    phase=zeros(1,length(signal_rcos));
    for i=1:length(signal_rcos)
        if(i==1)
            phase(i)=signal_rcos(i);
        else
            phase(i)= phase(i-1)+signal_rcos(i);
        end
    end
    %FM调制
    mod_data = exp(1i*phase*model_index);
else
    phase=zeros(1,length(signal_rcos));
    for i=1:length(signal_rcos)
        if(mod(i,sps) ==1)
            phase(i)=signal_rcos(1);
        else
            phase(i)= phase(i-1)+signal_rcos(i);
        end
    end
    %FM调制
    mod_data = exp(1i*phase*model_index);
    figure
    plot(real(mod_data))
end
end
function mod_data = Fsk4Modulator(msg,sample,fs,f_div,conttype)
Fre_space = fs/sample*1*f_div;
Rsignal1 = fskmod(msg, 4, Fre_space, sample, fs,conttype);
mod_data= Rsignal1;
end
function mod_data = Fsk8Modulator(msg,sample,fs,f_div,conttype)
Fre_space = fs/sample*1*f_div;
Rsignal1 = fskmod(msg, 8, Fre_space, sample, fs,conttype);
mod_data= Rsignal1;
end
function mod_data = MskModulator(msg,sample)
mod = comm.MSKModulator(...
    'SamplesPerSymbol', sample, ...
    'BitInput',true ...
    );
% Modulate
mod_data = mod(msg.').';
end
function mod_data = GmskModulator(msg,sample)
mod = comm.GMSKModulator(...
    'SamplesPerSymbol', sample, ...
    'BitInput',true ...
    );

% Modulate
mod_data = mod(msg.').';
end
