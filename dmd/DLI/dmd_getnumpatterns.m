
function np = dmd_getnumpatterns
[sts,np] = calllib('PortabilityLayer','DLP_Status_GetSeqDataNumPatterns',0);
