% compile mex files

p = which('compile');
idx = max(strfind(p,'\'));
cp = pwd;
cd(p(1:idx-1));
mex -v alazarReshapeCData2_openmp.c   COMPFLAGS="/openmp $COMPFLAGS" CFLAGS="\$CFLAGS -fopenmp" LDFLAGS="\$LDFLAGS -fopenmp" -v -largeArrayDims
mex -v alazarReshapeCData2bi_openmp.c COMPFLAGS="/openmp $COMPFLAGS" CFLAGS="\$CFLAGS -fopenmp" LDFLAGS="\$LDFLAGS -fopenmp" -v -largeArrayDims
clear mex
cd(cp);