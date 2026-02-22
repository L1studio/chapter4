close all
clear
clc
loadPath = "data\fftmat_0905\train\";
txtFiles = dir(fullfile(loadPath, '*.mat'));
fileNames = {txtFiles.name};

for x = 1:length(fileNames)-1
    tmp = fileNames{x};
    load([loadPath+tmp]);
    f =F_start + (0:1:length(image)-1)*F_resolution;
    N        = numel(image);
    anno_interp = interp1(annotation(:,1), annotation(:,2), (1:N), 'linear', 'extrap');  % 线性插值+外推

    figure(1)
    plot(f,image)
    hold on
    plot(f,anno_interp )
    colors = lines(length(shuffled_signals));  % 使用 lines colormap 生成不同颜色
    for i = 1:length(shuffled_signals)
        outline = round((shuffled_signals(i).start_freq-f(1))/F_resolution):round((shuffled_signals(i).end_freq-f(1))/F_resolution);
        plot(f(outline),(image(outline)),'-r','LineWidth',1);
        hold on
    end

    cut_point = 4096;
    for i = 1:floor(length(image)/cut_point)
        line([f(cut_point*(i)), f(cut_point*(i))], [(min(image)), (max(image))], 'Color', 'r', 'LineStyle', '--') ;
        hold on
    end
    figure(2)
    plot(f,image)
    hold on
    diff = (image-anno_interp);
    plot(f,diff )
    hold on
    th = 3;
    a = find(diff>th)
    stem(f(a),diff(a))

    close all
end

