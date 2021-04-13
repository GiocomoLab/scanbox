
function bpp = dmd_getframerate
[sts,bpp] = calllib('PortabilityLayer','DLP_Status_GetSeqDataBPP',0);
