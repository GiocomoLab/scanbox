function quad_lamp_off()

global quad;

if ~isempty(quad)
    fwrite(quad,2); 
    if(quad.BytesAvailable > 0)
        fread(quad,quad.BytesAvailable); % empty the buffer...
    end
end
