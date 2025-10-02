#!/bin/bash

CORPUS_DIR="in"


cat > "$CORPUS_DIR/seed_001.xml" << 'EOF'
<?xml version="1.0"?>
<request id="1" plugin="test">
  <command/>
</request>
EOF

cat > "$CORPUS_DIR/seed_002.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<request id="2" plugin="firewall">
  <command name="add_rule">
    <param name="source">192.168.1.1</param>
    <param name="dest">192.168.1.2</param>
  </command>
</request>
EOF

cat > "$CORPUS_DIR/seed_003.xml" << 'EOF'
<?xml version="1.0"?>
<request id="3" plugin="userservice">
  <command name="add_user">
    <user>
      <name>testuser</name>
      <group>users</group>
      <permissions>
        <read>true</read>
        <write>false</write>
      </permissions>
    </user>
  </command>
</request>
EOF

cat > "$CORPUS_DIR/seed_004.xml" << 'EOF'
<?xml version="1.0"?>
<request id="4" plugin="logger">
  <command name="log">
    <message><![CDATA[Log message with <special> & characters]]></message>
  </command>
</request>
EOF

cat > "$CORPUS_DIR/seed_005.xml" << 'EOF'
<?xml version="1.0"?>
<request id="5" plugin="system" initiator="admin" initiator_proc="snserv">
  <command name="status"/>
</request>
EOF

cat > "$CORPUS_DIR/seed_006.xml" << 'EOF'
<?xml version="1.0"?>
<request id="6" plugin="">
  <command/>
</request>
EOF

cat > "$CORPUS_DIR/seed_007.xml" << 'EOF'
<?xml version="1.0"?>
<request id="7" plugin="nonexistent_plugin_12345">
  <command name="test"/>
</request>
EOF

cat > "$CORPUS_DIR/seed_008.xml" << 'EOF'
<?xml version="1.0"?>
<request id="8" plugin="test">
  <command>
    <data>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA</data>
  </command>
</request>
EOF

cat > "$CORPUS_DIR/seed_009.xml" << 'EOF'
<?xml version="1.0"?>
<request id="9" plugin="test">
  <command>
    <value>&lt;test&gt;&amp;&quot;&apos;</value>
  </command>
</request>
EOF

cat > "$CORPUS_DIR/seed_010.xml" << 'EOF'
<?xml version="1.0"?>
<request id="10" plugin="batch">
  <command name="cmd1"/>
  <command name="cmd2"/>
  <command name="cmd3"/>
</request>
EOF

cat > "$CORPUS_DIR/seed_011.xml" << 'EOF'
<?xml version="1.0"?>
<!-- This is a test request -->
<request id="11" plugin="test">
  <!-- Command section -->
  <command name="test">
    <!-- Parameters -->
    <param>value</param>
  </command>
</request>
EOF

cat > "$CORPUS_DIR/seed_012.xml" << 'EOF'
<?xml version="1.0"?>
<request id="12" plugin="test">
  <command name="unclosed"
</request>
EOF

cat > "$CORPUS_DIR/seed_013.xml" << 'EOF'
<?xml version="1.0"?>
<sn:request xmlns:sn="http://secretnet.example.com" id="13" plugin="test">
  <sn:command/>
</sn:request>
EOF

cat > "$CORPUS_DIR/seed_014.xml" << 'EOF'
<?xml version="1.0"?>
<request id="14" plugin="test"/>
EOF

cat > "$CORPUS_DIR/seed_015.xml" << 'EOF'
<?xml version="1.0"?>
<request id="4294967295" plugin="test">
  <command>
    <value>-2147483648</value>
    <value>2147483647</value>
    <value>0</value>
  </command>
</request>
EOF

echo "Created 15 seed files in $CORPUS_DIR/"
