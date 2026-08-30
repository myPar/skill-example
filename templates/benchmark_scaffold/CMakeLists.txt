cmake_minimum_required(VERSION 3.18)
project(benchmark_operator LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CUDA_STANDARD 17)

find_package(Torch REQUIRED)

# @INSERT_OPERATOR_SOURCES
set(OPERATOR_SOURCES
    src/OPERATOR_NAME_plugin.cpp
    src/kernels/OPERATOR_NAME_kernel.cu
)

add_library(OPERATOR_NAME_plugin SHARED ${OPERATOR_SOURCES})
target_link_libraries(OPERATOR_NAME_plugin PRIVATE "${TORCH_LIBRARIES}")
target_include_directories(OPERATOR_NAME_plugin PRIVATE src src/kernels)
set_property(TARGET OPERATOR_NAME_plugin PROPERTY CUDA_ARCHITECTURES native)
