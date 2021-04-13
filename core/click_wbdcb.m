function click_wbdcb(src,callbackdata)

% button down

global scanbox_h nlines dxcal dycal captureDone
p = gca;
x = p.CurrentPoint(1,1);
y = p.CurrentPoint(1,2);

if(~captureDone && x>0 && x<796 && y>0 && y<nlines)
    dx = (x-796/2) * dxcal;
    dy = (y-nlines/2) * dycal;
    tri_send('KBY',0,1,-dx);    % send the centering commands
    tri_send('KBY',0,2,-dy);
end


