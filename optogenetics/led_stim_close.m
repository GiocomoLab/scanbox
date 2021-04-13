%% Instrument Connection

global sbconfig led_stim

if(~isempty(sbconfig.led_stim_com))
    try
        fclose(led_stim);
    catch
    end
end



