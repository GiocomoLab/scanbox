% load dmd library

function dmd_init(bf)

if (libisloaded('PortabilityLayer'))
    dmd_close;
end

warning off
if not(libisloaded('PortabilityLayer'))
    loadlibrary('PortabilityLayer')
    sts = calllib('PortabilityLayer','InitPortabilityLayer',0,0,0);
    dmd_park;   % park dmd
    dmd_runbatchfile(bf);
    if(contains(bf,'1bit'))
        dmd_writeimage('Welcome1',0);
    else
        dmd_writeimage('Welcome8',0);
    end
    dmd_writelut([0]);
    dmd_display_first;
    dmd_unpark;
end
warning on
fprintf('Scanbox DMD Configured with %d bpp @ %d fps\n',dmd_getbpp,dmd_getframerate);




