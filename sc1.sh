#!/bin/bash

# Скрипт генерации валидных XML корпусов для AFL фаззинга

OUTPUT_DIR="afl_in"
mkdir -p "$OUTPUT_DIR"

echo "[*] Generating valid XML corpus files..."

# 1. Базовый минимальный XML
cat > "$OUTPUT_DIR/001_minimal.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="1">
  <cmd name="test"/>
</system>
EOF

# 2. С атрибутами в разных местах
cat > "$OUTPUT_DIR/002_attributes.xml" << 'EOF'
<?xml version="1.0"?>
<policy plugin="policy" id="2" user="admin">
  <cmd name="get_all_policies" type="read"/>
</policy>
EOF

# 3. С вложенными элементами
cat > "$OUTPUT_DIR/003_nested.xml" << 'EOF'
<?xml version="1.0"?>
<loginconfig plugin="loginconfig" id="3">
  <cmd name="set_config">
    <param name="key1" value="value1"/>
    <param name="key2" value="value2"/>
  </cmd>
</loginconfig>
EOF

# 4. С текстовым содержимым
cat > "$OUTPUT_DIR/004_text_content.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="4">
  <cmd name="execute">
    <data>Some text data here</data>
  </cmd>
</system>
EOF

# 5. С множественными командами
cat > "$OUTPUT_DIR/005_multiple_cmds.xml" << 'EOF'
<?xml version="1.0"?>
<policy plugin="policy" id="5">
  <cmd name="get_policies"/>
  <cmd name="set_policy"/>
  <cmd name="delete_policy"/>
</policy>
EOF

# 6. С CDATA секцией
cat > "$OUTPUT_DIR/006_cdata.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="6">
  <cmd name="script">
    <![CDATA[
      echo "test"
      ls -la
    ]]>
  </cmd>
</system>
EOF

# 7. С различными типами плагинов
cat > "$OUTPUT_DIR/007_pamconfig.xml" << 'EOF'
<?xml version="1.0"?>
<pamconfig plugin="pamconfig" id="7">
  <cmd name="get_config"/>
</pamconfig>
EOF

# 8. С initiator атрибутами
cat > "$OUTPUT_DIR/008_initiator.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="8" initiator="admin" initiator_proc="bash">
  <cmd name="status"/>
</system>
EOF

# 9. Длинные значения атрибутов
cat > "$OUTPUT_DIR/009_long_attrs.xml" << 'EOF'
<?xml version="1.0"?>
<policy plugin="policy" id="9">
  <cmd name="create" description="This is a very long description that might test buffer handling in the XML parser and attribute processing code">
    <data>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA</data>
  </cmd>
</policy>
EOF

# 10. Специальные символы (escaped)
cat > "$OUTPUT_DIR/010_special_chars.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="10">
  <cmd name="test">
    <data attr="value&amp;test">&lt;test&gt; &quot;quoted&quot; &apos;single&apos;</data>
  </cmd>
</system>
EOF

# 11. Пустые теги
cat > "$OUTPUT_DIR/011_empty_tags.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="11">
  <cmd name="empty"/>
  <param/>
</system>
EOF

# 12. Много вложенности
cat > "$OUTPUT_DIR/012_deep_nesting.xml" << 'EOF'
<?xml version="1.0"?>
<policy plugin="policy" id="12">
  <level1>
    <level2>
      <level3>
        <level4>
          <level5>
            <cmd name="deep"/>
          </level5>
        </level4>
      </level3>
    </level2>
  </level1>
</policy>
EOF

# 13. Много атрибутов
cat > "$OUTPUT_DIR/013_many_attrs.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="13" attr1="val1" attr2="val2" attr3="val3" attr4="val4" attr5="val5">
  <cmd name="test" a="1" b="2" c="3" d="4" e="5"/>
</system>
EOF

# 14. Unicode символы
cat > "$OUTPUT_DIR/014_unicode.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<system plugin="system" id="14">
  <cmd name="test">
    <data>Привет мир! 你好世界 🚀</data>
  </cmd>
</system>
EOF

# 15. Минималистичный без объявления
cat > "$OUTPUT_DIR/015_no_declaration.xml" << 'EOF'
<system plugin="system" id="15">
  <cmd name="test"/>
</system>
EOF

# 16. С комментариями
cat > "$OUTPUT_DIR/016_comments.xml" << 'EOF'
<?xml version="1.0"?>
<!-- This is a comment -->
<system plugin="system" id="16">
  <!-- Another comment -->
  <cmd name="test"/>
  <!-- Final comment -->
</system>
EOF

# 17. Разные имена плагинов
for plugin in "loginconfig" "pamconfig" "policy" "system"; do
  cat > "$OUTPUT_DIR/017_${plugin}.xml" << EOF
<?xml version="1.0"?>
<${plugin} plugin="${plugin}" id="17">
  <cmd name="test"/>
</${plugin}>
EOF
done

# 18. Пустой корневой элемент
cat > "$OUTPUT_DIR/018_empty_root.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="18"/>
EOF

# 19. Численные значения
cat > "$OUTPUT_DIR/019_numbers.xml" << 'EOF'
<?xml version="1.0"?>
<system plugin="system" id="19">
  <cmd name="calc">
    <num>12345</num>
    <num>-67890</num>
    <num>3.14159</num>
  </cmd>
</system>
EOF

# 20. Смешанный контент
cat > "$OUTPUT_DIR/020_mixed.xml" << 'EOF'
<?xml version="1.0"?>
<policy plugin="policy" id="20">
  Text before
  <cmd name="test">Inner text</cmd>
  Text after
</policy>
EOF

echo "[+] Generated $(ls -1 $OUTPUT_DIR/*.xml 2>/dev/null | wc -l) corpus files in $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/"
