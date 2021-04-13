function led_stim_pulses(npulses)

global led_stim

% set the width of the LED stim pulse (in ms)

fwrite(led_stim,uint8([0 npulses]));




