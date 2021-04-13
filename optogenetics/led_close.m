%% Instrument Connection

global led_controller

try
    fclose(led_controller);
catch
end
