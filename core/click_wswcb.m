function sbxwswcb(src,callbackdata)

% scroll wheel callback

global scanbox_h nlines dxcal dycal captureDone
p = gca;
x = p.CurrentPoint(1,1);
y = p.CurrentPoint(1,2);

if(~captureDone && x>0 && x<796 && y>0 && y<nlines)
    tri_send('KBY',0,0,2*callbackdata.VerticalScrollCount);
end