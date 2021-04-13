function r = read_dbi(fname)

fid = fopen([fname '.dbi']);
signature = fread(fid,4,'uint8');
cbSize = fread(fid,1,'uint32');
rows = fread(fid,1,'uint32');
cols = fread(fid,1,'uint32');
bpp  = fread(fid,1,'uint32');
img = fread(fid,[1 2*rows*cols],'uint8');
img = reshape(img,[2 1024 768]);
img = squeeze(img(2,:,:))';
fclose(fid);

r.signature = char(signature);
r.cbSize = cbSize;
r.rows = rows;
r.cols = cols;
r.bpp  = bpp;
r.img = img;
