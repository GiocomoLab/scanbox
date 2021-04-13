% Searches for a reference image

global refimg fnum

% painstaking calibration measurements using pollen grains slide
microns_cal = [1091 990 778 683 543 471 386 328 272 230 194 163 150]; % 796 columns 512 rows
mag_list = [1 1.2 1.4 1.7 2.0 2.4 2.8 3.4 4.0 4.8 5.7 6.7 8];
tau = 5;
delta = exp(-1/tau);

if(flag) % first call? Format chA/chB according to lines/columns in data
    
    scanbox_config;
    
    sb = udp('localhost','RemotePort',7000);  % local connection to Scanbox
    fopen(sb);
   
    mmfile.Format = {'int16' [1 16] 'header' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chA' ; ...
        'uint16' double([mmfile.Data.header(2) mmfile.Data.header(3)]) 'chB'};
    
    magval = input('magnification?');
    mag = mag_list(mag_list==magval);
    microns = microns_cal(mag_list==magval);
    microns
    
    pmt = input('Which PMT (0/1)?');
    if pmt==0
        mchA = double(intmax('uint16')-mmfile.Data.chA);
    elseif pmt==1
        mchA = double(intmax('uint16')-mmfile.Data.chB);
    end
   
    [rows,cols] = size(mchA);
    micronsperpix_row = microns/rows; micronsperpix_col = microns/cols;
    % setup fig
    
    pickref([],[]); % select reference image
    
    close all
   
    f = figure(1);
    f.MenuBar = 'none';
    f.NumberTitle = 'off';
    f.Name = 'Search Display';
    figure(f);
    
    C = imfuse(refimg,mchA,'falsecolor','ColorChannels',[1 2 0]);
    h = imshow(C);
    ttl = title('');
    
    zrange  = sbconfig.plugin_param.searchref.zrange;
    zdelta  = sbconfig.plugin_param.searchref.zdelta;
    nframes = sbconfig.plugin_param.searchref.nframes;
    
    zpos = round(zrange:-zdelta:-zrange);
    idx = 0;
    midx = length(zpos);
    acc = zeros([size(mchA) midx]);
    
    fprintf(sb,'Ks'); % set knobby in superfine mode
    pause(0.5);
    fprintf(sb,sprintf('Pz%d',zrange)); % move to start zstack
    pause(1);
    
    flag = 0;
    newblock = true;
    done = false;
    k = 1;
    
else
%     disp('wtf');
    if ~done
        %%[idx k newblock fnum]
        if pmt==0
            mchA = double(intmax('uint16')-mmfile.Data.chA);
        elseif pmt==1
            mchA = double(intmax('uint16')-mmfile.Data.chB);
        end
%         mchA = double(intmax('uint16')-mmfile.Data.chA);
%         disp('in z stack');
        if idx<=midx
            if newblock
                idx = idx + 1;
                k = 1;
                acc(:,:,idx) = mchA;
                newblock = false;
                ttl.String = sprintf('z-stack: slice %d of %d (red = reference image)',idx,midx);
            else
                acc(:,:,idx) = acc(:,:,idx) + mchA;    % accumulate
                k = k + 1;
                newblock = (k>=nframes);
                if newblock
                    C = imfuse(refimg,squeeze(acc(:,:,idx)),'falsecolor','ColorChannels',[1 2 0]);
                    h.CData = C;
                    fprintf(sb,sprintf('Pz-%d',zdelta)); % move down by delta
                    pause(0.2);
                end
            end
        else
            pause(.5);
            fprintf(sb,sprintf('Pz%d',zrange+zdelta)); % move back to center
            pause(1);
            
            % compute optimal translation
            cc = zeros(1,midx);
            u = zeros(1,midx);
            v = zeros(1,midx);
            for i = 1:midx
                [u(i),v(i),cc(i)] = search_fftalign(refimg,squeeze(acc(:,:,i)));
            end
            
            [mcc,q] = max(cc);
            fprintf(sb,sprintf('Pz%d',zpos(q))); % move to optimal location
            fprintf(sb,sprintf('Px%d',-u(q)*micronsperpix_row));
            fprintf(sb,sprintf('Py%d',v(q)*micronsperpix_col));
            done = true;
            
            %         fprintf(sb,'S');      % stop sampling...
            %         fprintf(sb,'I0');     % disable plugins
            
        end
    else
        % just display result...
        ttl.String = 'Optimal alignment';
        if pmt==0
            mchA_ = double(intmax('uint16')-mmfile.Data.chA);
        elseif pmt==1
            mchA_ = double(intmax('uint16')-mmfile.Data.chB);
        end
        mchA = delta*mchA + (1-delta)*mchA_; 
%         mchA = double(intmax('uint16')-mmfile.Data.chA);
        C = imfuse(refimg,mchA,'falsecolor','ColorChannels',[1 2 0]);
        h.CData = C;        
    end
end

drawnow;