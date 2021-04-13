function sb_deadband_period(p)

% controls the period of the deadband pwm
% has to be 1245 < p < 1500

% call sb_deadband AFTER db_period

global sb;

p = 1500-p;
fwrite(sb,uint8([10 0 p]));