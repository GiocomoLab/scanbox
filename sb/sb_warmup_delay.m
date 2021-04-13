function sb_warmup_delay(p)

% controls the warmup delay period (in tens of msec)

global sb;

fwrite(sb,uint8([11 0 p]));