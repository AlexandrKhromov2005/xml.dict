#!/bin/bash

echo "=== Диагностика проблем с AFL корпусом ==="
echo ""

# 1. Проверяем, какой файл AFL считает favored
echo "1. Анализ favored файла:"
FAVORED_FILE=$(find out/main/queue/ -name "*+orig:*" | head -1)
if [ -n "$FAVORED_FILE" ]; then
    echo "Favored файл: $(basename $FAVORED_FILE)"
    echo "Размер: $(wc -c < $FAVORED_FILE) байт"
    echo "Содержимое:"
    head -n 10 "$FAVORED_FILE"
else
    echo "Favored файл не найден в out/main/queue/"
fi

echo ""
echo "=================================="

# 2. Тестируем поведение программы на разных файлах
echo "2. Тестирование поведения программы:"
echo ""

TEMP_LOG="/tmp/fuzz_test.log"
UNIQUE_OUTPUTS=0

for file in in/*.xml; do
    echo -n "Тестируем $(basename $file): "
    
    # Запускаем программу и сохраняем exit code и первые строки вывода
    timeout 5 ./snbckctl -l "$file" > "$TEMP_LOG" 2>&1
    EXIT_CODE=$?
    OUTPUT_HASH=$(head -n 5 "$TEMP_LOG" | md5sum | cut -d' ' -f1)
    
    echo "Exit: $EXIT_CODE, Output hash: $OUTPUT_HASH"
    
    # Показываем первые строки вывода для анализа
    if [ $EXIT_CODE -ne 0 ]; then
        echo "  Ошибка: $(head -n 1 $TEMP_LOG 2>/dev/null || echo 'Нет вывода')"
    fi
done

echo ""
echo "=================================="

# 3. Проверяем детерминированность
echo "3. Проверка детерминированности:"
echo ""

TEST_FILE="in/minimal.xml"
if [ -f "$TEST_FILE" ]; then
    echo "Запускаем $TEST_FILE 3 раза подряд:"
    for i in 1 2 3; do
        echo -n "Запуск $i: "
        timeout 2 ./snbckctl -l "$TEST_FILE" 2>&1 | head -n 1 | tr -d '\n'
        echo " (exit: $?)"
    done
else
    echo "Тестовый файл $TEST_FILE не найден"
fi

echo ""
echo "=================================="

# 4. Анализируем размеры файлов корпуса
echo "4. Анализ корпуса:"
echo ""

echo "Размеры файлов:"
for file in in/*.xml; do
    size=$(wc -c < "$file")
    echo "  $(basename $file): $size байт"
done | sort -k2 -n

echo ""
echo "Файлы больше 10KB (могут быть проигнорированы AFL):"
find in/ -name "*.xml" -size +10k -exec ls -lh {} \;

echo ""
echo "=================================="

# 5. Проверяем coverage с помощью gcov (если доступно)
echo "5. Анализ coverage (если программа скомпилирована с --coverage):"
echo ""

if [ -f "snbckctl.gcda" ] || [ -f "*.gcda" ]; then
    echo "Найдены файлы coverage, анализируем..."
    gcov snbckctl.cpp 2>/dev/null || echo "gcov недоступен или не настроен"
else
    echo "Coverage не настроен. Для детального анализа скомпилируйте с флагами:"
    echo "g++ -g -O0 --coverage -fprofile-arcs -ftest-coverage ..."
fi

echo ""
echo "=================================="

# 6. Рекомендации
echo "6. Рекомендации по исправлению:"
echo ""
echo "Если все файлы дают одинаковые exit codes и похожий вывод:"
echo "  - Проверьте исправления в ParseDescription()"
echo "  - Убедитесь что readFromFd() работает правильно"
echo "  - Добавьте отладочные printf() в код для проверки путей выполнения"
echo ""
echo "Если программа крашится одинаково на всех файлах:"
echo "  - Запустите под GDB: gdb ./snbckctl"
echo "  - Используйте AddressSanitizer: скомпилируйте с -fsanitize=address"
echo ""
echo "Для уменьшения корпуса используйте:"
echo "  afl-cmin -i in/ -o in_minimized/ -- ./snbckctl -l @@"

rm -f "$TEMP_LOG"
