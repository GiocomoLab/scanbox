% horizontal flip

function sts = dmd_verticalflip(flag)
sts = calllib('PortabilityLayer','DLP_Display_VerticalFlip',uint8(flag));

