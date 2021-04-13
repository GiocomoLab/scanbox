
function sts = dmd_writelut(lut)

[sts,~] = calllib('PortabilityLayer','DLP_RegIO_WriteImageOrderLut',dmd_getbpp,uint16(lut),uint16(length(lut)));

