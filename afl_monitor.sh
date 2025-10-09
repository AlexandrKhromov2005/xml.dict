#!/bin/bash

# Конфигурация
INPUT_DIR="./in"       # Входная директория с корпусами
SYNC_DIR="./out"       # Выходная директория AFL
CHECK_INTERVAL=60      # Проверка каждую минуту
DISPLAY_INTERVAL=600   # Вывод каждые 10 минут (600 секунд)
MAX_TIME_NO_PATHS=28800  # 8 часов без новых путей (в секундах)
SHORT_TIME_NO_PATHS=7200  # 2 часа без новых путей (в секундах)
MIN_EXECS=100000  # Минимальное количество выполненных тестов

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Массивы для хранения данных о фаззерах
declare -A FUZZERS=( ["master"]=0 ["slave1"]=0 ["slave2"]=0 ["slave3"]=0 )
declare -A LAST_NEW_PATH_TIME
declare -A LAST_TOTAL_PATHS
declare -A LAST_EXECS
declare -A FUZZER_PIDS
declare -A FUZZER_STOPPED

# Логирование
LOG_FILE="fuzzing_monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Инициализация времени последнего нового пути
init_fuzzer_data() {
    local fuzzer=$1
    LAST_NEW_PATH_TIME[$fuzzer]=$(date +%s)
    LAST_TOTAL_PATHS[$fuzzer]=0
    LAST_EXECS[$fuzzer]=0
    FUZZER_STOPPED[$fuzzer]=0
}

# Получить PID фаззера по имени
get_fuzzer_pid() {
    local fuzzer=$1
    local pid=$(pgrep -f "afl-fuzz.*-[MS] ${fuzzer}")
    echo "$pid"
}

# Парсинг fuzzer_stats для конкретного фаззера
parse_fuzzer_stats() {
    local fuzzer=$1
    local stats_file="${SYNC_DIR}/${fuzzer}/fuzzer_stats"
    
    if [[ ! -f "$stats_file" ]]; then
        echo "0:0:0"
        return
    fi
    
    local total_paths=$(grep "^paths_total" "$stats_file" | awk '{print $3}')
    local execs_done=$(grep "^execs_done" "$stats_file" | awk '{print $3}')
    local last_path=$(grep "^last_path" "$stats_file" | awk '{print $3}')
    
    # Если значения пустые, установить 0
    total_paths=${total_paths:-0}
    execs_done=${execs_done:-0}
    last_path=${last_path:-0}
    
    echo "${total_paths}:${execs_done}:${last_path}"
}

# Проверка условий остановки для фаззера
check_stop_conditions() {
    local fuzzer=$1
    local current_time=$(date +%s)
    
    # Если фаззер уже остановлен, пропустить
    if [[ ${FUZZER_STOPPED[$fuzzer]} -eq 1 ]]; then
        return
    fi
    
    # Получить статистику
    local stats=$(parse_fuzzer_stats "$fuzzer")
    IFS=':' read -r total_paths execs_done last_path <<< "$stats"
    
    # Если новые пути найдены, обновить время
    if [[ $total_paths -gt ${LAST_TOTAL_PATHS[$fuzzer]} ]]; then
        LAST_NEW_PATH_TIME[$fuzzer]=$current_time
        LAST_TOTAL_PATHS[$fuzzer]=$total_paths
    fi
    
    LAST_EXECS[$fuzzer]=$execs_done
    
    # Вычислить время без новых путей
    local time_no_paths=$((current_time - ${LAST_NEW_PATH_TIME[$fuzzer]}))
    
    # Условие 1: 8 часов без новых путей
    if [[ $time_no_paths -ge $MAX_TIME_NO_PATHS ]]; then
        log "${RED}[STOP]${NC} $fuzzer: Нет новых путей более 8 часов"
        stop_fuzzer "$fuzzer" "8 hours without new paths"
        return
    fi
    
    # Условие 2: 2 часа без новых путей + >= 100k тестов
    if [[ $time_no_paths -ge $SHORT_TIME_NO_PATHS ]] && [[ $execs_done -ge $MIN_EXECS ]]; then
        log "${RED}[STOP]${NC} $fuzzer: Нет новых путей более 2 часов и выполнено >= 100k тестов"
        stop_fuzzer "$fuzzer" "2 hours without new paths and >= 100k execs"
        return
    fi
}

# Остановка фаззера
stop_fuzzer() {
    local fuzzer=$1
    local reason=$2
    
    local pid=$(get_fuzzer_pid "$fuzzer")
    
    if [[ -n "$pid" ]]; then
        log "${RED}[STOPPING]${NC} $fuzzer (PID: $pid) - Reason: $reason"
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        
        # Проверка, что процесс завершен
        if ps -p "$pid" > /dev/null 2>&1; then
            log "${YELLOW}[WARNING]${NC} $fuzzer (PID: $pid) не остановился, отправляем SIGKILL"
            kill -KILL "$pid" 2>/dev/null
        fi
        
        FUZZER_STOPPED[$fuzzer]=1
        log "${GREEN}[SUCCESS]${NC} $fuzzer остановлен"
    else
        log "${YELLOW}[WARNING]${NC} $fuzzer: PID не найден (возможно уже остановлен)"
        FUZZER_STOPPED[$fuzzer]=1
    fi
}

# Форматирование времени в человекочитаемый вид
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Отображение статуса всех фаззеров
display_status() {
    local current_time=$(date +%s)
    
    echo ""
    echo "======================================================================="
    echo "                    FUZZING MONITOR STATUS"
    echo "                    $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================================="
    printf "%-10s %-10s %-15s %-15s %-15s\n" "FUZZER" "STATUS" "NO_PATHS_TIME" "TOTAL_PATHS" "EXECS_DONE"
    echo "-----------------------------------------------------------------------"
    
    for fuzzer in "${!FUZZERS[@]}"; do
        local stats=$(parse_fuzzer_stats "$fuzzer")
        IFS=':' read -r total_paths execs_done last_path <<< "$stats"
        
        local time_no_paths=$((current_time - ${LAST_NEW_PATH_TIME[$fuzzer]}))
        local formatted_time=$(format_time $time_no_paths)
        
        local status="${GREEN}RUNNING${NC}"
        if [[ ${FUZZER_STOPPED[$fuzzer]} -eq 1 ]]; then
            status="${RED}STOPPED${NC}"
        fi
        
        # Цветовое кодирование времени без путей
        local time_color=""
        if [[ $time_no_paths -ge $MAX_TIME_NO_PATHS ]]; then
            time_color="${RED}"
        elif [[ $time_no_paths -ge $SHORT_TIME_NO_PATHS ]]; then
            time_color="${YELLOW}"
        else
            time_color="${GREEN}"
        fi
        
        # Цветовое кодирование количества тестов
        local execs_color="${GREEN}"
        if [[ $execs_done -ge $MIN_EXECS ]]; then
            execs_color="${BLUE}"
        fi
        
        printf "%-10s %-20s ${time_color}%-15s${NC} %-15s ${execs_color}%-15s${NC}\n" \
            "$fuzzer" \
            "$(echo -e $status)" \
            "$formatted_time" \
            "$total_paths" \
            "$execs_done"
    done
    
    echo "======================================================================="
    echo "Stop Conditions:"
    echo "  1) No new paths for 8 hours (${MAX_TIME_NO_PATHS}s)"
    echo "  2) No new paths for 2 hours (${SHORT_TIME_NO_PATHS}s) + >= ${MIN_EXECS} execs"
    echo "======================================================================="
    echo ""
}

# Проверка наличия afl-whatsup
check_dependencies() {
    if ! command -v afl-whatsup &> /dev/null; then
        echo "${RED}[ERROR]${NC} afl-whatsup не найден. Установите AFL++."
        exit 1
    fi
    
    if [[ ! -d "$SYNC_DIR" ]]; then
        echo "${RED}[ERROR]${NC} Директория синхронизации $SYNC_DIR не найдена."
        exit 1
    fi
    
    if [[ ! -d "$INPUT_DIR" ]]; then
        echo "${YELLOW}[WARNING]${NC} Входная директория $INPUT_DIR не найдена."
    fi
}

# Основной цикл мониторинга
main() {
    log "${GREEN}[START]${NC} Fuzzing Monitor запущен"
    log "Input directory: $INPUT_DIR"
    log "Output/Sync directory: $SYNC_DIR"
    log "Check interval: ${CHECK_INTERVAL}s, Display interval: ${DISPLAY_INTERVAL}s"
    
    check_dependencies
    
    # Инициализация данных фаззеров
    for fuzzer in "${!FUZZERS[@]}"; do
        init_fuzzer_data "$fuzzer"
    done
    
    local last_display_time=$(date +%s)
    local iteration=0
    
    while true; do
        local current_time=$(date +%s)
        
        # Проверка каждого фаззера
        for fuzzer in "${!FUZZERS[@]}"; do
            check_stop_conditions "$fuzzer"
        done
        
        # Вывод статуса каждые 10 минут
        if [[ $((current_time - last_display_time)) -ge $DISPLAY_INTERVAL ]]; then
            display_status
            last_display_time=$current_time
        fi
        
        # Проверка, все ли фаззеры остановлены
        local all_stopped=1
        for fuzzer in "${!FUZZERS[@]}"; do
            if [[ ${FUZZER_STOPPED[$fuzzer]} -eq 0 ]]; then
                all_stopped=0
                break
            fi
        done
        
        if [[ $all_stopped -eq 1 ]]; then
            log "${BLUE}[INFO]${NC} Все фаззеры остановлены. Завершение мониторинга."
            display_status
            break
        fi
        
        iteration=$((iteration + 1))
        
        # Короткий вывод каждую минуту в лог
        if [[ $((iteration % 1)) -eq 0 ]]; then
            log "[CHECK] Iteration $iteration - Active fuzzers: $((4 - $(echo "${FUZZER_STOPPED[@]}" | tr ' ' '\n' | grep -c 1)))/4"
        fi
        
        sleep $CHECK_INTERVAL
    done
    
    log "${GREEN}[DONE]${NC} Мониторинг завершен"
}

# Обработка сигналов
trap 'log "${YELLOW}[SIGNAL]${NC} Получен сигнал завершения"; exit 0' SIGINT SIGTERM

# Запуск
main
