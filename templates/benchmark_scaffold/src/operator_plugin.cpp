#include <torch/extension.h>
#include "kernels/OPERATOR_NAME_kernel.cuh"

// @INSERT_TORCH_IMPL

at::Tensor OPERATOR_NAME_forward_cuda(const at::Tensor& input) {
    TORCH_CHECK(input.is_cuda(), "input must be a CUDA tensor");
    TORCH_CHECK(input.scalar_type() == at::kFloat, "only float32 supported in scaffold");

    auto output = torch::empty_like(input);
    launch_OPERATOR_NAME_kernel(
        input.data_ptr<float>(),
        output.data_ptr<float>(),
        static_cast<int64_t>(input.numel()),
        at::cuda::getCurrentCUDAStream());
    return output;
}

TORCH_LIBRARY_FRAGMENT(benchmark_ops, m) {
    m.def("OPERATOR_NAME(Tensor input) -> Tensor");
}

TORCH_LIBRARY_IMPL(benchmark_ops, CUDA, m) {
    m.impl("OPERATOR_NAME", &OPERATOR_NAME_forward_cuda);
}
