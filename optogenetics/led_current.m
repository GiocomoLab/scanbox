function r = led_current(curr)

global led_controller

% Set the LED current 

if(~isempty(curr))
    fprintf(led_controller,sprintf('SOURCE1:CCUR:CURRENT:AMPL %f',curr));
    r = [];
else
    r = query(led_controller,'SOURCE1:CCUR:CURRENT:AMPL?');
    r=r(1:end-1);
end
