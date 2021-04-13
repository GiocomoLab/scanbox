function slm_align

close all;
closepreview

q = figure(1); % fig 1 is the slm
mon = get(0,'MonitorPositions');
q.Units = 'pixels';
q.MenuBar = 'none';
q.Position = mon(2,:);
a = gca;
a.Position = [0 0 1.04 1.11];
colormap(gray(256));

%% bring camera up...
global vid;

imaqreset;
vid = videoinput('gige', 1, 'Mono12');

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

msg = text(100,1024,'Automatic SLM Calibration');
msg.FontSize = 18;
msg.Color = 'y';
drawnow;
pause(10);

preview(vid,hImage);

%% start scanning

scanbox_config
sb_open
laser_open
laser_send('SHUTTER=1')
sb_mirror(0)
sb_setparam(512,0,1);  %scan forever! need sb_abort to stop...
sb_deadband(0,0);
sb_scan

%% find scan area...

% title('Define Scan Area');
% [xs, ys] = ginputc(3, 'Color', 'y', 'LineWidth', 1);

msg.String = 'Find Scan Area'
%pause(4);

% q = double(getsnapshot(vid));
% for(i=1:5)
%     q = q+double(getsnapshot(vid));
% end
% q = (q-min(q(:)))/(max(q(:))-min(q(:)));
% level = graythresh(q);
% bw = bwareafilt(im2bw(q,level),1);
% bw = imerode(bw,strel('disk',3));
% [yy,xx] = find(bw);
% [rectx,recty,area,perimeter] = minboundrect(xx,yy);
% hold on
% plot(rectx,recty,'y-','linewidth',2);
% drawnow;

%sb_abort;
%laser_send('SHUTTER=0');
% 
% [xx,yy] = meshgrid(1:size(q,2),1:size(q,1));
% mask = inpolygon(xx(:),yy(:),rectx,recty);
% mask = reshape(mask,size(q));

%%

msg.String = 'Edge points'

[xx,yy] = meshgrid(1:1920,1:1080);

mat1 = zeros(size(xx));

yc = 1080/4-100;
xc = 1920/4-100;
dx = 100;

pts = zeros(9,2);
cal = zeros(9,2);
k = 1;
x = zeros(1080,1920);
for(ii=-1:2:1)
    for(jj=-1:2:1)
        x(yc+dx*ii,xc+dx*jj)=1;
    end
end

ph = gsa2(ones(size(x)),double(x));
ph = (ph + pi)/(2*pi)*255;
figure(1);
colormap(gray(256));
image('CData',ph);
axis off;
figure(f);
pause;

sb_abort
sb_close

function ph = gsa2(src,dest)
tic
a = exp(1i*rand(size(dest))*2*pi);
r =0;
for(k=1:20)
    b = abs(src) .* exp(1i*angle(a));
    c = fft2(b);
    d = abs(dest) .* exp(1i*angle(c));
    a = ifft2(d);
    rho = corrcoef(dest(:),abs(c(:)))
%     if(rho(1,2)<r+0.01)
%         break;
%     end
    r = rho(1,2)
end
ph = angle(a);
toc
