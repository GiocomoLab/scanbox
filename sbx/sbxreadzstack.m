function z = sbxreadzstack(fname,chan,drop)

z = sbxread(fname,0,1);
global info

switch nargin
    case 1
        chan = 1;
        drop = 1;
    case 2
        drop = 1;
    otherwise
end

z = sbxread(fname,0,1+info.max_idx);
z = squeeze(z(chan,:,:,:));
nf =  info.config.knobby.schedule(1,end);
z = reshape(z,[size(z,1) size(z,2) nf (info.max_idx+1)/nf]);
z = squeeze(mean(z(:,:,drop:end,:),3));
z = (z-min(z(:)))/(max(z(:))-min(z(:)));


