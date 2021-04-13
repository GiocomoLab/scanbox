%% Instrument Connection

global sbconfig pmeter

% Find a VISA-USB object.

pmeter = instrfind('Type', 'visa-usb', 'RsrcName',  sbconfig.pmeter_id, 'Tag', '');

if isempty(pmeter)
    pmeter = visa('NI',sbconfig.pmeter_id);
else
    fclose(pmeter);
    pmeter = pmeter(1);
end

if ~isempty(pmeter)
    fopen(pmeter);
end



