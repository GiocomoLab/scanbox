function speedbelt_open()

global speedbelt sbconfig;

if ~isempty(speedbelt)
    try,
        fclose(speedbelt);
    catch
    end
end

speedbelt = serial(sbconfig.speedbelt_com ,'BaudRate',57600,'InputBufferSize',4000); 

fopen(speedbelt);     % open it
pause(2);
fread(speedbelt,133); % discard initial message
