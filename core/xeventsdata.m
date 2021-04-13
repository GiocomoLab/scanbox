function xeventsdata(src,event)
global xefid;
code = event.Data * (2.^(0:7))';
fwrite(xefid,uint8(code));
end
