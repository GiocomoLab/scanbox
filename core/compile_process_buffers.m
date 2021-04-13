% compile mex files

p = which('compile_process_buffers');
idx = max(strfind(p,'\'));
cp = pwd;
cd(p(1:idx-1));
mex -v process_buffer.c  COMPFLAGS="/openmp $COMPFLAGS" CFLAGS="\$CFLAGS -fopenmp" LDFLAGS="\$LDFLAGS -fopenmp" -v -largeArrayDims
clear mex
cd(cp);