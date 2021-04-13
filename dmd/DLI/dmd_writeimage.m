% write image

function sts = dmd_writeimage(fn,idx)
[sts,~] = calllib('PortabilityLayer','WriteExternalImage',[fn '.dbi'],idx);
