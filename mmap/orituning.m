
% Example of real-time, pixelwise image processing in Scanbox

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
        
        % map the data
        
        mmfile.Format = {'int16' [1 16] 'header' ; ...
            'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chA' ; ...
            'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chB'};
        mchA = double(intmax('uint16')-mmfile.Data.chA);
        
        acc = zeros([size(mchA) 12]);   % accumulated responses
        N = zeros(1,12);    % number of frames for each condition

        % create figure
        
        close all
        f = figure(1);
        f.MenuBar = 'none';
        f.NumberTitle = 'off';
        f.Name = 'Orientation tuning';
        
        % show first frame
        
        h = imagesc(zeros(size(mchA))); truesize; axis off; colormap hsv;
        h.Parent.Color = [0 0 0]; % background color
        h.AlphaData = zeros(size(mchA));
        h.Parent.Parent.Color = [0 0 0]; % background color fig
        axis off;
        
        figure(f);
        
        % indicate we are done setting up the structures/figs
        
        flag = 0;
        update = true; 
    else
        
        if mmfile.Data.header(4)>0          % a stim present?
            
            idx = (mmfile.Data.header(13) / 30) + 1;
            acc(:,:,idx) = acc(:,:,idx) + double(intmax('uint16')-mmfile.Data.chA);
            N(idx) = N(idx)+1;
            update = true;
            
        elseif update && (sum(N)>0)           % stim not present and needs update?
            
            z = zeros(size(mchA)); % orientation map
            n = zeros(size(mchA));
                        
            for k = 1:12
                if N(k)>0
                    z = z + acc(:,:,k) .* exp(1i*(k-1)*30*2*pi/180) / N(k);
                    n = n + acc(:,:,k)/N(k);
                end
            end
            z = z./n;
            h.CData = angle(z);
            q = abs(z);
            q = q/max(q(:));    % normalize
            h.AlphaData = q;
            drawnow;
            update = false;
            
        end
        
    end
       
    mmfile.Data.header(1) = -1; % signal Scanbox that frame has been consumed!
    
end

clear(mmfile); % close the memory mapped file
close all;     % close all figures

