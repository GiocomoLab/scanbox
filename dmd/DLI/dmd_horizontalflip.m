% horizontal flip

function sts = dmd_horizontalflip(flag)
sts = calllib('PortabilityLayer','DLP_Display_HorizontalFlip',uint8(flag));

