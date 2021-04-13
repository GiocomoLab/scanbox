function r = led_terminal(term)

global led_controller

% Set the LED current 

if(~isempty(term))
    fprintf(led_controller,sprintf('OUTPUT:TERMINAL %f',term));
    r = [];
else
    r = query(led_controller,'OUTPUT:TERMINAL?');
    r=r(1:end-1);
end
