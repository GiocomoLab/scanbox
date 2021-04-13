function data = sbx_get_camport_frame(fn,idx)

fn = [fn '.mj2'];
vr = VideoReader(fn);

for j = 1:length(idx)
    vr.CurrentTime = idx(j);
    q = readFrame(vr);
    if(j==1)
        data = zeros([size(q) length(idx)]);
    end
    data(:,:,j) = q;
end
