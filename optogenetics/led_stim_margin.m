function led_stim_margin(m)

global led_stim

% set the width of the LED stim pulse (in ms)

fwrite(led_stim,uint8([4 m]));




