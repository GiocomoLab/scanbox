function quad_lamp_on()

global quad;

if ~isempty(quad)
    fwrite(quad,3);
    if(quad.BytesAvailable > 0)
        fread(quad,quad.BytesAvailable); % empty the buffer...
    end
end
