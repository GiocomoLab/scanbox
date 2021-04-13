function speedbelt_close()

global speedbelt;

if ~isempty(speedbelt)
    fclose(speedbelt);
end
