classdef helperModClassTestChannel < matlab.System

    properties
        SNR = 20
        CenterFrequency = 2.4e9
        N_power=0%噪声功率
    end
    properties (Nontunable)
        SampleRate = 1  %采样率 hz
        PathDelays = 0  %时延hz
        AveragePathGains = 0 %多径衰落
        KFactor = 3%直达路径与多径的功率比
        MaximumDopplerShift = 0%最大多普勒频移
        MaximumClockOffset = 0
        tot_gain=0;

    end
    properties(Access = private)
        MultipathChannel%多径信道
        FrequencyShifter%频偏
        TimingShifter%时延
        C % 1+(ppm/1e6)
    end
    methods
        function obj = helperModClassTestChannel(varargin)%构造函数
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:})
        end
    end
    methods(Access = protected)
        rng(seedValue);
        function setupImpl(obj)%obj相对于this关键字。这里放置初始化的代码
            %rician信道相对于瑞利信道，还多了直射信道
            seedValue = 12345; % 任意一个整数值
            rng(seedValue);
            obj.MultipathChannel = comm.RicianChannel(...
                'SampleRate', obj.SampleRate,...
                'PathDelays', obj.PathDelays, ...
                'AveragePathGains', obj.AveragePathGains, ...
                'KFactor', obj.KFactor, ...
                'MaximumDopplerShift', obj.MaximumDopplerShift ...
                );
            obj.FrequencyShifter = comm.PhaseFrequencyOffset(...
                'SampleRate', obj.SampleRate);
        end
        function [y] = stepImpl(obj,x)
            % Add channel impairments
%             yInt1 = addMultipathFading(obj,x);%加入多径模拟
% %             yInt1(1:15)
% %             x(1:15)
% %             figure;
% %             subplot(2,1,1);
% %             plot(abs(yInt1.'))
% %             subplot(2,1,2);
% %             plot(abs(x.'))
%             % 调整AveragePathGains以匹配输入信号功率
% %             假设我们知道需要调整的增益补偿因子
%             gainCompensationFactor = sqrt(mean(abs(x).^2) / mean(abs(yInt1).^2));
% 
% 
%             % 应用增益补偿因子
%             yInt1 = yInt1 * gainCompensationFactor;
% %             disp(["经rician信道传输后的信号功率：",num2str(mean(abs(yInt1).^2))]);
%             yInt1_temp=yInt1.';
%             TotalGain = 10^(obj.tot_gain/20);
%             yInt1=yInt1*TotalGain;
%             yInt1_pow=mean(abs(yInt1).^2);
%             attenuation_sig_pow=yInt1_pow;
% %             disp(["经衰减后信号的功率:",num2str(yInt1_pow)]);
%             yInt2 = addClockOffset(obj, yInt1);%加入时钟偏移(接收端和发送端)
% %             disp(["经时钟偏移传输后的信号功率：",num2str(mean(abs(yInt2).^2))]);
%             yInt2_temp=yInt2.';

            y= addNoise(obj, x);%加入噪声(所有路径信号在时域叠加后加入噪声)
        end
        function out = addMultipathFading(obj, in)
            reset(obj.MultipathChannel)%清除内部状态数据、缓冲区、计数器等
            out = obj.MultipathChannel(in);%将信号输入进多径信道
        end
        function out = addClockOffset(obj, in)
            maxOffset = obj.MaximumClockOffset;
            clockOffset = (rand() * 2*maxOffset) - maxOffset;%时钟偏移范围(-maxOffset,maxOffset)
            obj.C = 1 + clockOffset / 1e6;%时钟偏移以百万分之一为单位
            outInt1 = applyFrequencyOffset(obj, in);%
            out = applyTimingDrift(obj, outInt1);%
            out(end)=0;
        end
        function out = applyFrequencyOffset(obj, in)
            obj.FrequencyShifter.FrequencyOffset = ...
                -(obj.C-1)*obj.CenterFrequency;
            %生成随机相位抖动
            phaseOffset=rand(1)*360/180*pi;
            %       phaseOffset=deg2rad(pathPhaseOffsets(phase_jitter));
            obj.FrequencyShifter.PhaseOffset=phaseOffset;
            %       out=zeros(size(phase_jitter));
            %       for i=1:length(phase_jitter)
            %           obj.FrequencyShifter.PhaseOffset=phase_jitter(i);
            %           out(i) = obj.FrequencyShifter(complex(in(i)));
            %       end
            out=obj.FrequencyShifter(in);
        end
        function out = applyTimingDrift(obj, in)
            originalFs = obj.SampleRate;
            x = (0:length(in)-1)' / originalFs;
            newFs = originalFs * obj.C;%对原采样率进行
            xp = (0:length(in)-1)' / newFs;
            out = interp1(x, in, xp);%进行插值
        end
        %% 添加噪声
        function out = addNoise(obj, in)
            %这个需要改，应该使得同一个无人机上八个通道的噪声功率一样
            %       out = awgn(in,obj.SNR);%awgn函数可以将指定db大小的噪声加入到信号上
            %     noise=wgn(1,length(in),obj.N_power,'dBW');
            noise_power=10.^((obj.N_power/10));
            dataLen=length(in);
            %     signal_power=mean(abs(in.').^2);%信号功率
            %     disp(['经信道传输后信号功率',num2str(signal_power)]);
            noise = sqrt(noise_power/2).*(randn(1,dataLen)+1i*randn(1,dataLen));%产生复高斯白噪声
            noise_power=mean(abs(noise).^2);
            disp(['噪声功率',num2str(noise_power)]);
            out=in+noise;%加.防止发生共轭
        end
        %清除属性
        function resetImpl(obj)
            reset(obj.MultipathChannel);
            reset(obj.FrequencyShifter);
        end
        function s = infoImpl(obj)
            if isempty(obj.MultipathChannel)
                setupImpl(obj);
            end
            mpInfo = info(obj.MultipathChannel);%info函数用来获取其详细信息，会调用infoImpl()函数
            maxClockOffset = obj.MaximumClockOffset;
            maxFreqOffset = (maxClockOffset / 1e6) * obj.CenterFrequency;
            maxClockOffset = obj.MaximumClockOffset;
            maxSampleRateOffset = (maxClockOffset / 1e6) * obj.SampleRate;%计算多径里最大时间偏移
            s = struct('ChannelDelay', ...
                mpInfo.ChannelFilterDelay, ...
                'MaximumFrequencyOffset', maxFreqOffset, ...
                'MaximumSampleRateOffset', maxSampleRateOffset);
        end
    end
end
