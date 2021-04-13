#include "mex.h"
#include <omp.h>

#define MAXCHAN 4   /* maximum number of channels supported */
#define NCOL 796    /* number of columns */

/* This version allows for up to MAXCHAN channels */

static int n, k, m, j;
static unsigned short int *nchan;                    /* number of channels sampled by Alazaratech card */
static unsigned short int *inMatrix;                 /* 1xN input matrix [nchan 4 1250 nlines]*/
static unsigned short int *outMatrix;                /* [nchan S nlines] uint16*/
static unsigned short int *outMatrixA;               /* [S nlines]     uint16*/
static unsigned short int *outMatrixB;               /* [S nlines]     uint16*/
static unsigned short int *outMatrixC;               /* [S nlines]     uint16*/
static unsigned short int *outMatrixD;               /* [S nlines]     uint16*/
static unsigned char      *outMatrixCData;           /* [3 S nlines]   uint8 -- display data*/
static unsigned int       *inIdx;                    /* [nchan 4 S nlines] uint32 indices into inMatrix */
static unsigned short int *nlines;                   /* number of lines */
static unsigned short int *dispMode;                 /* display mode */
static unsigned short int *nt;                       /* number of threads to use */
static unsigned char      *ttlflag;                  /* ttl flag */
static unsigned char      *cmaps;                    /* 3 256 nchan colormaps for each channel */
static unsigned char      *weights;                  /* 1 x nchan mixing values for colormaps add up to 100 always */

static unsigned short int v[MAXCHAN];
static unsigned char      vh[MAXCHAN];
static unsigned int       tmp[MAXCHAN];
static unsigned int       mixed[3];                  /* blended colormaps */

static unsigned int nch;

void mexFunction( int nlhs, mxArray *plhs[],int nrhs, const mxArray *prhs[])
{
    /* input data */

    inMatrix   = (unsigned short int *) mxGetPr(prhs[0]);
    inIdx      = (unsigned int *)       mxGetPr(prhs[1]);
    outMatrix  = (unsigned short int *) mxGetPr(prhs[2]);
    outMatrixA = (unsigned short int *) mxGetPr(prhs[3]);
    outMatrixB = (unsigned short int *) mxGetPr(prhs[4]);
    outMatrixC = (unsigned short int *) mxGetPr(prhs[5]);
    outMatrixD = (unsigned short int *) mxGetPr(prhs[6]);
    outMatrixCData = (unsigned char *)  mxGetPr(prhs[7]);
    nlines     = (unsigned short int *) mxGetPr(prhs[8]);
    nt         = (unsigned short int *) mxGetPr(prhs[9]);
    nchan      = (unsigned short int *) mxGetPr(prhs[10]);
    ttlflag    = (unsigned char *)      mxGetPr(prhs[11]);
    cmaps      = (unsigned char *)      mxGetPr(prhs[12]);
    weights    = (unsigned char *)      mxGetPr(prhs[13]);

    ttlflag[0] = (unsigned char) (inMatrix[0] & 0x0003);
    nch = *nchan;

    omp_set_dynamic(1);
    omp_set_num_threads((int) *nt);

    #pragma omp parallel for private(tmp,j,k,m,v,vh,mixed)

    for(n=0;n<NCOL*(*nlines);n++){              /* for each pixel */

        mixed[0] = mixed[1] = mixed[2] = 0;

        for(j=0;j<nch;j++){        
                
                tmp[j]=0;            
                
                for (k=0;k<4;k++) {           
                    m = j+k*nch+n*4*nch;       
                    tmp[j] += inMatrix[inIdx[m]];
                }

                v[j] =  (unsigned short int) (tmp[j]/4);    /* remove lower 2 bits */
                outMatrix[nch*n+j] = v[j];                  /* place data in output matrix */
                
                switch (j) {                                /* place data in corresponding output channel matrix */
                    case 0: 
                        outMatrixA[n] = v[j];               /* used for online processing */
                        break;
                    case 1:
                        outMatrixB[n] = v[j];
                        break;
                    case 2:
                        outMatrixC[n] = v[j];
                        break;
                    case 3:
                        outMatrixD[n] = v[j];
                        break;
                    default:
                    break;
                }            
                
                vh[j] = v[j]/256;      

                for(m=0;m<3;m++) mixed[m] += (unsigned int)weights[j]*(unsigned int)cmaps[3*(255-vh[j])+m+3*256*j];

            }

        for (j=0;j<3;j++){                       /* for each gun -- R, G, B */
            outMatrixCData[3*n+j] = (unsigned char) (mixed[j]/100);
        }

    } /* for each pixel*/
}

        

