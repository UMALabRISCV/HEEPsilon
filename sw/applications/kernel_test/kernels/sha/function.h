#ifndef _CGRA_FUNCTION_H_
#define _CGRA_FUNCTION_H_

#define N_ITERS 80

int32_t* sha_transform(int32_t W[]){
	for (int i = 16; i < N_ITERS; ++i)
		W[i] = W[i-3] ^ W[i-8] ^ W[i-14] ^ W[i-16];
	return W;
}

#endif // _CGRA_FUNCTION_H_