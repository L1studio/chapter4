function Txobj = Get_Tx(filePath)
fileID = fopen(filePath, 'r');
rawData = fread(fileID, inf, 'uint8');  %二进制数据
fclose(fileID);
jsonData = jsondecode(char(rawData'));  %json解码
nodeNum = numel(jsonData);              %发射机个数
%% 分配空间
Txobj.Num = nodeNum;

Txobj.txId_V = strings(nodeNum, 1);
Txobj.freqC_V = zeros(nodeNum, 1);
Txobj.modType_V = strings(nodeNum, 1);
Txobj.multiplexingType_V = strings(nodeNum, 1);
Txobj.symbolRate_V = zeros(nodeNum, 1);
Txobj.shapingType_V = strings(nodeNum, 1);
Txobj.arfa_V = zeros(nodeNum, 1);
Txobj.modDepth_V = zeros(nodeNum, 1);
Txobj.contPhase_V = strings(nodeNum, 1);
Txobj.receive_snr_V = zeros(nodeNum, 1);
Txobj.systemType_V=strings(nodeNum,1);
%% 赋值
for i = 1:nodeNum
    Txobj.txId_V(i) = jsonData(i).tx_id;
    Txobj.freqC_V(i) = jsonData(i).freq_c;
    Txobj.modType_V(i) = jsonData(i).mod_type;
    Txobj.multiplexingType_V(i) = jsonData(i).multiplexing_type;
    Txobj.symbolRate_V(i) = jsonData(i).symbol_rate;
    Txobj.shapingType_V(i) = jsonData(i).shaping_type;
    Txobj.arfa_V(i) = jsonData(i).arfa;
    Txobj.modDepth_V(i) = jsonData(i).mod_depth;
    Txobj.contPhase_V(i) = jsonData(i).cont_Phase;
    Txobj.receive_snr_V(i) = jsonData(i).receive_snr;
    Txobj.systemType_V(i)=jsonData(i).system_type;
end
end
