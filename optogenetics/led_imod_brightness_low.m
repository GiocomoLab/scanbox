function r = led_imod_brightness_low(level)

global led_controller

if(~isempty(level))
    fprintf(led_controller,sprintf('SOURCE:IMODulation:BRIGhtness:LOW %f',level));
    r = [];
else
    r = query(led_controller,'SOURCE:IMODulation:BRIGhtness:LOW?');
    r=r(1:end-1);
end
