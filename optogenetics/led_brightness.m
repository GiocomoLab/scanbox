function r = led_brightness(level)

global led_controller

% Set the LED current 

if(~isempty(level))
    fprintf(led_controller,sprintf('SOURCE:CBRightness:BRIGhtness:AMPLitude %f',level));
    r = [];
else
    r = query(led_controller,'SOURCE:CBRightness:BRIGhtness:AMPLitude?');
    r=r(1:end-1);
end
