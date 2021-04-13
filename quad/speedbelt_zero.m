function speedbelt_zero()

global speedbelt;

if ~isempty(speedbelt)
    if speedbelt.BytesAvailable>0
        fread(speedbelt,speedbelt.BytesAvailable); % empty data stream
    end
end
