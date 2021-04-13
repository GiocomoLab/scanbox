
function sts = dmd_runbatchfile(fn)

[sts,~] = calllib('PortabilityLayer','RunBatchFile',[fn '.bf'],0);
  