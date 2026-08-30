---
name: cuda-operator-benchmark
description: >-
  Адаптирует CUDA-оператор из исходной директории под бенчмарк: копирует
  фрагменты кода в целевую структуру файлов, собирает плагин и запускает
  скрипт тестирования. Использовать при адаптации операторов под бенчмарк,
  интеграции torch-плагинов, CUDA kernel в benchmark harness, или когда
  пользователь упоминает operator benchmark, plugin.cpp, run_benchmark.
---

# CUDA Operator Benchmark Adapter

Скилл описывает перенос реализации CUDA-оператора из **исходной директории**
в **рабочую директорию** с фиксированной структурой бенчмарка, сборку и запуск тестов.

## Преамбула: переменные конфигурации

Перед началом работы **определи и зафиксируй** значения переменных.
Приоритет источников: явное указание пользователя в промпте → значения по умолчанию из таблицы.

| Переменная | Обозначение | Описание | Значение по умолчанию |
|------------|-------------|----------|----------------------|
| `OPERATOR_NAME` | `{op}` | Имя оператора в snake_case (`sum`, `layer_norm`) | Спросить у пользователя или вывести из имени исходной папки |
| `SOURCE_DIR` | — | Директория с исходным кодом оператора (откуда копируем) | Указана пользователем |
| `WORK_DIR` | — | Рабочая директория бенчмарка (куда вставляем) | `./benchmark_{op}/` в текущей директории |
| `BENCHMARK_TASKS_DIR` | — | Директория с задачами/кейсами бенчмарка | `{WORK_DIR}/tasks/` |
| `REPORT_DIR` | — | Директория для отчётов бенчмарка | `{WORK_DIR}/reports/{op}/` |
| `TEMPLATE_DIR` | — | Шаблон целевой структуры (скелет без реализации) | `<путь к скилу>/templates/benchmark_scaffold/` |
| `SKILL_ROOT` | — | Корень скила (где лежит этот SKILL.md) | Определяется при чтении скила |
| `BUILD_DIR` | — | Директория сборки (out-of-source) | `{WORK_DIR}/build/` |
| `BUILD_CMD` | — | Команда сборки после адаптации | `cmake --build {BUILD_DIR} -j` |

### Производные пути (не менять вручную — вычислять из переменных)

```
{op}           = OPERATOR_NAME
{work}         = WORK_DIR
{src}          = SOURCE_DIR
{tasks}        = BENCHMARK_TASKS_DIR
{reports}      = REPORT_DIR
{build}        = BUILD_DIR

# Целевые файлы (зависят от OPERATOR_NAME)
{plugin_cpp}   = {work}/src/{op}_plugin.cpp
{kernel_cu}    = {work}/src/kernels/{op}_kernel.cu
{kernel_cuh}   = {work}/src/kernels/{op}_kernel.cuh
{cmake}        = {work}/CMakeLists.txt
{bench_script} = {work}/scripts/run_benchmark.sh

# Исходные файлы (типичные имена в SOURCE_DIR — уточнить по факту)
{src_kernel}   = {src}/kernel.cu          # или {src}/kernels/{op}.cu
{src_impl}     = {src}/impl.cpp           # torch-обёртка, если есть
{src_header}   = {src}/{op}.h             # заголовок, если есть
```

### Разрешение WORK_DIR

1. Если пользователь указал путь в промпте — использовать его как `WORK_DIR`.
2. Иначе создать `{cwd}/benchmark_{op}/` (не перезаписывать существующую без подтверждения).
3. Создать `REPORT_DIR` и `BUILD_DIR`, если их нет.

---

## Карта вставки кода

Каждый целевой файл содержит **якоря** — маркеры, куда вставляется код из `SOURCE_DIR`.
Не заменяй весь файл целиком, если в шаблоне есть инфраструктура (includes, exports, registration).

| Целевой файл | Источник | Что вставлять | Якорь в шаблоне |
|--------------|----------|---------------|-----------------|
| `{plugin_cpp}` | `{src_impl}` или `{src}/plugin.cpp` | Тело torch-функции, вызов кернеля, регистрация в TORCH_LIBRARY | `// @INSERT_TORCH_IMPL` |
| `{kernel_cu}` | `{src_kernel}` | CUDA kernel и device-функции | `// @INSERT_CUDA_KERNEL` |
| `{kernel_cuh}` | `{src_header}` | Объявления kernel, struct params | `// @INSERT_CUDA_DECL` |
| `{cmake}` | — | Добавить `{op}_kernel.cu` и `{op}_plugin.cpp` в target | `# @INSERT_OPERATOR_SOURCES` |

### Правила переноса

1. **Прочитай** все файлы в `SOURCE_DIR` перед копированием; сопоставь с таблицей.
2. **Сохрани** сигнатуры, ожидаемые бенчмарком (имена entry-point в `{plugin_cpp}` не менять).
3. **Адаптируй** include-пути под целевую структуру (`#include "kernels/{op}_kernel.cuh"`).
4. **Не копируй** тестовый main, standalone launchers, README из `SOURCE_DIR`.
5. Если фрагмент не помещается ни в один якорь — добавь в `reference.md` секцию «Нестандартный перенос» и спроси пользователя.

---

## Workflow

```
Task Progress:
- [ ] 1. Зафиксировать переменные преамбулы (вывести таблицу значений в ответ)
- [ ] 2. Создать WORK_DIR из TEMPLATE_DIR (если ещё не существует)
- [ ] 3. Подставить {op} в имена файлов и пути внутри шаблона
- [ ] 4. Вставить код оператора по карте вставки
- [ ] 5. Обновить CMakeLists.txt (sources, CUDA arch если нужно)
- [ ] 6. Собрать: cmake -S {work} -B {build} && {BUILD_CMD}
- [ ] 7. Запустить scripts/run_benchmark.sh с опциями
- [ ] 8. Проверить отчёт в REPORT_DIR
```

### Шаг 1. Инициализация рабочей директории

```bash
# Если WORK_DIR новая — скопировать скелет
cp -r {TEMPLATE_DIR}/* {WORK_DIR}/

# Переименовать placeholder-файлы (если в шаблоне operator_plugin.cpp)
mv {WORK_DIR}/src/operator_plugin.cpp {plugin_cpp} 2>/dev/null || true
mv {WORK_DIR}/src/kernels/operator_kernel.cu {kernel_cu} 2>/dev/null || true
mv {WORK_DIR}/src/kernels/operator_kernel.cuh {kernel_cuh} 2>/dev/null || true

# Заменить плейсхолдер OPERATOR_NAME внутри файлов
find {WORK_DIR} -type f \( -name '*.cpp' -o -name '*.cu' -o -name '*.cuh' -o -name 'CMakeLists.txt' \) \
  -exec sed -i 's/OPERATOR_NAME/{op}/g' {} +
```

### Шаг 2. Сборка

```bash
cmake -S {work} -B {build} -DCMAKE_BUILD_TYPE=Release
{BUILD_CMD}
```

Ожидаемый артефакт: `{build}/lib{op}_plugin.so` (или путь из CMakeLists.txt).

### Шаг 3. Запуск бенчмарка

Использовать скрипт из рабочей директории:

```bash
bash {bench_script} \
  --operator {op} \
  --report-dir {reports} \
  --tasks-dir {tasks} \
  --plugin {build}/lib{op}_plugin.so
```

Полный список опций — в [scripts/run_benchmark.sh](scripts/run_benchmark.sh) (`--help`).

---

## Примеры

### Пример 1: оператор `sum`

| Переменная | Значение |
|------------|----------|
| `OPERATOR_NAME` | `sum` |
| `SOURCE_DIR` | `/path/to/operators/sum` |
| `WORK_DIR` | `./benchmark_sum/` |
| `BENCHMARK_TASKS_DIR` | `./benchmark_sum/tasks/` |
| `REPORT_DIR` | `./benchmark_sum/reports/sum/` |

Целевые файлы:
- `benchmark_sum/src/sum_plugin.cpp`
- `benchmark_sum/src/kernels/sum_kernel.cu`
- `benchmark_sum/src/kernels/sum_kernel.cuh`

Запуск:
```bash
bash benchmark_sum/scripts/run_benchmark.sh \
  --operator sum \
  --report-dir benchmark_sum/reports/sum \
  --tasks-dir benchmark_sum/tasks \
  --plugin benchmark_sum/build/libsum_plugin.so
```

### Пример 2: пользователь указал WORK_DIR

Промпт: «Адаптируй оператор layer_norm из `~/ops/ln` в `~/bench/custom_ln`»

| Переменная | Значение |
|------------|----------|
| `OPERATOR_NAME` | `layer_norm` |
| `SOURCE_DIR` | `~/ops/ln` |
| `WORK_DIR` | `~/bench/custom_ln` |
| `REPORT_DIR` | `~/bench/custom_ln/reports/layer_norm/` |

---

## Диагностика

| Симптом | Действие |
|---------|----------|
| Сборка: undefined reference to kernel | Проверить, что `{kernel_cu}` добавлен в CMake target |
| Бенчмарк не находит плагин | Передать абсолютный путь в `--plugin` |
| Неверный результат | Сверить сигнатуру torch-функции в `{plugin_cpp}` с контрактом в `tasks/` |
| Нет исходного файла | Вывести список файлов `SOURCE_DIR` и уточнить маппинг у пользователя |

## Дополнительно

- Детальная структура шаблона и контракт entry-point: [reference.md](reference.md)
- Скрипт бенчмарка: [scripts/run_benchmark.sh](scripts/run_benchmark.sh)
