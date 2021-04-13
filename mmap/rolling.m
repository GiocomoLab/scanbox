% flag is initialized by the calling plug-in server -- set to 0 after
% setting up the required data structures after the first call

% define time constact for exponential window (in frames)

tau = 5;
delta = exp(-1/tau);

if(flag) % first time? Format chA according to lines/columns in data
    
    % map the data 
    
    mmfile.Format = {'int16' [1 16] 'header' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chA' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chB'};
    mchA = double(intmax('uint16')-mmfile.Data.chA);
    
    % create figure
    
    close all
    f = figure(1);  
    f.MenuBar = 'none';
    f.NumberTitle = 'off';
    f.Name = 'Rolling Average Display';
    
    % show first frame
    
    h = imagesc(mchA); truesize; axis off; colormap gray;
    figure(f);
    
    % indicate we are done setting up the structures/figs
    
    flag = 0;

else
    
    % compute rolling average and update display 
    mchA = delta*mchA + (1-delta)*double(intmax('uint16')-mmfile.Data.chA);
    h.CData = mchA;

end

drawnow;
