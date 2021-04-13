function write_dbi(fname,img)

fid = fopen([fname '.dbi'],'w');
fwrite(fid,uint8(['DBI' 0]),'uint8');
fwrite(fid,16,'uint32');
fwrite(fid,size(img,1),'uint32');
fwrite(fid,size(img,2),'uint32');
if(all(ismember(unique(img(:)),[0 128])))
    fwrite(fid,1,'uint32');
else
    fwrite(fid,8,'uint32');
end
z = zeros([2 1024 768],'uint8');
z(2,:,:) = img';
fwrite(fid,z(:),'uint8');
fclose(fid);