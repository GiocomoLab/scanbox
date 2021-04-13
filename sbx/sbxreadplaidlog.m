function log = sbxreadplaidlog(fname)

fn = [fname '.log_47'];
fid = fopen(fn,'r');

l = fgetl(fid);
e = [];
while(l~=-1)
    e = [e ; str2num(l)];
    l = fgetl(fid);
end
log{1} = table(e(:,1),e(:,2),'VariableNames',{'frame' 'class'});


sbx = load(fname);
idx = find(sbx.info.event_id == 1);
scanbox_frame = sbx.info.frame(idx);
%scanbox_frame = sbx.info.frame(2:end-1);

% add sbxframe to all logs...

k = 1;
for j = 1: length(log)
    ov_frame = log{j}.frame;
    fit = polyfit(ov_frame,scanbox_frame(k:k+length(ov_frame)-1),1);           % from ov to sbx
    t = table(floor(polyval(fit,ov_frame)),'VariableName',{'sbxframe'});
    log{j} = [log{j} t];
end

