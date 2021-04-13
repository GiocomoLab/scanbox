function r = led_pulse_count(T)

global led_controller

% Set the pulse mode brightness

if(~isempty(T))
    fprintf(led_controller,sprintf('SOURCE:PULSe:COUNt %f',T));
    r = [];
else
    r = query(led_controller,'SOURCE:PULSe:COUNt?');
    r=r(1:end-1);
end
