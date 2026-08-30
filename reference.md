# Reference: структура бенчмарка и контракт плагина

## Дерево рабочей директории

```
{WORK_DIR}/
├── CMakeLists.txt
├── src/
│   ├── {op}_plugin.cpp          # Torch entry point, TORCH_LIBRARY export
│   └── kernels/
│       ├── {op}_kernel.cu       # __global__ kernels
│       └── {op}_kernel.cuh      # declarations, Param structs
├── scripts/
│   └── run_benchmark.sh
├── tasks/                       # BENCHMARK_TASKS_DIR (входные кейсы)
│   ├── case_001.json
│   └── ...
├── reports/                     # REPORT_DIR (создаётся при запуске)
│   └── {op}/
│       └── benchmark_*.json
└── build/                       # BUILD_DIR (генерируется cmake)
    └── lib{op}_plugin.so
```

## Контракт `{op}_plugin.cpp`

Бенчмарк ожидает:

1. C++-функцию с сигнатурой, заданной в task-файлах (обычно `at::Tensor`).
2. Внутри — вызов CUDA kernel из `{op}_kernel.cu`.
3. Экспорт через `TORCH_LIBRARY`:

```cpp
// Фрагмент шаблона — НЕ менять имена макросов/namespace бенчмарка
TORCH_LIBRARY_FRAGMENT(benchmark_ops, m) {
    m.def("{op}(Tensor input) -> Tensor");
}

TORCH_LIBRARY_IMPL(benchmark_ops, CUDA, m) {
    m.impl("{op}", &{op}_forward_cuda);
}
```

Имя оператора в `m.def` / `m.impl` должно совпадать с `OPERATOR_NAME` и флагом `--operator`.

## Якоря вставки (полный список)

### `{op}_plugin.cpp`

```cpp
#include <torch/extension.h>
#include "kernels/{op}_kernel.cuh"

// @INSERT_TORCH_IMPL
// <-- сюда: forward-функция, подготовка tensor, вызов launch_{op}_kernel(...)

TORCH_LIBRARY_FRAGMENT(benchmark_ops, m) {
    m.def("{op}(Tensor input) -> Tensor");
}

TORCH_LIBRARY_IMPL(benchmark_ops, CUDA, m) {
    m.impl("{op}", &{op}_forward_cuda);
}
```

### `{op}_kernel.cu`

```cpp
#include "{op}_kernel.cuh"

// @INSERT_CUDA_KERNEL
// <-- сюда: __global__ void ... и launch_* wrapper
```

### `{op}_kernel.cuh`

```cpp
#pragma once
#include <cuda_runtime.h>
#include <cstdint>

// @INSERT_CUDA_DECL
// <-- сюда: struct Params, __global__ declarations, void launch_{op}_kernel(...)
```

### `CMakeLists.txt`

```cmake
# @INSERT_OPERATOR_SOURCES
set(OPERATOR_SOURCES
    src/{op}_plugin.cpp
    src/kernels/{op}_kernel.cu
)
```

## Формат task-файла (пример)

`tasks/case_001.json`:

```json
{
  "operator": "sum",
  "input_shape": [1024, 1024],
  "dtype": "float32",
  "warmup": 10,
  "iterations": 100
}
```

Скрипт `run_benchmark.sh` читает все `*.json` из `--tasks-dir` и пишет сводный отчёт в `--report-dir`.

## Нестандартный перенос

Если исходный оператор разбит иначе (несколько `.cu`, header-only, PyBind вместо TORCH_LIBRARY):

1. Зафиксировать фактическую структуру `SOURCE_DIR` в ответе пользователю.
2. Kernel-код → `{kernel_cu}`, host glue → `{plugin_cpp}`.
3. Дополнительные `.cu` — добавить в `OPERATOR_SOURCES` в CMake.
4. Не менять публичный API бенчмарка без явного запроса.
