#!/usr/bin/env bash
# afl_pause_monitor_per_worker.sh
# Monitor each worker (master + slaves) separately and pause ALL afl-fuzz if any worker stalls.
#
# Usage:
#   ./afl_pause_monitor_per_worker.sh /path/to/outdir [-i 60] [-r] [-n]

set -euo pipefail

OUTDIR=""
INTERVAL=60
RESUME_ON_NEW=0
DRY_RUN=0

TWO_HOURS=$((2*3600))
EIGHT_HOURS=$((8*3600))
MIN_TESTS_FOR_2H_RULE=100000

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

usage() {
    echo "Usage: $0 /path/to/outdir [-i interval] [-r] [-n]"
    exit 2
}

[ $# -lt 1 ] && usage
OUTDIR="$1"; shift || true
while getopts ":i:rn" opt; do
  case $opt in
    i) INTERVAL="$OPTARG" ;;
    r) RESUME_ON_NEW=1 ;;
    n) DRY_RUN=1 ;;
    *) usage ;;
  esac
done

# find all fuzzer_stats (master + slaves)
find_stats() {
    find "$OUTDIR" -mindepth 1 -maxdepth 2 -name fuzzer_stats 2>/dev/null
}

read_stat() {
    local file="$1" key="$2"
    awk -F: -v k="$key" '$1==k {print $2; exit}' "$file" 2>/dev/null | awk '{print $1}'
}

find_afl_pids() {
    local pid cmd out
    out=()
    for pidpath in /proc/[0-9]*; do
        pid=${pidpath#/proc/}
        if [ -r "$pidpath/cmdline" ]; then
            cmd=$(tr '\0' ' ' < "$pidpath/cmdline" 2>/dev/null || true)
            if [[ "$cmd" == *afl-fuzz* && "$cmd" == *"$OUTDIR"* ]]; then
                out+=("$pid")
            fi
        fi
    done
    printf '%s\n' "${out[@]:-}"
}

send_signal() {
    local sig="$1"; shift
    local pids=("$@")
    [ "${#pids[@]}" -eq 0 ] && return
    for pid in "${pids[@]}"; do
        if [ "$DRY_RUN" -eq 1 ]; then
            log "[DRY-RUN] would send $sig to $pid"
        else
            kill -"$sig" "$pid" 2>/dev/null && log "Sent $sig to $pid" || log "Failed $sig to $pid"
        fi
    done
}

# associative arrays: one entry per worker dir
declare -A last_paths last_execs last_found_time

# initialize per-worker state
for f in $(find_stats); do
    worker=$(basename "$(dirname "$f")")
    p=$(read_stat "$f" "paths_total"); p=${p:-0}
    e=$(read_stat "$f" "execs_done");  e=${e:-0}
    last_paths["$worker"]=$p
    last_execs["$worker"]=$e
    last_found_time["$worker"]=$(date +%s)
    log "Init $worker: paths=$p execs=$e"
done

paused=0

log "Monitoring OUTDIR=$OUTDIR every ${INTERVAL}s resume=$RESUME_ON_NEW dryrun=$DRY_RUN"

while true; do
    any_new=0
    any_stalled=0

    for f in $(find_stats); do
        worker=$(basename "$(dirname "$f")")

        paths=$(read_stat "$f" "paths_total"); paths=${paths:-0}
        execs=$(read_stat "$f" "execs_done");  execs=${execs:-0}
        now=$(date +%s)

        if [ "$paths" -gt "${last_paths[$worker]}" ]; then
            log "[$worker] new paths: ${last_paths[$worker]} -> $paths (execs=$execs)"
            last_paths["$worker"]=$paths
            last_execs["$worker"]=$execs
            last_found_time["$worker"]=$now
            any_new=1
        else
            since=$(( now - ${last_found_time[$worker]} ))
            cond1=$(( since >= TWO_HOURS && execs >= MIN_TESTS_FOR_2H_RULE ? 1 : 0 ))
            cond2=$(( since >= EIGHT_HOURS ? 1 : 0 ))
            if [ $cond1 -eq 1 ] || [ $cond2 -eq 1 ]; then
                log "[$worker] STALLED (no new paths for ${since}s, execs=$execs)"
                any_stalled=1
            fi
        fi
    done

    if [ $any_stalled -eq 1 ]; then
        if [ $paused -eq 0 ]; then
            readarray -t pids < <(find_afl_pids)
            log "Pausing ALL afl-fuzz (one worker stalled)"
            send_signal STOP "${pids[@]}"
            paused=1
        fi
    elif [ $any_new -eq 1 ] && [ $paused -eq 1 ] && [ $RESUME_ON_NEW -eq 1 ]; then
        readarray -t pids < <(find_afl_pids)
        log "Resuming ALL afl-fuzz (new path appeared)"
        send_signal CONT "${pids[@]}"
        paused=0
    fi

    sleep "$INTERVAL"
done
