#!/bin/bash

# Создаем директорию для корпуса если она не существует
mkdir -p in

# 1. Минимальный валидный XML
cat > in/minimal.xml << 'EOF'
<?xml version="1.0"?>
<backup id="1" date="01.01.2023 00:00:00"/>
EOF

# 2. Базовая структура с комментарием
cat > in/basic_with_comment.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<backup id="123" date="15.03.2024 14:30:00" comment="Test backup"/>
EOF

# 3. Структура с core компонентом
cat > in/with_core.xml << 'EOF'
<?xml version="1.0"?>
<backup id="001" date="01.01.2024 12:00:00" version="1.0">
    <core>
        <file>/opt/securitycode/sns/config/main.conf</file>
    </core>
</backup>
EOF

# 4. Структура с несколькими компонентами
cat > in/multi_components.xml << 'EOF'
<?xml version="1.0"?>
<backup id="002" date="02.01.2024 13:00:00" comment="Multi component backup" version="8.0">
    <core>
        <file>/opt/securitycode/sns/config/core.conf</file>
        <file>/opt/securitycode/sns/bin/core</file>
    </core>
    <av>
        <file>/opt/securitycode/sns/config/av.conf</file>
        <file>/opt/securitycode/sns/av/signatures.db</file>
    </av>
</backup>
EOF

# 5. Большая структура с множеством файлов
cat > in/many_files.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<backup id="999" date="31.12.2023 23:59:59" comment="Large backup with many files" version="2.1.0">
    <core>
        <file>/opt/securitycode/sns/config/main.conf</file>
        <file>/opt/securitycode/sns/config/network.conf</file>
        <file>/opt/securitycode/sns/config/security.conf</file>
        <file>/opt/securitycode/sns/bin/daemon</file>
        <file>/opt/securitycode/sns/lib/libcore.so</file>
    </core>
    <firewall>
        <file>/opt/securitycode/sns/firewall/rules.conf</file>
        <file>/opt/securitycode/sns/firewall/whitelist.txt</file>
        <file>/opt/securitycode/sns/firewall/blacklist.txt</file>
    </firewall>
    <av>
        <file>/opt/securitycode/sns/av/engine.conf</file>
        <file>/opt/securitycode/sns/av/signatures.db</file>
        <file>/opt/securitycode/sns/av/quarantine.db</file>
    </av>
</backup>
EOF

# 6. Структура с различными типами компонентов
cat > in/different_components.xml << 'EOF'
<?xml version="1.0"?>
<backup id="555" date="10.06.2024 08:15:30" comment="Different components test">
    <config>
        <file>/etc/sns/main.conf</file>
    </config>
    <users>
        <file>/etc/sns/users.db</file>
        <file>/etc/sns/groups.db</file>
    </users>
    <certificates>
        <file>/opt/securitycode/sns/certs/ca.crt</file>
        <file>/opt/securitycode/sns/certs/server.crt</file>
        <file>/opt/securitycode/sns/certs/client.crt</file>
    </certificates>
    <logs>
        <file>/var/log/sns/system.log</file>
        <file>/var/log/sns/audit.log</file>
    </logs>
</backup>
EOF

# 7. Пустые компоненты (для тестирования обработки)
cat > in/empty_components.xml << 'EOF'
<?xml version="1.0"?>
<backup id="000" date="01.01.2000 00:00:01" comment="Empty components">
    <core>
    </core>
    <av>
    </av>
    <firewall/>
</backup>
EOF

# 8. Длинные строки (потенциальные buffer overflow)
cat > in/long_strings.xml << 'EOF'
<?xml version="1.0"?>
<backup id="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" date="01.01.2024 00:00:00" comment="BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" version="1.0">
    <core>
        <file>/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/very/long/path/to/file/that/might/cause/buffer/overflow/issues/config.conf</file>
    </core>
</backup>
EOF

# 9. Специальные символы и экранирование
cat > in/special_chars.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<backup id="special" date="01.01.2024 12:00:00" comment="Test &amp; special &lt;chars&gt; &quot;quotes&quot; &apos;apostrophe&apos;">
    <core>
        <file>/path/with spaces/and&amp;special&lt;chars&gt;.conf</file>
        <file>/path/with/unicode/файл.conf</file>
    </core>
</backup>
EOF

# 10. Различные форматы даты (потенциальные ошибки парсинга)
cat > in/date_formats.xml << 'EOF'
<?xml version="1.0"?>
<backup id="date_test" date="29.02.2024 25:61:61" comment="Invalid date test" version="0.0.0">
    <core>
        <file>/test/date/parsing.conf</file>
    </core>
</backup>
EOF

# 11. Отсутствующие обязательные атрибуты
cat > in/missing_id.xml << 'EOF'
<?xml version="1.0"?>
<backup date="01.01.2024 00:00:00" comment="Missing ID">
    <core>
        <file>/test/missing/id.conf</file>
    </core>
</backup>
EOF

# 12. Отсутствующая дата
cat > in/missing_date.xml << 'EOF'
<?xml version="1.0"?>
<backup id="no_date" comment="Missing date">
    <core>
        <file>/test/missing/date.conf</file>
    </core>
</backup>
EOF

# 13. Пустые значения атрибутов
cat > in/empty_attributes.xml << 'EOF'
<?xml version="1.0"?>
<backup id="" date="" comment="" version="">
    <core>
        <file></file>
    </core>
</backup>
EOF

# 14. Вложенные элементы (неправильная структура)
cat > in/nested_structure.xml << 'EOF'
<?xml version="1.0"?>
<backup id="nested" date="01.01.2024 00:00:00">
    <core>
        <core>
            <file>/nested/core.conf</file>
        </core>
        <file>/outer/core.conf</file>
    </core>
</backup>
EOF

# 15. Дублирующиеся компоненты
cat > in/duplicate_components.xml << 'EOF'
<?xml version="1.0"?>
<backup id="duplicate" date="01.01.2024 00:00:00">
    <core>
        <file>/first/core.conf</file>
    </core>
    <core>
        <file>/second/core.conf</file>
    </core>
</backup>
EOF

# 16. Неизвестные компоненты
cat > in/unknown_components.xml << 'EOF'
<?xml version="1.0"?>
<backup id="unknown" date="01.01.2024 00:00:00">
    <unknown_component>
        <file>/unknown/component.conf</file>
    </unknown_component>
    <malicious_component>
        <file>/etc/passwd</file>
        <file>/etc/shadow</file>
    </malicious_component>
</backup>
EOF

# 17. Только закрывающие теги (malformed XML)
cat > in/malformed_closing.xml << 'EOF'
<?xml version="1.0"?>
</backup>
</core>
</file>
EOF

# 18. Только открывающие теги (malformed XML)
cat > in/malformed_opening.xml << 'EOF'
<?xml version="1.0"?>
<backup id="malformed" date="01.01.2024 00:00:00">
<core>
<file>/test/malformed.conf
<another_tag
EOF

# 19. Смешанный контент
cat > in/mixed_content.xml << 'EOF'
<?xml version="1.0"?>
<backup id="mixed" date="01.01.2024 00:00:00">
    Mixed text content
    <core>
        Text before file
        <file>/mixed/content.conf</file>
        Text after file
    </core>
    More mixed content
</backup>
EOF

# 20. CDATA секции
cat > in/cdata_section.xml << 'EOF'
<?xml version="1.0"?>
<backup id="cdata" date="01.01.2024 00:00:00" comment="CDATA test">
    <core>
        <file><![CDATA[/path/with/<special>&chars.conf]]></file>
        <file>/normal/path.conf</file>
    </core>
</backup>
EOF

# 21. XML комментарии
cat > in/with_comments.xml << 'EOF'
<?xml version="1.0"?>
<!-- This is a backup XML with comments -->
<backup id="commented" date="01.01.2024 00:00:00">
    <!-- Core component section -->
    <core>
        <file>/commented/file.conf</file>
        <!-- Another comment inside component -->
    </core>
    <!-- End of backup -->
</backup>
EOF

# 22. Очень большой файл (для тестирования производительности)
cat > in/large_backup.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<backup id="large_backup_001" date="01.01.2024 00:00:00" comment="Large backup for performance testing" version="1.0.0">
EOF

# Добавляем много компонентов и файлов
for i in {1..50}; do
    cat >> in/large_backup.xml << EOF
    <component_$i>
        <file>/opt/securitycode/sns/component_$i/config_$i.conf</file>
        <file>/opt/securitycode/sns/component_$i/data_$i.db</file>
        <file>/opt/securitycode/sns/component_$i/binary_$i</file>
        <file>/opt/securitycode/sns/component_$i/library_$i.so</file>
    </component_$i>
EOF
done

echo "</backup>" >> in/large_backup.xml

# 23. Файл с нулевыми байтами
printf '<?xml version="1.0"?>\n<backup id="null" date="01.01.2024 00:00:00">\n<core>\n<file>/path/with\x00null/byte.conf</file>\n</core>\n</backup>' > in/null_bytes.xml

# 24. Только пробелы и переносы строк
cat > in/whitespace_only.xml << 'EOF'




   

	
EOF

# 25. Пустой файл
touch in/empty.xml

# 26. Не XML файл
cat > in/not_xml.txt << 'EOF'
This is not an XML file at all!
It contains random text that should cause parsing errors.
12345
@#$%^&*()
EOF

# 27. JSON вместо XML (частая ошибка)
cat > in/json_instead.xml << 'EOF'
{
  "backup": {
    "id": "json_test",
    "date": "01.01.2024 00:00:00",
    "components": {
      "core": [
        "/json/file.conf"
      ]
    }
  }
}
EOF

# 28. HTML вместо XML
cat > in/html_instead.xml << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Not XML</title></head>
<body>
<backup id="html_test" date="01.01.2024 00:00:00">
<core>
<file>/html/test.conf</file>
</core>
</backup>
</body>
</html>
EOF

# 29. Файл с BOM
printf '\xEF\xBB\xBF<?xml version="1.0" encoding="UTF-8"?>\n<backup id="bom" date="01.01.2024 00:00:00"><core><file>/bom/test.conf</file></core></backup>' > in/with_bom.xml

# 30. Файл со старой версией XML
cat > in/old_xml_version.xml << 'EOF'
<?xml version="1.1" encoding="ISO-8859-1"?>
<backup id="old_version" date="01.01.2024 00:00:00">
    <core>
        <file>/old/version.conf</file>
    </core>
</backup>
EOF
