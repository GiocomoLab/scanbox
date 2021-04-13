function sb_title

% refresh scanbox first LCD line

global sb;

fwrite(sb,uint8([254 0 0]));