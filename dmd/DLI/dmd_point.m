function dmd_point(x0,y0,radius,idx)

[xx,yy] = meshgrid(1:dmd_width,1:dmd_height);
rsq = (xx-x0).^2+(yy-y0).^2;
img = uint8(128*( rsq < radius^2 ));
imagesc(img)
write_dbi('tmp',img);
dmd_writeimage('tmp',idx);
dmd_writelut([idx]);
dmd_display_multiple;

