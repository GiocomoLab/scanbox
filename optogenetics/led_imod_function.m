function r = led_imod_function(type)

global led_controller

% 1 = SIN = sinusoid
% 2 = SQU = square
% 3 = TRI = triangular

if(~isempty(type))
    fprintf(led_controller,sprintf('SOURCE:IMODulation:FUNCtion:SHAPe %s',type));
    r = [];
else
    r = query(led_controller,'SOURCE:IMODulation:FUNCtion:SHAPe?');
    r=r(1:end-1);
end
