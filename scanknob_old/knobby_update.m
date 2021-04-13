%% Update knobby firmware...

scanbox_config;
global sbconfig;

if(~isempty(sbconfig.tri_knob))
    d = which('knobby_update.py');  % where is it?
    p = strsplit(d,'\');
    root = strjoin(p(1:end-1),'\');
    cd(root);
    switch sbconfig.tri_knob_ver
        case 1
            disp('Updating Knobby v1');
            cmd = ['python.exe knobby_update.py ' sbconfig.tri_knob];
        case 2
            disp('Updating Knobby v2');
            cmd = ['python.exe knobby_update_v2.py ' sbconfig.tri_knob];        
    end
    [~,~] = system(cmd,'-echo');
else
    warning('There is no definition of tri_knob in scanbox_config.m');
end