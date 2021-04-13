function varargout = scanbox(varargin)
% SCANBOX MATLAB code for scanbox.fig
%      SCANBOX, by itself, creates a new SCANBOX or raises the existing
%      singleton*.
%
%      H = SCANBOX returns the handle to a new SCANBOX or the handle to
%      the existing singleton*.
%
%      SCANBOX('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SCANBOX.M with the given input arguments.
%
%      SCANBOX('Property','Value',...) creates a new SCANBOX or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before scanbox_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to scanbox_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help scanbox

% Last Modified by GUIDE v2.5 19-Oct-2020 07:26:30

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @scanbox_OpeningFcn, ...
    'gui_OutputFcn',  @scanbox_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before scanbox is made visible.
function scanbox_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to scanbox (see VARARGIN)

% Choose default command line output for scanbox
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% check min release
mver = ver('Matlab');
myr = strsplit(mver.Date,'-');
if(str2double(myr{end})<2015)
    if(isempty(strfind(mver.Release,'R2015')))
        error('This version of Scanbox requires R2015a or later');
    end
end

% Set high priority

q = priority('sh');

% Make sure ethernet connection to outside world is disabled...

[~, ~] = system('netsh interface set interface World DISABLED');

% Configuration options and startup

istep = 1;
cprintf('\n');
cprintf('*blue','Scanbox v4.7 | https://scanbox.org/ | Dario Ringach (darioringach@me.com)\n\n');
pause(1);

cprintf('*comment','[%02d] Reading configuration file\n',istep); istep=istep+1;
scanbox_config;     % configuration file

% check if optocal LUT needs to be computed

if(exist('otcal.mat','file')) % found calibration file
    load('otcal.mat','otcoeff');
    sbconfig.optocal = otcoeff;
    sbconfig.optolut = uint16(polyval(sbconfig.optocal,0:1760));
else                          % use manual config
    if(~isempty(sbconfig.optocal))
        sbconfig.optolut = uint16(polyval(sbconfig.optocal,0:1760));
    end
end

% gray out optional boxes...

cprintf('*comment','[%02d] Setting up control panels\n',istep); istep=istep+1;

% analog out

% global ao;
% daqreset;
% ao = daq.createSession('ni')
% addAnalogOutputChannel(ao,'Dev1',1,'Voltage');


% ephys

daqreset;

if(sbconfig.ephys)
    cprintf('*comment','[%02d] Setting up ephys device\n',istep); istep=istep+1;
    global ephys;
    ephys = daq.createSession('ni');
    ephys.Rate = sbconfig.ephysRate;
    ephys.IsContinuous = true;
    addCounterInputChannel(ephys,sbconfig.ephysDev,'ctr1','EdgeCount');
    addAnalogInputChannel(ephys,sbconfig.ephysDev,1,'Voltage');
    addlistener(ephys,'DataAvailable', @ephysdata);
    prepare(ephys);
end

% external events

if(sbconfig.xevents)
    cprintf('*comment','[%02d] Setting up external TTL event device\n',istep); istep=istep+1;
    global xevents;
    xevents = daq.createSession('ni');
    xevents.IsContinuous = true;
    xevents.Rate = sbconfig.xeventsRate; % expected rate
    addDigitalChannel(xevents,sbconfig.xeventsDev,'Port0/Line0:7','InputOnly');
    addClockConnection(xevents,'External',sbconfig.xeventsClock,'ScanClock');
    addlistener(xevents,'DataAvailable', @xeventsdata);
    prepare(xevents);
end

% network stream

if(isempty(sbconfig.stream_host))
    set(handles.networkstream,'Enable','off');
    cprintf('*comment','[%02d] Network stream is OFF\n',istep); istep=istep+1;
else
    cprintf('*comment','[%02d] Network stream is ON\n',istep); istep=istep+1;
    
    global stream_udp;
    
    if(~isempty(stream_udp))
        fclose(stream_udp);
        stream_udp = [];
    end
end


if(sbconfig.balltracker == 0)
    ch = get(handles.ballpanel,'children');
    for(i=1:length(ch))
        try
            set(ch(i),'Enable','off');
        catch
        end
    end
end


if(sbconfig.eyetracker == 0)
    ch = get(handles.eyepanel,'children');
    for(i=1:length(ch))
        try
            set(ch(i),'Enable','off');
        catch
        end
    end
end

if(isempty(sbconfig.laser_type))
    ch = get(handles.uipanel11,'children');
    for(i=1:length(ch))
        try
            set(ch(i),'Enable','off');
        catch
        end
    end
    set(handles.lstatus,'String','Use the laser''s native GUI for control');
    handles.pockval.Enable = 'on';
    handles.powertxt.Enable = 'on';
end


% position by knobby? disable panel

% position panel is now gone

% if(~isempty(sbconfig.tri_knob))
%     c = get(handles.uipanel9,'Children');
%     set(c,'Enable','off');
% end


% default directory

global datadir
handles.dirname.String = sbconfig.datadir;
datadir = sbconfig.datadir;

% delete any hanging communication objects

cprintf('*comment','[%02d] Initializing instruments\n',istep); istep=istep+1;

delete(instrfindall);
pause(0.2);

global sb tri laser optotune sb_server

sb = [];
tri = [];
laser = [];
optotune = [];
sb_server = [];

% Open communication lines


cprintf('*comment','[%02d] Opening Scanbox\n',istep); istep=istep+1;

try
    sb_open;
catch
    % delete(10);
    uiwait(errordlg('Cannot communicate with scanbox. Please fix! Matlab will close.','scanbox','modal'));
    exit;
end

if isfield(sbconfig,'firmware') && ~isempty(sbconfig.firmware)
    if strcmp(sbconfig.firmware,sb_version)
        cprintf('*comment','[%02d] Matching firmware version\n',istep); istep=istep+1;
    else
        uiwait(errordlg('Firmware version mismatch! Please fix! Matlab will close.','scanbox','modal'));
        exit;
    end
end

sb_optotune_active(0);      % make sure optotune is not active
sb_current_power_active(0); % nor is the link between optotune and power


cprintf('*comment','[%02d] Interrupt mask = %d\n',istep,sbconfig.imask); istep=istep+1;
sb_imask(sbconfig.imask);

if(sbconfig.gain_override>0)
    cprintf('*comment','[%02d] Set custom x,y gains\n',istep); istep=istep+1;
    sb_galvo_dv(sbconfig.dv_galvo);
    for k=1:length(sbconfig.gain_resonant)
        sb_set_mag_x_i(k-1,sbconfig.gain_resonant(k));
        sb_set_mag_y_i(k-1,sbconfig.gain_galvo(k));
    end
end

if(exist('pockelscal.mat','file'))        % if calibration exists override LUT in config file
    pcal = load('pockelscal.mat');
    sbconfig.pockels_lut = pcal.pockels_lut;
    cprintf('*comment','[%02d] Pockels Calibration File Found\n',istep); istep=istep+1;
end


if(length(sbconfig.pockels_lut)==256)
    cprintf('*comment','[%02d] Loading Pockels LUT\n',istep); istep=istep+1;
    for(i=1:256)
        sb_pockels_lut(i,sbconfig.pockels_lut(i));
    end
else
    sb_pockels_lut_identity;        % if no linearization table make it the identity...
end

% range...

if isfield(sbconfig,'pockels_range')
    sb_pockels_range(sbconfig.pockels_range);
    cprintf('*comment','[%02d] Set pockels range to DAC=%d PGA=%d\n',istep,... 
        sbconfig.pockels_range(1),sbconfig.pockels_range(2)); istep=istep+1;
    if ~all(sbconfig.pockels_range == [1 2])
        cprintf('*comment','[%02d] Assuming TPC laser: forcing pockels LUT to identity',istep); istep=istep+1;
    end
else
    sb_pockels_range(uint8([1 2]));
    cprintf('*comment','[%02d] Set pockels range to DAC=%d PGA=%d\n',istep,...
        1,2); istep=istep+1;
end

cprintf('*comment','[%02d] Set HSYNC sign\n',istep); istep=istep+1;
sb_hsync_sign(sbconfig.hsync_sign);

cprintf('*comment','[%02d] Disable external TTL trig\n',istep); istep=istep+1;
sb_ttl_trig_disable;

cprintf('*comment','[%02d] Default to normal resonant mode\n',istep); istep=istep+1;
sb_continuous_resonant(0);

cprintf('*comment','[%02d] Default warm up time\n',istep); istep=istep+1;
sb_warmup_delay(sbconfig.wdelay);

% cprintf('*comment','[%02d] Default pulse width\n',istep); istep=istep+1;
% sb_cam_pulse_width(sbconfig.cam_pulse_width);

% cprintf('*comment','[%02d] Reset optotune\n',istep); istep=istep+1;
% sb_current(0);
%
% if(isempty(sbconfig.optocal))
%     handles.ot_txt.String = '0000';
% else
%     handles.ot_txt.String = '0 um';
%     handles.optomax.String = '100';
% end

% Set optotune

cprintf('*comment','[%02d] Set Default ETL value\n',istep);istep=istep+1;
handles.optoslider.Value = sbconfig.etl;
optoslider_Callback(handles.optoslider, [], handles);

cprintf('*comment','[%02d] Opening motor controller\n',istep); istep=istep+1;
tri_open;

cprintf('*comment','[%02d] Opening laser communication\n',istep); istep=istep+1;


try
    laser_open;
    if( strcmp(sbconfig.laser_type,'DISCOVERY') )
        
        handles.gddslider.Enable = 'on';
        
        r = laser_send('?GDDMIN');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Min = val;
        
        r = laser_send('?GDDMAX');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Max= val;
        
        r = laser_send('?GDD');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Value= val;
        handles.gddtxt.String = r{end};
        
        handles.gddtxt.Enable = 'on';
        handles.fshutter.Enable = 'on';
        
    end
catch
    %delete(10)
    error('Scanbox:LaserComm', ...
        '\nCannot communicate with laser!\nPlease check:\n -Serial cable\n -COM port in scanbox_config\n\n');
end

% open quad

if(~isempty(sbconfig.quad_com))
    cprintf('*comment','[%02d] Opening quadrature encoder\n',istep); istep=istep+1;
    quad_open;
end

if(~isempty(sbconfig.speedbelt_com))
    cprintf('*comment','[%02d] Opening speedbelt communication\n',istep); istep=istep+1;
    speedbelt_open;
end

% open 3d mouse if knobby not present....

if(isempty(sbconfig.tri_knob))
    cprintf('*comment','[%02d] Setting up 3dmouse driver\n',istep); istep=istep+1;
    import mouse3D.*
    global mouseDrv;
    mouseDrv = mouse3Ddrv; %instantiate driver object
    addlistener(mouseDrv,'SenState',@mousedrv_cb);
end

cprintf('*comment','[%02d] Opening UDP communications\n',istep); istep=istep+1;

udp_open;

cprintf('*comment','[%02d] Moving port camera mirror into place\n',istep); istep=istep+1;

sb_mirror(1);       % move mirror out of the way...

warning('off');

%
global opto2pow

opto2pow = [];

% ttlonline

global ttlonline;
ttlonline=0;

global zstack_running;
zstack_running = 0;

% motor variables init...

global axis_sel origin motor_gain mstep dmpos motormode mpos motorstate;

motormode = 1; % normal

motor_gain = [(2000/400/32)/2  ((.02*25400)/400/64)  ((.02*25400)/400/64) (0.0225/64)];  % z x y th

motorstate = [0 0 0 0];

axis_sel = 2; % select x axis to begin with

%mstep = [500 2000 2000 500];  % initialize with step sizes for coarse...

mstep = [400 1575 1575 400];

% set velocity and acceleration for motor 4 to control laser power

r = tri_send('SAP',4,4,10);        %% set max vel and acc for platform
r = tri_send('SAP',5,4,10);

try
    for(i=0:3)
        r = tri_send('GAP',1,i,0);       %% zero and set origin - was MVP
        origin(i+1) = r.value;
        switch i
            
            case {0,3}
                r = tri_send('SAP',4,i,400);    %% max vel accel - was 2000
                r = tri_send('SAP',5,i,400);
                
            case {1,2}
                
                r = tri_send('SAP',4,i,800);    %% max vel accel - was 2000
                r = tri_send('SAP',5,i,400);     %% was 1600
        end
        
        r = tri_send('SAP',140,i,6);     %% 64 microsteps (changed default in 610 board)
        r = tri_send('SAP',204,i,sbconfig.freewheel);     %% keep the power up...
        
    end
catch
    %delete(10)
    error('Scanbox:MotorComm', ...
        '\nCannot communicate with motor controller!\nPlease check:\n -Serial cable\n -COM port in scanbox_config\n -Power cycle controller\n\n');
end


dmpos = origin;                      %% desired motor position is the same as the origin

mpos = cell(1,4);                      %% reset memory
for(i=1:4)
    mpos{i} = dmpos;
end


% set(handles.xpos,'String','0.00')
% set(handles.ypos,'String','0.00')
% set(handles.zpos,'String','0.00')
% set(handles.thpos,'String','0.00')

% z-stack

global z_top z_bottom z_steps z_size z_vals;

z_top = 0;
z_bottom = 0;
z_steps = 0;
z_vals = 0;

% Pockels levels...

cprintf('*comment','[%02d] Default Pockels levels\n',istep); istep=istep+1;
sb_pockels(0,0);
cprintf('*comment','[%02d] Default Deadband\n',istep); istep=istep+1;

sb_deadband_period(round(24e6/sbconfig.resfreq/2));
sb_deadband(sbconfig.deadband(1),sbconfig.deadband(2));

handles.deadleft.Value = sbconfig.deadband(1);
handles.deadright.Value = sbconfig.deadband(2);


global scanmode;

if(sbconfig.unidirectional)
    cprintf('*comment','[%02d] Default Unidirectional mode\n',istep); istep=istep+1;
    sb_unidirectional;
    scanmode = 1;   % default is unidirectional
else   % default is bidirectional
    cprintf('*comment','[%02d] Default Bidirectional mode\n',istep); istep=istep+1;
    sb_bidirectional;
    scanmode = 0;   % default is unidirectional
    handles.unibi.String = 'Bidirectional';
end

frame_rate = sbconfig.resfreq/str2num(handles.lines.String)*(2-scanmode); %% use actual resonant freq...
set(handles.frate,'String',sprintf('%2.2f',frame_rate));


% ball tracker initialization
%

cprintf('*comment','[%02d] Initializing image acquisition\n',istep); istep=istep+1;

cprintf('comment','[%02d] Setting Line-2 as trigger source for all Dalsa cameras (please wait)\n',istep); istep=istep+1;

imaqreset;

q = gigecamlist;
if ~isempty(q)  % maybe there are no cameras at all
    idx = find(strcmp('DALSA',q.Manufacturer));
    for i = idx'
        g = gigecam(q.SerialNumber{i});
        g.TriggerMode = 'on';
        g.TriggerSource = 'Line2';
        g.TriggerMode = 'off';
        delete(g);
    end
end

cprintf('*comment','[%02d] Configuring image aquisition\n',istep); istep=istep+1;

if(sbconfig.balltracker + sbconfig.eyetracker + sbconfig.portcamera > 0)
    cprintf('*comment','[%02d] Getting camera information\n',istep); istep=istep+1;
    q = imaqhwinfo('gige');
    qg = imaqhwinfo('gentl');
end

if(sbconfig.balltracker)
    cprintf('*comment','[%02d] Configuring ball camera\n',istep); istep=istep+1;
    
    global wcam wcam_src wcam_roi;
    
    found = false;
    for(i=1:length(q.DeviceInfo))  % find ball camera
        if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.ballcamera)))  %% search for 1410 genie camera
            q.DeviceInfo(i).DeviceName = '';        %% in case there  are two cameras with same number
            found = true;
            break;
        end
    end
    
    if found
        wcam = videoinput('gige', i, 'Mono8');
        wcam_src = getselectedsource(wcam);
        wcam_src.ReverseX = 'False';
        wcam_src.BinningHorizontal = 2;
        wcam_src.BinningVertical = 2;
        wcam_src.ExposureTimeAbs = 7000;
        wcam.FramesPerTrigger = inf;
        wcam.ReturnedColorspace = 'grayscale';
        wcam_src.AcquisitionFrameRateAbs = 30.0;
        wcam_roi = [0 0 wcam.VideoResolution];
    else
          
        found = false;
        
        for(i=1:length(qg.DeviceInfo)) % find ball camera
            if(~isempty(strfind(qg.DeviceInfo(i).DeviceName,sbconfig.ballcamera))) %% search for 1410 genie camera
                qg.DeviceInfo(i).DeviceName = ''; %% in case there are two cameras with same number
                found = true;
                break;
            end
        end
        
        if found
            wcam = videoinput('gentl', i, 'Mono8');
            wcam_src = getselectedsource(wcam);
            wcam_src.AcquisitionFrameRateMode = 'Basic';
            wcam_src.ExposureMode = 'Timed';
            wcam_src.ExposureTime = 3e4;
            wcam_src.AcquisitionFrameRate = 30;
            wcam.FramesPerTrigger = inf;
            wcam.ReturnedColorspace = 'grayscale';
            wcam_roi = [0 0 wcam.VideoResolution];
        end     
    end
    
end


% eye tracker...

if(sbconfig.eyetracker)
    cprintf('*comment','[%02d] Configuring eyetracker\n',istep); istep=istep+1;
    
    global eyecam eye_src eye_roi;
    
    found = false;
    for(i=1:length(q.DeviceInfo)) % find camera...
        if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.eyecamera)))
            q.DeviceInfo(i).DeviceName = '';
            found = true;
            break;
        end
    end
    
    if found
        eyecam = videoinput('gige', i, 'Mono8');
        eye_src = getselectedsource(eyecam);
        % eye_src.TriggerMode = 'Off'; % added in case it was left On...
        
        eye_src.ReverseX = 'False';
        eye_src.BinningHorizontal = 2;
        eye_src.BinningVertical = 2;
        eye_src.AcquisitionFrameRateAbs = 15;
        eye_src.ExposureTimeAbs = 7000;
        eyecam.FramesPerTrigger = inf;
        eyecam.ReturnedColorspace = 'grayscale';
        eye_roi = [0 0 eyecam.VideoResolution];
    else
        
        found = false;
        
        for(i=1:length(qg.DeviceInfo)) % find ball camera
            if(~isempty(strfind(qg.DeviceInfo(i).DeviceName,sbconfig.ballcamera))) %% search for 1410 genie camera
                qg.DeviceInfo(i).DeviceName = ''; %% in case there are two cameras with same number
                found = true;
                break;
            end
        end
        
        if found
            eyecam = videoinput('gentl', i, 'Mono8');
            eye_src = getselectedsource(eyecam);
            eye_src.AcquisitionFrameRateMode = 'Basic';
            eye_src.ExposureMode = 'Timed';
            eye_src.ExposureTime = 3e4;
            eye_src.AcquisitionFrameRate = 30;
            eyecam.FramesPerTrigger = inf;
            eyecam.ReturnedColorspace = 'grayscale';
            eye_roi = [0 0 eyecam.VideoResolution];
        end
        
    end
    
end

% dalsa (or other port camera) config

if(sbconfig.portcamera)
    global dalsa dalsa_src;
    cprintf('*comment','[%02d] Configuring camera path\n',istep); istep=istep+1;
    
    flag = false;
    for(i=1:length(q.DeviceInfo))
        if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.pathcamera)))  %% search for path camera
            q.DeviceInfo(i).DeviceName = '';
            flag = true;
            break;
        end
    end
    
    if (flag)
        % dalsa = videoinput('gige', i, 'Mono8');
        dalsa = videoinput('gige',i,sbconfig.pathcamera_format);
        dalsa.FramesPerTrigger = inf;
        
        eval(sprintf('%s_init',sbconfig.pathcamera));   % init camera
        
        if(sbconfig.pathlr)
            global img0_h;
            setappdata(img0_h,'UpdatePreviewWindowFcn',@flipDalsaImg);
        end
    else
         q = imaqhwinfo('pcocameraadaptor_r2019a');
        
        flag = false;
        for(i=1:length(q.DeviceInfo))
            if(~isempty(strfind(q.DeviceInfo(i).DeviceName,sbconfig.pathcamera)))  %% search for imperx B2020M camera
                q.DeviceInfo(i).DeviceName = '';
                flag = true;
                break;
            end
        end
        
        if(flag==false)
            warning('Port camera not found');
        else
            dalsa =  videoinput('pcocameraadaptor_r2019a', q.DeviceIDs{i}, 'USB 3.0');
            dalsa.FramesPerTrigger = inf;
            eval(sprintf('%s_init',sbconfig.pathcamera));   % init camera
        end
    end
    
    % config disk logger for intrinsic imaging
    dalsa.LoggingMode = 'disk';
end

if(~isempty(sbconfig.ccam))
    if(sbconfig.ccam)
        sb_ccam(1);
        cprintf('*comment','[%02d] Copy CAM0->CAM1 \n',istep); istep=istep+1;
    else
        sb_ccam(0);
        cprintf('*comment','[%02d] Independent CAM0/CAM1 \n',istep); istep=istep+1;     
    end
end

if(~isempty(sbconfig.pmeter_id))
    cprintf('*comment','[%02d] Connecting to PM100D Power Meter\n',istep); istep=istep+1;
    powermeter_open;
end

if(~isempty(sbconfig.led_id))
    cprintf('*comment','[%02d] Connecting to Thorlabs LED Controller\n',istep); istep=istep+1;
    led_open;
end

if(~isempty(sbconfig.led_stim_com))
    cprintf('*comment','[%02d] Connecting to Arduino LED pulse generator\n',istep); istep=istep+1;
    led_stim_open;
end


cprintf('*comment','[%02d] Setting up digitizer\n',istep); istep=istep+1;

figure('visible','off'); % what for?

% Digitizer initialization

AlazarDefs;

% Load driver library
if ~alazarLoadLibrary()
    warndlg(sprintf('Error: ATSApi.dll not loaded\n'),'scanbox');
    return
end

systemId = int32(1);
boardId = int32(1);

global boardHandle

% Get a handle to the board
boardHandle = calllib('ATSApi', 'AlazarGetBoardBySystemID', systemId, boardId);
setdatatype(boardHandle, 'voidPtr', 1, 1);
if boardHandle.Value == 0
    warndlg(sprintf('Error: Unable to open board system ID %u board ID %u\n', systemId, boardId),'scanbox');
    return
end

% % Configure the board...
% %
% Set capture clock to external...

retCode = ...
    calllib('ATSApi', 'AlazarSetCaptureClock', ...
    boardHandle,		 ...	% HANDLE -- board handle
    FAST_EXTERNAL_CLOCK, ...	% U32 -- clock source id
    SAMPLE_RATE_USER_DEF, ...	% U32 -- IGNORED when clock is external!
    CLOCK_EDGE_RISING,	...	% U32 -- clock edge id
    0					...	% U32 -- clock decimation by 4 (3 is one less)
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetCaptureClock failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end


% % set external clock level if needed...
% % Not supported in 9440...!!!!

retCode = ...
    calllib('ATSApi', 'AlazarSetExternalClockLevel', ...
    boardHandle,		 ...	% HANDLE -- board handle
    single(65.0)	     ...	% U32 --level in percent
    );
if retCode ~= ApiSuccess
    fprintf('Error: AlazarSetExternalClockLevel failed -- %s\n', errorToText(retCode));
    return
end

% Determine appropiate range for amplifiers

cprintf('*comment','[%02d] Setting up input range for %s amplifiers\n',istep,sbconfig.pmt_amp_type); istep=istep+1;

try
    switch sbconfig.pmt_amp_type
        case 'variable'
            input_range = INPUT_RANGE_PM_200_MV;
        case 'fixed'
            input_range = INPUT_RANGE_PM_1_V;
        otherwise
            error('Invalid value of pmt_amp_type in config file');
    end
catch
    warning('Amplifier type not defined.  Using 200mV range');
    input_range = INPUT_RANGE_PM_200_MV; 
end



% Set CHA input parameters

retCode = ...
    calllib('ATSApi', 'AlazarInputControl', ...
    boardHandle,		...	% HANDLE -- board handle
    CHANNEL_A,			...	% U8 -- input channel
    DC_COUPLING,		...	% U32 -- input coupling id
    input_range, ...	% U32 -- input range id
    IMPEDANCE_50_OHM	...	% U32 -- input impedance id
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarInputControl failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% CHB params...

retCode = ...
    calllib('ATSApi', 'AlazarInputControl', ...
    boardHandle,		...	% HANDLE -- board handle
    CHANNEL_B,			...	% U8 -- channel identifier
    DC_COUPLING,		...	% U32 -- input coupling id
    input_range,	...	% U32 -- input range id
    IMPEDANCE_50_OHM	...	% U32 -- input impedance id
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarInputControl failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end


% Select trigger inputs...

retCode = ...
    calllib('ATSApi', 'AlazarSetTriggerOperation', ...
    boardHandle,		...	% HANDLE -- board handle
    TRIG_ENGINE_OP_J,	...	% U32 -- trigger operation
    TRIG_ENGINE_J,		...	% U32 -- trigger engine id
    TRIG_EXTERNAL,		...	% U32 -- trigger with TRIGOUT
    TRIGGER_SLOPE_POSITIVE+sbconfig.trig_slope,	... % U32 -- THE HSYNC is flipped on the PSoC board...
    sbconfig.trig_level, ...	% U32 -- trigger level from 0 (-range) to 255 (+range)
    TRIG_ENGINE_K,		...	% U32 -- trigger engine id
    TRIG_DISABLE,		...	% U32 -- trigger source id for engine K
    TRIGGER_SLOPE_POSITIVE, ...	% U32 -- trigger slope id
    128					...	% U32 -- trigger level from 0 (-range) to 255 (+range)
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetTriggerOperation failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% External trigger params...
retCode = ...
    calllib('ATSApi', 'AlazarSetExternalTrigger', ...
    boardHandle,		...	% HANDLE -- board handle
    uint32(DC_COUPLING),		...	% U32 -- external trigger coupling id
    uint32(ETR_TTL)				...	% U32 -- external trigger range id
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetExternalTrigger failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Delays...

triggerDelay_samples = uint32(0);
retCode = calllib('ATSApi', 'AlazarSetTriggerDelay', boardHandle, triggerDelay_samples);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetTriggerDelay failed -- %s\n', errorToText(retCode)),'scanbox');
    return;
end

% Trigger timeout...

retCode = ...
    calllib('ATSApi', 'AlazarSetTriggerTimeOut', ...
    boardHandle,            ...	% HANDLE -- board handle
    uint32(0)	... % U32 -- timeout_sec / 10.e-6 (0 == wait forever)
    );
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarSetTriggerTimeOut failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Configure AUX I/O

% Config TTL as inputs into two LSBs of stream...

cprintf('*comment','[%02d] Configuring TTLs\n',istep); istep=istep+1;

configureLsb9440(boardHandle,0,3);   %%

if(sbconfig.nroi_parallel)
    cprintf('*comment','[%02d] Starting parallel pool\n',istep); istep=istep+1;
    parpool(sbconfig.nroi_auto);
end

if(sbconfig.gpu_pages>0)
    cprintf('*comment','[%02d] Reset GPU\n',istep); istep=istep+1;
    gpuDevice(sbconfig.gpu_dev);   %% was 2,3
end

% setup memory mapped file if necessary

if(sbconfig.mmap>0)     % make sure file exists...
    cprintf('*comment','[%02d] Setting up memory mapped files\n',istep); istep=istep+1;
    fnmm = which('scanbox');
    fnmm = strsplit(fnmm,'\');
    fnmm{end-1} = 'mmap';
    fnmm{end} = 'scanbox.mmap';
    sbconfig.fnmm = strjoin(fnmm,'\');    % name of memory mapped file
    
    if(~exist(sbconfig.fnmm,'file'))
        fidmm = fopen(sbconfig.fnmm,'w');
        fwrite(fidmm,zeros(1,16+1024*796*2*2,'int16'),'uint16'); % 16 words of header + max frame size * 2 channels
        fclose(fidmm);
    end
    
    % launch sbxplugin_server in separate matlab instance
    cprintf('*comment','[%02d] Launch plugin server\n',istep); istep=istep+1;
    system('matlab -nosplash -r sbxplugin_server &');
    
end

cprintf('*comment','[%02d] Set plugin list\n',istep); istep=istep+1;
if(isfield(sbconfig,'plugin'))              % set plugin names
    handles.plugin.String = sbconfig.plugin;
end


% Check if knobby 2.0 and set up table (otherwise bring up other panels)

if(sbconfig.tri_knob_ver>1)
    cprintf('*comment','[%02d] Setting default knobby scheduler table\n',istep); istep=istep+1;
    
    if isfield(sbconfig,'knobby_table')
        handles.knobby_table.Data = sbconfig.knobby_table;
    else
        handles.knobby_table.Data = [];
    end
    
else
    cprintf('*comment','[%02d] Assuming knobby 1.0 interface\n',istep); istep=istep+1;
    handles.knobby_sched.Visible = 'off';
    handles.message_panel.Visible = 'on';
    handles.notes.Visible = 'on';
end

% panel list

global panel_list panel_sel
cprintf('*comment','[%02d] Panel list\n',istep); istep=istep+1;
if(sbconfig.tri_knob_ver>1)
    panel_list = { {handles.realtime} {handles.knobby_sched} {handles.sspanel} {handles.message_panel}  {handles.notes} {handles.intrinsic_panel} };
else
    panel_list = { {handles.realtime} {handles.message_panel}  {handles.notes} {handles.intrinsic_panel}};
end

% try to find a powermeter

global pmeter

if(~isempty(pmeter))
    panel_list{end+1} = {handles.powermeter_panel};
end

% try to find led controller

global led_controller

if(sbconfig.optogenetics)
    panel_list{end+1} = {handles.optogenetics_panel};
end

panel_sel = 1;

ptitles = cell(1,length(panel_list));
for i =1:length(panel_list)
    ptitles{i} = panel_list{i}{1}.UserData;
end

handles.panel_menu.String = ptitles;
handles.panel_menu.Min = 1;
handles.panel_menu.Max = length(ptitles);
handles.panel_menu.Value = 1;

set_panel_visible;

% selection of signal for trial start/stop

if(sbconfig.trig_sel)
    cprintf('*comment','[%02d] Setting trial start/stop signal to TTL1\n',istep); istep=istep+1;
    sb_trig_sel(1);
else
    cprintf('*comment','[%02d] Setting trial start/stop signal to extension header P1.6\n',istep); istep=istep+1;
    sb_trig_sel(0);
end

global calibration;
if(exist('sbxcal.mat','file'))
    handles.objective.Visible = 'on';
    load('sbxcal.mat','calibration');
    if isstruct(calibration)
        calibration = {calibration};    % Make it a cell array of one
        for i = 1:length(handles.objective.String)-1
            calibration{end+1} = [];    % if more objective than calibration add empty entries
        end
    end
    cprintf('*comment','[%02d] Loading spatial calibration\n',istep); istep=istep+1;
    handles.magnification.Callback(handles.magnification,[]);
else
    calibration = cell(1,length(handles.objective.String));     % no calibration file found
end

% SLM

if(sbconfig.slm)
    cprintf('comment','[%02d] Setting up SLM device (please wait)\n',istep); istep=istep+1;
    %daqreset;
    global slms slm;
    slms = daq.createSession('ni');
    slms.Rate = 1000;
    addAnalogOutputChannel(slms,sbconfig.slmdev,0:1,'Voltage');
    addTriggerConnection(slms,'external',sbconfig.slmTrigger,'StartTrigger'); % add trigger 
    outputSingleScan(slms,[-0.05 0]);

    slm = load(sbconfig.slmcal,'xhat','yhat','tform','rwidth','rheight', ...
        'x0','y0','I','pts','calpts', ...
        'slm_etl','slm_prismx','slm_prismy', ...
        'slm_slmx','slm_slmy','slm_lens','power_interp'); % load calibration file
        
    global slmfig slmimg g
    
    heds_init_slm;                  % open slm
    slmimg.CData = [];              % fake it...
    slmimg.UserData = [];
    heds_show_blankscreen(128);     % show uniform screen

%     
%     slmfig = figure(20); % fig 20 is the slm
% 
%     colormap(gray(256));
%     slmimg = image('CData',zeros([1080 1920],'uint8')); % holoeye size
%     axis off
%     
%     a = gca;
%     a.Position = [0 0 1.04 1.11];
% 
%     mon = get(0,'MonitorPositions');
%     for k = 1:size(mon,1)
%         if(mon(k,1)>1)
%             break;
%         end
%     end
%     slmfig.Units = 'pixels';
%     slmfig.MenuBar = 'none';
%     slmfig.Position = mon(k,:); % depends on how monitors are setup
% 
%     figure(20);
    
    %figure(scanbox_h);
    
    % set vars
    handles.prismx.String = num2str(sbconfig.slm_prismx);
    handles.prismy.String = num2str(sbconfig.slm_prismy);
    handles.slmsize.String = num2str(sbconfig.slm_size);
    
    % Overridden by calibration file
    handles.prismx.String = sprintf('%d',slm.slm_prismx);
    handles.prismy.String = sprintf('%d',slm.slm_prismy);
    handles.lens.String = sprintf('%d',slm.slm_lens);
    handles.slmx.String = sprintf('%d',slm.slm_slmx);
    handles.slmy.String = sprintf('%d',slm.slm_slmy);
    handles.optoslider.Value = slm.slm_etl;
    handles.optoslider.Callback(handles.optoslider,[]);
    
end


% if(sbconfig.optogenetics)
%     
% %     global sopto;
% %     sopto = daq.createSession('ni');
% %     addCounterOutputChannel(sopto,'Dev1', 'ctr1', 'PulseGeneration');
% %     addTriggerConnection(sopto,'external','Dev1/PFI1','StartTrigger');
% %     sopto.Connections(1).TriggerCondition = 'FallingEdge';
% % 
% %     ch = sopto.Channels(1);
% %     ch.Frequency = 10;
% %     ch.InitialDelay = 0;
% %     ch.DutyCycle = 0.05;
% %     sopto.Rate = 10000;
% %     sopto.DurationInSeconds = 0.1;
% end



% update laser status

% set(handles.lstatus,'String',laser_status);

global ltimer;  % laser timer

if(~isempty(sbconfig.laser_type))
    ltimer = timer('ExecutionMode','FixedRate','Period',5,'TimerFcn',@laser_cb,'Tag','LaserTimer');
    start(ltimer);
end

global ttltimer;  % Use to armed the microcope to be triggered with a TTL signal
ttltimer = timer('ExecutionMode','FixedRate','Period',.1,'TimerFcn',@sb_callback,'Tag','TTL_Timer','UserData',0);

global agc_timer  % AGC timer

agc_timer = timer('ExecutionMode','FixedRate','Period',sbconfig.agc_period,'TimerFcn',@autogain_callback,'Tag','AGC_Timer');


% start(ttltimer); % started by the GUI checkbox


% This was used to get knobby's position in real time...

% global ptimer;
% if(~isempty(sbconfig.tri_knob))
%     ptimer = timer('ExecutionMode','FixedRate','Period',.1,'TimerFcn',@pos_cb);
%     start(ptimer);
% end

if(sbconfig.qmotion==1)
    global qserial;
    qserial = serial(sbconfig.qmotion_com,'baud',38400,'terminator','','bytesavailablefcnmode','byte','bytesavailablefcncount',1,'bytesavailablefcn',@qmotion_cb);
    fopen(qserial);
end

%real time ROIs

global ncell cellpoly;

ncell = 0;
cellpoly = {};

% Done with daq configuration .... !!!!

global scanbox_h

% scanbox_h.Position = [150 150 1632 834];    % force position/size Matlab bug with large monitors
movegui(scanbox_h,'northwest');               % start on the top left

cprintf('\n');
drawnow;
pause(.5);
cprintf('*Comment','Scanbox initialization complete!\n\n',istep); istep=istep+1;
pause(1);


% UIWAIT makes scanbox wait for user response (see UIRESUME)
% uiwait(handles.scanboxfig);


% --- Outputs from this function are returned to the command line.
function varargout = scanbox_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in magnification.
function magnification_Callback(hObject, eventdata, handles)
% hObject    handle to magnification (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns magnification contents as cell array
%        contents{get(hObject,'Value')} returns selected item from magnification

global sbconfig scanmode calibration dxcal dycal;

fold_lines = str2double(handles.fold_lines.String);
if fold_lines == 0
    sb_setmag(get(hObject,'Value')-1);
else
    sb_setmag_fold(get(hObject,'Value')-1,fold_lines);
end

set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');

sel_cal = calibration{handles.objective.Value}; % selected calibration

if(~isempty(sel_cal))
    dxcal = sel_cal(hObject.Value).x;
    dycal = sel_cal(hObject.Value).y;
    handles.caltxt.String = sprintf('[%.2f,%.2f] (pix/um)   FOV=[%d,%d] um',...
        1/dxcal,1/dycal , ...
        round(dxcal*796), ...
        round(dycal*str2double(handles.lines.String)));
    handles.mousecontrol.Enable = 'on';
else
    handles.caltxt.String = 'No Spatial Calibration';
    dxcal = NaN;
    dycal = NaN;
    handles.mousecontrol.Value = 0;
    handles.mousecontrol.Callback(handles.mousecontrol,handles);
    handles.mousecontrol.Enable = 'off';
end


% --- Executes during object creation, after setting all properties.
function magnification_CreateFcn(hObject, eventdata, handles)
% hObject    handle to magnification (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global sbconfig;
list = sprintf('%.1f\n',sbconfig.gain_galvo);
list = list(1:end-1); % drop last \n
hObject.String = list;

function lines_Callback(hObject, eventdata, handles)
% hObject    handle to lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of lines as text
%        str2double(get(hObject,'String')) returns contents of lines as a double

global img0_h nlines sbconfig scanmode calibration dxcal dycal;

nlines = str2num(get(hObject,'String'));
if(isempty(nlines))
    nlines = 512;
    set(hObject,'String','512');
    warndlg('The number of lines must be a number! Resetting to default value (512).');
elseif (mod(nlines,2))
    nlines = ceil(nlines/2);
    set(hObject,'String',num2str(nlines));
    warndlg('The number of lines must be even!  Rounding...');
end

sb_setline(nlines);
frame_rate = sbconfig.resfreq/nlines*(2-scanmode); %% use actual resonant freq...
set(handles.frate,'String',sprintf('%2.2f',frame_rate));

sel_cal = calibration{handles.objective.Value}; % selected calibration

if(~isempty(sel_cal))
    dxcal = sel_cal(handles.magnification.Value).x;
    dycal = sel_cal(handles.magnification.Value).y;
    handles.caltxt.String = sprintf('[%.2f,%.2f] (pix/um)   FOV=[%d,%d] um',...
        1/dxcal,1/dycal , ...
        round(dxcal*796), ...
        round(dycal*str2double(handles.lines.String)));
        handles.mousecontrol.Enable = 'on';
else
     handles.caltxt.String = 'No Spatial Calibration';
     dxcal = NaN;
     dycal = NaN;
    handles.mousecontrol.Value = 0;
    handles.mousecontrol.Callback(handles.mousecontrol,handles);
    handles.mousecontrol.Enable = 'off';
end


% if(~isempty(calibration))
%     handles.caltxt.String = sprintf('(%.1f,%.1f) (%d,%d)',...
%         1/calibration(handles.magnification.Value).x,1/calibration(handles.magnification.Value).y , ...
%         round(calibration(handles.magnification.Value).x*796), ...
%         round(calibration(handles.magnification.Value).y*str2double(handles.lines.String)));
% end


% --- Executes during object creation, after setting all properties.
function lines_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function frames_Callback(hObject, eventdata, handles)
% hObject    handle to frames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frames as text
%        str2double(get(hObject,'String')) returns contents of frames as a double

n = str2num(hObject.String);
if(isempty(n))
    set(hObject,'String','0');
    warndlg('Total frames must be a number! Resetting to default value (0 = forever).');
    sb_setframe(0);
else
    sb_setframe(n);
end

% --- Executes during object creation, after setting all properties.
function frames_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox1.
function checkbox1_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox1


% --- Executes on button press in laserbutton.
function laserbutton_Callback(hObject, eventdata, handles)
% hObject    handle to laserbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of laserbutton

global sbconfig;

switch sbconfig.laser_type
    case 'CHAMELEON'
        laser_send(sprintf('LASER=%d',get(hObject,'Value')));
    case 'DISCOVERY'
        laser_send(sprintf('LASER=%d',get(hObject,'Value')));
        
        % now ask for max/min GDD and set values...
        
        r = laser_send('?GDDMIN');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Min = val;
        
        r = laser_send('?GDDMAX');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Max= val;
        
        r = laser_send('?GDD');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Value= val;
        handles.gddtxt.String = r{end};
        
        
    case 'MAITAI'
        if(get(hObject,'Value'))
            r = laser_send('READ:PCTWARMEDUP?');
            if(~isempty(strfind(r,'100')))
                laser_send(sprintf('ON'));
            else
                set(hObject,'Value',0);
            end
        else
            laser_send(sprintf('OFF'));
        end
end

if(get(hObject,'Value'))
    set(hObject,'String','Laser is on','FontWeight','bold','Value',1);
else
    set(hObject,'String','Laser is off','FontWeight','normal','Value',0);
end



% --- Executes on button press in shutterbutton.
function shutterbutton_Callback(hObject, eventdata, handles)
% hObject    handle to shutterbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of shutterbutton

global sbconfig;

switch sbconfig.laser_type
    case 'CHAMELEON'
        laser_send(sprintf('SHUTTER=%d',get(hObject,'Value')));
    case 'DISCOVERY'
        laser_send(sprintf('SHUTTER=%d',get(hObject,'Value')));
    case 'MAITAI'
        laser_send(sprintf('SHUTTER %d',get(hObject,'Value')));
end

if(get(hObject,'Value'))
    set(hObject,'String','Shutter open','FontWeight','bold','Value',1);
else
    set(hObject,'String','Shutter closed','FontWeight','normal','Value',0);
end


function wavelength_Callback(hObject, eventdata, handles)
% hObject    handle to wavelength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of wavelength as text
%        str2double(get(hObject,'String')) returns contents of wavelength as a double

global sbconfig;

val = str2num(get(hObject,'String'));

switch sbconfig.laser_type
    case 'CHAMELEON'
        r = [700 1040];
    case 'DISCOVERY'
        r = [700 1300];
    case 'MAITAI'
        r = [700 1040];
end

if(isempty(val))
    set(hObject,'String','920');
    warndlg('Wavelength must a number! Resetting to 920nm');
elseif (val>r(2) || val<r(1))
    set(hObject,'String','920');
    warndlg(sprintf('Wavelength outside allowable range [%d,%d]. Resetting to 920nm',r(1),r(2)));
end

switch sbconfig.laser_type
    
    case 'CHAMELEON'
        laser_send(sprintf('WAVELENGTH=%s',get(hObject,'String')));
        
    case 'DISCOVERY'
        laser_send(sprintf('WAVELENGTH=%s',get(hObject,'String')));
        
        r = laser_send('?GDDMIN');
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Min = val;
        
        r = laser_send(['?GDDMAX:' get(hObject,'String')]);
        [r,~] = strsplit(r,' ');
        val = str2double(r{end});
        handles.gddslider.Max= val;
        
        r = laser_send('?GDD');
        [r,~] = strsplit(r,' ');
        val = str2double(r{3});
        handles.gddslider.Value= val;
        handles.gddtxt.String = r{end};
        
    case 'MAITAI'
        laser_send(sprintf('WAVELENGTH %s',get(hObject,'String')));
end




% --- Executes during object creation, after setting all properties.
function wavelength_CreateFcn(hObject, eventdata, handles)
% hObject    handle to wavelength (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global wave_h;

wave_h = hObject;

%laser_send(sprintf('WAVELENGTH=%s',get(hObject,'String')));


% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2


% --- Executes during object creation, after setting all properties.
function popupmenu2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double


% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double


% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit7_Callback(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit7 as text
%        str2double(get(hObject,'String')) returns contents of edit7 as a double


% --- Executes during object creation, after setting all properties.
function edit7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox4.
function checkbox4_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox4


% --- Executes on selection change in popupmenu3.
function popupmenu3_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu3 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu3

global mstep;

switch(hObject.Value)
    case 1
        mstep = [400 1575 1575 400];
    case 2
        mstep = [80 315 315 80];
    case 3
        mstep = [16 63 63 16];
end


% --- Executes during object creation, after setting all properties.
function popupmenu3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in motorlock.
function motorlock_Callback(hObject, eventdata, handles)
% hObject    handle to motorlock (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of motorlock

% set(hObject,'enable','off');
% drawnow;
% set(hObject,'enable','on');
%WindowAPI(handles.scanboxfig,'setfocus')
% set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');



function xpos_Callback(hObject, eventdata, handles)
% hObject    handle to xpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xpos as text
%        str2double(get(hObject,'String')) returns contents of xpos as a double

eventdata.EventName = 2;
scanboxfig_WindowKeyPressFcn(hObject, eventdata, handles);


% --- Executes during object creation, after setting all properties.
function xpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global xpos_h

xpos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];




% --- Executes on button press in pushbutton8.
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton9.
function pushbutton9_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function ypos_Callback(hObject, eventdata, handles)
% hObject    handle to ypos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ypos as text
%        str2double(get(hObject,'String')) returns contents of ypos as a double


% --- Executes during object creation, after setting all properties.
function ypos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ypos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global ypos_h

ypos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];


% --- Executes on button press in pushbutton10.
function pushbutton10_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton11.
function pushbutton11_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function zpos_Callback(hObject, eventdata, handles)
% hObject    handle to zpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zpos as text
%        str2double(get(hObject,'String')) returns contents of zpos as a double


% --- Executes during object creation, after setting all properties.
function zpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global zpos_h

zpos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];



% --- Executes on button press in pushbutton12.
function pushbutton12_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton12 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton13.
function pushbutton13_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function thpos_Callback(hObject, eventdata, handles)
% hObject    handle to thpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of thpos as text
%        str2double(get(hObject,'String')) returns contents of thpos as a double


% --- Executes during object creation, after setting all properties.
function thpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to thpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global thpos_h

thpos_h = hObject;
hObject.BackgroundColor = [0.941 0.941 0.941];


% --- Executes on button press in pushbutton14.
function pushbutton14_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton15.
function pushbutton15_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton16.
function pushbutton16_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton16 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global datadir

datadir = uigetdir('Data directory');
set(handles.dirname,'String',datadir);


% --- Executes on button press in grabb.
function grabb_Callback(hObject, eventdata, handles)
% hObject    handle to grabb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global animal experiment trial savesel seg img0_h captureDone;
global scanbox_h buffersPerAcquisition;
global pmtdisp_h segment_h;
global wcam eyecam sbconfig dgain dbias;
global scanmode;
global ephys efid;
global xevents xefid;

% Some basic checking...

wf=0;
swrn = 'Correct the following before imaging:';

if(~isempty(sbconfig.laser_type))
    
    if(get(handles.laserbutton,'Value')==0)
        wf = wf + 1;
        swrn = sprintf('%s\n%s',swrn,'Turn the laser on and wait for modelock');
    end
    
    if(get(handles.shutterbutton,'Value')==0)
        wf = wf + 1;
        swrn = sprintf('%s\n%s',swrn,'Open the laser shutter');
    end
    
end

if(~isfield(sbconfig,'cam_ignore') || sbconfig.cam_ignore == false)
    if(get(handles.camerabox,'Value')==1)
        wf = wf + 1;
        swrn = sprintf('%s\n%s',swrn,'Camara pathway is activated.');
    end
end

if(get(segment_h,'Value')==1)
    wf = wf + 1;
    swrn = sprintf('%s\n%s',swrn,'Cannot acquire while segmenting.');
end

% if(get(handles.pmtenable,'Value')==0)
%     wf = wf + 1;
%     swrn = sprintf('%s\n%s',swrn,'Turn PMTs on and set their gains.');
% end

global z_vals;

if(wf>0)
    warndlg(swrn);
    return;
end

% turn zoom off

zoom(scanbox_h,'off');
pan(scanbox_h,'off');

AlazarDefs; % board constants

global shutter_h histbox_h sbconfig;
global boardHandle saveData fid stim_on buffersCompleted messages;
global abort_bit ttltimer agc_timer;

stim_on = 0;

switch(get(hObject,'String'))
    case 'Focus'
        abort_bit = 0;
        set(hObject,'String','Abort');
        set(handles.grabb,'Enable','off'); % make this invisible
        frames = 0;
        saveData = false;           % if data are being saved or not...
        set(messages,'String',{});  % clear messages...
        set(messages,'ListBoxTop',1);
        set(messages,'Value',1);
        drawnow;
    case 'Grab'
        abort_bit = 0;
        set(hObject,'String','Abort');
        set(handles.focusb,'Enable','off'); % make this invisible
        frames = str2num(get(handles.frames,'String'));
        saveData = true;            % if data are being saved or not...
        set(messages,'String',{});  % clear messages...
        set(messages,'ListBoxTop',1);
        set(messages,'Value',1);        
        handles.mousecontrol.Value = 0; % disable mouse control
        handles.mousecontrol.Callback(handles.mousecontrol,handles);

        drawnow;
    case 'Abort'
        abort_bit = 1;
        if(handles.agc.Value)   % start automatic gain timer
            stop(agc_timer);
        end
        sb_abort;
        
        % restart ttl timer if necessary

        if(ttltimer.UserData)
            start(ttltimer);
        end
        
        % Disable knobby scheduler
        if(sbconfig.tri_knob_ver>1)
            tri_send('KBY',0,81,150,0);
            handles.knobby_enable.Value = 0;
        end
        
        % make pmts zero...
        
        pause(0.2);
        
        sb_gain0(0);
        handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);
        
        sb_gain1(0);
        handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);
        
        handles.pmt0.Enable = 'off';
        handles.pmt1.Enable = 'off';
        
        global mm_flag mmfile;
        if(mm_flag) % signal end of aquisition
            mmfile.Data.header(1) = -2;
            pause(.15);
            mmfile.Data.header(1) = -1;
        end
        
        % close ephys
        if(sbconfig.ephys)
            try
                stop(ephys);
                fclose(efid);
            catch
            end
        end
        
        % close xevents
        if(sbconfig.xevents)
            try
                stop(xevents);
                fclose(xefid);
            catch
            end
        end
        
        retCode = calllib('ATSApi', 'AlazarAbortAsyncRead', boardHandle);
        if retCode ~= ApiSuccess
            warndlg(sprintf('Error: AlazarAbortCapture failed-- %s\n', errorToText(retCode)),'scanbox');
        end
        
        if(handles.ttltrigger.Value == 0)
            set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
            set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
        end
        
        captureDone = 1;
        
        return;
end


if frames==0
    frames = hex2dec('7fffffff'); % Inf for Alazar card
end

% set lines/mag/frames

lines  = str2num(get(handles.lines,'String'));
global nlines;
nlines = lines;
mag = get(handles.magnification,'Value')-1;
sb_setparam(lines,frames,mag);

fold_lines = str2double(handles.fold_lines.String);
if fold_lines>0
    sb_setmag_fold(handles.magnification.Value-1,fold_lines);
end

if(scanmode)
    recordsPerBuffer = lines;       % records per buffer - unidirectional
    handles.magnification.Enable = 'on';
else
    recordsPerBuffer = lines/2;       % records per buffer - bidirectional
    handles.magnification.Enable = 'off';   % no change in magnification during bidirectional
end

buffersPerAcquisition = frames; % Total  number of frames to capture

% Capture both channels
channelMask = CHANNEL_A + CHANNEL_B;

% Buffer time out....
bufferTimeout_ms = 2000;

% No of channels to sample
channelCount = 2;

% Get the sample and memory size
[retCode, boardHandle, maxSamplesPerRecord, bitsPerSample] = calllib('ATSApi', 'AlazarGetChannelInfo', boardHandle, 0, 0);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarGetChannelInfo failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Calculate sizes

global scanmode;

if(scanmode)
    postTriggerSamples = 5000;                % just one line...
    samplesPerRecord =   postTriggerSamples;  % 10000/4 (1 sample every laser clock) samples per scan (back and forth)
else
    postTriggerSamples = 9000;                % bidirectional
    samplesPerRecord =   postTriggerSamples;  % 10000/4 (1 sample every laser clock) samples per scan (back and forth)
end

% scanmode luts for non-uniform compensation

if(scanmode)                % unidirectional
    S = pixel_lut_2;
    ncol = length(S)/4;
else                        % bidirectinal 
    [S,postIdx,postIdxA,cdIdx,ncol] = pixel_lut_bi_2(nlines);
end

bytesPerSample = 2;
samplesPerBuffer = samplesPerRecord * recordsPerBuffer * channelCount ;
bytesPerBuffer   = samplesPerBuffer * bytesPerSample;

global sbconfig;

% Prepare DMA buffers...

bufferCount = uint32(sbconfig.nbuffer); % Pre allocate buffers to store the data...

% buffers = cell(1,bufferCount);
% for j = 1 : bufferCount
%     buffers{j} = libpointer('uint16Ptr', 1:samplesPerBuffer) ;
% end

buffers = cell(1, bufferCount);
for j = 1 : bufferCount
    pbuffer = calllib('ATSApi', 'AlazarAllocBufferU16', boardHandle, samplesPerBuffer);
    if pbuffer == 0
        fprintf('Error: AlazarAllocBufferU16 %u samples failed\n', samplesPerBuffer);
        return
    end
    buffers(1, j) = { pbuffer };
end



% Create a data file if required

fid = -1;
if saveData
    global datadir animal experiment unit
    
    fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.sbx'];
    
    if(exist(fn,'file'))
        warndlg('Data file exists!  Cannot overwrite! Aborting!');
        set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
        set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
        abort_bit = 1;
        
        pause(0.2);
        
        sb_gain0(0);
        handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);
        
        sb_gain1(0);
        handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);
        
        handles.pmt0.Enable = 'off';
        handles.pmt1.Enable = 'off';
        
        if(ttltimer.UserData)   % if aborting due to file name restart timer
            start(ttltimer);
        end
        
        return;
    end
    
    fid = fopen(fn,'w');
    if fid == -1
        warndlg(sprintf('Error: Unable to create data file\n'),'scanbox');
        
        % Restore buttons
        set(handles.grabb,'String','Grab','Enable','on'); % make this invisible
        set(handles.focusb,'String','Focus','Enable','on'); % make this invisible
        
        clear buffers;
        
        return;
    end
    
    if(sbconfig.ephys)
        global efid
        fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.ephys'];
        efid = fopen(fn,'w');
    end
    
    if(sbconfig.xevents)
        global xefid
        fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.xevents'];
        xefid = fopen(fn,'w');
    end
    
    % disable mouse control when grabbing
    
    handles.mousecontrol.Value = 0;
    handles.mousecontrol.Callback(handles.mousecontrol,handles);

end

% Set the record size
retCode = calllib('ATSApi', 'AlazarSetRecordSize', boardHandle, uint32(0), uint32(postTriggerSamples));
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarBeforeAsyncRead failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% TODO: Select AutoDMA flags as required
% ADMA_NPT - Acquire multiple records with no-pretrigger samples
% ADMA_EXTERNAL_STARTCAPTURE - call AlazarStartCapture to begin the acquisition
% ADMA_INTERLEAVE_SAMPLES - interleave samples for highest throughput

admaFlags = ADMA_EXTERNAL_STARTCAPTURE + ADMA_NPT + ADMA_INTERLEAVE_SAMPLES;

% Configure the board to make an AutoDMA acquisition
recordsPerAcquisition = recordsPerBuffer * buffersPerAcquisition;
retCode = calllib('ATSApi', 'AlazarBeforeAsyncRead', boardHandle, uint32(channelMask), uint64(0), uint32(samplesPerRecord), uint32(recordsPerBuffer),uint32(recordsPerAcquisition), uint32(admaFlags));
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarBeforeAsyncRead failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end

% Post the buffers to the board
for bufferIndex = 1 : bufferCount
    pbuffer = buffers{1, bufferIndex};
    retCode = calllib('ATSApi', 'AlazarPostAsyncBuffer', boardHandle, pbuffer, uint32(bytesPerBuffer));
    if retCode ~= ApiSuccess
        warndlg(sprintf('Error: AlazarPostAsyncBuffer failed -- %s\n', errorToText(retCode)),'scanbox');
        if(handles.agc.Value)   % start automatic gain timer
            stop(agc_timer);
        end
        sb_abort;
        
        if(ttltimer.UserData)
            start(ttltimer);
        end
        
        % Disable knobby scheduler
        if(sbconfig.tri_knob_ver>1)
            tri_send('KBY',0,81,150,0);
            handles.knobby_enable.Value = 0;
        end
        
        return
    end
end


% Prepare image axis

global chA chB acc accB accd accdB tfilter_h scanbox_h img0_h img0_axis;

%set(get(img0_h,'Parent'),'xlim',[0 samplesPerRecord/4-1],'ylim',[0 recordsPerBuffer-1]);

if(get(handles.camerabox,'Value')==0)
    set(get(img0_h,'Parent'),'xlim',[0.5 ncol+0.5],'ylim',[0.5 lines+0.5]);
    set(img0_h,'CData',ones([lines ncol 3],'uint8'));
    set(img0_h,'erasemode','none');
    axis off;
end

% loop vars...

buffersCompleted = 0;
captureDone = false;
success = false;
acc=[];
accB = [];

nacc=0;
trial_acc={};
trial_n=[];
ttlflag = 0;

global sb_server sb sbconfig;

sb_server.BytesAvailableFcn = ''; % we are going to poll...

global wcam wcam_src eyecam eye_src ballpos ballarrow ballmotion;
global datadir experiment animal unit;
global wcamlog eyecamlog;
global wcam_roi eye_roi;
global sbconfig;
global ttlonline;
global trace_idx trace_period cellpoly roi_traces_h;
global ref_img;
global gtime gData nlines;
global stream_udp;
global nroi;
global ref_img_fft xref yref
global roipix
global otwave otparam otwave_um opto2pow
global tri_pos dmpos origin xpos_h ypos_h zpos_h thpos_h motor_gain
global ephys xevents


% make sure previews are closed
closepreview;


if fid ~= -1
    if(get(handles.wc,'Value'))
        
        triggerconfig(wcam, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
        wcam.TriggerRepeat = inf;
        try
            wcam_src.FrameStartTriggerMode = 'On';
        catch
            wcam_src.TriggerMode = 'On';
            wcam_src.TriggerSource = 'Line2';            
        end
        wcam.FramesPerTrigger = 1;
        wcam.ROIPosition = wcam_roi;
        start(wcam);
        
    end
    
    if(get(handles.eyet,'Value'))
        
        triggerconfig(eyecam, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
        eyecam.TriggerRepeat = inf;
        try
            eye_src.FrameStartTriggerMode = 'On';
        catch
            eye_src.TriggerMode = 'On';
            eye_src.TriggerSource = 'Line2';
        end
        eyecam.FramesPerTrigger = 1;
        eyecam.ROIPosition = eye_roi;
        
        start(eyecam);
    end
end


global ltimer;

if(~isempty(sbconfig.laser_type))
    stop(ltimer);
end

% global ptimer;
% if(~isempty(sbconfig.tri_knob))
%     stop(ptimer);
% end

delete(get(roi_traces_h,'Children')); % remove children...
nroi = length(get(handles.blist,'String'));
ydata = NaN*zeros(trace_period+1,nroi);
Xtrace = repmat([1:trace_period NaN],[nroi 1])';
Xtrace = Xtrace(:);

%disable poly view

cellfun(@(x) set(x,'Parent',[]),cellpoly);


if(nroi>0)
    stream_data = zeros(1,nroi+3,'int16');
    roiidx = cellfun(@str2num,get(handles.blist,'String'));
    roipix = cell(1,length(roiidx));
    hold(roi_traces_h,'on');
    
    theline = plot(roi_traces_h,[1 1],[-4 nroi*4],'color',[.75 0 0],'linewidth',1);
    set(roi_traces_h,'Ylim',[-4 nroi*4],'Xlim',[1 trace_period]); % 4 std apart...
    trace_idx = 1;
    
    thetrace = animatedline('MaximumNumPoints',(trace_period+1)*50,'linewidth',.5,'color',[0 0 0.5],'tag','thetrace','Parent',roi_traces_h);
    thetrace.addpoints(Xtrace,ydata(:));
    hold(roi_traces_h,'off');
    for(i=1:length(roiidx))
        %roipix{i} = find(createMask(cellpoly{roiidx(i)}));
        roipix{i}=find(poly2mask(get(cellpoly{roiidx(i)},'XData'),get(cellpoly{roiidx(i)},'YData'),nlines,ncol));
        th = text(8,4*(i-1),sprintf('%02d',roiidx(i)),'parent',roi_traces_h,'fontsize',10,'color','r','BackgroundColor','w','edgecolor','k','fontname','CourierNew');
        uistack(th,'top');
    end
    
    
    %     ch = get(roi_traces_h,'Children');
    %     vch = ch(end);
    rmean = zeros(1,nroi);  %mean and variance (recursive)
    rvar = zeros(1,nroi);
    rtdata = zeros(sbconfig.rtmax,nroi);
    ttl_log = zeros(sbconfig.rtmax,1,'uint8');
end

% Allocate for encoder data
if(~isempty(sbconfig.quad_com) && (handles.quadcheck.Value>0))
    quad_data = zeros(1,sbconfig.rtmax,'int32');
    quad_zero;  % zero counter
    quad_flag = 1;
else
    quad_flag = 0;
end

% Allocate speedbelt data

if(~isempty(sbconfig.speedbelt_com) && (handles.sbcheck.Value>0))
    speedbelt_data = zeros(1,sbconfig.rtmax,'int32');
    speedbelt_zero;
    speedbelt_flag = 1;
else
    speedbelt_flag = 0;
end

% allocate for online alignment

global T preIdx;
Talign = zeros(sbconfig.rtmax,2*sbconfig.nroi_auto);


% Prepare for alignment...

u = zeros(1,sbconfig.nroi_auto);
v = zeros(1,sbconfig.nroi_auto);
N = sbconfig.nroi_auto_size(handles.magnification.Value);

global L I;
L = []; % list of patches and indices for roi stim patch visualization
I = [];

if(sbconfig.gpu_pages>0)
    % allocate memory...
    global nlines;
    if(nlines~=size(gData,2) || sbconfig.gpu_pages~=size(gData,1) || ncol~=size(gData,3))
        gData = zeros([sbconfig.gpu_pages nlines ncol ],'single','gpuArray');
    end
    gtime = 1;          % next page to be filled
    tmp  = rand(100);   % gpu warm up...
    gtmp = gpuArray(tmp);
    gtmp = gtmp*gtmp;
    tmp = gather(gtmp);
end

% network streaming

stream_flag = get(handles.networkstream,'Value');
stim_flag = get(handles.stimmark,'Value');

% prealocate stuff...

chAB = zeros([2 ncol lines],'uint16');
chA  = zeros([ncol lines],'uint16');
chB  = zeros([ncol lines],'uint16');

ttlflagnew = zeros(1,2,'uint8');

if(scanmode)    % unidirectional
    
    % new version does not merely sample on 4 sample boundaries...
    
    preIdx = reshape(0:prod([2 4 1250 lines])-1,[2 4*1250 lines]);
    preIdx = preIdx(:,S,:);
    preIdx = reshape(preIdx,2,4,[],lines);
    preIdx = uint32(preIdx);
    
else            % bidirectional
    % new version does not merely sample on 4 sample boundaries...

    preIdx = reshape(0:prod([2 4 2250 lines/2])-1,[2 4*2250 lines/2]);
    preIdx = preIdx(:,S,:);
    preIdx = reshape(preIdx,2,4,[],lines/2);
    preIdx = uint32(preIdx);
    preIdx = preIdx+sbconfig.bishift(handles.magnification.Value)*2;
end

outCData = zeros([3 ncol lines],'uint8');
newCData = zeros([lines ncol lines 3],'uint8');

% memory mapped file?

global mm_flag;
mm_flag = handles.mmap.Value;
if(mm_flag)
    try
        clear mmfile;
    catch
    end
    global mmfile;
    mmfile = memmapfile(sbconfig.fnmm,'Writable',true,'Format', ...
        { 'int16' [1 16] 'header' ; 'uint16' [nlines ncol] 'chA' ; 'uint16' [nlines ncol] 'chB'} , 'Repeat', 1);
    mmfile.Data.header(1) = -1;                 % semaphore or frame #
                                                % -1, not started
                                                % -2, stopped
                                                % 0...N frame number
    mmfile.Data.header(2) = int16(nlines);      % number of lines
    mmfile.Data.header(3) = int16(ncol);        % number of columns
    mmfile.Data.header(4) = 0;                  % TTL corresponding to stimulus
    mmfile.Data.header(5) = int16(handles.volscan.Value);   % volumetric scanning flag
    mmfile.Data.header(6) = int16(str2double(handles.optoperiod.String));   % period of volumetric wave
    mmfile.Data.header(7) = handles.plugin.Value; % code for plugin id #
    mmfile.Data.header(8) = int16(unit);
    mmfile.Data.header(9) = int16(experiment);
end

% acquiring ephys?  Start background collection

if(sbconfig.ephys)
    startBackground(ephys);
end

% external TTLs?
if(sbconfig.xevents)
    startBackground(xevents);
end

% Arm the board system to wait for triggers

retCode = calllib('ATSApi', 'AlazarStartCapture', boardHandle);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarStartCapture failed -- %s\n', errorToText(retCode)),'scanbox');
    return
end



% turn PMTs on

sb_gain0(uint8(255*handles.pmt0.Value));
handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);

sb_gain1(uint8(255*handles.pmt1.Value));
handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);

handles.pmt0.Enable = 'on';
handles.pmt1.Enable = 'on';

pause(.2);

sb_deadband(sbconfig.deadband(1),sbconfig.deadband(2));


% get the position at beginning of imaging/focus/grab
% this works only with knobby 2!!!!

if(sbconfig.tri_knob_ver>1)
    
    kbypos = cell(1,4);
    
    zpos = tri_send('KBY',0,100,0,0);
    kbypos{3} = sprintf('Z = %+5.2f um' ,zpos.val);
    
    ypos = tri_send('KBY',0,101,0,0);
    kbypos{2} = sprintf('Y = %+5.2f um' ,ypos.val);
    
    xpos = tri_send('KBY',0,102,0,0);
    kbypos{1} = sprintf('X = %+5.2f um' ,xpos.val);
    
    apos = tri_send('KBY',0,103,0,0);
    kbypos{4} = sprintf('A = %+2.2f deg',apos.val);
    
    handles.knobby_pos.String = kbypos;
    
    drawnow;
end

% is scheduler on?

if(sbconfig.tri_knob_ver>1 && handles.knobby_enable.Value)
        
    % if returnbox set, then save initial position in C
    
    if(handles.returnbox.Value) 
        tri_send('KBY',0,42,0,0);
    end
    
    tri_send('KBY',0,70,0,0);   %% reset scheduler
    sdata = (handles.knobby_table.Data);
    for(i = 1:size(sdata,1))
        if(sdata(i,1)~=0)
            tri_send('KBY',0,73,sdata(i,1),0);
        end
        if(sdata(i,2)~=0)
            tri_send('KBY',0,72,sdata(i,2),0);
            
        end
        
        if(sdata(i,3)~=0)
            tri_send('KBY',0,71,sdata(i,3),0);
        end
        
        if(sdata(i,4)~=0)
            tri_send('KBY',0,74,sdata(i,4),0);
        end
        
        tri_send('KBY',0,75,sdata(i,5),0);
    end
    
end


% now ready!

sb_scan;   % start scanning!

if(handles.agc.Value)   % start automatic gain timer
    start(agc_timer);
end

lines_u16 = uint16(nlines);
spl_u16 = uint16(length(S)/4);  % samples per line

% colormaps

% thecmaps = uint8(256*[hot(256)' inferno(256)']);

while ~captureDone
    
    % poll quadrature encoder
    
    if(quad_flag)
        quad_poll;
    end
    
    % which buffer to read
    bufferIndex = mod(buffersCompleted, bufferCount) + 1;
    pbuffer = buffers{1,bufferIndex};
    
    % Wait for the first available buffer to be filled by the board
    [retCode, boardHandle, bufferOut] = ...
        calllib('ATSApi', 'AlazarWaitAsyncBufferComplete', boardHandle, pbuffer, uint32(bufferTimeout_ms));
    if retCode == ApiSuccess
        % This buffer is full
        bufferFull = true;
        captureDone = false;
    elseif retCode == ApiWaitTimeout
        % The wait timeout expired before this buffer was filled.
        % The board may not be triggering, or the timeout period may be too short.
        
        warndlg(sprintf('Warning: AlazarWaitAsyncBufferComplete timeout -- Verify trigger!\n'),'scanbox');
        
        bufferFull = false;
        captureDone = true;
    else
        % The acquisition failed
        warndlg(sprintf('Error: AlazarWaitAsyncBufferComplete failed -- %s\n', errorToText(retCode)),'scanbox');
        bufferFull = false;
        captureDone = true;
    end
    
    if bufferFull
        
        setdatatype(bufferOut, 'uint16Ptr', 1, samplesPerBuffer);  %% keep bytes separate
        dt_u16 = int16(pmtdisp_h.Value);
                
        if(scanmode)
%             process_buffer(...
%                 bufferOut.Value,...
%                 preIdx,...
%                 chAB,...
%                 chA,...
%                 chB,...
%                 chB,...
%                 chB,...
%                 outCData, ...
%                 lines_u16, ...
%                 sbconfig.cores_uni, ...
%                 uint16(2), ...
%                 ttlflagnew, ...
%                 thecmaps, ... 
%                 uint8([50 50]) );
            alazarReshapeCData2_openmp(bufferOut.Value,preIdx,chAB,chA,chB,outCData,lines_u16,dt_u16,sbconfig.cores_uni,ttlflagnew);
        else
            alazarReshapeCData2bi_openmp(bufferOut.Value,preIdx,postIdx,postIdxA,cdIdx,chAB,chA,chB,outCData,lines_u16,dt_u16,spl_u16,sbconfig.cores_bi,ttlflagnew);
        end
       
        %ttlflagnew = bitget(bufferOut.Value(1),2,'uint16');
        ttl_log(buffersCompleted+1) = ttlflagnew(1);
        
        % Save the buffer to file
        
        if fid ~= -1
            switch(savesel)
                case 1
                    fwrite(fid,chAB,'uint16');
                case 2
                    fwrite(fid,chA,'uint16');
                case 3
                    fwrite(fid,chB,'uint16');
            end
        end
        
        if (handles.dispenable.Value == 1)  % if display enabled
            
            if ( (handles.sliceview.Value == 0) || ... 
                    ( (handles.sliceview.Value == 1) && (mod(buffersCompleted,length(handles.slice.String)) == (handles.slice.Value - 1)) ) )
                
                % arrange image
                
                newCData = permute(outCData,[3 2 1]);
                
                % visualization gain/bias
                
                newCData = dgain.Value*(newCData+dbias.Value); % gain!!!!
                
                % stabilize
                
                if(handles.stabilize.Value)
                    
                    A = chA'; % do we need double()?
                    
                    for(ka=1:sbconfig.nroi_auto)
                        C = fftshift(real(ifft2(fft2(A(yref(ka,:),xref(ka,:))).*ref_img_fft{ka})));
                        [~,ia] = max(C(:));
                        [iia jja] = ind2sub(size(C),ia);
                        u(ka) = N/2-iia;
                        v(ka) = N/2-jja;
                    end
                    
                    um = round(median(u));
                    vm = round(median(v));
                    img0_h.CData = circshift(newCData,[um vm 0]);
                    chA = circshift(chA,[vm um]);
                    chB = circshift(chB,[vm um]);
                    Talign(buffersCompleted+1,:) = [u v];
                else
                    img0_h.CData = newCData;
                end
            end
            
        end
        
        % log chA to gpu page
        
        if(sbconfig.gpu_pages>0)
            if(gtime<=sbconfig.gpu_pages)
                if(mod(buffersCompleted+1,sbconfig.gpu_interval)==0)
                    gData(gtime,:,:) = chA';
                    gtime = gtime+1;
                end
            end
        end
        
        % log to memory mapped file...
        
        if(mm_flag && ((fid ~= -1) || handles.onfocus.Value))     % if grabbing or onfocus flag is on
            if(mmfile.Data.header(1)<0)                           % data was consumed?  If not, move on...  Server loses a frame
                mmfile.Data.header(4) = ttlflagnew(1);               % ttl flag 
                mmfile.Data.chA = chA';
                mmfile.Data.chB = chB';
                mmfile.Data.header(1) = buffersCompleted;
            end
        end
        
        % accumulator mode?
        
        if(handles.camerabox.Value==0)
            
            switch get(tfilter_h,'Value')
                
                case 1
                    
                case 2
                    
                    if(isempty(acc))
                        acc = chA;
                        accB = chB;
                    else
                        acc = min(acc,chA);
                        accB = min(accB,chB);
                    end
                    
                case 3                          %% accumulate and keep value in global var acc
                    if(isempty(acc))
                        acc = uint32(chA);
                        accB = uint32(chB);
                        nacc = 1;
                    else
                        acc = acc + uint32(chA);
                        accB = accB + uint32(chB);
                        nacc = nacc+1;
                    end
            end
        end
        
        % stimulus present in this frame?
        
        if(fid~=-1 && ttlonline)
            
            switch(ttlflag==0)
                case true
                    if(ttlflagnew(1)~=0)
                        if(~isempty(acc))
                            acc = [];
                            accB = [];
                            nacc = 0;
                        end
                    end
                    
                case false
                    if(ttlflagnew(1)==0)
                        if(~isempty(acc))
                            trial_acc{end+1} = {acc accB};
                            trial_n(end+1) = nacc;
                            acc = [];
                            accB = [];
                            nacc = 0;
                        end
                    end
            end
        end
        
        % trace processing
        
        if(nroi>0)
            
            % check if we need to remove/adjust anything...
            idxdel = [];
            for (jj=1:length(L))
                if(I(jj,1)<=trace_idx && I(jj,2)>=trace_idx && isempty(get(L(jj),'userdata')))
                    I(jj,1) = trace_idx;
                    if(I(jj,1) == I(jj,2))
                        idxdel(end+1) = jj;
                    else
                        set(L(jj),'xdata',[I(jj,1) I(jj,1) I(jj,2) I(jj,2)]);
                    end
                end
            end
            
            if(~isempty(idxdel))
                delete(L(idxdel));
                I(idxdel,:) = [];
                L(idxdel) = [];
            end
            
            % check if we need to add a new stim patch...
            
            if(stim_flag)
                
                if(ttlflag == 0 && ttlflagnew(1) ~= 0) % new stim
                    
                    L(end+1) = patch([trace_idx trace_idx trace_idx trace_idx],[-4 nroi*4 nroi*4 -4],[1 .75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'FaceLighting','none','userdata',1);
                    uistack(L(end),'bottom');
                    I(end+1,:) = [trace_idx trace_idx];
                    
                elseif (ttlflag ~= 0 && ttlflagnew(1) ~= 0) % during stim
                    
                    if(trace_idx>=trace_period) % reached the end
                        
                        I(end,2) = trace_idx;
                        set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)],'userdata',[]);
                        
                    elseif (trace_idx == 1)     % we wrapped around during the stimulus
                        L(end+1) = patch([1 1 1 1],[-4 nroi*4 nroi*4 -4],[1 0.75 1],'edgecolor',0.941*[1 1 1],'parent',roi_traces_h,'userdata',1);
                        uistack(L(end),'bottom');
                        I(end+1,:) = [1 1];
                    else                        % during a stimulus in the middle...
                        I(end,2) = trace_idx;
                        set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)]);
                    end
                    
                elseif (ttlflag ~= 0 && ttlflagnew(1) == 0) % end stim
                    
                    if(~isempty(get(L(end),'userdata')))
                        I(end,2) = trace_idx;
                        set(L(end),'xdata',[I(end,1) I(end,1) I(end,2) I(end,2)],'userdata',[]);
                    end
                    
                end
            end
            
            if handles.rtchan.Value == 1  % select RT channel
                tchA = chA';
            else
                tchA = chB';
            end
            
            t = buffersCompleted+1;
            
            for(k=1:nroi)
                roiv = mean(tchA(roipix{k}));
                rtdata(t,k) = roiv;
                if(t==1)
                    rmean(k) = roiv;
                    ydata(trace_idx,k) =  4*(k-1);
                else
                    rmean(k) = ((t-1)*rmean(k) + roiv)/t;
                    rvar(k)  =  (t-1)/t * rvar(k) + (roiv-rmean(k))^2 / (t-1);
                    tmp = (roiv-rmean(k))/sqrt(rvar(k));
                    ydata(trace_idx,k) = 4*(k-1) + tmp;
                    stream_data(k+2) = int16(tmp*1000);

                    %                     if(k==1)
                    %                         zz = -(roiv-rmean(k))/sqrt(rvar(k));
                    %                         if(abs(zz)>10)
                    %                             zz = 10*sign(zz);
                    %                         end
                    %                         ao.outputSingleScan(zz);
                    %                     end
                end
            end
            thetrace.clearpoints;
            thetrace.addpoints(Xtrace,ydata(:));
            trace_idx = mod(trace_idx,trace_period)+1;
            theline.XData = [trace_idx trace_idx];
        end
               
        drawnow limitrate
        
        % drawing completed
        
        %         if(mod(buffersCompleted,sbconfig.idisplay))
        %             drawnow expose;
        %         else
        %             drawnow;
        %         end
        
        ttlflag = ttlflagnew(1);           % update flag status
        
        if(nroi>0 && stream_flag)
            stream_data(1)= buffersCompleted;
            stream_data(2) = nroi;
            stream_data(end) = ttlflag;
            fwrite(stream_udp,stream_data,'int16');
        end
        
        % Make the buffer available to be filled again by the board
        retCode = calllib('ATSApi', 'AlazarPostAsyncBuffer', boardHandle, pbuffer, uint32(bytesPerBuffer));
        if retCode ~= ApiSuccess
            if(retCode ~= 520)
                warndlg(sprintf('Error: AlazarPostAsyncBuffer failed -- %s\n', errorToText(retCode)),'scanbox');
            end
            captureDone = true;
        end
        
        % quad update needed?
        
        if(quad_flag)
            quad_data(buffersCompleted+1) = quad_get; % read counter
            if(buffersCompleted>0)
                handles.quadtxt.String = sprintf('%+05d',quad_data(buffersCompleted+1));
            end
        end
        
        if(speedbelt_flag)
            speedbelt_data(buffersCompleted+1) = speedbelt_read;
            handles.sbtxt.String = sprintf('%+05d',speedbelt_data(buffersCompleted+1));
        end
        
        if (sb_server.BytesAvailable>0)
            udp_cb(sb_server,[]);
        end
        
        sb_callback;
        
        % Update progress
        
        buffersCompleted = buffersCompleted + 1;
        
        if buffersCompleted >= buffersPerAcquisition;
            captureDone = true;
            success = true;
        end
        
    end % if bufferFull
    
    % update counter/timer
    
    set(handles.etime,'String',sprintf('%05d - %s',buffersCompleted, datestr(datenum(0,0,0,0,0,toc),'MM:SS')));
    set(handles.etime2,'String',sprintf('%04d - %04d', gtime-1,size(T,1)));
    
end % while ~captureDone

% alwsays enable magnification pulldown
handles.magnification.Enable = 'on';   % no change in magnification during bidirectional

if(handles.agc.Value)   % stop automatic gain timer
    stop(agc_timer);
end

sb_abort; % stop scanning
closepreview;

pause(0.2);

% Disable knobby scheduler -- always!

if(sbconfig.tri_knob_ver>1)
    
    tri_send('KBY',0,81,150,0);
    handles.knobby_enable.Value = 0;
    pause(0.2);
    if(handles.returnbox.Value)
        tri_send('KBY',0,52,0,0);   %% go back to initial position
    end
end

% Turn PMTs off

sb_gain0(0);
handles.pmt0txt.String = sprintf('%1.2f',handles.pmt0.Value);

sb_gain1(0);
handles.pmt1txt.String = sprintf('%1.2f',handles.pmt1.Value);

handles.pmt0.Enable = 'off';
handles.pmt1.Enable = 'off';

% mem map

if(mm_flag) % signal end of acuisition
    mmfile.Data.header(1) = -2;
    pause(.15);
    mmfile.Data.header(1) = -1;
end

if(sbconfig.ephys)
    pause(0.15);
    try
        stop(ephys);
        fclose(efid);
    catch
    end
end

if(sbconfig.xevents)
    pause(0.15);
    try
        stop(xevents);
        fclose(xefid);
    catch
    end
end


if(sbconfig.gpu_pages>0)
    gtime = gtime-1;            % last index
end

cellfun(@(x) set(x,'Parent',img0_h.Parent),cellpoly);

%
if ~isempty(acc)
    accd =  double(acc);
    accdB = double(accB);
    
    %fill in bidi mode
    
    if(scanmode==0) % remove bands
        %         accd(1:sbconfig.margin,:) = NaN;
        %         accd(end-sbconfig.margin:end,:) = NaN;
        %         accdB(1:sbconfig.margin,:) = NaN;
        %         accdB(end-sbconfig.margin:end,:) = NaN;
        jj = find(accd(:,2)==0);
        accd(jj,2:2:end) = accd(jj,1:2:end);
        accdB(jj,2:2:end) = accdB(jj,1:2:end);
    end
    
    M = max(accd(:));
    m = min(accd(:));
    accd = ((accd-m)/(M-m));
    %     if(scanmode==0) % remove bands
    %         accd(1:sbconfig.margin,:) = 1;
    %         accd(end-sbconfig.margin:end,:) = 1;
    %     end
    
    M = max(accdB(:));
    m = min(accdB(:));
    accdB = ((accdB-m)/(M-m));
    %     if(scanmode==0) % remove bands
    %         accdB(1:sbconfig.margin,:) = 1;
    %         accdB(end-sbconfig.margin:end,:) = 1;
    %     end
    
    switch(handles.pmtdisp.Value)
        case 1
            
            img0_h.CData(:,:,1) = 0;
            img0_h.CData(:,:,2) =  uint8(255-uint8(255*accd'));
            img0_h.CData(:,:,3) = 0;
            
        case 2
            
            img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
            img0_h.CData(:,:,2) = 0;
            img0_h.CData(:,:,3) = 0;
            
        case 3
            
            img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
            img0_h.CData(:,:,2) = uint8(255-uint8(255*accd'));
            img0_h.CData(:,:,3) = 0;
            
    end
    
end

if(fid ~= -1)
    if(ttlonline && ~isempty(trial_acc))
        fn = sprintf('%s\\%s\\%s_%03d_%03d_trials.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving trial data...','ForegroundColor',[1 0 0]);
        drawnow;
        save(fn,'trial_acc','trial_n');
        clear trial_acc trial_n;
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end

% save real time  data....

if(fid ~= -1)
    if(nroi>0)
        fn = sprintf('%s\\%s\\%s_%03d_%03d_realtime.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving realtime signals','ForegroundColor',[1 0 0]);
        drawnow;
        rtdata = rtdata(1:buffersCompleted,:);
        ttl_log = ttl_log(1:buffersCompleted);
        save(fn,'rtdata','ttl_log','roipix');
        clear rtdata;
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end


% save real time alignment....

if(fid ~= -1)
    if(get(handles.stabilize,'Value'))
        fn = sprintf('%s\\%s\\%s_%03d_%03d_align.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving alignment','ForegroundColor',[1 0 0]);
        drawnow;
        Talign = Talign(1:buffersCompleted,:);
        global xref yref;
        save(fn,'Talign','ref_img','xref','yref');
        clear T;
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end

if(fid ~= -1)
    if(quad_flag)
        fn = sprintf('%s\\%s\\%s_%03d_%03d_quadrature.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving Encoder','ForegroundColor',[1 0 0]);
        drawnow;
        quad_data = quad_data(1:buffersCompleted);
        save(fn,'quad_data');
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
    
    if(speedbelt_flag)
        fn = sprintf('%s\\%s\\%s_%03d_%03d_speedbelt.mat',datadir,animal,animal,unit,experiment);
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving Speedbelt','ForegroundColor',[1 0 0]);
        drawnow;
        speedbelt_data = speedbelt_data(1:buffersCompleted);
        save(fn,'speedbelt_data');
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
    
end

if(fid ~= -1)
    
    if(get(handles.wc,'Value'))
        stop(wcam); % stop web cam...
        try
            wcam_src.FrameStartTriggerMode = 'Off';
        catch
            wcam_src.TriggerMode = 'Off';
        end
        triggerconfig(wcam, 'immediate', 'none', 'none');
        wcam.FramesPerTrigger = inf;
        wcam.TriggerRepeat = 1;
        wcam.ROIPosition = wcam_roi;
    end
    
    if(get(handles.eyet,'Value'))
        stop(eyecam); % stop eye cam...
        try
            eye_src.FrameStartTriggerMode = 'Off';
        catch
            eye_src.TriggerMode = 'Off';
        end
        
        triggerconfig(eyecam, 'immediate', 'none', 'none');
        eyecam.FramesPerTrigger = inf;
        eyecam.TriggerRepeat = 1;
        eyecam.ROIPosition = eye_roi;
    end
    
    if(get(handles.wc,'Value') || get(handles.eyet,'Value'))
        oldstr = get(handles.etime,'String');
        set(handles.etime,'String','Saving tracking data','ForegroundColor',[1 0 0]);
        drawnow;
        
        if(get(handles.wc,'Value')) % write wcam data...
            [data,time,abstime] = getdata(wcam);
            fn = sprintf('%s\\%s\\%s_%03d_%03d_ball.mat',datadir,animal,animal,unit,experiment);
            flushdata(wcam);
            
            save(fn,'data','time','abstime','-v7.3');
            clear data time abstime;
        end
        
        if(get(handles.eyet,'Value')) % write eyet data...
            [data,time,abstime] = getdata(eyecam);
            fn = sprintf('%s\\%s\\%s_%03d_%03d_eye.mat',datadir,animal,animal,unit,experiment);
            flushdata(eyecam);
            save(fn,'data','time','abstime','-v7.3');
            clear data time abstime;
        end
        
        set(handles.etime,'String',oldstr,'ForegroundColor',[0 0 0]);
    end
end

sb_server.BytesAvailableFcn = @udp_cb;  % restore...


% stop automatic gain timer

if(handles.agc.Value)   % start automatic gain timer
    stop(agc_timer);
end

% Stop scanning just in case...

sb_abort;

% Disable knobby scheduler

if(sbconfig.tri_knob_ver>1)
    tri_send('KBY',0,81,150,0);
    handles.knobby_enable.Value = 0;
end

if(mm_flag) % signal end of acuisition
    mmfile.Data.header(1) = -2;
    pause(.15);
    mmfile.Data.header(1) = -1;
end

if(sbconfig.ephys)
    try
        global efid;
        stop(ephys);
        fclose(efid);
    catch
    end
end

if(sbconfig.xevents)
    try
        global xefid;
        stop(xefid);
        fclose(xefid);
    catch
    end
end


global ltimer;
if(~isempty(sbconfig.laser_type))
    start(ltimer);
end

% if(~isempty(sbconfig.tri_knob))
%     start(ptimer);
% end

% Terminate the acquisition
retCode = calllib('ATSApi', 'AlazarAbortAsyncRead', boardHandle);
if retCode ~= ApiSuccess
    warndlg(sprintf('Error: AlazarAbortAsyncRead failed -- %s\n', errorToText(retCode)),'scanbox');
end

% Restore buttons
if(handles.ttltrigger.Value == 0)
    handles.grabb.Enable = 'on';
    handles.focusb.Enable = 'on';
end
handles.grabb.String = 'Grab';
handles.focusb.String = 'Focus';

% Release the buffers
for bufferIndex = 1:bufferCount
    pbuffer = buffers{1, bufferIndex};
    retCode = calllib('ATSApi', 'AlazarFreeBufferU16', boardHandle, pbuffer);
    if retCode ~= ApiSuccess
        fprintf('Error: AlazarFreeBufferU16 failed -- %s\n', errorToText(retCode));
    end
    clear pbuffer;
end

%WindowAPI(handles.scanboxfig,'setfocus');

sb_callback; % any time stamps left?



% Close the data file
if fid ~= -1
    fclose(fid);
    fid = -1;
    fn = [datadir filesep animal filesep sprintf('%s_%03d',animal,unit) '_'  sprintf('%03d',experiment) '.mat'];
    info = sb_timestamps;   % get time stamps and image size...
    info.resfreq = sbconfig.resfreq;    % resonant frequency in Hz...
    info.postTriggerSamples = postTriggerSamples;
    info.recordsPerBuffer = recordsPerBuffer;
    info.bytesPerBuffer = bytesPerBuffer;
    info.channels = get(handles.savesel,'Value');
    info.ballmotion = ballmotion;
    info.abort_bit = abort_bit;
    info.scanbox_version = 2;
    info.scanmode = scanmode;
    info.config = scanbox_getconfig;
    info.sz = size(chA');
    info.fold_lines = str2double(handles.fold_lines.String);
    info.otwave = otwave;
    info.otwave_um = otwave_um;
    info.otparam = otparam;
    info.otwavestyle = handles.optowavestyle.Value;
    info.volscan = handles.volscan.Value;
    info.power_depth_link = handles.linkcheck.Value;
    info.opto2pow = opto2pow;
    info.area_line = strcmp('Area', handles.arealine.String);   % area vs line
    global calibration
    if(~isempty(calibration))                              % add calibration if it exists
        info.calibration = calibration{handles.objective.Value};
        info.objective = handles.objective.String{handles.objective.Value};
    end
    
    % save any messages too...
    
    global messages;
    
    info.messages = get(messages,'String');
    
    set(messages,'String',{});  % clear messages after saving...
    set(messages,'ListBoxTop',1);
    set(messages,'Value',1);
    
    % and the notes
    
    info.usernotes = handles.notestxt.String;
    handles.notestxt.String = '';
    
    save(fn,'info');
        
    if(sbconfig.autoinc);
        global experiment
        experiment = str2double(handles.expt.String)+1;
        handles.expt.String = sprintf('%03d',experiment);
    end
    
    % check ttl timer
    
    if(ttltimer.UserData)   % restart...
        start(ttltimer);
    end
    
end

function edit15_Callback(hObject, eventdata, handles)
% hObject    handle to edit15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit15 as text
%        str2double(get(hObject,'String')) returns contents of edit15 as a double


% --- Executes during object creation, after setting all properties.
function edit15_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox6.
function checkbox6_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox6


% --- Executes on button press in checkbox7.
function checkbox7_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox7


% --- Executes on key press with focus on scanboxfig and none of its controls.

% hObject    handle to scanboxfig (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

switch eventdata.Key
    case 'z'
        zoom(scanbox_h,'toggle');
    case 'p'
        pan(scanbox_h,'toggle');
    case 'n'
        zoom(scanbox_h,'off');
        pan(scanbox_h,'off');     
end


% --- Executes on button press in zerobutton.
function zerobutton_Callback(hObject, eventdata, handles)
% hObject    handle to zerobutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global origin dmpos

choice = questdlg('Warning! This action will bring the objective to its vertical position. Make sure there is space around for it to move. Do you want to proceed?', ...
    'scanbox', ...
    'Yes','No','No');
% Handle response
switch choice
    case 'Yes'
        set(hObject,'ForegroundColor',[1 0 0]);
        drawnow;
        
        r = tri_send('RUN',1,0,1);
        r = tri_send('GAS',0,0,0);      % wait for application to stop
        r = bitand(uint32(r.value),hex2dec('ff000000'));
        while(r ~= 0)% bug in TMC 610 return codes!
            r = tri_send('GAS',0,0,0);
            r = bitand(uint32(r.value),hex2dec('ff000000'));
        end
        
        for(i=0:3)
            r = tri_send('GAP',1,i,0);
            origin(i+1) = r.value;
        end
        
        dmpos = origin;
        
        set(handles.xpos,'String','0.00');
        set(handles.ypos,'String','0.00');
        set(handles.zpos,'String','0.00');
        set(handles.thpos,'String','0.00');
        
        set(hObject,'ForegroundColor',[0 0 0]);
        drawnow;
        
    case 'No'
end





% --- Executes on button press in originbutton.
function originbutton_Callback(hObject, eventdata, handles)
% hObject    handle to originbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if(hObject.Value)
    for(i=0:2)
        tri_send('SAP',204,0,1);
    end
else
    for(i=0:2)
        tri_send('SAP',204,0,0);
    end
end



% --- Executes on selection change in pmtdisp.
function pmtdisp_Callback(hObject, eventdata, handles)
% hObject    handle to pmtdisp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns pmtdisp contents as cell array
%        contents{get(hObject,'Value')} returns selected item from pmtdisp

% reset accumulator automatically...

global accd accdB img0_h captureDone;

if(captureDone)
    if(~isempty(accd))
        switch(hObject.Value)
            case 1
                img0_h.CData(:,:,1) = 0;
                img0_h.CData(:,:,2) =  uint8(255-uint8(255*accd'));
                img0_h.CData(:,:,3) = 0;
                
            case 2
                
                img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
                img0_h.CData(:,:,2) = 0;
                img0_h.CData(:,:,3) = 0;
                
            case 3
                
                img0_h.CData(:,:,1) = uint8(255-uint8(255*accdB'));
                img0_h.CData(:,:,2) = uint8(255-uint8(255*accd'));
                img0_h.CData(:,:,3) = 0;
        end
    end
else
    switch(hObject.Value)
        case 1
            img0_h.CData(:,:,[1 3])=0;
            
        case 2
            img0_h.CData(:,:,[2 3])=0;
            
        case 3
            
    end
end


% --- Executes during object creation, after setting all properties.
function pmtdisp_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmtdisp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global pmtdisp_h;

pmtdisp_h = hObject;

% --- Executes during object creation, after setting all properties.
function image0_CreateFcn(hObject, eventdata, handles)
% hObject    handle to image0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate image0

global img0_h img0_axis cm;

% colormaps

global cm;

axis(hObject);
cm = gray(256);
cm(end,:) = [1 0 0]; % saturation signal
cm = flipud(cm);
colormap(cm);
img0_h = imshow(ones([512 796 3],'uint8'));
axis off image


% --- Executes on slider movement.
function slider3_Callback(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function pix_histo_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pix_histo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate pix_histo

global histo_h;

histo_h = hObject;

% % --- Executes on button press in camerabox.
function camerabox_Callback(hObject, eventdata, handles)
% hObject    handle to camerabox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of camerabox

global vid img0_h cm dalsa sbconfig dalsa_src cellpoly;

sb_mirror(get(hObject,'Value')-1);

if(sbconfig.portcamera==1)
    
    if(get(hObject,'Value'))
        hObject.UserData = img0_h.CData;
        %set(img0_h.Parent,'xlim',[0 dalsa_src.CUR_HRZ_SZE-1],'ylim',[0 dalsa_src.CUR_VER_SZE-1]);
        % dalsa_src.ExposureTimeRaw = dalsa_src.MaxExposure;
        % eval(sprintf('%s_me(%f)',sbconfig.pathcamera,1.0));   % max exposure camera
        cellfun(@(x) set(x,'Visible','off'),cellpoly);
        preview(dalsa,img0_h);
        set(handles.dalsa_exposure,'Value',1.0);
    else
        closepreview(dalsa);
        img0_h.CData = hObject.UserData;
        cellfun(@(x) set(x,'Visible','on'),cellpoly);
        %set(img0_h,'xlim',[0.5 795.5],'ylim',[0.5 511.5]);
    end
end


% --- Executes during object creation, after setting all properties.
function shutterbutton_CreateFcn(hObject, eventdata, handles)
% hObject    handle to shutterbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global shutter_h;

shutter_h = hObject;

% laser_send(sprintf('SHUTTER=%d',get(hObject,'Value')));


% --- Executes when user attempts to close scanboxfig.
function scanboxfig_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure

global scanbox_h ltimer ptimer sbconfig;


istep = 1;
cprintf('\n');
% cprintf('*blue','Scanbox v4.1 | https://scanbox.org/ | Dario Ringach (darioringach@me.com)\n\n');
% cprintf('\n');

[~, ~] = system('netsh interface set interface "The World" ENABLED');

cprintf('*comment','[%02d] Deleting timer objects\n',istep); istep=istep+1;

delete(ltimer);
%delete(ptimer);
delete(hObject);

cprintf('*comment','[%02d] Setting PMT gains zero\n',istep); istep=istep+1;

sb_gain1(0); % make sure pmt gains are zero on exit...
sb_gain0(0);

cprintf('*comment','[%02d] Setting ETL current to zero\n',istep); istep=istep+1;

sb_current(0);

cprintf('*comment','[%02d] Moving mirror into default position\n',istep); istep=istep+1;

sb_mirror(0); % make sure camera path enabled upon shutdown

cprintf('*comment','[%02d] Enforce normal resonant mode\n',istep); istep=istep+1;
sb_continuous_resonant(0);

cprintf('*comment','[%02d] Closing Scanbox communication \n',istep); istep=istep+1;

sb_close();
cprintf('*comment','[%02d] Closing motor controller communication \n',istep); istep=istep+1;

tri_close();

cprintf('*comment','[%02d] Closing laser shutter\n',istep); istep=istep+1;

switch sbconfig.laser_type
    case 'CHAMELEON'
       laser_send(sprintf('SHUTTER=0'));
    case 'DISCOVERY'
       laser_send(sprintf('SHUTTER=0'));
       laser_send(sprintf('SFIXED=0'));
end

cprintf('*comment','[%02d] Closing laser communication \n',istep); istep=istep+1;
laser_close();

cprintf('*comment','[%02d] Closing quadrature encoder communication \n',istep); istep=istep+1;
quad_close();

cprintf('*comment','[%02d] Closing speedbelt communication \n',istep); istep=istep+1;
speedbelt_close();

cprintf('*comment','[%02d] Closing UDP communication \n',istep); istep=istep+1;

udp_close();

if(sbconfig.nroi_parallel)
    cprintf('*comment','[%02d] Closing parallel pool\n',istep); istep=istep+1;
    
    delete(gcp); % shutdown parallel pool
end

if(sbconfig.gpu_pages>0)
    cprintf('*comment','[%02d] Resetting GPU\n',istep); istep=istep+1;
    gpuDevice(sbconfig.gpu_dev);
end

cprintf('*comment','[%02d] Unload digitizer library\n',istep); istep=istep+1;
unloadlibrary('ATSApi')

cprintf('*comment','[%02d] Reset image acquisition\n',istep); istep=istep+1;
imaqreset

global pmeter
if(~isempty(pmeter))
    cprintf('*comment','[%02d] Closing power meter \n',istep); istep=istep+1;
    powermeter_close;
end

global led_controller
if(~isempty(led_controller))
    cprintf('*comment','[%02d] Closing LED controller \n',istep); istep=istep+1;
    powermeter_close;
end

cprintf('*comment','[%02d] Clear Matlab workplace and figures\n\n',istep); istep=istep+1;

fclose all;     % close any open files
clear all;      % clear all vars just in case... shutdown
close all;      % close all figs

cprintf('*comment','Scanbox shutdown complete\n');

% --- Executes during object creation, after setting all properties.
function scanboxfig_CreateFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global scanbox_h seg;

scanbox_h = hObject;
p = get(0,'screensize');
q = get(hObject,'Position');
q(1:2) = p(3:4)/2 - q(3:4)/2;
set(hObject,'Position',q)
seg = [];
scanbox_config;

% --- Executes on button press in timebin.
function timebin_Callback(hObject, eventdata, handles)
% hObject    handle to timebin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of timebin


% --- Executes on selection change in tfilter.
function tfilter_Callback(hObject, eventdata, handles)
% hObject    handle to tfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns tfilter contents as cell array
%        contents{get(hObject,'Value')} returns selected item from tfilter


% --- Executes during object creation, after setting all properties.
function tfilter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global tfilter_h;

tfilter_h = hObject;


% --- Executes on button press in pix_histo.
function histbox_Callback(hObject, eventdata, handles)
% hObject    handle to pix_histo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of pix_histo


% --- Executes during object creation, after setting all properties.
function histbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pix_histo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global histbox_h;

histbox_h = hObject;


% --- Executes during object deletion, before destroying properties.
function scanboxfig_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in sfilter.
function sfilter_Callback(hObject, eventdata, handles)
% hObject    handle to sfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns sfilter contents as cell array
%        contents{get(hObject,'Value')} returns selected item from sfilter


% --- Executes during object creation, after setting all properties.
function sfilter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sfilter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in text14.
function text14_Callback(hObject, eventdata, handles)
% hObject    handle to text14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '@', handles);

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')



% --- Executes on button press in text15.
function text15_Callback(hObject, eventdata, handles)
% hObject    handle to text15 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '#', handles);
%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in text16.
function text16_Callback(hObject, eventdata, handles)
% hObject    handle to text16 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '$', handles);

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in text17.
function text17_Callback(hObject, eventdata, handles)
% hObject    handle to text17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');      % make sure the zoom is off...
pan(scanbox_h,'off');
scanboxfig_WindowKeyPressFcn(hObject, '%', handles);
%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in focusb.
function focusb_Callback(hObject, eventdata, handles)
% hObject    handle to focusb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


grabb_Callback(hObject, eventdata, handles); % Call the grab button... with my own info


% --- Executes on button press in pushbutton23.
function pushbutton23_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton23 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton24.
function pushbutton24_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton24 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global acc gtime;
acc = [];
gtime = 1;

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');


% --- Executes on button press in pushbutton25.
function pushbutton25_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton25 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h img0_axis p1 p2 seg scanbox_h;

N = 25; % size of cell neighborhood....

z = img0_h.CData;   % keep original image

if(isempty(seg))
    seg.ncell = 0;
    seg.boundary = {};
    seg.pixels = {};
    seg.img = zeros(size(z)); % segmentation image
    i = 1;
else
    i = seg.ncell + 1;  % append cells...
end


axis(img0_axis);
x=round(ginput_c(1));
while(~isempty(x))
    hold on;
    plot(x(1),x(2),'r.','Tag','ctr','markersize',15);
    q = z((x(2)-N):(x(2)+N),(x(1)-N):(x(1)+N));
    m = cellseg(-double(q),p1,p2);
    if(~sum(m.mask(:))==0)
        seg.img((x(2)-N+1):(x(2)+N-1),(x(1)-N+1):(x(1)+N)-1) = m.mask*i;
        seg.pixels{i} = find(seg.img == i);
        i = i+1;
    end
    x = round(ginput_c(1));
end
hold off;
set(scanbox_h,'pointer','arrow');


seg.ncell = (i-1);

% delete centers and draw boundaries...

%  h = get(get(img0_h,'Parent'),'Children');
%  delete(h(1:end-1));

%%%drawnow;

h = get(get(img0_h,'Parent'),'Children');
delete(findobj(h,'tag','ctr'));

axis(img0_axis);
hold on;
for(i=1:seg.ncell)
    B{i} = bwboundaries(seg.img==i);
    b = B{i};
    for(j=1:length(b))
        bb = b{j};
        plot(bb(:,2),bb(:,1),'-','tag','bound','UserData',i,'color',[1 0.7 0]);
    end
end

if(seg.ncell>0)
    seg.boundary = B;
    cstr = {};
    m=1;
    for(k=1:seg.ncell)
        if(~isempty(seg.boundary{k}))
            cstr{m} = num2str(k);
            m = m+1;
        end
    end
    set(handles.alist,'String',cstr,'Value',1);
else
    set(handles.alist,'String','','Value',1);
end

set(handles.cell_d,'String','','Value',1);




function edit17_Callback(hObject, eventdata, handles)
% hObject    handle to edit17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit17 as text
%        str2double(get(hObject,'String')) returns contents of edit17 as a double


% --- Executes during object creation, after setting all properties.
function edit17_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit17 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit18_Callback(hObject, eventdata, handles)
% hObject    handle to edit18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit18 as text
%        str2double(get(hObject,'String')) returns contents of edit18 as a double


% --- Executes during object creation, after setting all properties.
function edit18_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in alist.
function alist_Callback(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns alist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from alist

global seg img0_h lastsel;

h = get(get(img0_h,'Parent'),'Children');
h = findobj(h,'tag','bound');
sel = get(hObject,'Value');
str = get(hObject,'String');
if(~isempty(str))
    sel = str2num(str{sel});
    lastsel = sel;
    for(i=1:length(h))
        if(get(h(i),'UserData')==sel)
            set(h(i),'linewidth',3);
        else
            set(h(i),'linewidth',1);
        end
    end
end








% --- Executes during object creation, after setting all properties.
function alist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String',{},'Value',0);

global alist_h
alist_h = hObject;


% --- Executes on selection change in cell_d.
function cell_d_Callback(hObject, eventdata, handles)
% hObject    handle to cell_d (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns cell_d contents as cell array
%        contents{get(hObject,'Value')} returns selected item from cell_d

global seg img0_h lastsel;

h = get(get(img0_h,'Parent'),'Children');
h = findobj(h,'tag','bound');
sel = get(hObject,'Value');
str = get(hObject,'String');
if(~isempty(str))
    sel = str2num(str{sel});
    lastsel = sel;
    for(i=1:length(h))
        if(get(h(i),'UserData')==sel)
            set(h(i),'linewidth',3);
        else
            set(h(i),'linewidth',1);
        end
    end
end


% --- Executes during object creation, after setting all properties.
function cell_d_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cell_d (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton26.
function pushbutton26_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton26 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% remove selection from first list

cella = handles.alist;
idx = get(cella,'value');
l = get(cella,'String');
v = l{idx};
l(idx) = [];
set(cella,'String',l,'Value',1)

%add it to the second one...

celld = handles.cell_d;
l = get(celld,'String');
l{end+1} = v;
set(celld,'String',l,'Value',1);


% --- Executes on button press in pushbutton27.
function pushbutton27_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



celld = handles.cell_d;
idx = get(celld,'value');
l = get(celld,'String');
v = l{idx};
l(idx) = [];
set(celld,'String',l,'Value',1)

%add it to the second one...

cella = handles.alist;
l = get(cella,'String');
l{end+1} = v;
set(cella,'String',l,'Value',1);




% --- Executes on button press in pushbutton28.
function pushbutton28_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton28 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

cella = handles.alist;
la = get(cella,'String');
set(cella,'String',{},'Value',1)

%add it to the second one...

celld = handles.cell_d;
set(celld,'String',la,'Value',1);



% --- Executes on button press in pushbutton29.
function pushbutton29_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton29 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

celld = handles.cell_d;
ld = get(celld,'String');
set(celld,'String',{},'Value',1);

%add it to the second one...

cella = handles.alist;
set(cella,'String',ld,'Value',1);


% --- Executes during object creation, after setting all properties.
function roi_traces_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roi_traces (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate roi_traces

global roi_traces_h trace_idx trace_period;

axis(hObject);
delete(get(hObject,'children'));
roi_traces_h = hObject;
trace_idx = 1;
trace_period = 300; % how many points in the trace....
xlim(hObject,[1 trace_period]);
axis(hObject,'normal','off');


% trace_img = imshow(254*ones(300,796,'uint8'));
% axis(hObject,'off','image');


function animal_Callback(hObject, eventdata, handles)
% hObject    handle to animal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of animal as text
%        str2double(get(hObject,'String')) returns contents of animal as a double

global animal datadir;

animal = get(hObject,'String');

if(~exist([datadir filesep animal],'dir'))
    r = questdlg('Directory does not exist. Do you want to create it?','Question','Yes','No','Yes');
    switch(r)
        case 'Yes'
            mkdir([datadir filesep animal]);
    end
end

% --- Executes during object creation, after setting all properties.
function animal_CreateFcn(hObject, eventdata, handles)
% hObject    handle to animal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global animal;
animal ='xx0';


function expt_Callback(hObject, eventdata, handles)
% hObject    handle to expt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of expt as text
%        str2double(get(hObject,'String')) returns contents of expt as a double

global experiment;

experiment = str2double(hObject.String);

% --- Executes during object creation, after setting all properties.
function expt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to expt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global experiment;
experiment = 0;


function edit21_Callback(hObject, eventdata, handles)
% hObject    handle to edit21 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit21 as text
%        str2double(get(hObject,'String')) returns contents of edit21 as a double


% --- Executes during object creation, after setting all properties.
function edit21_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit21 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in savesel.
function savesel_Callback(hObject, eventdata, handles)
% hObject    handle to savesel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns savesel contents as cell array
%        contents{get(hObject,'Value')} returns selected item from savesel

global savesel;

savesel= get(hObject,'Value');



% --- Executes during object creation, after setting all properties.
function savesel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to savesel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global savesel;
savesel = 2;


% --- Executes during object creation, after setting all properties.
function dirname_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dirname (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global datadir animal expt trial

datadir = 'c:\2pdata';
animal = 'xx0';
expt = 0;
trial = 0;


% --- Executes during object creation, after setting all properties.
function laserbutton_CreateFcn(hObject, eventdata, handles)
% hObject    handle to laserbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% laser_send(sprintf('LASER=%d',get(hObject,'Value')));

global laser_h;

laser_h = hObject;


% --- Executes on slider movement.
function low_Callback(hObject, eventdata, handles)
% hObject    handle to low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
end




% --- Executes during object creation, after setting all properties.
function low_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function high_Callback(hObject, eventdata, handles)
% hObject    handle to high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider



global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
end


% --- Executes during object creation, after setting all properties.
function high_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function gamma_Callback(hObject, eventdata, handles)
% hObject    handle to gamma (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
end


% --- Executes during object creation, after setting all properties.
function gamma_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gamma (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function grabb_CreateFcn(hObject, eventdata, handles)
% hObject    handle to grabb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global grabb_h;

grabb_h = hObject;


function gencm(low,high,gamma)

global cm scanbox_h;

x = (1:256)';
low = round(low*length(x));
high = round(high*length(x));

y(1:low*length(x)) = 0;
y(high+1:end) = 1;

y = (x-low).^gamma /(high-low)^gamma;
y(1:low) = 0;
y(high:end) = 1;

cm = repmat(y,[1 3]);
cm(end,2:3) = 0;  % red

cm = flipud(cm);

colormap(scanbox_h,cm); % set colormap


function appendcm(low,high,gamma)

global cm scanbox_h;

x = (1:256)';
low = round(low*length(x));
high = round(high*length(x));

y(1:low*length(x)) = 0;
y(high+1:end) = 1;

y = (x-low).^gamma /(high-low)^gamma;
y(1:low) = 0;
y(high:end) = 1;

cmold = cm;

cm = repmat(y,[1 3]);
cm(end,2:3) = 0;  % red

cm = flipud(cm);

cm = [cmold(2:2:end,:) ; cm(2:2:end,:)];

colormap(scanbox_h,cm); % set colormap



function unit_Callback(hObject, eventdata, handles)
% hObject    handle to unit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of unit as text
%        str2double(get(hObject,'String')) returns contents of unit as a double

global unit;
unit = str2num(get(hObject,'String'));


% --- Executes during object creation, after setting all properties.
function unit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to unit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


global unit;
unit = 0;


% --- Executes on button press in pushbutton30.
function pushbutton30_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton30 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% just get the laser status and print it...

set(handles.lstatus,'String',laser_status);


function laser_cb(obj,~)
global lstatus;
set(lstatus,'String',laser_status);


function pos_cb(obj,~)
global tri_pos dmpos origin xpos_h ypos_h zpos_h thpos_h motor_gain

if(tri_pos.Data(1))
    if(tri_pos.Data(1)==1)
        dmpos = double(tri_pos.Data(2:end))';
    else
        origin = double(tri_pos.Data(2:end))';
    end
    v = motor_gain .* (dmpos - origin);
    zpos_h.String=sprintf('%.2f',v(1));
    ypos_h.String=sprintf('%.2f',v(2));
    xpos_h.String=sprintf('%.2f',v(3));
    thpos_h.String=sprintf('%.2f',v(4));
    tri_pos.Data(1)=0;
    drawnow;
end

function qmotion_cb(obj,~)
global qserial axis_sel scanbox_h;

if(qserial.bytesavailable>0)
    cmd = fread(qserial,qserial.bytesavailable);
    h = guidata(scanbox_h);
    for(i=1:length(cmd))
        switch cmd(i)
            case 64 % x-
                if(axis_sel ~= 2)
                    eventdata.EventName = '@';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = '!';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 65 % x+
                
                if(axis_sel ~= 2)
                    eventdata.EventName = '@';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = ')';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
                
            case 32 % z-
                if(axis_sel ~= 0)
                    eventdata.EventName = '$';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = '!';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 33 % z+
                
                if(axis_sel ~= 0)
                    eventdata.EventName = '$';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = ')';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 16 % y-
                
                if(axis_sel ~= 1)
                    eventdata.EventName = '#';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = ')';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            case 17 % y+
                if(axis_sel ~= 1)
                    eventdata.EventName = '#';
                    scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                end
                eventdata.EventName = '!';
                scanboxfig_WindowKeyPressFcn(obj, eventdata, h);
                
            otherwise
                
                sw = dec2bin(cmd(i)-240,4);
                
                if(sw(1)=='0' &&  sw(2)=='0')
                    set(h.popupmenu3,'Value',3);
                end
                if(sw(1)=='1' &&  sw(2)=='0')
                    set(h.popupmenu3,'Value',3);
                end
                if(sw(1)=='0' &&  sw(2)=='1')
                    set(h.popupmenu3,'Value',2);
                end
                if(sw(1)=='1' &&  sw(2)=='1')
                    set(h.popupmenu3,'Value',1);
                end
                
                popupmenu3_Callback(h.popupmenu3, [], h);
                
                if(sw(3)=='0' &&  sw(4)=='0')
                    set(h.rotated,'Value',3);
                end
                if(sw(3)=='1' &&  sw(4)=='0')
                    set(h.rotated,'Value',3);
                end
                if(sw(3)=='0' &&  sw(4)=='1')
                    set(h.rotated,'Value',2);
                end
                if(sw(3)=='1' &&  sw(4)=='1')
                    set(h.rotated,'Value',1);
                end
                
        end
    end
end



% --- Executes on button press in pushbutton32.
function pushbutton32_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h animal experiment unit;

img = img0_h.CData;% get current image

save('img.mat','img');
[FileName,PathName] = uiputfile('*.mat');
if(~isempty(FileName))
    save([PathName FileName],'img');
end

% --- Executes on button press in pushbutton35.
function pushbutton35_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton35 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;
zoom(scanbox_h,'toggle');


% --- Executes on button press in pushbutton36.
function pushbutton36_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton36 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global scanbox_h;
pan(scanbox_h,'toggle');


% --- Executes on button press in pushbutton37.
function pushbutton37_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton37 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanbox_h;

zoom(scanbox_h,'off');
pan(scanbox_h,'off');

%set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
% WindowAPI(handles.scanboxfig,'setfocus')


% --- Executes on button press in pushbutton38.
function pushbutton38_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton38 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global cm scanbox_h img0_h;

cm = flipud(gray(256));
newcm = histeq(img0_h.Cdata,cm);
cm(end,:) = [1 0.5 0];

colormap(scanbox_h,cm); % set colormap
drawnow;


% --- Executes on selection change in popupmenu10.
function popupmenu10_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu10 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu10


% --- Executes during object creation, after setting all properties.
function popupmenu10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function slider13_Callback(hObject, eventdata, handles)
% hObject    handle to slider13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider13_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider14_Callback(hObject, eventdata, handles)
% hObject    handle to slider14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider14_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in rotated.
function rotated_Callback(hObject, eventdata, handles)
% hObject    handle to rotated (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rotated

global motormode

motormode = get(hObject,'Value');


% --- Executes on button press in pushbutton42.
function pushbutton42_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton42 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h seg;

h = get(get(img0_h,'Parent'),'Children');
delete(findobj(h,'tag','bound'));
h = get(get(img0_h,'Parent'),'Children');
delete(findobj(h,'tag','pt'));

seg =[];
set(handles.alist,'String',[]);
set(handles.cell_d,'String',[]);




% --- Executes on button press in pushbutton43.
function pushbutton43_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton43 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h


[FileName,PathName] = uigetfile('*.mat');
load([PathName FileName],'img','-mat');
img0_h.CData = img;


function p1_Callback(hObject, eventdata, handles)
% hObject    handle to p1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p1 as text
%        str2double(get(hObject,'String')) returns contents of p1 as a double

global p1;

p1 = str2num(get(hObject,'String'));



% --- Executes during object creation, after setting all properties.
function p1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global p1;
p1 = 0.6;




function p2_Callback(hObject, eventdata, handles)
% hObject    handle to p2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p2 as text
%        str2double(get(hObject,'String')) returns contents of p2 as a double
global p2;

p2 = str2num(get(hObject,'String'));

% --- Executes during object creation, after setting all properties.
function p2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global p2;
p2 = 30;


% --- Executes on button press in pushbutton44.
function pushbutton44_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton44 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global img0_h lastsel seg;

h = get(get(img0_h,'Parent'),'Children');
h = findobj(h,'tag','bound');

seg.boundary{lastsel} = {};
seg.pixels{lastsel} = {};
for(i=1:length(h))
    if(get(h(i),'UserData')==lastsel)
        delete(h(i));
        seg.img(seg.img==lastsel)=0;
    end
end


str = get(handles.alist,'String');
idx = find(strcmp(num2str(lastsel),str));
if(~isempty(idx))
    str(idx) = [];
    set(handles.alist,'String',str,'Value',1);
end


str = get(handles.cell_d,'String');
idx = find(strcmp(num2str(lastsel),str));
if(~isempty(idx))
    str(idx) = [];
    set(handles.cell_d,'String',str,'Value',1);
end



function restore_seg

global seg img0_h img0_axis;


if(~isempty(seg))
    
    axis(get(img0_h,'Parent'));
    hold on;
    for(i=1:seg.ncell)
        b = seg.boundary{i};
        if(~isempty(b))
            for(j=1:length(b))
                bb = b{j};
                plot(bb(:,2),bb(:,1),'-','tag','bound','UserData',i,'color',[1 0.7 0]);
            end
        end
    end
    hold off;
    
end


% --- Executes on slider movement.
function tracegain_Callback(hObject, eventdata, handles)
% hObject    handle to tracegain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global trace_gain;

trace_gain = get(hObject,'Value');

% --- Executes during object creation, after setting all properties.
function tracegain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tracegain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global trace_gain;

trace_gain = 1;

% --- Executes on button press in traceon.
function traceon_Callback(hObject, eventdata, handles)
% hObject    handle to traceon (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of traceon



function p3_Callback(hObject, eventdata, handles)
% hObject    handle to p3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p3 as text
%        str2double(get(hObject,'String')) returns contents of p3 as a double


% --- Executes during object creation, after setting all properties.
function p3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function p4_Callback(hObject, eventdata, handles)
% hObject    handle to p4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of p4 as text
%        str2double(get(hObject,'String')) returns contents of p4 as a double


% --- Executes during object creation, after setting all properties.
function p4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to p4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function tpos_Callback(hObject, eventdata, handles)
% hObject    handle to tpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function tpos_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tpos (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes during object creation, after setting all properties.
function messages_CreateFcn(hObject, eventdata, handles)
% hObject    handle to messages (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global messages;

messages = hObject;



% --- Executes on button press in autostab.
function autostab_Callback(hObject, eventdata, handles)
% hObject    handle to autostab (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of autostab

global autostab img0_axis img0_h refs refctr Ns;

if(autostab)
    set(hObject,'String','Image Stabilization Off')
    autostab = 0;
    refs = [];
    refctr = [];
    delete(findobj(get(get(img0_h,'parent'),'children'),'tag','abox'));
else
    set(hObject,'String','Image Stabilization On')
    autostab = 1;
    axis(img0_axis);
    x=round(ginput_c(1));
    img = img0_h.CData;
    refs = double(img(x(2)-Ns:x(2)+Ns,x(1)-Ns:x(1)+Ns));
    refs = refs - mean(refs(:));
    hold on
    plot([x(1)-Ns x(1)+Ns x(1)+Ns x(1)-Ns x(1)-Ns],[x(2)-Ns x(2)-Ns x(2)+Ns x(2)+Ns x(2)-Ns],'r:','tag','abox','linewidth',2)
    hold off;
    refctr = x;
end

% set(hObject,'enable','off'); drawnow; set(hObject,'enable','on');
%
% drawnow;
% WindowAPI(handles.scanboxfig,'setfocus')




% --- Executes during object creation, after setting all properties.
function autostab_CreateFcn(hObject, eventdata, handles)
% hObject    handle to autostab (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global autostab Ns;

autostab=0;
Ns = 30;


function msg = laser_status

global laser_h shutter_h wave_h sbconfig;

msg = {};

switch sbconfig.laser_type
    
    case 'CHAMELEON'
        
        r = laser_send('PRINT LASER');
        
        switch(r(end))
            case '0'
                %msg = [msg 'Laser is in standby'];
                set(laser_h,'String','Laser is off','FontWeight','Normal','Value',0);
            case '1'
                %msg = [msg 'Laser in on'];
                set(laser_h,'String','Laser is on','FontWeight','Bold','Value',1);
            case '2'
                msg{end+1} = 'Laser of due to fault!';
        end
        
        
        r = laser_send('PRINT KEYSWITCH');
        switch(r(end))
            case '0'
                msg{end+1} = 'Key is off';
            case '1'
                msg{end+1} = 'Key is on';
        end
        
        r = laser_send('PRINT SHUTTER');
        switch(r(end))
            case '0'
                %msg = [msg sprintf('\n') 'Shutter is closed'];
                set(shutter_h,'String','Shutter closed','FontWeight','Normal','Value',0);
                
            case '1'
                %msg = [msg sprintf('\n') 'Shutter is open'];
                set(shutter_h,'String','Shutter open','FontWeight','Bold','Value',1);
        end
        
        r = laser_send('PRINT TUNING STATUS');
        switch(r(end))
            case '0'
                msg{end+1} = 'Tuning is ready';
            case '1'
                msg{end+1} = 'Tuning in progress';
            case '2'
                msg{end+1} = 'Search for modelock in progress';
            case '3'
                msg{end+1} = 'Recovery in progress';
        end
        
        
        r = laser_send('PRINT MODELOCKED');
        switch(r(end))
            case '0'
                msg{end+1} = 'Standby...';
            case '1'
                msg{end+1} = 'Modelocked!';
            case '2'
                msg{end+1} = 'CW';
        end
        
        
    case 'DISCOVERY'
        
        r = laser_send('PRINT LASER');
        
        switch(r(end))
            case '0'
                %msg = [msg 'Laser is in standby'];
                set(laser_h,'String','Laser is off','FontWeight','Normal','Value',0);
            case '1'
                %msg = [msg 'Laser in on'];
                set(laser_h,'String','Laser is on','FontWeight','Bold','Value',1);
            case '2'
                msg{end+1} = 'Laser of due to fault!';
        end
        
        
        r = laser_send('PRINT KEYSWITCH');
        switch(r(end))
            case '0'
                msg{end+1} = 'Key is off';
            case '1'
                msg{end+1} = 'Key is on';
        end
        
        r = laser_send('PRINT SHUTTER');
        switch(r(end))
            case '0'
                %msg = [msg sprintf('\n') 'Shutter is closed'];
                set(shutter_h,'String','Shutter closed','FontWeight','Normal','Value',0);
                
            case '1'
                %msg = [msg sprintf('\n') 'Shutter is open'];
                set(shutter_h,'String','Shutter open','FontWeight','Bold','Value',1);
        end
        
        
        r = laser_send('PRINT TUNING STATUS');
        switch(r(end))
            case '0'
                msg{end+1} = 'Tuning is ready';
            case '1'
                msg{end+1} = 'Tuning in progress';
            case '2'
                msg{end+1} = 'Search for modelock in progress';
            case '3'
                msg{end+1} = 'Recovery in progress';
        end
        
        
        r = laser_send('PRINT MODELOCKED');
        r = r(1:end-1);
        switch(r(end))
            case '0'
                msg{end+1} = 'Standby...';
            case '1'
                msg{end+1} = 'Modelocked!';
            case '2'
                msg{end+1} = 'CW';
        end
        
    case 'MAITAI'
        
        r = laser_send('SHUTTER?');
        switch(r(end))
            case '0'
                set(shutter_h,'String','Shutter closed','FontWeight','Normal','Value',0);
                
            case '1'
                set(shutter_h,'String','Shutter open','FontWeight','Bold','Value',1);
        end
        
        r = laser_send('READ:PCTWARMEDUP?');
        msg = r;
        
        r = laser_send('READ:WAVELENGTH?');
        msg = [msg sprintf('\n') r];
        
end




% --- Executes on button press in pushbutton46.
function pushbutton46_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton46 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Removed!
% switch(questdlg('Do you really want to retract the objective?'))
%     case 'Yes'
%         r = tri_send('SAP',4,0,1000);   % change velocity/acceleration for 'z'
%         r = tri_send('SAP',5,0,1000);
%         r = tri_send('MVP',1,0,128041);
%
%         pause(6);
%
%         popupmenu3_Callback(handles.popupmenu3,[],handles); % restore velocity
%         eventdata.EventName = '2';                          % select 'x' and update position...
%         scanboxfig_WindowKeyPressFcn(hObject, eventdata, handles);
% end


% --- Executes on slider movement.
function slider18_Callback(hObject, eventdata, handles)
% hObject    handle to slider18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global boardHandle;

retCode = ...
    calllib('ATSApi', 'AlazarSetExternalClockLevel', ...
    boardHandle,		 ...	% HANDLE -- board handle
    double(get(hObject,'Value'))			 ...	% U32 --level in percent
    )



% --- Executes during object creation, after setting all properties.
function slider18_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function udp_open

global sb_server sbconfig;

if(~isempty(sb_server))
    udp_close;
end

if isfield(sbconfig,'remotehost')
    sb_server=udp(sbconfig.remotehost, 'LocalPort', 7000,'RemotePort',9090,'BytesAvailableFcn',@udp_cb);
else
    sb_server=udp('localhost', 'LocalPort', 7000,'RemotePort',9090,'BytesAvailableFcn',@udp_cb);
end

fopen(sb_server);


function udp_close

global sb_server;

try
    fclose(sb_server);
    delete(sb_server);
catch
    sb_server = [];
end


function udp_cb(a,b)

global scanbox_h messages captureDone frames sb_server;

s = fgetl(a);   % read the message

switch(s(1))
    
    case 'A'                % set animal name
        an = s(2:end);
        h = findobj(scanbox_h,'Tag','animal');
        set(h,'String',an);
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'E'                % set experiment number
        e = s(2:end);
        h = findobj(scanbox_h,'Tag','expt');
        set(h,'String',e);
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'U'                % set unit number (imaging field numnber)
        u = s(2:end);
        h = findobj(scanbox_h,'Tag','unit');
        set(h,'String',u);
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'L'                % programatically turn laser ON/OFF
        global org_pock
        if(s(2)~='0')
            sb_pockels(org_pock(1),org_pock(2))
        else
            sb_pockels(0,0)
        end
        
    case 'T'                % programmatically change optotune slider
        
        val = s(2:end);
        h = findobj(scanbox_h,'Tag','optoslider');
        set(h,'Value',str2double(val));
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'M'                % add message...
        mssg = s(2:end);
        oldmssg = get(messages,'String');
        if(length(oldmssg)==0)
            set(messages,'String',{mssg});
        else
            oldmssg{end+1} = mssg;
            set(messages,'String',oldmssg,'ListBoxTop',length(oldmssg),'Value',length(oldmssg));
        end
        
    case 'C'                % clear message....
        set(messages,'String',{});
        set(messages,'ListBoxTop',1);
        set(messages,'Value',1);
        
    case 'Z'                % press the zero button in the motor position box...
        
        h = findobj(scanbox_h,'Tag','zerobutton');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the zero button....
        
    case 'P'               % move axis by um relative to current position
                
        global motor_gain origin scanbox_h dxcal dycal
        
        r = [];
        
        mssg = s(2:end);
        ax = mssg(1);
        val = str2num(mssg(2:end));
        
        switch(ax)      %% relative position command....
            case 'x'
                tri_send('KBY',0,2,val); %% in um
                
            case 'y'
                tri_send('KBY',0,1,val);
                
            case 'z' 
                tri_send('KBY',0,0,val);
                
            case 'X'
                tri_send('KBY',0,5,val); %% increment by steps not um
                
            case 'Y'
                tri_send('KBY',0,4,val);
                
            case 'Z'
                tri_send('KBY',0,3,val);
                
            case 'a'
                tri_send('KBY',0,2,round(val*dycal)); %% increment by pixels 
                
            case 'b'
                tri_send('KBY',0,1,round(val*dxcal));
                
        end
        
        %         h = findobj(scanbox_h,'Tag',s);
        %         set(h,'String',sprintf('%.2f',v));
        
        drawnow;
        
%         
%         
%         global motor_gain origin scanbox_h
%         
%         r = [];
%         
%         mssg = s(2:end);
%         ax = mssg(1);
%         val = str2num(mssg(2:end));
%         
%         switch(ax)      %% relative position command....
%             case 'x'
%                 val = val/motor_gain(3);
%                 r=tri_send('MVP',1,2,val);
%                 s = 'xpos';
%                 v =  motor_gain(3) * double(r.value-origin(3));
%                 
%             case 'y'
%                 val = val/motor_gain(2);
%                 r=tri_send('MVP',1,1,val);
%                 s = 'ypos';
%                 v =  motor_gain(2)* double(r.value-origin(2));
%                 
%             case 'z'
%                 val = val/motor_gain(1);
%                 r=tri_send('MVP',1,0,val);
%                 s = 'zpos';
%                 v =  motor_gain(1) * double(r.value-origin(1));
%         end
%         
%         h = findobj(scanbox_h,'Tag',s);
%         set(h,'String',sprintf('%.2f',v));
%         
%         drawnow;
        
    case 'O'        % go to origin
        
        h = findobj(scanbox_h,'Tag','originbutton');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the origin button....
        
    case 'G'        % Go ... start scanning
        h = findobj(scanbox_h,'Tag','camerabox');
        if(h.Value == 0)
            h = findobj(scanbox_h,'Tag','frames');
            h.String = '0';
            drawnow;
            sb_setframe(0);
            h = findobj(scanbox_h,'Tag','grabb');
            f = get(h,'Callback');
            f(h,guidata(h));  % press the grab button....
        else                   
            h = findobj(scanbox_h,'Tag','igrab');   % intrinsic imaging
            f = get(h,'Callback');
            f(h,guidata(h));  % press the grab button....
        end
        
    case 'S'        % Stop scanning
                
        h = findobj(scanbox_h,'Tag','camerabox');
        if(h.Value == 0)            
            global captureDone;
            captureDone = 1;
        else
            h = findobj(scanbox_h,'Tag','igrab');   % intrinsic imaging
            f = get(h,'Callback');
            f(h,guidata(h));  % press the grab/stop button....
        end      
        
        
    case '?'
        switch s(2)
            case 'x'
                xpos = tri_send('KBY',0,102,0,0);
                str = sprintf('X = %+5.2f um' ,xpos.val);
            case 'y'
                ypos = tri_send('KBY',0,101,0,0);
                str = sprintf('Y = %+5.2f um' ,ypos.val);
            case 'z'
                zpos = tri_send('KBY',0,100,0,0);
                str = sprintf('Z = %+5.2f um' ,zpos.val);
            case 'a'
                apos = tri_send('KBY',0,103,0,0);
                str = sprintf('A = %+2.2f deg',apos.val);
        end
        fprintf(sb_server,str);
        
    case 'D'        % Set base directory...
        global datadir;
        newdir = s(2:end);
        h = findobj(scanbox_h,'Tag','dirname');
        set(h,'String',newdir);
        datadir = newdir;
        
    case 'm'
        val = double(s(2)=='1');
        h = findobj(scanbox_h,'Tag','camerabox');
        set(h,'Value',str2double(val));
        f = get(h,'Callback');
        f(h,guidata(h));
        
    case 'r'        % SLM radius
        h = findobj(scanbox_h,'Tag','slmradius');
        h.String = s(2:end);
        
    case 'p'        % SLM pulse
        h = findobj(scanbox_h,'Tag','slmpulse');
        h.String = s(2:end);
        
    case 's'        % SLM stimulate
        h = findobj(scanbox_h,'Tag','slmstim');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the slm stim button.... 
        
    case 'l'        % slm laser power
        val = str2double(s(2:end));
        h = findobj(scanbox_h,'Tag','slmpower');
        h.Value = val;
        
    case 'h'        % slm phase - compute slm phase
        val = str2double(s(2:end));
        h = findobj(scanbox_h,'Tag','phase');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the slm stim button....   
        
    case 'i'        % select roi
        val = str2double(s(2:end));
        h = findobj(scanbox_h,'Tag','blist');
        h.Value = val;
        f = get(h,'Callback');
        f(h,guidata(h));  % select the cell with index val
        
    case 'e'        % trigger LED protocol
        h = findobj(scanbox_h,'Tag','ledstimtrig');
        f = get(h,'Callback');
        f(h,guidata(h));  % select the cell with index val
        
end

% WindowAPI(handles.scanbox_fig,'setfocus');


% --- Executes on key press with focus on scanboxfig or any of its controls.
function scanboxfig_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to scanboxfig (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)

% global motormode;
%
% if(ischar(eventdata))
%     sel = eventdata;
% else
%     sel = eventdata.Character;
% end
%
% switch sel
%     case 'a'
%         handles.rotated.Value = 3-handles.rotated.Value;
%         motormode = handles.rotated.Value;
%     case 'b'
%         handles.popupmenu3.Value = 1+ mod(handles.popupmenu3.Value,3);
%         popupmenu3_Callback(handles.popupmenu3,[],handles);
%     otherwise
% end
%
% drawnow;


function frate_Callback(hObject, eventdata, handles)
% hObject    handle to frate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frate as text
%        str2double(get(hObject,'String')) returns contents of frate as a double


global nlines sbconfig scanmode;

frate = str2num(get(hObject,'String'));

if(isempty(frate))
    warndlg('Frame rate must be a number.  Resetting to 10fps');
    frate = 10;
    set(hObject,'String','10.0');
end

nlines = round(sbconfig.resfreq/frate)*(2-scanmode);
sb_setline(nlines);
set(handles.lines,'String',num2str(nlines));
frame_rate = sbconfig.resfreq/nlines;
set(handles.frate,'String',sprintf('%2.2f',frame_rate));


% --- Executes during object creation, after setting all properties.
function frate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function low1_Callback(hObject, eventdata, handles)
% hObject    handle to low1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    gencm(low,high,gamma);
end


% --- Executes during object creation, after setting all properties.
function low1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to low1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function high1_Callback(hObject, eventdata, handles)
% hObject    handle to high1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    gencm(low,high,gamma);
end

% --- Executes during object creation, after setting all properties.
function high1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to high1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function gamma1_Callback(hObject, eventdata, handles)
% hObject    handle to gamma1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


global cm;

if(get(handles.pmtdisp,'Value')==4)
    
    low = get(handles.low,'Value');
    high = get(handles.high,'Value');
    gamma = get(handles.gamma,'Value');
    
    gencm(low,high,gamma);
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    appendcm(low,high,gamma);
    
else
    
    low = get(handles.low1,'Value');
    high = get(handles.high1,'Value');
    gamma = get(handles.gamma1,'Value');
    
    gencm(low,high,gamma);
end



% --- Executes during object creation, after setting all properties.
function gamma1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gamma1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function messages_Callback(hObject, eventdata, handles)
% hObject    handle to messages (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of messages as text
%        str2double(get(hObject,'String')) returns contents of messages as a double


% --- Executes during object creation, after setting all properties.
function edit28_CreateFcn(hObject, eventdata, handles)
% hObject    handle to messages (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function pmt1_Callback(hObject, eventdata, handles)
% hObject    handle to pmt1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

sb_gain1(uint8(255*get(hObject,'Value')));
set(handles.pmt1txt,'String',sprintf('%1.2f',get(hObject,'Value')));

% --- Executes during object creation, after setting all properties.
function pmt1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function pmt0_Callback(hObject, eventdata, handles)
% hObject    handle to pmt0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

sb_gain0(uint8(255*get(hObject,'Value')));
set(handles.pmt0txt,'String',sprintf('%1.2f',get(hObject,'Value')));


% --- Executes during object creation, after setting all properties.
function pmt0_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt0 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function edit29_Callback(hObject, eventdata, handles)
% hObject    handle to pmt0txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pmt0txt as text
%        str2double(get(hObject,'String')) returns contents of pmt0txt as a double


% --- Executes during object creation, after setting all properties.
function pmt0txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt0txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit30_Callback(hObject, eventdata, handles)
% hObject    handle to pmt1txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pmt1txt as text
%        str2double(get(hObject,'String')) returns contents of pmt1txt as a double


% --- Executes during object creation, after setting all properties.
function pmt1txt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pmt1txt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pmtenable.
function pmtenable_Callback(hObject, eventdata, handles)
% hObject    handle to pmtenable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of pmtenable

if(get(hObject,'Value'))
    set(handles.pmt0,'Enable','on');
    set(handles.pmt1,'Enable','on');
    pmt0_Callback(handles.pmt0, [], handles);
    pmt1_Callback(handles.pmt1, [], handles);
else
    set(handles.pmt0,'Enable','off');
    set(handles.pmt1,'Enable','off');
    sb_gain0(0);
    sb_gain1(0);
end


% --- Executes on button press in wc.
function wc_Callback(hObject, eventdata, handles)
% hObject    handle to wc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of wc


% configureLSB

function Configure_TTL


%
%     // Select output for LSB[0]
%     // REG_29[13..12] = 0 ==> LSB[0] = '0'  (default)
%     // REG_29[13..12] = 1 ==> LSB[0] = EXT TRIG input
%     // REG_29[13..12] = 2 ==> LSB[0] = AUX_IN[0] input
%     // REG_29[13..12] = 3 ==> LSB[0] = AUX_IN[1] input
%  
%     // select output for LSB[1]:
%     // REG_29[15..14] = 0 ==> LSB[1] = '0'  (default)
%     // REG_29[15..14] = 1 ==> LSB[1] = EXT TRIG input
%     // REG_29[15..14] = 2 ==> LSB[1] = AUX_IN[0] input
%     // REG_29[15..14] = 3 ==> LSB[1] = AUX_IN[1] input


global boardHandle;

v = libpointer('uint32Ptr',1); % value of register
newv = uint(32);               % new value...

retCode =  calllib('ATSApi', 'AlazarReadRegister', boardHandle, uint32(29), v, uint32(hex2dec('32145876')));

if (retCode ~= ApiSuccess)
    error('In AlazarReadRegister()');
end

newv = uint32(bin2dec(['1110' dec2bin(v.Value,14)]));       % write 11 10 means 3 2 -> LSB[1]= AUX_IN[1] and LSB[0] = AUX_IN[0]

retCode =  calllib('ATSApi', 'AlazarWriteRegister', boardHandle, uint32(29), newv, uint32(hex2dec('32145876')));

if (retCode ~= ApiSuccess)
    error('In AlazarWriteRegister()');
end


% --- Executes on slider movement.
function slider27_Callback(hObject, eventdata, handles)
% hObject    handle to slider27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider27_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider27 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider28_Callback(hObject, eventdata, handles)
% hObject    handle to slider28 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider28_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider28 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on selection change in popupmenu13.
function popupmenu13_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu13 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu13


% --- Executes during object creation, after setting all properties.
function popupmenu13_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit31_Callback(hObject, eventdata, handles)
% hObject    handle to edit31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit31 as text
%        str2double(get(hObject,'String')) returns contents of edit31 as a double




% --- Executes during object creation, after setting all properties.
function edit31_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit31 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit32_Callback(hObject, eventdata, handles)
% hObject    handle to edit32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit32 as text
%        str2double(get(hObject,'String')) returns contents of edit32 as a double



% --- Executes during object creation, after setting all properties.
function edit32_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit32 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit33_Callback(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit33 as text
%        str2double(get(hObject,'String')) returns contents of edit33 as a double



% --- Executes during object creation, after setting all properties.
function edit33_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit33 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on slider movement.
function ot_slider_Callback(hObject, eventdata, handles)
% hObject    handle to ot_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function ot_slider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ot_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in pushbutton51.
function pushbutton51_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton51 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global wcam wcam_roi;
wcam.ROIPosition = wcam_roi;
preview(wcam);


% --- Executes on key press with focus on expt and none of its controls.
function expt_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to expt (see GCBO)
% eventdata  structure with the following fields (see UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on slider movement.
function dalsa_exposure_Callback(hObject, eventdata, handles)
% hObject    handle to dalsa_exposure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global dalsa_src sbconfig;  % can only be called is dalsa is in preview mode...

% dalsa_src.ExposureTimeRaw = dalsa_src.MaxExposure * hObject.Value;

eval(sprintf('%s_me(%f)',sbconfig.pathcamera,hObject.Value));   % max exposure camera



% --- Executes during object creation, after setting all properties.
function dalsa_exposure_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dalsa_exposure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function dalsa_gain_Callback(hObject, eventdata, handles)
% hObject    handle to dalsa_gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% global dalsa dalsa_src img0_h;  % can only be called is dalsa is in preview mode...
%
% closepreview(dalsa);
% %dalsa_src.GainRaw = get(hObject,'Value');
% dalsa_src.DigitalGainAll = get(hObject,'Value');
% preview(dalsa,img0_h);


% --- Executes during object creation, after setting all properties.
function dalsa_gain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dalsa_gain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider34_Callback(hObject, eventdata, handles)
% hObject    handle to slider34 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global dalsa dalsa_src img0_h;  % can only be called is dalsa is in preview mode...

% closepreview(dalsa);
% dalsa_src.AcquisitionFrameRateAbs = get(hObject,'Value');
% preview(dalsa,img0_h);



% --- Executes during object creation, after setting all properties.
function slider34_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider34 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


function c=scanbox_getconfig

global scanbox_h sbconfig;

c.wavelength = str2num(get(findobj(scanbox_h,'Tag','wavelength'),'String'));
c.frames = str2num(get(findobj(scanbox_h,'Tag','frames'),'String'));
c.lines = str2num(get(findobj(scanbox_h,'Tag','lines'),'String'));
c.magnification = get(findobj(scanbox_h,'Tag','magnification'),'Value');
c.magnification_list = get(findobj(scanbox_h,'Tag','magnification'),'String');
c.pmt0_gain = get(findobj(scanbox_h,'Tag','pmt0'),'Value');
c.pmt1_gain = get(findobj(scanbox_h,'Tag','pmt1'),'Value');

if (sbconfig.tri_knob_ver>1)
    zpos = tri_send('KBY',0,100,0,0);
    ypos = tri_send('KBY',0,101,0,0);
    xpos = tri_send('KBY',0,102,0,0);
    apos = tri_send('KBY',0,103,0,0);
    
    c.knobby.pos.x = xpos.val;
    c.knobby.pos.y = ypos.val;
    c.knobby.pos.z = zpos.val;
    c.knobby.pos.a = apos.val;
    
    c.knobby.schedule = get(findobj(scanbox_h,'Tag','knobby_table'),'Data');
end



% c.zstack.top = get(findobj(scanbox_h,'Tag','z_top'),'String');
% c.zstack.bottom = get(findobj(scanbox_h,'Tag','z_top'),'String');
% c.zstack.steps = get(findobj(scanbox_h,'Tag','z_steps'),'String');
% c.zstack.size = get(findobj(scanbox_h,'Tag','z_size'),'String');

% --- Executes on button press in autoillum.
function autoillum_Callback(hObject, eventdata, handles)
% hObject    handle to autoillum (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function z_top_Callback(hObject, eventdata, handles)
% hObject    handle to z_top (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_top as text
%        str2double(get(hObject,'String')) returns contents of z_top as a double

global z_top z_bottom z_steps z_size z_vals;

z_top = str2num(get(hObject,'String'));

if(isempty(z_top))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_top = 0;
    set(hObject,'String','0');
end

z_vals = linspace(z_bottom,z_top,z_steps);
z_size = mean(diff(z_vals));
set(handles.z_size,'String',num2str(z_size));

% --- Executes during object creation, after setting all properties.
function z_top_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_top (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_bottom_Callback(hObject, eventdata, handles)
% hObject    handle to z_bottom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_bottom as text
%        str2double(get(hObject,'String')) returns contents of z_bottom as a double

global z_top z_bottom z_steps z_size z_vals;

z_bottom = str2num(get(hObject,'String'));

if(isempty(z_bottom))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_bottom = 0;
    set(hObject,'String','0');
end

z_vals = linspace(z_top,z_bottom,z_steps);
z_size = mean(diff(z_vals));
set(handles.z_size,'String',num2str(z_size));



% --- Executes during object creation, after setting all properties.
function z_bottom_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_bottom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_steps_Callback(hObject, eventdata, handles)
% hObject    handle to z_steps (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_steps as text
%        str2double(get(hObject,'String')) returns contents of z_steps as a double

global z_top z_bottom z_steps z_size z_vals;

z_steps = str2num(get(hObject,'String'));

if(isempty(z_steps))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_bottom = 0;
    set(hObject,'String','0');
end


z_vals = linspace(z_top,z_bottom,z_steps);
z_size = mean(diff(z_vals));
set(handles.z_size,'String',num2str(z_size));


% --- Executes during object creation, after setting all properties.
function z_steps_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_steps (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_size_Callback(hObject, eventdata, handles)
% hObject    handle to z_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of z_size as text
%        str2double(get(hObject,'String')) returns contents of z_size as a double

global z_top z_bottom z_steps z_size z_vals;

z_size = str2num(get(hObject,'String'));

if(isempty(z_size))
    warndlg('Parameter should be a number.  Resetting to zero.')
    z_size = 0;
    set(hObject,'String','0');
end

z_vals = z_top:z_size:z_bottom;
set(handles.z_steps,'String',length(z_vals));


% --- Executes during object creation, after setting all properties.
function z_size_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_size (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton53.
function pushbutton53_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton53 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in pushbutton54.
function pushbutton54_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton54 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global z_top z_bottom z_steps z_size z_vals;
global motor_gain origin scanbox_h;
global experiment zstack_running motormode thpos_h dmpos zpos_h xpos_h ypos_h;

if(zstack_running)
    
    h = findobj(scanbox_h,'Tag','grabb');
    f = get(h,'Callback');
    f(h,guidata(h));  % press the grab button to abort...
    zstack_running = 0;
    set(hObject,'String','Acquire');
    drawnow;
    
else
    
    set(hObject,'String','Stop');
    drawnow;
    
    zstack_running = 1;
    
    z_vals = linspace(z_top,z_bottom,z_steps);
    
    if(~isempty(z_vals) && ~any(isnan(z_vals)))
        
        z_vals = [z_vals(1) diff(z_vals)];  % the differences...
        
        for(val=z_vals)
            
            if(zstack_running)
                %move the z-motor relative to the beginning...
                
                switch motormode
                    
                    case 1  % moves only in z (normal mode)
                        
                        valz = round(val/motor_gain(1));
                        r=tri_send('MVP',1,0,valz);
                        
                    case 2
                        
                        thval = str2double(thpos_h.String);
                        
                        valz = round( val/motor_gain(1))*cosd(thval);
                        r=tri_send('MVP',1,0,valz);
                        
                        valx = round(-val/motor_gain(3))*sind(thval);
                        r=tri_send('MVP',1,2,valx);
                        
                end
                
                pause(.5);                      % update reading
                
                v = zeros(1,4);
                for(i=3:-1:0)                   % let z be the last axis...
                    r = tri_send('GAP',1,i,0);
                    dmpos(i+1) = r.value;
                    v(i+1) =  motor_gain(i+1) * double(r.value-origin(i+1));  %%  (inches/rot) / (steps/rot) * 25400um
                end
                
                zpos_h.String=sprintf('%.2f',v(1));
                ypos_h.String=sprintf('%.2f',v(2));
                xpos_h.String=sprintf('%.2f',v(3));
                thpos_h.String=sprintf('%.2f',v(4));
                
                drawnow;
                
                %scan
                h = findobj(scanbox_h,'Tag','grabb');
                f = get(h,'Callback');
                f(h,guidata(h));  % press the grab button....
                
                % update file number - done by autoinc now...
                
            end
            
        end
        
    end
    
    % Done!
    zstack_running = 0;
    set(hObject,'String','Acquire');
    drawnow;
    
end


% --- Executes on button press in eyet.
function eyet_Callback(hObject, eventdata, handles)
% hObject    handle to eyet (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of eyet


% --- Executes on button press in pushbutton55.
function pushbutton55_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton55 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global eyecam eyecam_h eye_roi;

eyecam.ROIPosition = eye_roi;
eyecam_h = preview(eyecam);
colormap(ancestor(eyecam_h,'axes'),sqrt(gray(256)));


% --- Executes on button press in pushbutton56.
function pushbutton56_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton56 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global eyecam eyecam_h eye_roi;

closepreview(eyecam);
eyecam.ROIPosition = [0 0 eyecam.VideoResolution];
eye_roi = eyecam.ROIPosition;
start(eyecam);
pause(0.5);
stop(eyecam);
q = peekdata(eyecam,1);
figure('MenuBar','none','ToolBar','none','Name','Set ROI','NumberTitle','off');
imagesc(q); colormap(sqrt(gray(256))); axis off; truesize;

h = imrect(gca,[eyecam.VideoResolution/2-[160 112]/2 160 112]);
h.setFixedAspectRatioMode(true);
h.setResizable(false);
eyecam.ROIPosition = wait(h);
eye_roi = eyecam.ROIPosition;
close(gcf);
eyecam_h = preview(eyecam);
colormap(ancestor(eyecam_h,'axes'),sqrt(gray(256)));

% --- Executes on button press in pushbutton57.
function pushbutton57_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton57 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global eyecam eyecam_h eye_roi;
closepreview(eyecam);
eyecam.ROIPosition = [0 0 eyecam.VideoResolution];
eye_roi = eyecam.ROIPosition;
eyecam_h = preview(eyecam);
colormap(ancestor(eyecam_h,'axes'),sqrt(gray(256)));


% --- Executes on slider movement.
function slider40_Callback(hObject, eventdata, handles)
% hObject    handle to slider40 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global wcam wcam_src;

closepreview(wcam);
wcam_src.Exposure = get(hObject,'Value');
preview(wcam);



% --- Executes during object creation, after setting all properties.
function slider40_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider40 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in pushbutton58.
function pushbutton58_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton58 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global wcam wcam_h wcam_roi;

closepreview(wcam);
wcam.ROIPosition = [0 0 wcam.VideoResolution];
wcam_roi = wcam.ROIPosition;
start(wcam);
pause(0.5);
stop(wcam);
q = peekdata(wcam,1);
figure('MenuBar','none','ToolBar','none','Name','Set ROI','NumberTitle','off');
imagesc(q); colormap(sqrt(gray(256))); axis off; truesize;
h = imrect(gca,[wcam.VideoResolution/2-[192 192]/2 192 192]);
h.setFixedAspectRatioMode(true);
h.setResizable(false);
wcam.ROIPosition = wait(h);
wcam_roi = wcam.ROIPosition;
close(gcf);
wcam_h = preview(wcam);
colormap(ancestor(wcam_h,'axes'),sqrt(gray(256)));


% --- Executes on button press in pushbutton59.
function pushbutton59_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton59 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global wcam wcam_h wcam_roi;
closepreview(wcam);
wcam.ROIPosition = [0 0 wcam.VideoResolution];
wcam_roi = wcam.ROIPosition;
wcam_h = preview(wcam);
colormap(ancestor(wcam_h,'axes'),sqrt(gray(256)));


% --- Executes during object creation, after setting all properties.
function lstatus_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lstatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global lstatus;
lstatus = hObject;


% --- Executes on button press in ttlonline.
function ttlonline_Callback(hObject, eventdata, handles)
% hObject    handle to ttlonline (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ttlonline

global ttlonline;

ttlonline = get(hObject,'Value');


% --- Executes on button press in pushbutton60.
function pushbutton60_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton60 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{1} = dmpos;

% for(i=0:3)
%     tri_send('CCO',11,i,0);
% end



% --- Executes on button press in pushbutton61.
function pushbutton61_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton61 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{1}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;


for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{1};
update_pos;


% --- Executes on button press in pushbutton62.
function pushbutton62_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton62 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{2} = dmpos;

% for(i=0:3)
%     tri_send('CCO',12,i,0);
% end

% --- Executes on button press in pushbutton63.
function pushbutton63_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton63 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{2}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;

for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{2};
update_pos;


% --- Executes on button press in pushbutton64.
function pushbutton64_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton64 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{3} = dmpos;

% for(i=0:3)
%     tri_send('CCO',13,i,0);
% end

% --- Executes on button press in pushbutton65.
function pushbutton65_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton65 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{3}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;

for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{3};
update_pos;


% --- Executes on button press in pushbutton66.
function pushbutton66_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton66 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dmpos mpos;
mpos{4} = dmpos;

% for(i=0:3)
%     tri_send('CCO',14,i,0);
% end

% --- Executes on button press in pushbutton67.
function pushbutton67_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton67 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global mpos dmpos;

for(i=0:3)
    tri_send('SCO',0,i,mpos{4}(i+1));
end

v = zeros(4,2);

for(i=0:3)                      % current vel and acc
    r1 = tri_send('GAP',4,i,0);
    r2 = tri_send('GAP',5,i,0);
    v(i+1,1) = r1.value;
    v(i+1,2) = r2.value;
    tri_send('SAP',4,i,1200);
    tri_send('SAP',5,i,275);
end

tri_send('MVP',2,hex2dec('8f'),0);

set(hObject,'ForegroundColor',[1 0 0]);
drawnow;
st = 0;                         % wait for movement to finish
while(st==0)
    st = 1;
    for(i=0:3)
        r = tri_send('GAP',8,i,0);
        st = st * r.value;
    end
end
set(hObject,'ForegroundColor',[0 0 0]);
drawnow;

for(i=0:3)
    r1 = tri_send('SAP',4,i,v(i+1,1));
    r2 = tri_send('SAP',5,i,v(i+1,2));
end

dmpos = mpos{4};
update_pos;




function update_pos

global dmpos motor_gain origin scanbox_h;

mname = {'zpos','ypos','xpos','thpos'};
v = zeros(1,4);

for(i=0:3)
    v(i+1) =  motor_gain(i+1) * double(dmpos(i+1)-origin(i+1));  %%  (inches/rot) / (steps/rot) * 25400um
end

for(i=0:3)
    h = findobj(scanbox_h,'Tag',mname{i+1});
    set(h,'String',sprintf('%.2f',v(i+1)));
    drawnow;
end




% --- Executes on button press in pushbutton68.
function pushbutton68_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton68 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global origin dmpos

for(i=0:2)
    r = tri_send('GAP',1,i,0);
    origin(i+1) = r.value;
end

dmpos(1:3) = origin(1:3);
update_pos;


% --- Executes on button press in text76.
function text76_Callback(hObject, eventdata, handles)
% hObject    handle to text76 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in text77.
function text77_Callback(hObject, eventdata, handles)
% hObject    handle to text77 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on selection change in alist.
function listbox6_Callback(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns alist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from alist


% --- Executes during object creation, after setting all properties.
function listbox6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to alist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in blist.
function blist_Callback(hObject, eventdata, handles)
% hObject    handle to blist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns blist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from blist

global cellpoly slmimg sbconfig cellphase

if(sbconfig.slm)
    idx = str2double(handles.blist.String{handles.blist.Value});
    slmimg.CData = cellphase{idx};
    heds_show_data(uint8(slmimg.CData));
end

cellfun(@(x) set(x,'EdgeColor',[1 1 1],'LineWidth',1,'FaceAlpha',0.4,'FaceColor',[1 1 1]),cellpoly);
try
    idx = str2num(hObject.String{hObject.Value});
    cellpoly{idx}.FaceAlpha = .9;
    cellpoly{idx}.FaceColor = [1 .5 .5];
catch
end

% --- Executes during object creation, after setting all properties.
function blist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to blist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject,'String',{},'Value',0);


% --- Executes on button press in deletecell.
function deletecell_Callback(hObject, eventdata, handles)
% hObject    handle to deletecell (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ncell cellpoly;

l = get(handles.alist,'String');
v = get(handles.alist,'Value');
if(v>0)
    j = str2num(l{v});
    delete(cellpoly{j});
    cellpoly{j} = [];
    l(v) = [];
    set(handles.alist,'String',l,'Value',min(v,length(l)));
end

% --- Executes on button press in alla2b.
function alla2b_Callback(hObject, eventdata, handles)
% hObject    handle to alla2b (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(la)>0)
    lb = {lb{:} la{:}};
    la = {};
    set(handles.alist,'String',{},'Value',0);
    vb = length(lb);
    set(handles.blist,'String',lb,'Value',length(lb));
end





% --- Executes on button press in a2b.
function a2b_Callback(hObject, eventdata, handles)
% hObject    handle to a2b (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(la)>0)
    lb{end+1} = la{va};    % append
    
    la(va) = [];
    set(handles.alist,'String',la,'Value',min(va,length(la)));
    
    vb = length(lb);
    set(handles.blist,'String',lb,'Value',length(lb));
end


% --- Executes on button press in b2a.
function b2a_Callback(hObject, eventdata, handles)
% hObject    handle to b2a (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(lb)>0)
    la{end+1} = lb{vb};    % append
    
    lb(vb) = [];
    set(handles.blist,'String',lb,'Value',min(vb,length(lb)));
    
    va = length(la);
    set(handles.alist,'String',la,'Value',length(la));
end

% --- Executes on button press in addtoa.
function addtoa_Callback(hObject, eventdata, handles)
% hObject    handle to addtoa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ncell cellpoly sbconfig;

% h = imfreehand(handles.image0);
% h.setColor([.5 1 0]);

h = imfreehand(handles.image0);
xy = h.getPosition;
delete(h);
h = patch(xy(:,1),xy(:,2),'w','facealpha',0.4,'edgecolor',[1 1 1],'parent',handles.image0,'FaceLighting','none');


l = get(handles.alist,'String');
if(isempty(l))
    ncell = ncell+1;
    l = {num2str(ncell)};
    cellpoly{ncell} = h;
else
    ncell = ncell+1;
    l = {l{:} num2str(ncell)};
    cellpoly{ncell} = h;
end
set(handles.alist,'String',l,'Value',length(l));


% --- Executes on button press in allb2a.
function allb2a_Callback(hObject, eventdata, handles)
% hObject    handle to allb2a (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

la = get(handles.alist,'String');
va = get(handles.alist,'Value');

lb = get(handles.blist,'String');
vb = get(handles.blist,'Value');

if(length(lb)>0)
    la = {la{:} lb{:}};
    lb = {};
    set(handles.blist,'String',{},'Value',0);
    
    va = length(la);
    set(handles.alist,'String',la,'Value',length(la));
end


% --- Executes during object creation, after setting all properties.
function addtoa_CreateFcn(hObject, eventdata, handles)
% hObject    handle to addtoa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in mmap.
function mmap_Callback(hObject, eventdata, handles)
% hObject    handle to mmap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of mmap



% --- Executes on button press in networkstream.
function networkstream_Callback(hObject, eventdata, handles)
% hObject    handle to networkstream (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of networkstream

global stream_udp sbconfig;

if(get(hObject,'Value'))
    try
        stream_udp  = udp(sbconfig.stream_host, 'RemotePort', sbconfig.stream_port);
        fopen(stream_udp);
    catch
        warndlg('Connection refused. Check network parameters.','scanbox');
        set(hObject,'Value',0);
        delete(stream_udp);
        stream_udp = [];
    end
else
    try
        fclose(stream_udp);
        stream_udp = [];
    catch
    end
end



% --- Executes on button press in dellall.
function dellall_Callback(hObject, eventdata, handles)
% hObject    handle to dellall (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ncell cellpoly roi_traces_h;

ncell = 0;
cellfun(@delete,cellpoly);
cellpoly = {};
set(handles.alist,'String',{},'Value',0);
set(handles.blist,'String',{},'Value',0);
delete(roi_traces_h.Children);


function edit38_Callback(hObject, eventdata, handles)
% hObject    handle to edit38 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit38 as text
%        str2double(get(hObject,'String')) returns contents of edit38 as a double


% --- Executes during object creation, after setting all properties.
function edit38_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit38 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in stabilize.
function stabilize_Callback(hObject, eventdata, handles)
% hObject    handle to stabilize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of stabilize

global ref_img

if(get(hObject,'Value')==1)
    if(isempty(ref_img))
        warndlg('First define a reference image by accumulating during times of no relative movement.','scanbox');
        set(hObject,'Value',0);
    end
else
    % ref_img = [];
end

% --- Executes on button press in pushbutton76.
function pushbutton76_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton76 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global ref_img img0_h ref_img_fft xref yref ref_th sbconfig;
global gData gtime scanmode;


% set reference

if(gtime<10)
    warndlg('Please collect a longer sequence to define a reference image','scanbox');
    ref_img = [];
    return;
end


% mm = mean(gData(1:gtime,:,:),1);
% ss = std(gData(1:gtime,:,:),[],1);
% cv = mm./ss;
% Mx = max(cv(:));
% Mm = min(cv(:));
% ref_img = squeeze(gather((cv-Mm)/(Mx-Mm)));
% set(img0_h,'Cdata',uint8(255*ref_img));

mm = squeeze(mean(gData(1:gtime,:,:),1));
if(scanmode==0)
    mm(:,1:sbconfig.margin) = NaN;
    mm(:,end-sbconfig.margin:end) = NaN;
end
Mx = max(mm(:));
Mm = min(mm(:));
if(scanmode==0)
    mm(:,1:sbconfig.margin) = Mx;
    mm(:,end-sbconfig.margin:end) = Mx;
end
ref_img = squeeze(gather((mm-Mm)/(Mx-Mm)));
img0_h.CData(:,:,2) = 255-uint8(255*ref_img);
img0_h.CData(:,:,1) = 0;

R = cell(1,sbconfig.nroi_auto);
pos = zeros(sbconfig.nroi_auto,4);
theSize = sbconfig.nroi_auto_size(handles.magnification.Value);

for(i=1:sbconfig.nroi_auto)
    h = imrect(handles.image0,theSize*[1 1 1 1]);
    h.setFixedAspectRatioMode(true);
    h.setResizable(false);
    R{i} = h;
    pos(i,:) = wait(h);
end
pos = round(pos(:,1:2) + pos(:,3:4)/2);

for(i=1:length(R))
    delete(R{i});
end

ref_img_fft = cell(1,length(sbconfig.nroi_auto));
ref_th = zeros(1,length(sbconfig.nroi_auto));
xref = zeros(sbconfig.nroi_auto,theSize);
yref = zeros(sbconfig.nroi_auto,theSize);

for(i=1:sbconfig.nroi_auto)
    yref(i,:) = pos(i,2)- theSize/2 + 1 : pos(i,2) + theSize/2;
    xref(i,:) = pos(i,1)- theSize/2 + 1 : pos(i,1) + theSize/2;
    rsub = ref_img(yref(i,:),xref(i,:));
    ref_img_fft{i} = fft2(rot90(rsub,2));
end


% --- Executes during object creation, after setting all properties.
function mmap_CreateFcn(hObject, eventdata, handles)
% hObject    handle to mmap (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function networkstream_CreateFcn(hObject, eventdata, handles)
% hObject    handle to networkstream (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


%-------------------------------------------------------------------------
function [] = wrap_cb()
% wrap_cb.m--Callback for "wrap" dial.
%-------------------------------------------------------------------------

wrapDial = dial.find_dial('wrapDial','-1');
dialVal = round(get(wrapDial,'Value'))


function [u,v] = fftalignauto(A)

global ref_img_fft xref yref ref_th sbconfig

u = zeros(1,sbconfig.nroi_auto);
v = zeros(1,sbconfig.nroi_auto);
N = sbconfig.roi_auto_size;

for(k=1:sbconfig.nroi_auto)
    C = fftshift(real(ifft2(fft2(A(yref(k,:),xref(k,:))).*ref_img_fft{k})));
    [~,i] = max(C(:));
    [ii jj] = ind2sub(size(C),i);
    u(k) = N/2-ii;
    v(k) = N/2-jj;
end


% --- Executes on button press in segment.
function segment_Callback(hObject, eventdata, handles)
% hObject    handle to segment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of segment

global scanbox_h img0_h gData gtime me va ku corrmap th_corr th_txt oldCData

if(get(hObject,'Value'))
    
    me = mean(gData(1:gtime,:,:),1);
    gData = bsxfun(@minus,gData(1:gtime,:,:),me);
    va = mean(gData(1:gtime,:,:).^2,1);
    gData = bsxfun(@rdivide,gData(1:gtime,:,:),sqrt(va));
    ku = mean(gData(1:gtime,:,:).^4,1)-3;
    
    corrmap = zeros([size(gData,2) size(gData,3)],'single','gpuArray');
    
    for(m=-1:1)
        for(n=-1:1)
            if(m~=0 || n~=0)
                corrmap = corrmap+squeeze(sum(gData(1:gtime,:,:).*circshift(gData(1:gtime,:,:),[0 m n]),1));
            end
        end
    end
    corrmap = corrmap/8/gtime;
    oldCData = img0_h.CData;
    
    qq = zeros([size(corrmap) 3]);
    qq(:,:,1) = adapthisteq(gather(corrmap));
    img0_h.CData = uint8(255*qq);
    
    global th_corr;
    th_corr = 0.2;
    th_txt = text(.05,.1,sprintf('%1.2f',th_corr),'color','w','fontsize',14,'parent',handles.image0,'units','normalized');
    
    set(scanbox_h,'WindowButtonMotionFcn',@wbmcb)
    set(scanbox_h,'WindowScrollWheelFcn',@wswcb)
    set(scanbox_h,'WindowButtonDownFcn',@wbdcb)
else
    set(scanbox_h,'WindowButtonMotionFcn',[])
    set(scanbox_h,'WindowScrollWheelFcn',[])
    set(scanbox_h,'WindowButtonDownFcn',[])
    delete(th_txt);
    img0_h.CData = oldCData;
    drawnow;
    
end


% --- Executes on selection change in reftype.
function reftype_Callback(hObject, eventdata, handles)
% hObject    handle to reftype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns reftype contents as cell array
%        contents{get(hObject,'Value')} returns selected item from reftype


% --- Executes during object creation, after setting all properties.
function reftype_CreateFcn(hObject, eventdata, handles)
% hObject    handle to reftype (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton78.
function pmtzero_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton78 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

set(handles.pmt0,'Value',0);
set(handles.pmt1,'Value',0);
set(handles.pmt0txt,'String','0.00');
set(handles.pmt1txt,'String','0.00');
sb_gain0(0);
sb_gain1(0);


% --- Executes on button press in stimmark.
function stimmark_Callback(hObject, eventdata, handles)
% hObject    handle to stimmark (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of stimmark


% --- Executes during object creation, after setting all properties.
function segment_CreateFcn(hObject, eventdata, handles)
% hObject    handle to segment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global segment_h;

segment_h = hObject;


% --- Executes on slider movement.
function pockval_Callback(hObject, eventdata, handles)
% hObject    handle to pockval (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

sb_pockels(0,uint8(get(hObject,'Value')));
handles.powertxt.String = sprintf('%3d%%',round(hObject.Value/255.0*100));



% --- Executes during object creation, after setting all properties.
function pockval_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pockval (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global laserpower_h

laserpower_h = hObject;


% --- Executes on button press in quadcheck.
function quadcheck_Callback(hObject, eventdata, handles)
% hObject    handle to quadcheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of quadcheck


function mousedrv_cb(obj,b,varargin)

global motorstate motormode xpos_h ypos_h zpos_h thpos_h dmpos origin motor_gain nroi motorlock_h stabilize_h mstep


if(motorlock_h.Value==0)
    
    stabilize_h.Value = 0;   % stop stabilizing if you move motors...
    nroi = 0;                % in case real time was showing -- shut it down
    
    thval = str2double(thpos_h.String);
    
    newstate = [obj.Sen.Translation.Y -obj.Sen.Translation.Z obj.Sen.Translation.X ];
    newstate  = [(abs(newstate)>500).*sign(newstate) -sign(obj.Sen.Rotation.Y)*(obj.Sen.Rotation.Angle>250)];
    
    j = find(newstate ~= motorstate);
    
    if(~isempty(j))     % state changed
        
        switch motormode
            
            case 1
                
                for(i=j)
                    r = tri_send('ROR',0,i-1,newstate(i)*mstep(i));   % fix each axis that changed...
                end
                
            case 2
                
                for(i=j)
                    switch(i)
                        case 1
                            tri_send('ROR',0,0,newstate(i)*mstep(1)*cosd(thval));
                            tri_send('ROR',0,2,-newstate(i)*mstep(3)*sind(thval));
                        case 3
                            tri_send('ROR',0,0,newstate(i)*mstep(1)*sind(thval));
                            tri_send('ROR',0,2,newstate(i)*mstep(3)*cosd(thval));
                        otherwise
                            tri_send('ROR',0,i-1,newstate(i)*mstep(i));
                    end
                end
                
        end
        
        motorstate = newstate;
        
        % update position reading
        if(all(motorstate==0))
            
            % stop all motors
            %             tri_send('MST',0,0,0);
            %             tri_send('MST',0,1,0);
            %             tri_send('MST',0,2,0);
            %             tri_send('MST',0,3,0);
            
            v = zeros(1,4);
            for(i=3:-1:0)                   % let z be the last axis...
                r = tri_send('GAP',1,i,0);
                dmpos(i+1) = r.value;
                v(i+1) =  motor_gain(i+1) * double(r.value-origin(i+1));  %%  (inches/rot) / (steps/rot) * 25400um
            end
            
            zpos_h.String=sprintf('%.2f',v(1));
            ypos_h.String=sprintf('%.2f',v(2));
            xpos_h.String=sprintf('%.2f',v(3));
            thpos_h.String=sprintf('%.2f',v(4));
            drawnow;
            
        end
        
    end
end



% --- Executes during object creation, after setting all properties.
function motorlock_CreateFcn(hObject, eventdata, handles)
% hObject    handle to motorlock (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global motorlock_h;

motorlock_h = hObject;


% --- Executes during object creation, after setting all properties.
function stabilize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stabilize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

global stabilize_h

stabilize_h = hObject;


% --- Executes on slider movement.
function optoslider_Callback(hObject, eventdata, handles)
% hObject    handle to optoslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global opto2pow sbconfig

sb_current(hObject.Value);

if(isempty(sbconfig.optocal))
    handles.ot_txt.String = sprintf('%04d',floor(hObject.Value));
else
    handles.ot_txt.String = sprintf('%03d',floor(polyval(sbconfig.optocal,hObject.Value)));
end

if(handles.linkcheck.Value)
    handles.pockval.Value = opto2pow(floor(hObject.Value/16)+1); % set value
    pockval_Callback(handles.pockval,[],handles);                % execute callback
end

% --- Executes during object creation, after setting all properties.
function optoslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optoslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in clearoptotable.
function clearoptotable_Callback(hObject, eventdata, handles)
% hObject    handle to clearoptotable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global opto2pow;

opto2pow = [];
handles.linkcheck.Value = 0;    % uncheck the link button
handles.linkcheck.Callback(handles.linkcheck,[]);


% --- Executes on button press in optolink.
function optolink_Callback(hObject, eventdata, handles)
% hObject    handle to optolink (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global opto2pow;

pow = round(handles.pockval.Value);        % 0-255
opto = floor(handles.optoslider.Value/16); % 0-255

pow = min(max(0,pow),255);
opto = min(max(0,opto),255);

opto2pow = [opto2pow ; opto pow];          % add points to the list




% --- Executes on button press in linkcheck.
function linkcheck_Callback(hObject, eventdata, handles)
% hObject    handle to linkcheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of linkcheck


global opto2pow;

if(hObject.Value)
    if(size(opto2pow,2)==2)
        opto2pow = interp1(opto2pow(:,1),opto2pow(:,2),0:255);
        nidx = find(~isnan(opto2pow));
        idx = min(nidx);
        opto2pow(1:idx-1) = opto2pow(idx);
        idx = max(nidx);
        opto2pow(idx+1:end) = opto2pow(idx);
        opto2pow = floor(opto2pow);
    end
    for(i=1:256)
        sb_current_power(i-1,opto2pow(i)); % link current to power
    end
    sb_current_power_active(1);     % active link between current and power
else
    sb_current_power_active(0);
end



function optomin_Callback(hObject, eventdata, handles)
% hObject    handle to optomin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of optomin as text
%        str2double(get(hObject,'String')) returns contents of optomin as a double


% --- Executes during object creation, after setting all properties.
function optomin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optomin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function optoperiod_Callback(hObject, eventdata, handles)
% hObject    handle to optoperiod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of optoperiod as text
%        str2double(get(hObject,'String')) returns contents of optoperiod as a double


% --- Executes during object creation, after setting all properties.
function optoperiod_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optoperiod (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function optomax_Callback(hObject, eventdata, handles)
% hObject    handle to optomax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of optomax as text
%        str2double(get(hObject,'String')) returns contents of optomax as a double


% --- Executes during object creation, after setting all properties.
function optomax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optomax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in optowavestyle.
function optowavestyle_Callback(hObject, eventdata, handles)
% hObject    handle to optowavestyle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns optowavestyle contents as cell array
%        contents{get(hObject,'Value')} returns selected item from optowavestyle


% --- Executes during object creation, after setting all properties.
function optowavestyle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to optowavestyle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in volscan.
function volscan_Callback(hObject, eventdata, handles)
% hObject    handle to volscan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of volscan

global otwave otwave_um;

if(hObject.Value)
    sb_optotune_active(1);
else
    sb_optotune_active(0);
    handles.optoslider.Callback(handles.optoslider,[]); % restore ETL value
end

% --- Executes on button press in pushbutton81.
function pushbutton81_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton81 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global messages captureDone buffersCompleted

r = tri_send('MST',0,4,0);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=0',buffersCompleted);
end


% --- Executes on button press in pushbutton82.
function pushbutton82_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton82 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global messages captureDone buffersCompleted

r = tri_send('ROR',0,4,200);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=1',buffersCompleted);
end

% --- Executes on button press in pushbutton83.
function pushbutton83_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton83 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global messages captureDone buffersCompleted

r = tri_send('ROR',0,4,400);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=2',buffersCompleted);
end


% --- Executes on slider movement.
function dgain_Callback(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function dgain_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global dgain
dgain = hObject;

% --- Executes on slider movement.
function dbias_Callback(hObject, eventdata, handles)
% hObject    handle to dbias (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function dbias_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dbias (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

global dbias
dbias = hObject;



% --- Executes on slider movement.
function slider48_Callback(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider


% --- Executes during object creation, after setting all properties.
function slider48_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dgain (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function notestxt_Callback(hObject, eventdata, handles)
% hObject    handle to notestxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of notestxt as text
%        str2double(get(hObject,'String')) returns contents of notestxt as a double


% --- Executes during object creation, after setting all properties.
function notestxt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to notestxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in unibi.
function unibi_Callback(hObject, eventdata, handles)
% hObject    handle to unibi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanmode sbconfig;

if(strcmp('Unidirectional',hObject.String))
    hObject.String = 'Bidirectional';
    sb_bidirectional;
    scanmode = 0;
else
    hObject.String = 'Unidirectional';
    sb_unidirectional;
    scanmode = 1;
end

frame_rate = sbconfig.resfreq/str2num(handles.lines.String)*(2-scanmode); %% use actual resonant freq...
set(handles.frate,'String',sprintf('%2.2f',frame_rate));

drawnow;


% --- Executes on button press in otupload.
function otupload_Callback(hObject, eventdata, handles)
% hObject    handle to otupload (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global otwave otparam;

% compute and upload table...

m = str2double(handles.optomin.String);
M = str2double(handles.optomax.String);
per = str2double(handles.optoperiod.String);

otparam = [m M per];

switch(handles.optowavestyle.Value)
    
    case 1
        sb_optowave_square(m,M,per);
        
    case 2
        sb_optowave_sawtooth(m,M,per);
        
    case 3
        sb_optowave_triangular(m,M,per);
        
    case 4
        sb_optowave_sine(m,M,per);
end


% --- Executes on button press in pushbutton86.
function pushbutton86_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton86 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global captureDone

r = tri_send('ROR',0,4,-200);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=-1',buffersCompleted);
end

% --- Executes on button press in pushbutton87.
function pushbutton87_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton87 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global captureDone

r = tri_send('ROR',0,4,-400);
if ~captureDone
    messages.String{end+1} = sprintf('*%5d T=-2',buffersCompleted);
end


% --- Executes on button press in arealine.
function arealine_Callback(hObject, eventdata, handles)
% hObject    handle to arealine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global scanmode sbconfig;

if(strcmp('Area',hObject.String))
    hObject.String = 'Line';
    sb_linescan(1);
    handles.image0.Units = 'normalized';
    p = handles.image0.Position;
    global hline scanbox_h
    hline = annotation(scanbox_h,'line',[p(1) p(1)+p(3)],(p(2)+p(4)/2)*ones(1,2));
    hline.Color = [.8 .8 .8];
    hline.LineStyle = '--';
else
    hObject.String = 'Area';
    sb_linescan(0);
    global hline;
    delete(hline);
end
drawnow;

% --- Executes on button press in pushbutton89.
function pushbutton89_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton89 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global scanmode ;

if(strcmp('Normal Resonant',hObject.String))
    hObject.String = 'Continuous Resonant';
    sb_continuous_resonant(1);
else
    hObject.String = 'Normal Resonant';
    sb_continuous_resonant(0);
end

drawnow;

function flipDalsaImg(obj,event,himage)
himage.CData=fliplr(event.Data);


% --- Executes on button press in slmstim.
function slmstim_Callback(hObject, eventdata, handles)
% hObject    handle to slmstim (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmstim

global cellphase cellgain slms slmimg slm

% selected cell is already being shown in SLM phase fig

idx = str2double(handles.blist.String{handles.blist.Value});    % selected cell
g = cellgain(idx);

if(handles.powequal.Value)
    d1 = [-.05 min((handles.slmpower.Value*ones(1,str2double(handles.slmpulse.String)))/g,5) -.05]'; % control laser power
else
    d1 = [-.05 (handles.slmpower.Value*ones(1,str2double(handles.slmpulse.String))) -.05]'; % control laser power
end

d0 = [0 5*ones(1,str2double(handles.slmpulse.String)) 0]'; %signal scanbox we are stimulating

d = [d0 d1];
queueOutputData(slms,double(d));
startBackground(slms);  % send pulse


% --- Executes on button press in slmbox.
function slmbox_Callback(hObject, eventdata, handles)
% hObject    handle to slmbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmbox


% --- Executes on button press in phase.
function phase_Callback(hObject, eventdata, handles)
% hObject    handle to phase (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global cellpoly cellphase nlines sbconfig cellgain scanbox_h slm; %#ok<NUSED>
global slmfig slmimg
hObject.String = 'Wait...'; hObject.ForegroundColor = 'r'; drawnow;

[xh,yh] = meshgrid(1:1920,1:1080); % holoeye size

cellphase = cell(1,length(cellpoly));
cellgain = ones(1,length(cellpoly));
[xx,yy] = meshgrid(1:796,1:str2double(handles.lines.String)); % scan size

for(j=1:length(cellpoly))
    p = cellpoly{j}.Vertices;
    mask = inpolygon(xx,yy,p(:,1),p(:,2));
    [y,x] = find(mask);
    x = mean(x)+ str2double(handles.slmx.String);     % center of mass + offsets
    y = mean(y)+ str2double(handles.slmy.String);
    x = x/796;       %normalized coordinates
    y = y/str2double(handles.lines.String);
    x = x*slm.rwidth; % match to scan size
    y = y*slm.rheight;
    vp = x*slm.xhat + y*slm.yhat;
    vp(1) = vp(1)+slm.x0;
    vp(2) = vp(2)+slm.y0;
    
%     [aa,bb] = transformPointsForward(slm.tform,vp(:,1),vp(:,2));
%     z = zeros(size(xh),'uint8');
%     z(round(bb),round(aa)) = 1;
%     z = imdilate(z,strel('disk',str2double(handles.slmradius.String)));  %change size...
     

    % new version interprets radius in 2p coordinates
    
    th = linspace(0,2*pi,16);
    up = zeros(16,2);

    srad = str2double(handles.slmradius.String);
    up(:,1) = vp(1)+srad*cos(th);
    up(:,2) = vp(2)+srad*sin(th);

    [aa0,bb0] = transformPointsForward(slm.tform,vp(:,1),vp(:,2));

    [aa,bb] = transformPointsForward(slm.tform,up(:,1),up(:,2));
    z = inpolygon(xh,yh,aa,bb);

    cellphase{j} = gsa(ones(size(z)),double(z));
    
    % Phase should use prism and lens from calibration!
    slmimg.CData = cellphase{j};
    heds_show_data(uint8(slmimg.CData));
    slmimg.UserData = cellphase{j};
    handles.prismx.Callback(handles.prismx,handles);
    handles.lens.Callback(handles.lens,handles);
    cellphase{j} = slmimg.CData;
    
    cellgain(j) = slm.power_interp(aa0,bb0);     % equalize power
    if(isnan(cellgain(j))) 
        cellgain(j) = 1;
    end
    
%     mid = size(slm.pts,1)/2;
%     p = slm.pts;
%     npts = size(p,1);
%     p((mid+2):(npts+1),:) = p((mid+1):npts,:);
%     p(mid+1,:) = median(slm.pts);
%     I = slm.I;
%     I((mid+2):(npts+1)) = I((mid+1):npts);
%     I(mid+1) = 0;
%     cellgain(j) = interp2(reshape(p(:,1),[sbconfig.slm_nx sbconfig.slm_ny])', ...
%         reshape(p(:,2),[sbconfig.slm_nx sbconfig.slm_ny])', ...
%         reshape(I,[sbconfig.slm_nx sbconfig.slm_ny])',aa,bb,'cubic',1)/max(I); % normalize by max Intensity
end

hObject.String = 'Compute Phase'; hObject.ForegroundColor = 'k'; drawnow;




function slmpulse_Callback(hObject, eventdata, handles)
% hObject    handle to slmpulse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmpulse as text
%        str2double(get(hObject,'String')) returns contents of slmpulse as a double


% --- Executes during object creation, after setting all properties.
function slmpulse_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmpulse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in dispenable.
function dispenable_Callback(hObject, eventdata, handles)
% hObject    handle to dispenable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of dispenable


% --- Executes on slider movement.
function deadleft_Callback(hObject, eventdata, handles)
% hObject    handle to deadleft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global sbconfig

sb_deadband(handles.deadleft.Value,handles.deadright.Value);
sbconfig.deadband(1) = round(handles.deadleft.Value);

% --- Executes during object creation, after setting all properties.
function deadleft_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deadleft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function deadright_Callback(hObject, eventdata, handles)
% hObject    handle to deadright (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global sbconfig

sb_deadband(handles.deadleft.Value,handles.deadright.Value);
sbconfig.deadband(2) = round(handles.deadright.Value);


% --- Executes during object creation, after setting all properties.
function deadright_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deadright (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in bishiftminus.
function bishiftminus_Callback(hObject, eventdata, handles)
% hObject    handle to bishiftminus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global preIdx sbconfig

sbconfig.bishift(handles.magnification.Value) = sbconfig.bishift(handles.magnification.Value)-1;
preIdx = preIdx-2;

% --- Executes on button press in bishiftplus.
function bishiftplus_Callback(hObject, eventdata, handles)
% hObject    handle to bishiftplus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global preIdx sbconfig

sbconfig.bishift(handles.magnification.Value) = sbconfig.bishift(handles.magnification.Value)+1;
preIdx = preIdx+2;


% --- Executes on button press in fshutter.
function fshutter_Callback(hObject, eventdata, handles)
% hObject    handle to fshutter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fshutter

global sbconfig;

% It must be discovery otherwise button is disabled

laser_send(sprintf('SFIXED=%d',get(hObject,'Value')));

if(get(hObject,'Value'))
    set(hObject,'String','Shutter open','FontWeight','bold','Value',1);
else
    set(hObject,'String','Shutter closed','FontWeight','normal','Value',0);
end

r = laser_send('?GDDMIN');
[r,~] = strsplit(r,' ');
val = str2double(r{end});
handles.gddslider.Min = val;

r = laser_send('?GDDMAX');
[r,~] = strsplit(r,' ');
val = str2double(r{end});
handles.gddslider.Max= val;

r = laser_send('?GDD');
[r,~] = strsplit(r,' ');
val = str2double(r{end});
handles.gddslider.Value= val;
handles.gddtxt.String = r{end};


% --- Executes on slider movement.
function gddslider_Callback(hObject, eventdata, handles)
% hObject    handle to gddslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

msg = sprintf('GDD=%d',round(hObject.Value));
r = laser_send(msg);
handles.gddtxt.String = num2str(round(hObject.Value));

% --- Executes during object creation, after setting all properties.
function gddslider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gddslider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in savebidi.
function savebidi_Callback(hObject, eventdata, handles)
% hObject    handle to savebidi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sbconfig

fn = which('scanbox_config.m');
fid = fopen(fn,'a');

fprintf(fid,'\n%% Bishift calibration saved\n');
fprintf(fid,'sbconfig.bishift = [');
fprintf(fid,'%d ',sbconfig.bishift);
fprintf(fid,'];\n');
fclose(fid);

% --- Executes on button press in dbsave.
function dbsave_Callback(hObject, eventdata, handles)
% hObject    handle to dbsave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sbconfig

fn = which('scanbox_config.m');
fid = fopen(fn,'a');

fprintf(fid,'\n%% Deadband settings saved\n');
fprintf(fid,'sbconfig.deadband = [');
fprintf(fid,'%d ',sbconfig.deadband);
fprintf(fid,'];\n');
fclose(fid);


% --- Executes during object creation, after setting all properties.
function text1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes on button press in knobby_insert.
function knobby_insert_Callback(hObject, eventdata, handles)
% hObject    handle to knobby_insert (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

d = handles.knobby_table.Data;
if(isempty(d))
    d = [0 0 0 0 0];
else
    d = [d;0 0 0 0 0];
end
handles.knobby_table.Data = d;


% --- Executes on button press in knobby_delete.
function knobby_delete_Callback(hObject, eventdata, handles)
% hObject    handle to knobby_delete (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

d = handles.knobby_table.Data;
d = d(1:end-1,:);
handles.knobby_table.Data = d;



% --- Executes on button press in knobby_enable.
function knobby_enable_Callback(hObject, eventdata, handles)
% hObject    handle to knobby_enable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of knobby_enable

global sbconfig

if sbconfig.tri_knob_ver>1
    
    if(hObject.Value)
        % check format first
        t = handles.knobby_table.Data;
        flag = size(t,1)==0;
        flag = flag || any(diff(t(:,5))<0); % nondecreasing frames
        flag = flag || t(end,4)~=0 ;         % ends with motor command
        flag = flag || any((sum(abs(t(:,1:3)),2) .* t(:,4)) > 0);   % simul motor and memory
        if(flag==0) 
       
            % send table....
            
            tri_send('KBY',0,70,0,0);   %% reset scheduler
            sdata = (handles.knobby_table.Data);
            for(i = 1:size(sdata,1))
                if(sdata(i,1)~=0)
                    tri_send('KBY',0,73,sdata(i,1),0);
                end
                if(sdata(i,2)~=0)
                    tri_send('KBY',0,72,sdata(i,2),0);
                    
                end
                
                if(sdata(i,3)~=0)
                    tri_send('KBY',0,71,sdata(i,3),0);
                end
                
                if(sdata(i,4)~=0)
                    tri_send('KBY',0,74,sdata(i,4),0);
                end
                
                tri_send('KBY',0,75,sdata(i,5),0);
            end
            
            tri_send('KBY',0,80,150,0); %% enable
        else
            warndlg('Invalid knobby scheduler table format','scanbox');
            hObject.Value = 0;
        end
    else
        tri_send('KBY',0,81,150,0); %% disable
    end
end


% --- Executes on button press in knobby_save.
function knobby_save_Callback(hObject, eventdata, handles)
% hObject    handle to knobby_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

table = handles.knobby_table.Data;% get current image
[FileName,PathName] = uiputfile('*.mat');
if(~isempty(FileName))
    save([PathName FileName],'table');
end

% --- Executes on button press in knobby_load.
function knobby_load_Callback(hObject, eventdata, handles)
% hObject    handle to knobby_load (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[FileName,PathName] = uigetfile('*.mat');
load([PathName FileName],'table','-mat');
handles.knobby_table.Data = table;




    

% Callback for messages from scanbox

function sb_callback(obj,event)

global T sb captureDone scanbox_h ttltimer;

s = ttltimer.Running;

if s(2) == 'n'  % if the ttl-timer was running....
    
    n = floor(sb.BytesAvailable/5);

    if(n>0)
          
        stop(ttltimer); % stop the timer... as it will be called manually in loop
        
        fread(sb,[5 n],'uint8');
        
        h = findobj(scanbox_h,'Tag','frames');  % set the frames to zero
        h.String = '0';
        drawnow;
        sb_setframe(0);
        h = findobj(scanbox_h,'Tag','grabb');
        f = get(h,'Callback');
        f(h,guidata(h));  % press the grab button....
        
    end
    
else  % ttl timer is not running...  same as before...
    
    n = floor(sb.BytesAvailable/5);
    
    if(n>0)
        q = fread(sb,[5 n],'uint8');
        idx = find(q(5,:)==255);
        q(:,idx) = [];
        
        if(size(q,2)>0)
            T = [T; q'];
        end
        
        if(~isempty(idx))     
            captureDone = 1;
        end
    end
end



% --- Executes on button press in ttltrigger.
function ttltrigger_Callback(hObject, eventdata, handles)
% hObject    handle to ttltrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ttltrigger

global ttltimer scanbox_h;

if hObject.Value
    start(ttltimer);        % start listening for messages from Scanbox
    sb_ttl_trig_enable;     % enable the interrupts
    ttltimer.UserData = 1;  % set the userdata to 1
    h = findobj(scanbox_h,'Tag','grabb');  % disable the buttons
    h.Enable = 'off';
    h = findobj(scanbox_h,'Tag','focusb');
    h.Enable = 'off';
    
else
    sb_ttl_trig_disable;    % disable the interrupt
    stop(ttltimer);         % stop the timer
    ttltimer.UserData = 0;  % clear the userdata
    h = findobj(scanbox_h,'Tag','grabb'); % restore the buttons
    h.Enable = 'on';
    h = findobj(scanbox_h,'Tag','focusb');
    h.Enable = 'on';
end


% --- Executes on selection change in plugin.
function plugin_Callback(hObject, eventdata, handles)
% hObject    handle to plugin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns plugin contents as cell array
%        contents{get(hObject,'Value')} returns selected item from plugin


% --- Executes during object creation, after setting all properties.
function plugin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to plugin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in onfocus.
function onfocus_Callback(hObject, eventdata, handles)
% hObject    handle to onfocus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of onfocus


% --- Executes on button press in returnbox.
function returnbox_Callback(hObject, eventdata, handles)
% hObject    handle to returnbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of returnbox


% --- Executes on button press in caltxt.
function caltxt_Callback(hObject, eventdata, handles)
% hObject    handle to caltxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%warndlg({'Requirements:';'1. Make xx0 is available and empty';'2. Place pollen grain at center at max magnification';'3. Click Ok when ready to proceed'})

sel = questdlg('Ready to run spatial calibration?', ...
	'Scanbox', ...
    'Yes','No','No');


switch sel
    case 'No'
        return;
    case 'Yes'
        sbxspatialcalibration;  %% do a spatial calibration
end



% --- Executes on button press in next.
function next_Callback(hObject, eventdata, handles)
% hObject    handle to next (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global panel_list panel_sel

panel_sel = panel_sel+1;
if(panel_sel>length(panel_list))
    panel_sel=1;
end
set_panel_visible;

% --- Executes on button press in prev.
function prev_Callback(hObject, eventdata, handles)
% hObject    handle to prev (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global panel_list panel_sel

panel_sel = panel_sel-1;
if(panel_sel<1)
    panel_sel=length(panel_list);
end
set_panel_visible;


function set_panel_visible
global panel_list panel_sel

for i = 1:length(panel_list)
    if(panel_sel == i)
        for j =1:length(panel_list{i})
            panel_list{i}{j}.Visible = 'on';
        end
    else
        for j =1:length(panel_list{i})
            panel_list{i}{j}.Visible = 'off';
        end
    end
end



function zrange_Callback(hObject, eventdata, handles)
% hObject    handle to zrange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zrange as text
%        str2double(get(hObject,'String')) returns contents of zrange as a double


zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end


[yy,zz,xx] = meshgrid(y,z,x);

P = [xx(:) yy(:) zz(:)];
dP = diff(P);

t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end

% --- Executes during object creation, after setting all properties.
function zrange_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zrange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function zstep_Callback(hObject, eventdata, handles)
% hObject    handle to zstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of zstep as text
%        str2double(get(hObject,'String')) returns contents of zstep as a double



zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end


[yy,zz,xx] = meshgrid(y,z,x);

P = [xx(:) yy(:) zz(:)];
dP = diff(P);



t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end


% --- Executes during object creation, after setting all properties.
function zstep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to zstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





function framesperstep_Callback(hObject, eventdata, handles)
% hObject    handle to framesperstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of framesperstep as text
%        str2double(get(hObject,'String')) returns contents of framesperstep as a double


zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end




[yy,zz,xx] = meshgrid(y,z,x);

P = [xx(:) yy(:) zz(:)];
dP = diff(P);



t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end


% --- Executes during object creation, after setting all properties.
function framesperstep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to framesperstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in pushbutton104.
function pushbutton104_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton104 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

tri_send('KBY',0,12,0); % set knobby to super fine

% --- Executes on button press in pushbutton105.
function pushbutton105_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton105 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

tri_send('KBY',0,11,0); % set knobby to super fine

% --- Executes on button press in pushbutton106.
function pushbutton106_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton106 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,10,0); % set knobby to super fine


% --- Executes on button press in pushbutton107.
function pushbutton107_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton107 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,20,0);

% --- Executes on button press in pushbutton108.
function pushbutton108_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton108 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

tri_send('KBY',0,21,0); % set knobby to normal


% --- Executes on button press in pushbutton109.
function pushbutton109_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton109 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,30,0);

% --- Executes on button press in pushbutton110.
function pushbutton110_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton110 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,31,0);


% --- Executes on button press in mousecontrol.
function mousecontrol_Callback(hObject, eventdata, handles)
% hObject    handle to mousecontrol (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of mousecontrol
global scanbox_h

if(hObject.Value)
    set(scanbox_h,'WindowButtonDownFcn',@click_wbdcb);
    set(scanbox_h,'WindowScrollWheelFcn',@click_wswcb);
else
    set(scanbox_h,'WindowButtonDownFcn',[]);
    set(scanbox_h,'WindowScrollWheelFcn',[]);
end


% --- Executes on selection change in kax.
function kax_Callback(hObject, eventdata, handles)
% hObject    handle to kax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns kax contents as cell array
%        contents{get(hObject,'Value')} returns selected item from kax


% --- Executes during object creation, after setting all properties.
function kax_CreateFcn(hObject, eventdata, handles)
% hObject    handle to kax (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function kstep_Callback(hObject, eventdata, handles)
% hObject    handle to kstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of kstep as text
%        str2double(get(hObject,'String')) returns contents of kstep as a double


% --- Executes during object creation, after setting all properties.
function kstep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to kstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in kminus.
function kminus_Callback(hObject, eventdata, handles)
% hObject    handle to kminus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


switch(handles.kax.Value)
    case 1
        ax = 2;
    case 2
        ax = 1;
    case 3
        ax = 0;
end

step = round(str2double(handles.kstep.String));
tri_send('KBY',0,ax,-step);


% --- Executes on button press in kplus.
function kplus_Callback(hObject, eventdata, handles)
% hObject    handle to kplus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


switch(handles.kax.Value)
    case 1
        ax = 2;
    case 2
        ax = 1;
    case 3
        ax = 0;
end

step = round(str2double(handles.kstep.String));
tri_send('KBY',0,ax,step);





function slmradius_Callback(hObject, eventdata, handles)
% hObject    handle to slmradius (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmradius as text
%        str2double(get(hObject,'String')) returns contents of slmradius as a double


% --- Executes during object creation, after setting all properties.
function slmradius_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmradius (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in calgrid.
function calgrid_Callback(hObject, eventdata, handles)
% hObject    handle to calgrid (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


global slm

if(get(hObject,'Value'))
    axes(handles.image0);
    hold on;
    h = plot(slm.calpts(:,1),slm.calpts(:,2),'w+','markersize',10,'linewidth',2);
    hObject.UserData = h;
    hold off;
else
    axes(handles.image0);
    delete(hObject.UserData);
    hold off
end


% --- Executes on slider movement.
function slmpower_Callback(hObject, eventdata, handles)
% hObject    handle to slmpower (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

global slms

handles.slmpowertxt.String = sprintf('%.2f',handles.slmpower.Value);

if handles.slmpowerenable.Value>0
    outputSingleScan(slms,[0 handles.slmpower.Value]);
else
    outputSingleScan(slms,[0 -0.05]);
end

% --- Executes during object creation, after setting all properties.
function slmpower_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmpower (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in slmpattern.
function slmpattern_Callback(hObject, eventdata, handles)
% hObject    handle to slmpattern (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmpattern

global slmimg sbconfig

[xx,yy] = meshgrid(1:sbconfig.slmwidth,1:sbconfig.slmheight);

yc = sbconfig.slm_centery;
xc = sbconfig.slm_centerx;
dx = str2double(handles.slmsize.String);

x = zeros(sbconfig.slmheight,sbconfig.slmwidth);

switch hObject.Value
    
    case 1                      % zero phase
    
    case 2                      % 3x3 grid

        for(ii=-1:1)
            for(jj=-1:1)
                x(yc+dx*ii,xc+dx*jj)=1;
            end
        end
        
    case 3
        
        
        for(ii=-2:2)
            for(jj=-2:2)
                x(yc+dx*ii,xc+dx*jj)=1;
            end
        end
        
    case 4
        
        
        for(ii=-3:3)
            for(jj=-3:3)
                x(yc+dx*ii,xc+dx*jj)=1;
            end
        end

    case 5                      % cross hair
        
        x(yc-dx:yc+dx,xc)=1;
        x(yc,xc-dx:xc+dx)=1;
        
        
    case 6                      % target
       
        r = sqrt((xx-xc).^2 + (yy-yc).^2);
        x = (r<100) - (r<75) + (r<50) - (r<25);
        
end

ph = gsa(ones(size(x)),double(x));
slmimg.CData = ph;
heds_show_data(uint8(slmimg.CData));
slmimg.UserData = ph;

handles.slmpowerenable.Value = 1;
handles.slmpowerenable.Callback(handles.slmpowerenable,handles);

% update prism + lens settings 

handles.prismx.Callback(handles.prismx,handles);
handles.lens.Callback(handles.lens,handles);



% --- Executes on button press in camprops.
function camprops_Callback(hObject, eventdata, handles)
% hObject    handle to camprops (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dalsa dalsa_src

inspect(dalsa_src);

% --- Executes on button press in slmscan.
function slmscan_Callback(hObject, eventdata, handles)
% hObject    handle to slmscan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmscan

% if(handles.camerabox.Value == 0)
%     handles.camerabox.Callback(handles.camerabox,handles);
% end
% 
% handles.shutterbutton.Value = 1;
% handles.shutterbutton.Callback(handles.shutterbutton,handles);

if(hObject.Value>0)
    sb_scan;
    hObject.ForegroundColor = 'r';
else
    if(handles.agc.Value)   % start automatic gain timer
        stop(agc_timer);
    end
    sb_abort;
    hObject.ForegroundColor = 'k';
end

% --- Executes on button press in slmcalibrate.
function slmcalibrate_Callback(hObject, eventdata, handles)
% hObject    handle to slmcalibrate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global slmimg dalsa dalsa_src scanbox_h sbconfig

if hObject.UserData == 1        % Abort
    hObject.String = 'Wait';
    hObject.UserData = 0;
    return;
end

hObject.UserData = 1;            % Running!
hObject.String = 'Abort';
hObject.ForegroundColor = 'r';


if hObject.UserData == 1
    
    % open camera
    
    if(handles.camerabox.Value==0)
        handles.camerabox.Value = 1;
        handles.camerabox.Callback(handles.camerabox,handles);
    end
    
    % enable powerenable
    
    handles.slmpowerenable.Value = 1;
    handles.slmpowerenable.Callback(handles.slmpowerenable,handles);
    
    % make sure slmpower is zero
    
    handles.slmpower.Value = -0.05;
    handles.slmpower.Callback(handles.slmpower,handles);
    
    % make sure shutter is open
    
    handles.shutterbutton.Value = 1;
    handles.shutterbutton.Callback(handles.shutterbutton,handles);
    
    % handles.dalsa_exposure.Value = 1;
    % handles.dalsa_exposure.Callback(handles.dalsa_exposure,handles);
    
    % Make deadband zero to see the entire scan - should store/recall previous
    % values
    
    sb_deadband(0,0);
    
end

if hObject.UserData == 1
    
    % Scan
    
    sb_scan;
    pause(6);   % Pause to allow high mag to settle
    
    % accumulate a few frames
    q = double(getsnapshot(dalsa));
    for(i=1:40)
        q = q+double(getsnapshot(dalsa));
    end
    
    % compute scan area
    
    q = (q-min(q(:)))/(max(q(:))-min(q(:)));
    
    %bw = bwareafilt(imbinarize(q,'adaptive'),1);
    bw = q>graythresh(q);
    bw = bwareafilt(bw,1);
    bw = imerode(bw,strel('disk',3));
    [yy,xx] = find(bw);
    [rectx,recty,area,perimeter] = minboundrect(xx,yy);
    
    [xx,yy] = meshgrid(1:size(q,2),1:size(q,1));
    mask = inpolygon(xx(:),yy(:),rectx,recty);
    mask = reshape(mask,size(q));
    
    hold on;
    plot(rectx,recty,'r-','linewidth',1,'UserData','x');
        
    pause(4);   % to allow one to watch quality of match
    
    % close shutter first
    handles.shutterbutton.Value = 0;
    handles.shutterbutton.Callback(handles.shutterbutton,handles);
    
    sb_abort;
end

if hObject.UserData == 1
    
    % restore deadband
    handles.deadleft.Value = sbconfig.deadband(1);
    handles.deadright.Value = sbconfig.deadband(2);
    handles.deadleft.Callback(handles.deadleft,handles);
    handles.deadright.Callback(handles.deadright,handles);
    
    % compute area scan was here...
    
    % bring exposure down
    handles.dalsa_exposure.Value = sbconfig.slm_calexposure;  % must be kept high in non pco-cameras
    handles.dalsa_exposure.Callback(handles.dalsa_exposure,handles);
    
    % % Turn SLM on...
    %
    % handles.slmpower.Value = sbconfig.slmpowerpoint;
    % handles.slmpower.Callback(handles.slmpower,handles);
    
    [xx,yy] = meshgrid(1:sbconfig.slmwidth,1:sbconfig.slmheight);
    
    mat1 = zeros(size(xx));
    
    yc = sbconfig.slm_centery;
    xc = sbconfig.slm_centerx;
    dx = str2double(handles.slmsize.String);
    
    N = sbconfig.slm_nx*sbconfig.slm_ny;
    pts = zeros(N-1,2);
    cal = NaN*zeros(N-1,2);
    I = NaN*zeros(N-1,1);
    img = cell(1,N-1);
    
    k = 1;
    
end

nx = (sbconfig.slm_nx-1)/2;
ny = (sbconfig.slm_ny-1)/2;

mid_acc = [];

for(ii=-ny:ny)
    for(jj=-nx:nx)
        if hObject.UserData == 0
            continue;
        end
        if(ii~=0 || jj~=0)

            x = zeros(sbconfig.slmheight,sbconfig.slmwidth);
            x(yc+dx*ii,xc+dx*jj)=1;
            
            ph = gsa(ones(size(x)),double(x));
            slmimg.CData = ph;
            heds_show_data(uint8(slmimg.CData));
            slmimg.UserData = ph;
            handles.prismx.Callback(handles.prismx,handles);
            handles.lens.Callback(handles.lens,handles);
            
            pts(k,:) = [xc+dx*jj yc+dx*ii];           

            low = sbconfig.slm_powerlow;
            high = sbconfig.slm_powerhigh;
            
            for w=1:12
                
                mid = (low+high)/2;
                
                handles.slmpower.Value = mid;
                handles.slmpower.Callback(handles.slmpower,handles);
                
                pause(0.5);
                
                q = double(getsnapshot(dalsa)); % average a little bit
                for u=1:15
                    q = q+double(getsnapshot(dalsa)); 
                end
                q = q/16;
                M = max(q(:).*mask(:));
                
                if(M>sbconfig.slm_threshold)
                    high = mid;
                else
                    low = mid;
                end
                
            end

            mid_acc(end+1) = mid;
            
            I(k) = mid * sbconfig.slm_threshold / max(q(:)); % must be inside the scan area
            
            img{k} = q;
            [yp, xp] = find(q.*mask > 0.9 * M);
            xp = mean(xp(:));
            yp = mean(yp(:));
            cal(k,:) = [xp yp];
            plot(xp,yp,'yx','UserData','x');
            k = k+1;
        end
    end
end

if hObject.UserData == 1

    % stop SLM...
    
    handles.slmpower.Value = -0.05;
    handles.slmpower.Callback(handles.slmpower,handles);
    
    
    % Normalize I to max value
    
    I = I/max(I(:));
    insert = @(a, x, n)cat(2,  x(1:n), a, x(n+1:end));
    
    % Compute gridded interpolant
    
    Isq = reshape(insert(0,I',((sbconfig.slm_nx * sbconfig.slm_ny) - 1)/2),[sbconfig.slm_nx sbconfig.slm_ny]);
    midpts = median(pts);
    xx  = reshape(insert(midpts(1),pts(:,1)',((sbconfig.slm_nx * sbconfig.slm_ny) - 1)/2),[sbconfig.slm_nx sbconfig.slm_ny]);
    yy  = reshape(insert(midpts(2),pts(:,2)',((sbconfig.slm_nx * sbconfig.slm_ny) - 1)/2),[sbconfig.slm_nx sbconfig.slm_ny]);
    power_interp = griddedInterpolant(xx,yy,Isq,'cubic');
    
    %     p = slm.pts;
    %     npts = size(p,1);
    %     p((mid+2):(npts+1),:) = p((mid+1):npts,:);
    %     p(mid+1,:) = median(slm.pts);
    %     I = slm.I;
    %     I((mid+2):(npts+1)) = I((mid+1):npts);
    %     I(mid+1) = 0;
    %     cellgain(j) = interp2(reshape(p(:,1),[sbconfig.slm_nx sbconfig.slm_ny])', ...
    %         reshape(p(:,2),[sbconfig.slm_nx sbconfig.slm_ny])', ...
    %         reshape(I,[sbconfig.slm_nx sbconfig.slm_ny])',aa,bb,'cubic',1)/max(I); % normalize by max Intensity
    
    % find best affine transform
    
    tform = fitgeotrans(cal,pts,'affine');
    
    
    %
    % % Relative intensity
    %
    
    % handles.slmpower.Value = sbconfig.slmpowergrid;
    % handles.slmpower.Callback(handles.slmpower,handles);
    %
    % x = zeros(sbconfig.slmheight,sbconfig.slmwidth);
    % for(ii=-ny:ny)
    %     for(jj=-nx:nx)
    %         if(ii~=0 || jj~=0)
    %             x(yc+dx*ii,xc+dx*jj)=1;
    %         end
    %     end
    % end
    %
    % ph = gsa(ones(size(x)),double(x));
    % slmimg.CData = ph;
    %
    % pause(2);
    % q = double(getsnapshot(dalsa));
    % for(i=1:40)
    %     q = q+double(getsnapshot(dalsa));
    % end
    %
    % rI = q/41;
    
    %
    % %% validation
    %
    
    % handles.slmpower.Value = sbconfig.slm_validation_power;
    % handles.slmpower.Callback(handles.slmpower,handles);
    
    while(true)
        [xi yi] = myginput(1,'circle');
        if(isempty(xi))
            break;
        end
        
        plot(xi,yi,'wo','UserData','x');
        [aa,bb] = transformPointsForward(tform,xi,yi);  % just one point...
        
        % Do not compensate for intensity during validation (for now)
        
        %     factor = power_interp(aa,bb);
        %
        %     if(isnan(factor))
        %         factor = 1;
        %     end
        
        if(~isnan(sbconfig.slm_validation_power))
            handles.slmpower.Value = min(sbconfig.slm_validation_power,5);
        else
            handles.slmpower.Value = min(median(mid_acc),5);
        end
        handles.slmpower.Callback(handles.slmpower,handles);
        
        % what was this doing here?
        %     handles.slmpowerenable.Value = 0;
        %     handles.slmpowerenable.Callback(handles.slmpowerenable,handles);
        
        x = zeros(sbconfig.slmheight,sbconfig.slmwidth);
        x(round(bb),round(aa))=1;
        ph = gsa(ones(size(x)),double(x));
        
        % apply prism/lens
        slmimg.CData = ph;
        heds_show_data(uint8(slmimg.CData));
        slmimg.UserData = ph;
        handles.prismx.Callback(handles.prismx,handles);
        handles.lens.Callback(handles.lens,handles);
        
    end
end

% remove marks

global img0_h;
a = img0_h.Parent;
c = a.Children;
for i = 1:length(c)
    if(c(i).UserData == 'x')
        delete(c(i))
    end
end
hold off;

% stop SLM...

handles.slmpower.Value = -0.05;
handles.slmpower.Callback(handles.slmpower,handles);

% disable powerenable

handles.slmpowerenable.Value = 0;
handles.slmpowerenable.Callback(handles.slmpowerenable,handles);

if hObject.UserData ==1
    
    %Compute calibration
    
    rectx = rectx(1:end-1);
    recty = recty(1:end-1);
    d = (rectx.^2 + recty.^2);
    [~,idx] = min(d);
    x0 = rectx(idx);
    y0 = recty(idx);
    
    ip = idx+1; 
    if(ip>length(d))
       ip = 1; 
    end
    
    im = idx-1;
    if(im<1)
        im = length(d);
    end
    
    xhat = [rectx(ip)-x0 recty(ip)-y0]; rwidth  = norm(xhat); xhat = xhat/rwidth;
    yhat = [rectx(im)-x0 recty(im)-y0]; rheight = norm(yhat); yhat = yhat/rheight;
    
    % compute calibration points in scanbox window coords
    
    calpts = [cal(:,1)-x0 cal(:,2)-y0] * [xhat' yhat'];
    calpts(:,1) = calpts(:,1)/rwidth*796;
    calpts(:,2) = calpts(:,2)/rheight*512;   % assumes 512 lines!!!!  WARNING!
    
    %what's the optotune value for this calibration?
    
    slm_etl    = handles.optoslider.Value;  % save it along with calibration
    slm_prismx = str2double(handles.prismx.String);
    slm_prismy = str2double(handles.prismx.String);
    slm_lens   = str2double(handles.lens.String);
    slm_size   =  str2double(handles.slmsize.String);
    slm_slmx   = str2double(handles.slmx.String);
    slm_slmy   = str2double(handles.slmy.String);
    
    uisave({'tform','cal','pts','rectx','recty','x0','y0','xhat','yhat','rwidth', ...
        'rheight','I','img','calpts','mask','slm_etl','slm_prismx','slm_prismy', ...
        'slm_lens','slm_size','slm_slmx','slm_slmy','power_interp'});
    
    % Make new calibration active
    
    global slm
    
    slm.xhat = xhat;
    slm.yhat = yhat;
    slm.tform = tform;
    slm.rwidth =  rwidth;
    slm.rheight = rheight;
    slm.x0 = x0;
    slm.y0 = y0;
    slm.I = I;
    slm.pts = pts;
    slm.calpts = calpts;
    slm.slm_etl =  slm_etl;
    slm.prismx = slm_prismx;
    slm.prismy = slm_prismy;
    slm.lens = slm_lens;
    slm.slm_slmx = slm_slmx;
    slm.slm_slmy = slm_slmy;
    slm.power_interp = power_interp;
    
end

hObject.ForegroundColor = 'k';      % not running any more...
hObject.String = 'Calibration';
hObject.UserData = 0;


% --- Executes on button press in loadslmcalib.
function loadslmcalib_Callback(hObject, eventdata, handles)
% hObject    handle to loadslmcalib (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global slm 

fn = uigetfile;

if(fn~=0)
    
    slm = load(fn,'xhat','yhat','tform','rwidth','rheight',...
        'x0','y0','I','pts','calpts','slm_etl','slm_prismx','slm_prismy','slm_lens', ...
        'slm_slmx','slm_slmy','power_interp'); % load calibration file
    
    handles.prismx.String = sprintf('%d',slm.slm_prismx);
    handles.prismy.String = sprintf('%d',slm.slm_prismy);
    handles.lens.String = sprintf('%d',slm.slm_lens);
    handles.slmx.String = sprintf('%d',slm.slm_slmx);
    handles.slmy.String = sprintf('%d',slm.slm_slmy);
    handles.optoslider.Value = slm.slm_etl;
    handles.optoslider.Callback(handles.optoslider,[]);
end

function slmy_Callback(hObject, eventdata, handles)
% hObject    handle to slmy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmy as text
%        str2double(get(hObject,'String')) returns contents of slmy as a double


% --- Executes during object creation, after setting all properties.
function slmy_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function slmx_Callback(hObject, eventdata, handles)
% hObject    handle to slmx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmx as text
%        str2double(get(hObject,'String')) returns contents of slmx as a double


% --- Executes during object creation, after setting all properties.
function slmx_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in slmpowerenable.
function slmpowerenable_Callback(hObject, eventdata, handles)
% hObject    handle to slmpowerenable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmpowerenable

handles.slmpower.Callback(handles.slmpower,handles);




% --- Executes on button press in dbzero.
function dbzero_Callback(hObject, eventdata, handles)
% hObject    handle to dbzero (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% zero deadbands
handles.deadleft.Value  =0 ;
handles.deadright.Value = 0;
handles.deadleft.Callback(handles.deadleft,handles);
handles.deadright.Callback(handles.deadright,handles);



% --- Executes on button press in optocal.
function optocal_Callback(hObject, eventdata, handles)
% hObject    handle to optocal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



sel = questdlg('Ready to run optotune calibration?', ...
	'Scanbox', ...
    'Yes','No','No');

switch sel
    case 'No'
        return;
    case 'Yes'
         sbxoptotunecalibration;  %% do a spatial calibration
end





function prismy_Callback(hObject, eventdata, handles)
% hObject    handle to prismy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of prismy as text
%        str2double(get(hObject,'String')) returns contents of prismy as a double

global slmimg sbconfig

[xx,yy] = meshgrid(1:sbconfig.slmwidth,1:sbconfig.slmheight);

z = str2double(handles.prismx.String) + 1i*str2double(handles.prismy.String);
th = angle(z);
cth = cos(th);
sth = sin(th);

dph = (cth*xx + sth*yy)*2*pi*abs(z)  / size(yy,2);  % in radians

lensphase = str2double(handles.lens.String);
if(lensphase ~= 0)
    r = (xx-size(xx,2)/2).^2+(yy-size(yy,1)).^2;
    dph = dph + 2*pi*lensphase*r/size(xx,2)*2;
end

dph = dph / (2*pi) * 256;                       % in holoeye 8-bit units
ph = floor(mod(double(slmimg.UserData) + dph,256));

slmimg.CData = ph;
heds_show_data(uint8(lmimg.CData));

% --- Executes during object creation, after setting all properties.
function prismy_CreateFcn(hObject, eventdata, handles)
% hObject    handle to prismy (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function prismx_Callback(hObject, eventdata, handles)
% hObject    handle to prismx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of prismx as text
%        str2double(get(hObject,'String')) returns contents of prismx as a double

global slmimg sbconfig

[xx,yy] = meshgrid(1:sbconfig.slmwidth,1:sbconfig.slmheight);

z = str2double(handles.prismx.String) + 1i*str2double(handles.prismy.String);
th = angle(z);
cth = cos(th);
sth = sin(th);

dph = (cth*xx + sth*yy)*2*pi*abs(z)  / size(yy,2);  % in radians

lensphase = str2double(handles.lens.String);
if(lensphase ~= 0)
    r = (xx-size(xx,2)/2).^2+(yy-size(yy,1)).^2;
    dph = dph + 2*pi*lensphase*r/size(xx,2)*2;
end

dph = dph / (2*pi) * 256;                       % in holoeye 8-bit units
ph = floor(mod(double(slmimg.UserData) + dph,256));

slmimg.CData = ph;
heds_show_data(uint8(slmimg.CData));


% --- Executes during object creation, after setting all properties.
function prismx_CreateFcn(hObject, eventdata, handles)
% hObject    handle to prismx (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function slmsize_Callback(hObject, eventdata, handles)
% hObject    handle to slmsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmsize as text
%        str2double(get(hObject,'String')) returns contents of slmsize as a double

handles.slmpattern.Callback(handles.slmpattern,handles);

% --- Executes during object creation, after setting all properties.
function slmsize_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmsize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function lens_Callback(hObject, eventdata, handles)
% hObject    handle to lens (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of lens as text
%        str2double(get(hObject,'String')) returns contents of lens as a double

global slmimg sbconfig

[xx,yy] = meshgrid(1:sbconfig.slmwidth,1:sbconfig.slmheight);

z = str2double(handles.prismx.String) + 1i*str2double(handles.prismy.String);
th = angle(z);
cth = cos(th);
sth = sin(th);

dph = (cth*xx + sth*yy)*2*pi*abs(z)  / size(yy,2);  % in radians

lensphase = str2double(handles.lens.String);
if(lensphase ~= 0)
    r = sqrt((xx-size(xx,2)/2).^2+(yy-size(yy,1)/2).^2);
    rsq = (r/(size(xx,2)/2)).^2;
    dph = dph + 2*pi*lensphase/10*rsq;
end

dph = dph / (2*pi) * 256;                       % in holoeye 8-bit units
ph = floor(mod(double(slmimg.UserData) + dph,256));

slmimg.CData = ph;
heds_show_data(uint8(slmimg.CData));


% --- Executes during object creation, after setting all properties.
function lens_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lens (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in agc.
function agc_Callback(hObject, eventdata, handles)
% hObject    handle to agc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of agc

global agc_timer captureDone

if(hObject.Value>0)
    if(~captureDone)
        start(agc_timer);
    else
        stop(agc_timer);
    end
else
    stop(agc_timer);
end


% Callback for AGC timer

function autogain_callback(obj,event)
global img0_h sbconfig laserpower_h;

p = sum(img0_h.CData(:)>sbconfig.agc_threshold)/numel(img0_h.CData);

if (p<sbconfig.agc_prctile(1))
    laserpower_h.Value = min(laserpower_h.Value*sbconfig.agc_factor(2),255);
    laserpower_h.Callback(laserpower_h,[]);
end

if (p>sbconfig.agc_prctile(2))
    laserpower_h.Value = laserpower_h.Value*sbconfig.agc_factor(1);
    laserpower_h.Callback(laserpower_h,[]);
end




% --- Executes on selection change in slice.
function slice_Callback(hObject, eventdata, handles)
% hObject    handle to slice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns slice contents as cell array
%        contents{get(hObject,'Value')} returns selected item from slice


% --- Executes during object creation, after setting all properties.
function slice_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in sliceview.
function sliceview_Callback(hObject, eventdata, handles)
% hObject    handle to sliceview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of sliceview

if hObject.Value
    p = str2double(handles.optoperiod.String);
    s = cell(1,p);
    for i = 1:p
        s{i} = sprintf('Slice %02d',i);
    end
    handles.slice.String = s;
    handles.slice.Value = 1;
    handles.slice.Visible = 'on';
else
    handles.slice.Visible = 'off';
end
    


% --- Executes on button press in powequal.
function powequal_Callback(hObject, eventdata, handles)
% hObject    handle to powequal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of powequal




% --- Executes on selection change in objective.
function objective_Callback(hObject, eventdata, handles)
% hObject    handle to objective (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns objective contents as cell array
%        contents{get(hObject,'Value')} returns selected item from objective

handles.magnification.Callback(handles.magnification,handles);


% --- Executes during object creation, after setting all properties.
function objective_CreateFcn(hObject, eventdata, handles)
% hObject    handle to objective (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

global objective_h sbconfig

objective_h = hObject;
objective_h.String = sbconfig.objectives;




function edit60_Callback(hObject, eventdata, handles)
% hObject    handle to edit60 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit60 as text
%        str2double(get(hObject,'String')) returns contents of edit60 as a double

global sopto
sopto.Channels(1).DutyCycle = min(str2double(hObject.String)/100,1);



% --- Executes during object creation, after setting all properties.
function edit60_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit60 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton121.
function pushbutton121_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton121 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sopto

sopto.startBackground;




function yrange_Callback(hObject, eventdata, handles)
% hObject    handle to yrange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of yrange as text
%        str2double(get(hObject,'String')) returns contents of yrange as a double

zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end



[yy,zz,xx] = meshgrid(y,z,x);

P = [xx(:) yy(:) zz(:)];
dP = diff(P);


t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end


% --- Executes during object creation, after setting all properties.
function yrange_CreateFcn(hObject, eventdata, handles)
% hObject    handle to yrange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ystep_Callback(hObject, eventdata, handles)
% hObject    handle to ystep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ystep as text
%        str2double(get(hObject,'String')) returns contents of ystep as a double

zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end



[yy,zz,xx] = meshgrid(y,z,x);
P = [xx(:) yy(:) zz(:)];
dP = diff(P);


t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end


% --- Executes during object creation, after setting all properties.
function ystep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ystep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function xrange_Callback(hObject, eventdata, handles)
% hObject    handle to xrange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xrange as text
%        str2double(get(hObject,'String')) returns contents of xrange as a double


zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end



[yy,zz,xx] = meshgrid(y,z,x);

P = [xx(:) yy(:) zz(:)];
dP = diff(P);


t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end

% --- Executes during object creation, after setting all properties.
function xrange_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xrange (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function xstep_Callback(hObject, eventdata, handles)
% hObject    handle to xstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of xstep as text
%        str2double(get(hObject,'String')) returns contents of xstep as a double

zstep = str2double(handles.zstep.String);
zrange = str2double(handles.zrange.String);

ystep = str2double(handles.ystep.String);
yrange = str2double(handles.yrange.String);

xstep = str2double(handles.xstep.String);
xrange = str2double(handles.xrange.String);

fps = str2double(handles.framesperstep.String);

z = 0:zstep:zrange;
y = 0:ystep:yrange;
x = 0:xstep:xrange;

if(isempty(z)) 
    z = 0;
end
if(isempty(y))
    y = 0;
end
if(isempty(x))
    x = 0;
end


[yy,zz,xx] = meshgrid(y,z,x);

P = [xx(:) yy(:) zz(:)];
dP = diff(P);


t = zeros(size(dP,1),5);
t(:,1:3) = dP;
t(:,5) = cumsum(fps*ones(size(dP,1),1));
try
    handles.knobby_table.Data = t;
    handles.frames.String = num2str(t(end,5)+t(1,5));
catch
end


% --- Executes during object creation, after setting all properties.
function xstep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xstep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in storea.
function storea_Callback(hObject, eventdata, handles)
% hObject    handle to storea (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

tri_send('KBY',0,40,0);


% --- Executes on button press in storeb.
function storeb_Callback(hObject, eventdata, handles)
% hObject    handle to storeb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,41,0);


% --- Executes on button press in storec.
function storec_Callback(hObject, eventdata, handles)
% hObject    handle to storec (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,42,0);


% --- Executes on button press in recalla.
function recalla_Callback(hObject, eventdata, handles)
% hObject    handle to recalla (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,50,0);


% --- Executes on button press in recallb.
function recallb_Callback(hObject, eventdata, handles)
% hObject    handle to recallb (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,51,0);


% --- Executes on button press in recallc.
function recallc_Callback(hObject, eventdata, handles)
% hObject    handle to recallc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tri_send('KBY',0,52,0);


% --- Executes on button press in measure.
function measure_Callback(hObject, eventdata, handles)
% hObject    handle to measure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dxcal dycal

[xi, yi] = myginput(2,'circle');
if(length(xi)~=2)
    return;
end
hObject.String = sprintf('(%.1f,%.1f)',... 
    abs(diff(xi)*dxcal),abs(diff(yi)*dycal));


% --- Executes on button press in text112.
function text112_Callback(hObject, eventdata, handles)
% hObject    handle to text112 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.optomin.String = handles.ot_txt.String;
handles.optomin.Callback(handles.optomin,[]);


% --- Executes on button press in text113.
function text113_Callback(hObject, eventdata, handles)
% hObject    handle to text113 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.optomax.String = handles.ot_txt.String;
handles.optomax.Callback(handles.optomax,[]);


% --- Executes on button press in ssclear.
function ssclear_Callback(hObject, eventdata, handles)
% hObject    handle to ssclear (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sstable;

sstable = [];
handles.ssenable.Value = 0;    % uncheck the link button
handles.ssenable.Callback(handles.ssenable,[]);

% --- Executes on button press in sslink.
function sslink_Callback(hObject, eventdata, handles)
% hObject    handle to sslink (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global sstable;

opto = floor(handles.optoslider.Value);
pt = myginput(1,'top');
line = round(pt(2));

sstable = [sstable ; line opto];          % add points to the list



% --- Executes on button press in ssenable.
function ssenable_Callback(hObject, eventdata, handles)
% hObject    handle to ssenable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ssenable

global sstable;

nl = str2double(handles.lines.String);

if(hObject.Value)
    if(~isempty(sstable) && size(sstable,1)>1)
        [~,i] = sort(sstable(:,1));  % sort by line 
        sstable = sstable(i,:);
        sstable = interp1(sstable(:,1),sstable(:,2),1:nl);
        nidx = find(~isnan(sstable));
        idx = min(nidx);
        sstable(1:idx-1) = sstable(idx);
        idx = max(nidx);
        sstable(idx+1:end) = sstable(idx);
        sstable = floor(sstable);
        sstable = [(1:nl)' sstable'];
        sb_optocontrol(sstable(:,2));
        sb_optocontrol_active(1);     % active surface sampling
    else
        sb_optocontrol_active(0);     % bad table...
        hObject.Value = 0;      
    end
else
    sb_optocontrol_active(0);   % bad table...
end



% --- Executes on button press in lamp.
function lamp_Callback(hObject, eventdata, handles)
% hObject    handle to lamp (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of lamp

if(hObject.Value)
    quad_lamp_on;
else
    quad_lamp_off;
end



% --- Executes on button press in igrab.
function igrab_Callback(hObject, eventdata, handles)
% hObject    handle to igrab (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dalsa dalsa_src

if(handles.camerabox.Value == 1)
    if hObject.UserData==1
        sb_intrinsic(0);
        stop(dalsa);
        
        hObject.String = 'Saving';
        hObject.ForegroundColor = 'r';
        drawnow;
        while (dalsa.FramesAcquired ~= dalsa.DiskLoggerFrameCount)
            pause(0.1);
        end
        close(dalsa.DiskLogger);
        hObject.String = 'Grab';
        hObject.ForegroundColor = 'k';
        
        handles.istatus.String = sprintf('Acquired %d frames',dalsa.FramesAcquired);
        hObject.UserData = 0;
               
        % read the TTL data and save...
        
        fn = sprintf('%s\\%s\\%s_%s_%s.mj2_events', handles.dirname.String,handles.animal.String,handles.animal.String,handles.unit.String,handles.expt.String);

        global sb;
        
        if(sb.BytesAvailable>0)
            q = fread(sb,sb.BytesAvailable);
            ttl_events = reshape(q,5,[])';
        else
            ttl_events = [];
        end
        
        save(fn,'ttl_events');
        
%         hObject.UserData = 0;
%         [data,time,metadata] = getdata(dalsa);
%         
%         freq = 1/mean(diff(time));
%         nframes = size(data,4);
%         handles.istatus.String = sprintf('Acquired %d frames at %.1f fps [%s]',nframes,freq,class(data));
%         fn = sprintf('%s\\%s\\%s_%s_%s.portcam', handles.dirname.String,handles.animal.String,handles.animal.String,handles.unit.String,handles.expt.String);
%         drawnow;
%         hObject.String = 'Saving';
%         hObject.ForegroundColor = 'r';
%         drawnow;
%         save(fn,'data','time','metadata','-v7.3');
%         hObject.String = 'Grab';
%         hObject.ForegroundColor = 'k';
%         drawnow;
        
    else
        fn = sprintf('%s\\%s\\%s_%s_%s.mj2', handles.dirname.String,handles.animal.String,handles.animal.String,handles.unit.String,handles.expt.String);
        vw = VideoWriter(fn,'Motion JPEG 2000');
        vw.LosslessCompression = true;
        vw.FrameRate = 1;
        dalsa.DiskLogger = vw;
        hObject.String = 'Stop';
        hObject.ForegroundColor = 'r';
        hObject.UserData = 1;
        handles.istatus.String = 'Streaming to disk...';
        sb_intrinsic(1);
        start(dalsa);
    end
else
    handles.istatus.String = 'Camera port is currently disabled. Check mirror position.';
end



% --- Executes on button press in setiroi.
function setiroi_Callback(hObject, eventdata, handles)
% hObject    handle to setiroi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dalsa dalsa_src dalsa_roi;

% q = peekdata(dalsa,1);
% figure('MenuBar','none','ToolBar','none','Name','Set ROI','NumberTitle','off');
% imagesc(q); colormap(sqrt(gray(256))); axis off; truesize;

h = imrect(gca,[dalsa.VideoResolution/2-[192 192]/2 192 192]);
h.setFixedAspectRatioMode(false);
h.setResizable(true);
dalsa.ROIPosition = wait(h);
delete(h);
dalsa_roi = dalsa.ROIPosition;

% wcam_h = preview(wcam);
% colormap(ancestor(wcam_h,'axes'),sqrt(gray(256)));


% --- Executes on button press in cleariroi.
function cleariroi_Callback(hObject, eventdata, handles)
% hObject    handle to cleariroi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global dalsa dalsa_src dalsa_roi;

dalsa.ROIPosition = [0 0 dalsa.VideoResolution];
dalsa_roi = dalsa.ROIPosition;



% --- Executes on selection change in rtchan.
function rtchan_Callback(hObject, eventdata, handles)
% hObject    handle to rtchan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns rtchan contents as cell array
%        contents{get(hObject,'Value')} returns selected item from rtchan


% --- Executes during object creation, after setting all properties.
function rtchan_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rtchan (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in powermeter_calibration.
function powermeter_calibration_Callback(hObject, eventdata, handles)
% hObject    handle to powermeter_calibration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


sel = questdlg('Ready to run pockels calibration?', ...
	'Scanbox', ...
    'Yes','No','No');

switch sel
    case 'No'
        return;
    case 'Yes'
         sbxpockelscalibration;  %% do a spatial calibration
end

% --- Executes on button press in powermeter_measure.
function powermeter_measure_Callback(hObject, eventdata, handles)
% hObject    handle to powermeter_measure (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.powermeter_value.String = sprintf('%.5f W',powermeter_read);



% --- Executes on selection change in panel_menu.
function panel_menu_Callback(hObject, eventdata, handles)
% hObject    handle to panel_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns panel_menu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from panel_menu


global panel_list panel_sel

panel_sel = hObject.Value;
set_panel_visible;



% --- Executes during object creation, after setting all properties.
function panel_menu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to panel_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in sbcheck.
function sbcheck_Callback(hObject, eventdata, handles)
% hObject    handle to sbcheck (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of sbcheck


% --- Executes on button press in slmpreview.
function slmpreview_Callback(hObject, eventdata, handles)
% hObject    handle to slmpreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of slmpreview

heds_utils_slm_preview_show(hObject.Value); % toggle preview



function slmpowertxt_Callback(hObject, eventdata, handles)
% hObject    handle to slmpowertxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of slmpowertxt as text
%        str2double(get(hObject,'String')) returns contents of slmpowertxt as a double

handles.slmpower.Value = str2double(hObject.String);
handles.slmpower.Callback(handles.slmpower,guidata(handles.slmpower));

% --- Executes during object creation, after setting all properties.
function slmpowertxt_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slmpowertxt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ledmode.
function ledmode_Callback(hObject, eventdata, handles)
% hObject    handle to ledmode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ledmode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ledmode

contents = cellstr(get(hObject,'String'));
led_mode(contents{get(hObject,'Value')});   % set LED mode

% --- Executes during object creation, after setting all properties.
function ledmode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ledmode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ledterm.
function ledterm_Callback(hObject, eventdata, handles)
% hObject    handle to ledterm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ledterm contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ledterm

led_state(0);   % turn off first
led_terminal(hObject.Value);    

% --- Executes during object creation, after setting all properties.
function ledterm_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ledterm (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ledstate.
function ledstate_Callback(hObject, eventdata, handles)
% hObject    handle to ledstate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of ledstate

if(hObject.UserData==0)
    hObject.UserData=1;
    hObject.String = 'LED On';
    led_state(1);
else
    hObject.UserData=0;
    hObject.String = 'LED Off';
    led_state(0);
end



function cc_current_Callback(hObject, eventdata, handles)
% hObject    handle to cc_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cc_current as text
%        str2double(get(hObject,'String')) returns contents of cc_current as a double

led_current(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function cc_current_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cc_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function cb_brightness_Callback(hObject, eventdata, handles)
% hObject    handle to cb_brightness (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cb_brightness as text
%        str2double(get(hObject,'String')) returns contents of cb_brightness as a double

led_brightness(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function cb_brightness_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cb_brightness (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pulse_low_Callback(hObject, eventdata, handles)
% hObject    handle to pulse_low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pulse_low as text
%        str2double(get(hObject,'String')) returns contents of pulse_low as a double

led_pulse_
% --- Executes during object creation, after setting all properties.
function pulse_low_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pulse_low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function imod_low_Callback(hObject, eventdata, handles)
% hObject    handle to imod_low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of imod_low as text
%        str2double(get(hObject,'String')) returns contents of imod_low as a double

led_imod_brightness_low(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function imod_low_CreateFcn(hObject, eventdata, handles)
% hObject    handle to imod_low (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in imod_func.
function imod_func_Callback(hObject, eventdata, handles)
% hObject    handle to imod_func (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns imod_func contents as cell array
%        contents{get(hObject,'Value')} returns selected item from imod_func

contents = cellstr(get(hObject,'String'));
led_imod_function(contents{get(hObject,'Value')});


% --- Executes during object creation, after setting all properties.
function imod_func_CreateFcn(hObject, eventdata, handles)
% hObject    handle to imod_func (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pulse_high_Callback(hObject, eventdata, handles)
% hObject    handle to pulse_high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pulse_high as text
%        str2double(get(hObject,'String')) returns contents of pulse_high as a double

led_pulse_brightness(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function pulse_high_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pulse_high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pulse_on_Callback(hObject, eventdata, handles)
% hObject    handle to pulse_on (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pulse_on as text
%        str2double(get(hObject,'String')) returns contents of pulse_on as a double

led_pulse_ontime(str2double(get(hObject,'String')));


% --- Executes during object creation, after setting all properties.
function pulse_on_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pulse_on (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pulse_off_Callback(hObject, eventdata, handles)
% hObject    handle to pulse_off (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pulse_off as text
%        str2double(get(hObject,'String')) returns contents of pulse_off as a double

led_pulse_offtime(str2double(get(hObject,'String')));


% --- Executes during object creation, after setting all properties.
function pulse_off_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pulse_off (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function pulse_count_Callback(hObject, eventdata, handles)
% hObject    handle to pulse_count (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of pulse_count as text
%        str2double(get(hObject,'String')) returns contents of pulse_count as a double

led_pulse_count(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function pulse_count_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pulse_count (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function imod_high_Callback(hObject, eventdata, handles)
% hObject    handle to imod_high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of imod_high as text
%        str2double(get(hObject,'String')) returns contents of imod_high as a double

led_imod_brightness_high(str2double(get(hObject,'String')));


% --- Executes during object creation, after setting all properties.
function imod_high_CreateFcn(hObject, eventdata, handles)
% hObject    handle to imod_high (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function imod_freq_Callback(hObject, eventdata, handles)
% hObject    handle to imod_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of imod_freq as text
%        str2double(get(hObject,'String')) returns contents of imod_freq as a double

led_imod_freq(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function imod_freq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to imod_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ttl_current_Callback(hObject, eventdata, handles)
% hObject    handle to ttl_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ttl_current as text
%        str2double(get(hObject,'String')) returns contents of ttl_current as a double

led_ttl_current(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function ttl_current_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ttl_current (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ttl_on_Callback(hObject, eventdata, handles)
% hObject    handle to ttl_on (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ttl_on as text
%        str2double(get(hObject,'String')) returns contents of ttl_on as a double

led_stim_width(str2double(get(hObject,'String')));


% --- Executes during object creation, after setting all properties.
function ttl_on_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ttl_on (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ttl_margin_Callback(hObject, eventdata, handles)
% hObject    handle to ttl_margin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of ttl_margin as text
%        str2double(get(hObject,'String')) returns contents of ttl_margin as a double

led_stim_margin(str2double(get(hObject,'String')));

% --- Executes during object creation, after setting all properties.
function ttl_margin_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ttl_margin (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit83_Callback(hObject, eventdata, handles)
% hObject    handle to edit83 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit83 as text
%        str2double(get(hObject,'String')) returns contents of edit83 as a double

led_stim_pulses(str2double(get(hObject,'String')))

% --- Executes during object creation, after setting all properties.
function edit83_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit83 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ledstimtrig.
function ledstimtrig_Callback(hObject, eventdata, handles)
% hObject    handle to ledstimtrig (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

led_stim_trig  



function fold_lines_Callback(hObject, eventdata, handles)
% hObject    handle to fold_lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of fold_lines as text
%        str2double(get(hObject,'String')) returns contents of fold_lines as a double

handles.magnification.Callback(handles.magnification,handles);

% --- Executes during object creation, after setting all properties.
function fold_lines_CreateFcn(hObject, eventdata, handles)
% hObject    handle to fold_lines (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
