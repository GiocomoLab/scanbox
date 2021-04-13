#include "mex.h"
#include <omp.h>

static int n, k, m, j;
static unsigned short int *inMatrix;                 /* 1xN input matrix [2 4 1250 nlines]*/
static unsigned short int *outMatrix;                /* [2 S nlines] uint16*/
static unsigned short int *outMatrixA, *outMatrixB;  /* [S nlines]   uint16*/
static unsigned char      *outMatrixCData;           /* [3 S nlines]   uint8*/
static unsigned int       *inIdx;                    /* [2 4 S nlines] uint32 indices into inMatrix */
static unsigned short int *nlines;
static unsigned short int *dispMode;                 /* display mode */
static unsigned short int *nt;
static unsigned short int *ttlflag;

static    unsigned short int v0,v1;
static    unsigned char vh0;
static    unsigned char vh1;
static    unsigned int tmp[2];

void mexFunction( int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
    /* input data */

    inMatrix   = (unsigned short int *) mxGetPr(prhs[0]);
    inIdx      = (unsigned int *)       mxGetPr(prhs[1]);
    outMatrix  = (unsigned short int *) mxGetPr(prhs[2]);
    outMatrixA = (unsigned short int *) mxGetPr(prhs[3]);
    outMatrixB = (unsigned short int *) mxGetPr(prhs[4]);
    outMatrixCData = (unsigned char *)  mxGetPr(prhs[5]);
    nlines     = (unsigned short int *) mxGetPr(prhs[6]);
    dispMode   = (unsigned short int *) mxGetPr(prhs[7]);
    nt         = (unsigned short int *) mxGetPr(prhs[8]);
    ttlflag    = (unsigned char *) mxGetPr(prhs[9]);


    ttlflag[0] = (unsigned char) (inMatrix[0] & 0x0003);

    omp_set_dynamic(1);
    omp_set_num_threads((int) *nt);

    switch(*dispMode) {
        
        case 1:

            #pragma omp parallel for private(tmp,j,k,m,v0,v1,vh0,vh1) 

            for(n=0;n<796*(*nlines);n++){           /* pixels */
                tmp[0]=0; tmp[1]=0;
                for (j=0;j<4;j++) {                 /* samples/pix */ 
                        for(k=0;k<2;k++) {          /* chan */ 
                            m = k+j*2+n*8;
                            tmp[k] += inMatrix[inIdx[m]];
                        }
                    }
                
                v0 = (unsigned short int) (tmp[0] >> 2);
                v1 = (unsigned short int) (tmp[1] >> 2);

                outMatrix[2*n]   = outMatrixA[n] = v0;
                outMatrix[2*n+1] = outMatrixB[n] = v1;
                
                vh0 = (v0>>8);

                if(vh0){                           /* display */
                    outMatrixCData[3*n]   = outMatrixCData[3*n+2]  = 0;   
                    outMatrixCData[3*n+1] = 255-vh0;
                } else {
                    outMatrixCData[3*n] = outMatrixCData[3*n+1] =  outMatrixCData[3*n+2] = 0xff;   /* saturated */
                }
            }

            
            break;

        case 2:

            #pragma omp parallel for private(tmp,j,k,m,v0,v1,vh0,vh1)

            for(n=0;n<796*(*nlines);n++){           /* pixels */
                tmp[0]=0; tmp[1]=0;
                for (j=0;j<4;j++) {                 /* samples/pix */ 
                        for(k=0;k<2;k++) {          /* chan */ 
                            m = k+j*2+n*8;
                            tmp[k] += inMatrix[inIdx[m]];
                        }
                    }
                
                v0 = (unsigned short int) (tmp[0] >> 2);
                v1 = (unsigned short int) (tmp[1] >> 2);

                outMatrix[2*n]   = outMatrixA[n] = v0;
                outMatrix[2*n+1] = outMatrixB[n] = v1;
                
                vh1 = (v1>>8);

                if(vh1){                           /* display */
                    outMatrixCData[3*n]   = 255-vh1;    /* gray scale */
                    outMatrixCData[3*n+1] = 0;
                    outMatrixCData[3*n+2] = 0;

                } else {
                    outMatrixCData[3*n]   = 0xff;   /* saturated */
                    outMatrixCData[3*n+1] = 0xff;
                    outMatrixCData[3*n+2] = 0xff;
                }
            }

            break;

        default:
            
            #pragma omp parallel for private(tmp,j,k,m,v0,v1,vh0,vh1)

               for(n=0;n<796*(*nlines);n++){           /* pixels */
                tmp[0]=0; tmp[1]=0;
                for (j=0;j<4;j++) {                 /* samples/pix */ 
                        for(k=0;k<2;k++) {          /* chan */ 
                            m = k+j*2+n*8;
                            tmp[k] += inMatrix[inIdx[m]];
                        }
                    }
                
                v0 = (unsigned short int) (tmp[0] >> 2);
                v1 = (unsigned short int) (tmp[1] >> 2);

                outMatrix[2*n]   = outMatrixA[n] = v0;
                outMatrix[2*n+1] = outMatrixB[n] = v1;
                
                vh0 = (v0>>8);
                vh1 = (v1>>8);

                if( vh0>0 && vh1>0) {                    /* display */
                    outMatrixCData[3*n]   = 255 - vh1;    /* merged */
                    outMatrixCData[3*n+1] = 255 - vh0;
                    outMatrixCData[3*n+2] = 0;

                } else {
                    outMatrixCData[3*n]   = 0xff;   /* saturated */
                    outMatrixCData[3*n+1] = 0xff;
                    outMatrixCData[3*n+2] = 0xff;
                }
            }
            
            break;
    }

}
