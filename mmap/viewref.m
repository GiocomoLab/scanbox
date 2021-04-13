
% Example on how to show data from both red and green channels together

% flag is initialized by the calling plug-in server -- set to 0 after
% setting up the required data structures after the first call

global refimg

if(flag) % first call? Format chA/chB according to lines/columns in data
    mmfile.Format = {'int16' [1 16] 'header' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chA' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chB'};
    mchA = double(intmax('uint16')-mmfile.Data.chA);
    
    % setup fig
    
    close all
    f = figure(1);
    f.MenuBar = 'none';
    f.NumberTitle = 'off';
    f.Name = 'Reference Display';
    
    % show first frame
    
    h = imagesc(mchA); truesize; axis off; colormap gray;
    mchA = double(intmax('uint16')-mmfile.Data.chA);

    C = imfuse(refimg,mchA,'falsecolor','ColorChannels',[1 2 0]);
    h = imshow(C);
    
    figure(f);
    loadb = uicontrol('Style','pushbutton','String','Reference','Callback',@pickref);
    
    flag = 0;
    
else
    mchA = double(intmax('uint16')-mmfile.Data.chA);
    C = imfuse(refimg,mchA,'falsecolor','ColorChannels',[1 2 0]);
    h.CData = C;
end

drawnow;