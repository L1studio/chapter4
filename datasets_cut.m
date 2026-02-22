clc
clear
close all
cut_point = 2048;
% 原始数据路径（修改成你的路径）
srcDir = 'fftmat_with_floor_0905\test';
files = dir(fullfile(srcDir, '*.mat'));
nFiles = numel(files);
outDir = 'submat_with_floor_0905\test';
if ~exist(outDir, 'dir'); mkdir(outDir); end

f_ori = 20e6;
f_ = 6250;
for i = 1:nFiles
    data = load(fullfile(srcDir,files(i).name));
    fft_mat = data.fft_mat;
    Rxobj = data.Rxobj;
    current_shuffled_signals = data.current_shuffled_signals;
    predict_floor1 = data.predict_floor;
    datalen  = size(fft_mat,2);
    for j = 1:floor(datalen/cut_point)
        annotation = [];
        sub_fft_mat = fft_mat(:,(j-1)*cut_point+1:j*cut_point);
        predict_floor = predict_floor1(:,(j-1)*cut_point+1:j*cut_point);
        s_st = f_ori+f_*((j-1)*cut_point+1);
        e_st = f_ori+f_*j*cut_point;
        for s = 1:length(current_shuffled_signals)
            st = current_shuffled_signals(s).start_freq;
            ed = current_shuffled_signals(s).end_freq;
            if(st>=s_st&&st<=e_st)||(ed>=s_st&&ed<=e_st)||(st<=s_st&&ed>=e_st)
                hang = current_shuffled_signals(s).hang;
                if(~isempty(hang))
                    for h = 1:size(hang,1)
                        on = hang(h,1);
                        under = hang(h,2);
                        left = max(round((st-s_st)/f_),1);
                        right = min(round((ed-s_st)/f_),cut_point);
                        snr = current_shuffled_signals(s).receive_snr;
                        annotation = [annotation;left,right,on,under,snr];

                    end
                else
                    on = 1;
                    under = size(sub_fft_mat,1);
                    left = max(round((st-s_st)/f_),1);
                    right = min(round((ed-s_st)/f_),cut_point);
                    snr = current_shuffled_signals(s).receive_snr;
                    annotation = [annotation;left,right,on,under,snr];
                end
            elseif(st>=e_st)
                break;
            end
        end
%         figure()
%         imagesc(sub_fft_mat)
%         hold on
%         for  s = 1:size(annotation,1)
%             plot([annotation(s,1) annotation(s,2)],[annotation(s,3),annotation(s,3)],'-r','LineWidth',1)
%             plot([annotation(s,1) annotation(s,2)],[annotation(s,4),annotation(s,4)],'-r','LineWidth',1)
%             plot([annotation(s,1) annotation(s,1)],[annotation(s,3),annotation(s,4)],'-r','LineWidth',1)
%             plot([annotation(s,2) annotation(s,2)],[annotation(s,3),annotation(s,4)],'-r','LineWidth',1)
%         end
        [~, name, Ext] = fileparts(files(i).name);
        pattern = 'chapter4_(\d{5})';
        match = regexp(name,pattern,'tokens');
        number = match{1}{1};
        filename = "sub_matrix_with_floor_(dBW)"+"_"+"chapter4_"+number+"_"+string(j)+Ext;
        save(fullfile(outDir, filename), "sub_fft_mat","annotation","predict_floor");

    end
end
