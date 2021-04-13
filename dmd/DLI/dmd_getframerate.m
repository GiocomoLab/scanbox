
function fr = dmd_getframerate
[sts,fr] = calllib('PortabilityLayer','DLP_Status_GetSeqDataFrameRate',0);
