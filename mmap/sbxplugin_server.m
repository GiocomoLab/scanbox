
% Scanbox plug in server script

% This code will run upon startup of Scanbox on a separate matlab instance if mmap=true
% in the scanbox_config file

% DO NOT MODIFY!!!!!  There is no need for users to modify this file

% Open memory mapped file -- define just the header first

global fnum;    % frame number being processed

scanbox_config; % read the scanbox config structure

mmfile = memmapfile('scanbox.mmap','Writable',true, ...
    'Format', { 'int16' [1 16] 'header' } , 'Repeat', 1);

plugin_id = -1;

disp('Plugin server ready');

% Process all incoming frames until Scanbox stops

running  = false;

while(true)
    
    disp('Waiting for imaging data stream');
    
    while ~running
        running = mmfile.Data.header(1)>=0;
    end
    
    fnum = mmfile.Data.header(1);
 
    flag = (fnum == 0) || (plugin_id ~= mmfile.Data.header(7));
    
    plugin_id = mmfile.Data.header(7); % get the plug in to be used
    
    fprintf('Plugin id=%d\n',plugin_id);
    fprintf('Experiment %d_%d\n',mmfile.Data.header(8),mmfile.Data.header(9));
    
    while running
        
        running = (mmfile.Data.header(1) ~= -2);    % no stop signal present
        
        if running && mmfile.Data.header(1)>=0      % if not stopped and frame present
            
            try
                fprintf('Frame: %05d Plugin: %s\n',mmfile.Data.header(1),sbconfig.plugin{plugin_id});
                eval(sbconfig.plugin{plugin_id});
            catch
                disp('Invalid plugin or error in plugin code');
            end
            
            mmfile.Data.header(1) = -1; % signal Scanbox that frame has been consumed!
            
        end
    end
end


