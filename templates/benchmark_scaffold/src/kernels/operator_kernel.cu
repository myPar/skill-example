#include "OPERATOR_NAME_kernel.cuh"

// @INSERT_CUDA_KERNEL

__global__ void OPERATOR_NAME_kernel_impl(const float* input, float* output, int64_t n) {
    int64_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        output[idx] = input[idx];  // placeholder — replace with operator logic
    }
}

void launch_OPERATOR_NAME_kernel(
    const float* input,
    float* output,
    int64_t n,
    cudaStream_t stream) {
    const int threads = 256;
    const int blocks = static_cast<int>((n + threads - 1) / threads);
    OPERATOR_NAME_kernel_impl<<<blocks, threads, 0, stream>>>(input, output, n);
}
