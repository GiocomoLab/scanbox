function r = led_imod_brightness_high(level)

global led_controller

if(~isempty(level))
    fprintf(led_controller,sprintf('SOURCE:IMODulation:BRIGhtness:HIGH %f',level));
    r = [];
else
    r = query(led_controller,'SOURCE:IMODulation:BRIGhtness:HIGH?');
    r=r(1:end-1);
end
