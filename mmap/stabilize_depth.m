% Depth stabilization plugin

global refimg fnum

if(flag) % first call? Format chA/chB according to lines/columns in data
    
    scanbox_config;
    
    sb = udp('localhost','RemotePort',7000);  % local connection to Scanbox
    fopen(sb);
    
    mmfile.Format = {'int16' [1 16] 'header' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chA' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chB'};
    mchA = double(intmax('uint16')-mmfile.Data.chA);
    
    % setup fig
        
    close all
    f = figure(1);
    f.MenuBar = 'none';
    f.NumberTitle = 'off';
    f.Name = 'Depth Stabilization Display';
    figure(f);
    
    h = imagesc(mchA);
    colormap gray;
    axis off equal
    
    ttl = title('');
    
    zrange  = sbconfig.plugin_param.stabilize_depth.zrange;
    zdelta  = sbconfig.plugin_param.stabilize_depth.zdelta;
    nframes = sbconfig.plugin_param.stabilize_depth.nframes;
    alpha  = sbconfig.plugin_param.stabilize_depth.alpha;
    
    zpos = round(zrange:-zdelta:-zrange);
    idx = 0;
    midx = length(zpos);
    acc = zeros([size(mchA) midx]);
        
    fprintf(sb,'Ks'); % set knobby in superfine mode
    pause(0.5);
    fprintf(sb,sprintf('PZ%d',zrange)); % move to start zstack
    pause(1);
    
    flag = 0;
    newblock = true;
    done = false;
    ccplot = false;
    k = 1;
    
else
    
    if ~done     % doing zstack here...
        
        %%[idx k newblock fnum]
        
        mchA = double(intmax('uint16')-mmfile.Data.chA);
        
        if idx<=midx
            if newblock
                idx = idx + 1;
                k = 1;
                acc(:,:,idx) = mchA;
                newblock = false;
                ttl.String = sprintf('z-stack: slice %d of %d',idx,midx);
            else
                acc(:,:,idx) = acc(:,:,idx) + mchA;    % accumulate
                k = k + 1;
                newblock = (k>=nframes);
                if newblock
                    h.CData = squeeze(acc(:,:,idx));
                    fprintf(sb,sprintf('PZ-%d',zdelta)); % move down by delta
                    pause(0.2);
                end
            end
                       
        else
            delete(h);
            done = true; % finished doing zstack
            pause(.5);
            fprintf(sb,sprintf('PZ%d',zrange+zdelta)); % move back to center!
            pause(1);
        end
    else
        
        mchA = double(intmax('uint16')-mmfile.Data.chA);
        
        % Compute the best depth...
        
        cc = zeros(1,midx);
        u = zeros(1,midx);
        v = zeros(1,midx);
        for i = 1:midx
            [u(i),v(i),cc(i)] = search_fftalign(mchA,squeeze(acc(:,:,i)));
        end
                
        [mcc,q] = max(cc);
        
        if ~ccplot
            h = plot(zpos/12.8,cc/max(cc),'-o');
            xlabel('Relative depth (um)');
            ylabel('Normalized correlation');
            ylim([0.5 1]);
            xlim(1.05*[zpos(end) zpos(1)]/12.8);
            title('Tracking');
        else
            ccplot = true;
            h.YData = cc/max(cc);
        end
          
        fprintf(sb,sprintf('PZ%d',-zpos(q))); % move to 0
        pause(2);
       
     
    end
end

drawnow;