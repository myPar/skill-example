#pragma once

#include <cuda_runtime.h>
#include <cstdint>

// @INSERT_CUDA_DECL

void launch_OPERATOR_NAME_kernel(
    const float* input,
    float* output,
    int64_t n,
    cudaStream_t stream);
