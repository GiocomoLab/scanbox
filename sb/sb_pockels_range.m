function sb_pockels_range(r)

% set range of pockels dac = r(1) pga = r(2)

global sb;

fwrite(sb,uint8([13 r(1) r(2)]));