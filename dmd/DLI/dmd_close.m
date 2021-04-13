% load dmd library 

warning off
if libisloaded('PortabilityLayer')
    dmd_park;   % park dmd
    unloadlibrary('PortabilityLayer')
end
warning on

