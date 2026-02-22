function shuffled_signals = rand_except_basejson(rf,band,shuffled_signals)
% REF_EXCEPT_BASEJSON 重构场景：随机打乱信号在频谱上的中心位置 和 SNR，更新配置文件
% 输入：
%   rf              : 接收机中心频率 (Hz)
%   band            : 接收机带宽 (Hz)
%   shuffled_signals: 输入信号列表（包含 .type 等信息，但频率和SNR待更新）
% 输出：
%   shuffled_signals: 更新后的信号列表（包含新的 .fc, .rate, .receive_snr）
filename = 'Tx_para.json';
fid = fopen(filename, 'r');
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
data = jsondecode(str);

new_data = data(1); % 保留原始数据

% 获取最后一个 tx_id 的数值
last_tx_id = str2double(new_data(end).tx_id);
% 设置字段的范围
freq_min = rf-band/2+500e3;  % 频率下限
freq_max =  rf+band/2-500e3;   % 频率上限
baudrate_step = 50e3; % 码元速率步长
receive_snr_min = 0;
receive_snr_max = 15;
shuffled_signals = rand_except_baseallo(6250,baudrate_step,freq_min,freq_max,shuffled_signals);

for xx = 1:length(shuffled_signals)
    new_object = new_data(1); % 复制第一个对象作为模板
    % 更新 tx_id
    new_object.tx_id = num2str(last_tx_id + xx);
    new_object.mod_type =  shuffled_signals(xx).type;
    % 在范围内随机波动值
    new_object.symbol_rate = shuffled_signals(xx).rate;
    new_object.freq_c = shuffled_signals(xx).fc;
    if rand() < 0.6
        % 60% 的概率在 0-5 dB 内
        snr = receive_snr_min + (5 - receive_snr_min) * rand();
    else
        % 30% 的概率在 5-8 dB 
        if rand() < 0.75
            snr = 5 + (8 - 5) * rand(); 
        else
            snr = 8 + (receive_snr_max - 8) * rand();                 % 8~15
        end
    end
    new_object.receive_snr = snr;  % 随机 transmit_power

    new_object.arfa =  shuffled_signals(xx).alpha; % 随机 arfa
    % 将新对象加入到数组中
    new_data(xx) = new_object;
    shuffled_signals(xx).receive_snr = new_object.receive_snr;
    shuffled_signals(xx).type = new_object.mod_type;

end
% 将数据转换为 JSON 字符串
json_str = jsonencode(new_data);

% 使用替换符号进行格式化输出
formatted_json_str = pretty_json(json_str);

% 将格式化后的 JSON 写入文件
fid = fopen('Tx_para.json', 'w');
fwrite(fid, formatted_json_str, 'char');
fclose(fid);

% JSON 格式化函数
    function formatted_str = pretty_json(json_str)
        % 在指定位置插入换行和缩进
        formatted_str = '';
        indent = 0;
        in_string = false;

        for x = 1:length(json_str)
            char = json_str(x);

            if char == '"' && (x == 1 || json_str(x-1) ~= '\')  % 如果是字符串的开始或结束
                in_string = ~in_string;
                formatted_str = [formatted_str char];
            elseif in_string
                formatted_str = [formatted_str char];
            else
                switch char
                    case '{'
                        indent = indent + 1;
                        formatted_str = [formatted_str char newline repmat('    ', 1, indent)];
                    case '}'
                        indent = indent - 1;
                        formatted_str = [formatted_str newline repmat('    ', 1, indent) char];
                    case '['
                        indent = indent + 1;
                        formatted_str = [formatted_str char newline repmat('    ', 1, indent)];
                    case ']'
                        indent = indent - 1;
                        formatted_str = [formatted_str newline repmat('    ', 1, indent) char];
                    case ','
                        formatted_str = [formatted_str char newline repmat('    ', 1, indent)];
                    case ':'
                        formatted_str = [formatted_str char ' '];
                    otherwise
                        formatted_str = [formatted_str char];
                end
            end
        end
    end
end