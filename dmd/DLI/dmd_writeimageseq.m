function dmd_writeimageseq(root,N)

% writes a sequence of files

for i =0:N-1
    dmd_writeimage(sprintf('%s_%03d',root,i),i);
end
dmd_writelut(0:(N-1));
