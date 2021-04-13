function sbx2tif_large(fname,chan,varargin)

% sbx2tif_large

% Generates tif file from sbx files using Malab's Tiff objects
% Argument is the number of frames to convert
% chan is the channel index
% If no argument is passed the whole file is converted

z = sbxread(fname,1,1);
global info;

if(nargin>1)
    N = min(varargin{1},info.max_idx);
else
    N = info.max_idx;
end

k = 0;
done = false;

while(~done && k<=N)
    try
        q = sbxread(fname,k,1);
        q = squeeze(q(chan,:,:));
        if(k==0)
            obj = Tiff([fname '.tif'],'w8');    % open big tiff file
            tagstruct.ImageLength = size(q,1);
            tagstruct.ImageWidth  = size(q,2);
            tagstruct.Photometric = Tiff.Photometric.LinearRaw;
            tagstruct.SamplesPerPixel = 1;
            tagstruct.BitsPerSample = 16;
            tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            tagstruct.Software = 'Scanbox';
            obj.setTag(tagstruct);
            obj.write(q);
            obj.writeDirectory();
        else
            obj.setTag(tagstruct);
            obj.write(q);
            obj.writeDirectory();
         end
    catch
        done = true;
        obj.close();
    end
    k = k+1;
end
obj.close();
