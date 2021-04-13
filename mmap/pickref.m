function pickref(src,event)

global refimg;

[file,path,indx] = uigetfile;
if ~isempty(file)
    theimg = load([path file]);
end
refimg = mean(theimg.img,3);