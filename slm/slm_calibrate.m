function slm_calibrate(fname)

%% setup analog in of laser

s = daq.createSession('ni');
addAnalogOutputChannel(s,'Dev1','ao1', 'Voltage');
outputSingleScan(s,0);

%% setup fig

gpuDevice(1);
close all;
closepreview

[xx,yy] = meshgrid(1:1920,1:1080); % holoeye size

q = figure(1); % fig 1 is the slm
mon = get(0,'MonitorPositions');
q.Units = 'pixels';
q.MenuBar = 'none';
q.Position = mon(2,:);
a = gca;
a.Position = [0 0 1.04 1.11];

figure(1);
colormap(gray(256));
slmimg = image('CData',uint8(zeros(size(xx))));
axis off;
        
% slmimg = image(zeros(size(xx),'uint8'));
% colormap(gray(256));
% axis off;

%% bring camera up...
global vid;

imaqreset;
vid = videoinput('gige', 2, 'Mono12');

src = getselectedsource(vid);
src.BinningHorizontal = 'x2';
src.BinningVertical = 'x2';
src.ReverseX = 'True';

src.ConstantFrameRate = 'True';
src.ProgFrameTimeEnable = 'True';
src.ProgFrameTimeAbs = 100000;
src.ExposureMode = 'Timed';
src.ExposureTimeRaw = src.MaxExposure;

vidRes = vid.VideoResolution;
f = figure('Visible', 'off');
f.MenuBar = 'none';
imageRes = fliplr(vidRes);

hImage = imshow(zeros(imageRes));
axis image;
colormap(hImage.Parent,parula(256));


msg = text(30,30,'Automatic SLM Calibration');
msg.FontSize = 18;
msg.Color = 'y';
drawnow;

preview(vid,hImage);

pause(1);

%% start scanning

scanbox_config
sb_open
sb_mirror(0)
sb_current(800);

if(sbconfig.gain_override>0)
    sb_galvo_dv(sbconfig.dv_galvo);
    sb_set_mag_x_0(sbconfig.gain_resonant(1));
    sb_set_mag_x_1(sbconfig.gain_resonant(2));
    sb_set_mag_x_2(sbconfig.gain_resonant(3));
    sb_set_mag_y_0(sbconfig.gain_galvo(1));
    sb_set_mag_y_1(sbconfig.gain_galvo(2));
    sb_set_mag_y_2(sbconfig.gain_galvo(3));
end

laser_open
laser_send('SHUTTER=1');
sb_setparam(512,0,1);  %scan forever! need sb_abort to stop...
sb_pockels(0,60);
sb_deadband(0,0);
sb_scan

%% find scan area...

% title('Define Scan Area');
% [xs, ys] = ginputc(3, 'Color', 'y', 'LineWidth', 1);

msg.String = 'Find Scan Area';
pause(6);

q = double(getsnapshot(vid));
for(i=1:10)
    q = q+double(getsnapshot(vid));
end
q = (q-min(q(:)))/(max(q(:))-min(q(:)));
level = graythresh(q);
bw = bwareafilt(im2bw(q,level),1);
bw = imerode(bw,strel('disk',3));
[yy,xx] = find(bw);
[rectx,recty,area,perimeter] = minboundrect(xx,yy);
hold on
plot(rectx,recty,'y-','linewidth',2);
drawnow;

sb_abort;
laser_send('SHUTTER=0');

[xx,yy] = meshgrid(1:size(q,2),1:size(q,1));
mask = inpolygon(xx(:),yy(:),rectx,recty);
mask = reshape(mask,size(q));

%%
closepreview(vid);
src.ExposureTimeRaw = 750;
preview(vid,hImage);

outputSingleScan(s,.14);

msg.String = 'Spatial calibration';

[xx,yy] = meshgrid(1:1920,1:1080);

mat1 = zeros(size(xx));

yc = 1080/4-100;
xc = 1*1920/4-100;
dx = 130;

pts = zeros(9,2);
cal = zeros(9,2);
I = zeros(9,1);
img = cell(1,9);
k = 1;

for(ii=-1:.5:1)
    for(jj=-1:.5:1)
        x = zeros(1080,1920);
        x(yc+dx*ii,xc+dx*jj)=1;
        
        ph = gsa(ones(size(x)),double(x));
        slmimg.CData = ph;
        
%         figure(1);
%         colormap(gray(256));
%         image('CData',ph);
%         axis off;
%         figure(f);
        
        pts(k,:) = [xc+dx*jj yc+dx*ii];
        %[xi, yi] = ginputc(1, 'Color', 'y', 'LineWidth', 1);

        pause(2);
        
        q = double(getsnapshot(vid));
        for(i=1:20)
            q = q+double(getsnapshot(vid));
        end
        q = q/21/4095;
        
        I(k) = max(q(:).*mask(:));

        img{k} = q;
        [yp xp] = find(q.*mask == I(k));
        xp = mean(xp(:));
        yp = mean(yp);
        cal(k,:) = [xp yp];
        plot(xp,yp,'yx');
        k = k+1;
    end
end

%% find best affine transform

tform = fitgeotrans(cal,pts,'affine');

%%

outputSingleScan(s,2.7);
msg.String = 'Relative intensity';

x = zeros(1080,1920);
for(ii=-1:.5:1)
    for(jj=-1:.5:1)
        x(yc+dx*ii,xc+dx*jj)=1;
    end
end

ph = gsa(ones(size(x)),double(x));
slmimg.CData = ph;

% figure(1);
% colormap(gray(256));
% image('CData',ph);
% axis off;
% figure(f);
        
pause(2);
q = double(getsnapshot(vid));
for(i=1:40)
    q = q+double(getsnapshot(vid));
end

rI = q/41/4095;


%% validation


msg.String = 'Validation'; drawnow;

figure(f);
hold on

outputSingleScan(s,0.2);

while(true)
    %[xi, yi] = ginputc(1, 'Color', 'y', 'LineWidth', 1, 'ShowPoints','False');
    [xi yi] = ginput(1);
    if(isempty(xi))
        break;
    end
    plot(xi,yi,'wo');
    [aa,bb] = transformPointsForward(tform,xi,yi);  % just one point...
    x = zeros(1080,1920);
    x(round(bb),round(aa))=1;
  
    ph = gsa(ones(size(x)),double(x));
    slmimg.CData = ph;
%     figure(1);
%     colormap(gray(256));
%     image('CData',ph);
%     axis off;
%     figure(f);
  
end

outputSingleScan(s,0);

msg.String = 'Calibration saved!';

% compute xhat yhat and x0 y0

d = (rectx.^2 + recty.^2);
[~,idx] = min(d);
x0 = rectx(idx);
y0 = recty(idx);

xhat = [rectx(idx+1)-x0 recty(idx+1)-y0]; rwidth= norm(xhat); xhat = xhat/rwidth;
yhat = [rectx(idx-1)-x0 recty(idx-1)-y0]; rheight = norm(yhat); yhat = yhat/rheight;

% compute calibration points in scanbox window coords

calpts = [cal(:,1)-x0 cal(:,2)-y0] * [xhat' yhat'];
calpts(:,1) = calpts(:,1)/rwidth*796;
calpts(:,2) = calpts(:,2)/rheight*512;   % assumes 512 lines!

save(fname,'tform','cal','pts','rectx','recty','x0','y0','xhat','yhat','rwidth','rheight','I','img','rI', 'calpts');
    

close all;


% function ph = gsa2(src,dest)
% tic
% gsrc = gpuArray(src);
% gdest = gpuArray(dest);
% a = exp(1i*rand(size(gdest))*2*pi);
% r =0;
% for(k=1:30)
%     b = abs(gsrc) .* exp(1i*angle(a));
%     c = fft2(b);
%     d = abs(gdest) .* exp(1i*angle(c));
%     a = ifft2(d);
%     rho = corrcoef(gdest(:),abs(c(:)));
% end
% %rho(1,2)
% ph = gather(angle(a));
% %toc
% 
% 
% function ph = gsa3(src,dest)
% tic
% a = exp(1i*rand(size(dest))*2*pi);
% r =0;
% for(k=1:30)
%     b = abs(src) .* exp(1i*angle(a));
%     c = fft2(b);
%     d = abs(dest) .* exp(1i*angle(c));
%     a = ifft2(d);
%     rho = corrcoef(dest(:),abs(c(:)));
% end
% rho(1,2)
% ph = angle(a);
% toc
% 

