#!/usr/bin/env bash
# Запуск бенчмарка CUDA-оператора.
# Копируется в {WORK_DIR}/scripts/ при инициализации из шаблона.

set -euo pipefail

OPERATOR=""
REPORT_DIR=""
TASKS_DIR=""
PLUGIN_PATH=""
WARMUP=10
ITERATIONS=100
VERBOSE=0

usage() {
  cat <<'EOF'
Usage: run_benchmark.sh [OPTIONS]

Обязательные:
  --operator NAME       Имя оператора (совпадает с OPERATOR_NAME / TORCH_LIBRARY op)
  --report-dir PATH     Директория для отчётов бенчмарка
  --tasks-dir PATH      Директория с task-файлами (*.json)
  --plugin PATH         Путь к собранной .so библиотеке плагина

Опциональные:
  --warmup N            Прогрев перед замером (default: 10)
  --iterations N        Число итераций замера (default: 100)
  --verbose             Подробный вывод
  -h, --help            Эта справка

Пример:
  run_benchmark.sh \
    --operator sum \
    --report-dir ./reports/sum \
    --tasks-dir ./tasks \
    --plugin ./build/libsum_plugin.so
EOF
}

log() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    echo "[benchmark] $*"
  fi
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --operator)    OPERATOR="$2"; shift 2 ;;
    --report-dir)  REPORT_DIR="$2"; shift 2 ;;
    --tasks-dir)   TASKS_DIR="$2"; shift 2 ;;
    --plugin)      PLUGIN_PATH="$2"; shift 2 ;;
    --warmup)      WARMUP="$2"; shift 2 ;;
    --iterations)  ITERATIONS="$2"; shift 2 ;;
    --verbose)     VERBOSE=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "unknown option: $1 (use --help)" ;;
  esac
done

[[ -n "${OPERATOR}" ]]    || die "--operator is required"
[[ -n "${REPORT_DIR}" ]]  || die "--report-dir is required"
[[ -n "${TASKS_DIR}" ]]   || die "--tasks-dir is required"
[[ -n "${PLUGIN_PATH}" ]] || die "--plugin is required"

[[ -d "${TASKS_DIR}" ]]   || die "tasks directory not found: ${TASKS_DIR}"
[[ -f "${PLUGIN_PATH}" ]] || die "plugin not found: ${PLUGIN_PATH}"

mkdir -p "${REPORT_DIR}"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_FILE="${REPORT_DIR}/benchmark_${OPERATOR}_${TIMESTAMP}.json"

log "operator=${OPERATOR}"
log "plugin=${PLUGIN_PATH}"
log "tasks=${TASKS_DIR}"
log "report=${REPORT_FILE}"

# --- Заглушка движка бенчмарка ---
# В реальном проекте здесь вызов Python/C++ harness, загружающего PLUGIN_PATH
# и прогоняющего кейсы из TASKS_DIR.
#
# Пример интеграции (раскомментировать и адаптировать):
#   python3 "$(dirname "$0")/benchmark_harness.py" \
#     --operator "${OPERATOR}" \
#     --plugin "${PLUGIN_PATH}" \
#     --tasks-dir "${TASKS_DIR}" \
#     --warmup "${WARMUP}" \
#     --iterations "${ITERATIONS}" \
#     --output "${REPORT_FILE}"

TASK_COUNT=0
for task_file in "${TASKS_DIR}"/*.json; do
  [[ -f "${task_file}" ]] || continue
  TASK_COUNT=$((TASK_COUNT + 1))
  log "task: ${task_file}"
done

[[ "${TASK_COUNT}" -gt 0 ]] || die "no task files (*.json) in ${TASKS_DIR}"

# Минимальный отчёт-заглушка для проверки пайплайна скилла
cat > "${REPORT_FILE}" <<EOF
{
  "operator": "${OPERATOR}",
  "plugin": "${PLUGIN_PATH}",
  "tasks_dir": "${TASKS_DIR}",
  "task_count": ${TASK_COUNT},
  "warmup": ${WARMUP},
  "iterations": ${ITERATIONS},
  "timestamp": "${TIMESTAMP}",
  "status": "stub_ok",
  "note": "Replace stub with real harness in benchmark_harness.py"
}
EOF

echo "benchmark report written: ${REPORT_FILE}"
