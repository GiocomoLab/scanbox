
function mode = dmd_getrunstate
[sts,mode] = calllib('PortabilityLayer','DLP_Status_GetSeqRunState',0);
