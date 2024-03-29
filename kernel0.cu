
#include <assert.h>

#include "common.h"
#include "timer.h"

__global__ void nw_0(int* matrix, unsigned char* sequence1_d, unsigned char* sequence2_d, int* scores_d, unsigned int numSequences) {

	unsigned long long int base = SEQUENCE_LENGTH*SEQUENCE_LENGTH*blockIdx.x;
	unsigned int segment = SEQUENCE_LENGTH*blockIdx.x;
    unsigned int tidx = threadIdx.x;
	int row, col, top, left, topleft, insertion, deletion, match, max;

	for(unsigned int i=0; i<SEQUENCE_LENGTH; ++i)
	{ 
		if(tidx <= i)
		{
			row = i-tidx;
			col = tidx;
			
			if(col == 0 && row == 0) {
				top = DELETION;
				left = INSERTION;
				topleft = 0;
			}		
			else if(col == 0) {
				top = matrix[base + SEQUENCE_LENGTH*(row-1) + col];
				left = (row+1)*INSERTION;
				topleft = row*INSERTION;
			}	
			else if(row==0) {
				top = (col+1)*DELETION;
				left = matrix[base + SEQUENCE_LENGTH*row + (col-1)];
				topleft = col*INSERTION;
			}
			else {
				top = matrix[base + SEQUENCE_LENGTH*(row-1) + col];
				left = matrix[base + SEQUENCE_LENGTH*row + (col-1)];
				topleft = matrix[base + SEQUENCE_LENGTH*(row-1) + (col-1)];
			}
			
			insertion = top + INSERTION;
			deletion = left + DELETION;
			match = topleft;

			if(sequence1_d[segment + col] == sequence2_d[segment + row]) {
				match += MATCH;
			}
			else {
				match += MISMATCH;
			}

			if(insertion > deletion) {
				max = insertion;
			}
			else {
				max = deletion;
			}

			if(match > max) {
				max = match;
			}

			matrix[base + SEQUENCE_LENGTH*row + col] = max;
		}				
		__syncthreads();
	}
        
	for(int i=SEQUENCE_LENGTH-1; i>0; --i)
	{
		if(tidx < i)
		{
			row = SEQUENCE_LENGTH - tidx - 1;
			col = SEQUENCE_LENGTH + tidx - i;

			top  = matrix[base + SEQUENCE_LENGTH*(row-1) + col];
			left = matrix[base + SEQUENCE_LENGTH*row + (col-1)];
			topleft = matrix[base + SEQUENCE_LENGTH*(row-1) + (col-1)];

			insertion = top + INSERTION;
			deletion = left + DELETION;
			match = topleft;

			if(sequence1_d[segment + col] == sequence2_d[segment + row]) {
				match += MATCH;
			}
			else {
				match += MISMATCH;
			}

			if(insertion > deletion) {
				max = insertion;
			}
			else {
				max = deletion;
			}

			if(match > max){
				max = match;
			}

			matrix[base + SEQUENCE_LENGTH*row + col] = max;
		}
		__syncthreads();
	}

	if(threadIdx.x == 0)
	{
		scores_d[blockIdx.x] = matrix[base + SEQUENCE_LENGTH*(SEQUENCE_LENGTH-1) + (SEQUENCE_LENGTH-1)];
	}

}


void nw_gpu0(unsigned char* sequence1_d, unsigned char* sequence2_d, int* scores_d, unsigned int numSequences) {
    
    assert(SEQUENCE_LENGTH <= 1024); // You can assume the sequence length is not more than 1024

	int* matrix;
    cudaMalloc((void**)&matrix,sizeof(int)*SEQUENCE_LENGTH*SEQUENCE_LENGTH*numSequences);
	
	int numThreadsPerBlock = SEQUENCE_LENGTH;
    int numBlocks = numSequences;
	nw_0 <<<numBlocks, numThreadsPerBlock>>> (matrix, sequence1_d,sequence2_d,scores_d,numSequences);
    cudaFree(matrix);
}
