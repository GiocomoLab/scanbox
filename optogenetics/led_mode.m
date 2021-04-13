function r = led_mode(mode)

global led_controller

% Set the LED operating mode:
% 1 = CC = Constant Current
% 2 = CB = Constant Brightness
% 3 = PWM = Pulse Width Modulation
% 4 = PULS = Pulse Modulation
% 5 = IMOD = Internal Modulation
% 6 = EMOD = External Modulation
% 7 = TTL = TTL Input Controlled

if(~isempty(mode))
    led_state(0);   % turn off first
    fprintf(led_controller,sprintf('SOURCE:MODE %s',mode));
    r = [];
else
    r = query(led_controller,'SOURCE:MODE?');
    r=r(1:end-1);
end
