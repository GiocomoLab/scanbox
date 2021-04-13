function dmd_grid(nx,ny,side,radius,idx)

[xx,yy] = meshgrid(1:dmd_width,1:dmd_height);

img = zeros(size(xx),'uint8');
for i = -(nx-1)/2:(nx-1)/2
    for j=-(ny-1)/2:(ny-1)/2
        rsq = (xx-dmd_width/2+i*side).^2+(yy-dmd_height/2+j*side).^2;
        img = img + uint8(128*( rsq < radius^2 ));
    end
end

write_dbi('tmp',img);
dmd_writeimage('tmp',idx);
dmd_writelut([idx]);
dmd_display_multiple;

