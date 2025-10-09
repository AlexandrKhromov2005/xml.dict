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
declare -A FUZZER_STOPPED

# Логирование
LOG_FILE="fuzzing_monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Инициализация
init_fuzzer_data() {
    local fuzzer=$1
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
        echo "0:0:0:0"
        return
    fi
    
    local total_paths=$(grep "^paths_total" "$stats_file" | awk '{print $3}')
    local execs_done=$(grep "^execs_done" "$stats_file" | awk '{print $3}')
    local last_find=$(grep "^last_find" "$stats_file" | awk '{print $3}')
    local last_crash=$(grep "^last_crash" "$stats_file" | awk '{print $3}')
    
    # Если значения пустые, установить 0
    total_paths=${total_paths:-0}
    execs_done=${execs_done:-0}
    last_find=${last_find:-0}
    last_crash=${last_crash:-0}
    
    echo "${total_paths}:${execs_done}:${last_find}:${last_crash}"
}

# Конвертация Unix timestamp в секунды назад
get_seconds_since() {
    local timestamp=$1
    local current_time=$(date +%s)
    
    # Если timestamp = 0, значит никогда не находили
    if [[ $timestamp -eq 0 ]]; then
        echo "999999999"  # Очень большое число
        return
    fi
    
    echo $((current_time - timestamp))
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
    IFS=':' read -r total_paths execs_done last_find last_crash <<< "$stats"
    
    # Проверка, что фаззер вообще запущен (есть fuzzer_stats)
    if [[ ! -f "${SYNC_DIR}/${fuzzer}/fuzzer_stats" ]]; then
        return
    fi
    
    # Вычислить время без новых путей на основе last_find
    local time_no_paths=$(get_seconds_since $last_find)
    
    # Если last_find = 0 и фаззер только запустился, не останавливать
    if [[ $last_find -eq 0 ]]; then
        # Проверить, как давно запущен фаззер
        local fuzzer_start=$(stat -c %Y "${SYNC_DIR}/${fuzzer}/fuzzer_stats" 2>/dev/null || echo $current_time)
        local running_time=$((current_time - fuzzer_start))
        
        # Если фаззер работает меньше 10 минут, не останавливать
        if [[ $running_time -lt 600 ]]; then
            return
        fi
        
        # Если работает больше 10 минут и last_find всё ещё 0, 
        # использовать время запуска как базу
        time_no_paths=$running_time
    fi
    
    # Условие 1: 8 часов без новых путей
    if [[ $time_no_paths -ge $MAX_TIME_NO_PATHS ]]; then
        log "${RED}[STOP]${NC} $fuzzer: Нет новых путей более 8 часов (last_find: $(date -d @$last_find '+%Y-%m-%d %H:%M:%S'))"
        stop_fuzzer "$fuzzer" "8 hours without new paths"
        return
    fi
    
    # Условие 2: 2 часа без новых путей + >= 100k тестов
    if [[ $time_no_paths -ge $SHORT_TIME_NO_PATHS ]] && [[ $execs_done -ge $MIN_EXECS ]]; then
        log "${RED}[STOP]${NC} $fuzzer: Нет новых путей более 2 часов и выполнено >= 100k тестов (last_find: $(date -d @$last_find '+%Y-%m-%d %H:%M:%S'))"
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
    
    # Если время очень большое (фаззер не нашёл пути)
    if [[ $seconds -gt 99999999 ]]; then
        echo "NEVER"
        return
    fi
    
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Форматирование Unix timestamp в читаемую дату
format_date() {
    local timestamp=$1
    
    if [[ $timestamp -eq 0 ]]; then
        echo "NEVER"
    else
        date -d @$timestamp '+%Y-%m-%d %H:%M:%S'
    fi
}

# Отображение статуса всех фаззеров
display_status() {
    local current_time=$(date +%s)
    
    echo ""
    echo "================================================================================"
    echo "                          FUZZING MONITOR STATUS"
    echo "                          $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
    printf "%-10s %-10s %-15s %-20s %-12s %-12s\n" \
        "FUZZER" "STATUS" "TIME_NO_PATHS" "LAST_FIND" "PATHS" "EXECS"
    echo "--------------------------------------------------------------------------------"
    
    for fuzzer in master slave1 slave2 slave3; do
        local stats=$(parse_fuzzer_stats "$fuzzer")
        IFS=':' read -r total_paths execs_done last_find last_crash <<< "$stats"
        
        # Вычислить время без новых путей
        local time_no_paths=$(get_seconds_since $last_find)
        local formatted_time=$(format_time $time_no_paths)
        local formatted_date=$(format_date $last_find)
        
        local status="${GREEN}RUNNING${NC}"
        if [[ ${FUZZER_STOPPED[$fuzzer]} -eq 1 ]]; then
            status="${RED}STOPPED${NC}"
        fi
        
        # Проверка, что фаззер запущен
        if [[ ! -f "${SYNC_DIR}/${fuzzer}/fuzzer_stats" ]]; then
            status="${YELLOW}NOT_STARTED${NC}"
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
        
        printf "%-10s %-20s ${time_color}%-15s${NC} %-20s %-12s ${execs_color}%-12s${NC}\n" \
            "$fuzzer" \
            "$(echo -e $status)" \
            "$formatted_time" \
            "$formatted_date" \
            "$total_paths" \
            "$execs_done"
    done
    
    echo "================================================================================"
    echo "Stop Conditions:"
    echo "  1) No new paths for 8 hours (${MAX_TIME_NO_PATHS}s / $(format_time $MAX_TIME_NO_PATHS))"
    echo "  2) No new paths for 2 hours (${SHORT_TIME_NO_PATHS}s / $(format_time $SHORT_TIME_NO_PATHS)) + >= ${MIN_EXECS} execs"
    echo "================================================================================"
    
    # Дополнительная статистика
    echo ""
    echo "Additional Stats:"
    for fuzzer in master slave1 slave2 slave3; do
        if [[ -f "${SYNC_DIR}/${fuzzer}/fuzzer_stats" ]]; then
            local stats=$(parse_fuzzer_stats "$fuzzer")
            IFS=':' read -r total_paths execs_done last_find last_crash <<< "$stats"
            
            # Получить дополнительные данные
            local crashes=$(grep "^saved_crashes" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            local hangs=$(grep "^saved_hangs" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            local cycles=$(grep "^cycles_done" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            
            crashes=${crashes:-0}
            hangs=${hangs:-0}
            cycles=${cycles:-0}
            
            printf "  %-10s: Crashes: %-5s Hangs: %-5s Cycles: %-5s\n" \
                "$fuzzer" "$crashes" "$hangs" "$cycles"
        fi
    done
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
    log "Stop condition 1: No paths for $(format_time $MAX_TIME_NO_PATHS)"
    log "Stop condition 2: No paths for $(format_time $SHORT_TIME_NO_PATHS) + >= ${MIN_EXECS} execs"
    
    check_dependencies
    
    # Инициализация данных фаззеров
    for fuzzer in "${!FUZZERS[@]}"; do
        init_fuzzer_data "$fuzzer"
    done
    
    local last_display_time=$(date +%s)
    local iteration=0
    
    # Показать начальный статус
    display_status
    
    while true; do
        local current_time=$(date +%s)
        
        # Проверка каждого фаззера
        for fuzzer in master slave1 slave2 slave3; do
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
        local active_count=0
        for fuzzer in "${!FUZZERS[@]}"; do
            if [[ ${FUZZER_STOPPED[$fuzzer]} -eq 0 ]]; then
                ((active_count++))
            fi
        done
        
        log "[CHECK] Iteration $iteration - Active fuzzers: ${active_count}/4"
        
        sleep $CHECK_INTERVAL
    done
    
    log "${GREEN}[DONE]${NC} Мониторинг завершен"
    
    # Финальная сводка
    echo ""
    echo "================================================================================"
    echo "                          FINAL SUMMARY"
    echo "================================================================================"
    
    local total_paths=0
    local total_execs=0
    local total_crashes=0
    local total_hangs=0
    
    for fuzzer in master slave1 slave2 slave3; do
        if [[ -f "${SYNC_DIR}/${fuzzer}/fuzzer_stats" ]]; then
            local paths=$(grep "^paths_total" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            local execs=$(grep "^execs_done" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            local crashes=$(grep "^saved_crashes" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            local hangs=$(grep "^saved_hangs" "${SYNC_DIR}/${fuzzer}/fuzzer_stats" | awk '{print $3}')
            
            total_paths=$((total_paths + ${paths:-0}))
            total_execs=$((total_execs + ${execs:-0}))
            total_crashes=$((total_crashes + ${crashes:-0}))
            total_hangs=$((total_hangs + ${hangs:-0}))
        fi
    done
    
    echo "Total unique paths found: $total_paths"
    echo "Total executions: $total_execs"
    echo "Total crashes: $total_crashes"
    echo "Total hangs: $total_hangs"
    echo "================================================================================"
}

# Обработка сигналов
trap 'log "${YELLOW}[SIGNAL]${NC} Получен сигнал завершения"; exit 0' SIGINT SIGTERM

# Запуск
main
