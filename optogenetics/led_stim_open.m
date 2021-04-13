%% Instrument Connection

global sbconfig led_stim

if(~isempty(sbconfig.led_stim_com))
    led_stim = serial(sbconfig.led_stim_com);
    led_stim.BaudRate = 38400;
    led_stim.Terminator = [];
    fopen(led_stim);
end



