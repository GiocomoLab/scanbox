function sb_cam_pulse_width(p)

% sets the width of CAM0/1 pulse in lines (one line = 1/8khz = 125um)

global sb;

fwrite(sb,uint8([12 0 p]));