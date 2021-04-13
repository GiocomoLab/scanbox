% flag is initialized by the calling plug-in server -- set to 0 after
% setting up the required data structures after the first call

global thehist thetitle

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
    f.Name = 'Histogram Display';
    
    margin = 128;
    nbins  = 128;
    
    % show first frame
    
    thehist = histogram(intmax('uint16')-mmfile.Data.chA(margin:end-margin,margin:end-margin),...
        linspace(0,double(intmax('uint16')),nbins+1)); % display histogram
    
    thetitle = title('');
    
    box off;
    
    % indicate we are done setting up the structures/figs
    
    flag = 0;
    
else    % updata data

    thehist.Data = intmax('uint16')-mmfile.Data.chA(margin:end-margin,margin:end-margin);
    x = double(thehist.Data);
    x = x(:);
    thetitle.String = sprintf('mean=%d median=%d std=%.2f',...
        round(mean(x)),...
        median(x),...
        std(x));
end
drawnow;

