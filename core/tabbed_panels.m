global scanbox_h
f = figure;
tgroup = uitabgroup('Parent', f);
atab = cell(0);
ch = scanbox_h.Children;
k = 1;
for i = 1:length(ch)
    if(isa(ch(i),'matlab.ui.container.Panel'))
        atab{k} =  uitab('Parent', tgroup, 'Title', ch(i).Title);
        ch(i).Parent = atab{k};
        ch(i).Units = 'normalized';
        p = ch(i).Position;
        p(1) = (1-p(3))/2;
        p(2) = (1-p(4))/2;
        ch(i).Position = p;
        k = k+1;
    end
end
