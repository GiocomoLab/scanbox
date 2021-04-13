
function exp = dmd_getexposure
[sts,exp] = calllib('PortabilityLayer','DLP_Status_GetSeqDataExposure',0);
