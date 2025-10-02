#!/bin/bash
# prepare_fuzzing.sh - Подготовка корпуса и словаря для AFL

set -e

echo "=== Preparing AFL fuzzing environment ==="

# Очистка старых данных
rm -rf in out
mkdir -p in

echo "[+] Creating corpus..."

# Тест 1: Минимальный запрос
cat > in/test1.xml << 'EOF'
<?xml version="1.0"?>
<request id="1" plugin="test">
<command/>
</request>
EOF

# Тест 2: С параметрами
cat > in/test2.xml << 'EOF'
<?xml version="1.0"?>
<request id="2" plugin="firewall">
<command name="add">
<param>value</param>
</command>
</request>
EOF

# Тест 3: Вложенная структура
cat > in/test3.xml << 'EOF'
<?xml version="1.0"?>
<request id="3" plugin="userservice">
<command name="list">
<filter>
<name>test</name>
<group>users</group>
</filter>
</command>
</request>
EOF

# Тест 4: С CDATA
cat > in/test4.xml << 'EOF'
<?xml version="1.0"?>
<request id="4" plugin="logger">
<command name="log">
<message><![CDATA[Test message]]></message>
</command>
</request>
EOF

# Тест 5: С атрибутами initiator
cat > in/test5.xml << 'EOF'
<?xml version="1.0"?>
<request id="5" plugin="system" initiator="admin" initiator_proc="snserv">
<command name="status"/>
</request>
EOF

echo "[+] Created $(ls in/ | wc -l) test files"

# Создание словаря (БЕЗ комментариев!)
echo "[+] Creating dictionary..."
cat > xml.dict << 'DICT_EOF'
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
"<?xml"
"version="
"encoding="
"UTF-8"
"<request"
"</request>"
"<command"
"</command>"
"<param"
"</param>"
"<ack"
"</ack>"
"<nack"
"</nack>"
"id=\""
"plugin=\""
"name=\""
"initiator=\""
"test"
"firewall"
"userservice"
"admin"
"root"
"true"
"false"
DICT_EOF

echo "[+] Dictionary created: xml.dict"

# Проверка
echo ""
echo "=== Verification ==="
echo "Corpus files:"
ls -lh in/
echo ""
echo "Dictionary:"
wc -l xml.dict
echo ""
echo "Sample corpus file:"
head -5 in/test1.xml
echo ""
echo "✓ Ready to fuzz!"
echo ""
echo "Run: afl-fuzz -i in -o out -m none -x xml.dict -- ./snserv"
