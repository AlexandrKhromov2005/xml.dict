#!/bin/bash

# Создаем новую директорию для минимального корпуса
rm -rf in_minimal
mkdir -p in_minimal

# 1. Совсем пустой файл
touch in_minimal/empty.xml

# 2. Один символ
echo "a" > in_minimal/single_char.xml

# 3. Только XML declaration
echo '<?xml version="1.0"?>' > in_minimal/only_declaration.xml

# 4. Неправильный XML (без закрывающего тега)
echo '<?xml version="1.0"?><backup' > in_minimal/unclosed_tag.xml

# 5. Минимальный валидный XML
echo '<?xml version="1.0"?><backup id="1" date="01.01.2024 00:00:00"/>' > in_minimal/minimal_valid.xml

# 6. С missing id (должен возвращать другую ошибку)
echo '<?xml version="1.0"?><backup date="01.01.2024 00:00:00"/>' > in_minimal/no_id.xml

# 7. С missing date (другая ошибка)  
echo '<?xml version="1.0"?><backup id="123"/>' > in_minimal/no_date.xml

# 8. С компонентом
cat > in_minimal/with_component.xml << 'EOF'
<?xml version="1.0"?>
<backup id="123" date="01.01.2024 00:00:00">
    <core>
        <file>/test.conf</file>
    </core>
</backup>
EOF

echo "Создан минимальный корпус в in_minimal/ с 8 файлами"
echo "Теперь запустите фаззинг с минимальным корпусом:"
echo "afl-fuzz -i in_minimal/ -o out_minimal/ -m none -M main -- ./snbckctl -l @@"
