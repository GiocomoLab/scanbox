%% Instrument Connection

global sbconfig led_controller

% Find a VISA-USB object.

led_controller = instrfind('Type', 'visa-usb', 'RsrcName',  sbconfig.led_id, 'Tag', '');

if isempty(led_controller)
    led_controller = visa('NI',sbconfig.led_id);
else
    fclose(led_controller);
    led_controller = led_controller(1);
end

if ~isempty(led_controller)
    fopen(led_controller);
end



