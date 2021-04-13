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
    
    % create figure
    
    close all
    f = figure(1);  
    f.MenuBar = 'none';
    f.NumberTitle = 'off';
    f.Name = 'Rolling Average Display for Mesoscope';
    
    % show first frame
    
    nrois = mmfile.Data.header(12);
    mchA = cell(1,nrois);
    mchA{1} = double(intmax('uint16')-mmfile.Data.chA);
    for k = 2:nrois
        mchA{k} =  double(intmax('uint16'))*ones(size(mchA{1}));
    end
    
    switch nrois
        case 1
            nrow = 1;
            ncol = 1;
        case 2 
            nrow = 2;
            ncol = 1;
        case 3
            nrow = 3;
            ncol = 1;
        case 4
            nrow = 2;
            ncol = 2;
        case 5
            nrow = 3;
            ncol = 2;
        case 6 
            nrow = 3;
            ncol = 2;
        otherwise
            N = ceil(sqrt(nrois));
            nrow = N;
            ncol = N-1;
    end
    
    
    for k=1:double(nrois)
        subplot(nrow,ncol,k);
        h{k} = imagesc(mchA{k}); axis off equal; colormap gray;
    end
    
    figure(f);
    
    % indicate we are done setting up the structures/figs
    
    flag = 0;

else
    
    idx = mod(mmfile.Data.header(1),nrois)+1;
    
    % compute rolling average and update display 
    mchA{idx} = delta*mchA{idx} + (1-delta)*double(intmax('uint16')-mmfile.Data.chA);
    h{idx}.CData = mchA{idx};

end

drawnow;
