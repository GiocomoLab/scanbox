function r = led_imod_freq(freq)

global led_controller

% Set the LED current 

if(~isempty(freq))
    fprintf(led_controller,sprintf('SOURCE:IMODulation:FREQ %f',freq));
    r = [];
else
    r = query(led_controller,'SOURCE:IMOD:FREQ?');
    r=r(1:end-1);
end
