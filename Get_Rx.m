function Rxobj = Get_Rx(filePath)

fileID = fopen(filePath, 'r');
rawData = fread(fileID, inf, 'uint8');
fclose(fileID);
jsonData = jsondecode(char(rawData'));
nodeNum = numel(jsonData);
Rxobj.Num = nodeNum;

Rxobj.rxId_V = strings(nodeNum, 1);
Rxobj.sample_band = zeros(nodeNum, 1);
Rxobj.freq_rf = zeros(nodeNum, 1);
% Rxobj.F_ = zeros(nodeNum, 1);
Rxobj.nfft = zeros(nodeNum, 1);
Rxobj.antenna_gain = zeros(nodeNum, 1);

for i = 1:nodeNum
    Rxobj.rxId_V(i) = jsonData(i).rx_id;
    Rxobj.sample_band(i) = jsonData(i).band;
    Rxobj.freq_rf(i) = jsonData(i).rf;
    % Rxobj.F_(i) = jsonData(i).F_;
    Rxobj.nfft(i) = jsonData(i).nfft;
    Rxobj.antenna_gain(i) = jsonData(i).antenna_gain;


end
end
