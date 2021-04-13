function pow = led_state(onoff)

global led_controller

if(onoff)
    fprintf(led_controller,'OUTPUT:STATE ON');
else
    fprintf(led_controller,'OUTPUT:STATE OFF');
end

