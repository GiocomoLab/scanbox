function dmd_sparse(nx,ny)

[xx,yy] = meshgrid(1:dmd_width,1:dmd_height);

dx = dmd_width/nx;
dy = dmd_height/ny;
img = zeros(size(xx),'uint8');

k = 0;
for i = 0:nx-1
    for j=0:ny-1
        img = 128*uint8((floor(xx/dx)==i) & (floor(yy/dy)==j));
        write_dbi('tmp',img);
        dmd_writeimage('tmp',k);
        k = k+1;
    end
end

dmd_writelut(0:k-1);
dmd_display_multiple;

