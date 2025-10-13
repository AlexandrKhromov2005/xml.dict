#!/bin/bash

# Скрипт проверки валидности XML корпусов

INPUT_DIR="${1:-afl_in}"
BINARY="${2:-./snserv}"
RESULTS_FILE="validation_results.txt"

if [ ! -d "$INPUT_DIR" ]; then
    echo "[!] Error: Directory $INPUT_DIR not found"
    exit 1
fi

if [ ! -f "$BINARY" ]; then
    echo "[!] Error: Binary $BINARY not found"
    exit 1
fi

echo "[*] Validating corpus files in $INPUT_DIR/"
echo "[*] Using binary: $BINARY"
echo ""
echo "========================================" > "$RESULTS_FILE"
echo "Corpus Validation Results" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "========================================" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

TOTAL=0
VALID=0
INVALID=0
CRASHED=0

for xmlfile in "$INPUT_DIR"/*.xml; do
    if [ ! -f "$xmlfile" ]; then
        continue
    fi
    
    TOTAL=$((TOTAL + 1))
    filename=$(basename "$xmlfile")
    
    echo -n "Testing $filename ... "
    
    # 1. XML синтаксис проверка (xmllint если доступен)
    if command -v xmllint &> /dev/null; then
        if ! xmllint --noout "$xmlfile" 2>/dev/null; then
            echo "❌ INVALID XML SYNTAX"
            echo "[$filename] INVALID - XML syntax error" >> "$RESULTS_FILE"
            INVALID=$((INVALID + 1))
            continue
        fi
    fi
    
    # 2. Запуск через программу
    timeout 2s "$BINARY" "$xmlfile" > /dev/null 2>&1
    EXIT_CODE=$?
    
    case $EXIT_CODE in
        0)
            echo "✅ VALID (exit 0)"
            echo "[$filename] VALID - Normal exit" >> "$RESULTS_FILE"
            VALID=$((VALID + 1))
            ;;
        124)
            echo "⏱️  TIMEOUT"
            echo "[$filename] TIMEOUT - Execution timeout" >> "$RESULTS_FILE"
            INVALID=$((INVALID + 1))
            ;;
        139)
            echo "💥 SEGFAULT"
            echo "[$filename] CRASHED - Segmentation fault" >> "$RESULTS_FILE"
            CRASHED=$((CRASHED + 1))
            ;;
        134)
            echo "💥 ABORT"
            echo "[$filename] CRASHED - Aborted" >> "$RESULTS_FILE"
            CRASHED=$((CRASHED + 1))
            ;;
        *)
            echo "⚠️  EXIT $EXIT_CODE"
            echo "[$filename] WARNING - Exit code $EXIT_CODE" >> "$RESULTS_FILE"
            INVALID=$((INVALID + 1))
            ;;
    esac
done

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "Summary:" | tee -a "$RESULTS_FILE"
echo "  Total files:   $TOTAL" | tee -a "$RESULTS_FILE"
echo "  Valid:         $VALID" | tee -a "$RESULTS_FILE"
echo "  Invalid:       $INVALID" | tee -a "$RESULTS_FILE"
echo "  Crashed:       $CRASHED" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""
echo "[+] Results saved to $RESULTS_FILE"

# Показать содержимое невалидных файлов
if [ $INVALID -gt 0 ] || [ $CRASHED -gt 0 ]; then
    echo ""
    echo "[*] Details of problematic files:"
    echo ""
    for xmlfile in "$INPUT_DIR"/*.xml; do
        filename=$(basename "$xmlfile")
        if grep -q "\[$filename\] \(INVALID\|CRASHED\)" "$RESULTS_FILE"; then
            echo "--- $filename ---"
            head -5 "$xmlfile"
            echo ""
        fi
    done
fi

exit 0
