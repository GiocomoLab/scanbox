
function mode = dmd_getdatamode
[sts,mode] = calllib('PortabilityLayer','DLP_Status_GetSeqDataMode',0);
