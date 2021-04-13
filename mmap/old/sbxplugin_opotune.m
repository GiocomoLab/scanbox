
% Plug-in Demo: Display optical sections separately

close all; % Close all open figs

% Open memory mapped file -- define just the header first

mmfile = memmapfile('scanbox.mmap','Writable',true, ...
    'Format', { 'int16' [1 16] 'header' } , 'Repeat', 1);
flag = 1;

% Process all incoming frames until Scanbox stops

while(true)
    
    while(mmfile.Data.header(1)<0) % wait for a new frame...
        if(mmfile.Data.header(1) == -2) % exit if Scanbox stopped
            return;
        end
    end
        
    if(flag) % first time? Format chA according to lines/columns in data
        mmfile.Format = {'int16' [1 16] 'header' ; ...
            'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chA'};
        mchA = double(intmax('uint16')-mmfile.Data.chA);
        flag = 0;
        nplanes = mmfile.Data.header(6);
        I = zeros([size(mchA) 1 nplanes]);
        I(:,:,1,1) = mchA;
        imaqmontage(I);
        axis off;           % remove axis
        colormap gray;      % use gray colormap
    else
        I(:,:,1,mod(mmfile.Data.header(1),nplanes)+1) = double(intmax('uint16')-mmfile.Data.chA);
        imaqmontage(I);
    end
    
    mmfile.Data.header(1) = -1; % signal Scanbox that frame has been consumed!
    drawnow limitrate;
    
end

clear(mmfile); % close the memory mapped file
close all;     % close all figures

