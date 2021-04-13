function led_stim_width(w)

global sbconfig led_stim

% set the width of the LED stim pulse (in ms)

fwrite(led_stim,uint8([1 w]));




