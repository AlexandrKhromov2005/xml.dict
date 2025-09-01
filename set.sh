#!/bin/bash

echo "Создание минимальной структуры директорий для фаззинга..."

# Создаем основные директории
sudo mkdir -p /opt/securitycode/sns/etc/backup.d
sudo mkdir -p /opt/securitycode/sns/usr/backup
sudo mkdir -p /opt/securitycode/sns/share/locale

# Даем права на запись для текущего пользователя
sudo chown -R $(whoami):$(whoami) /opt/securitycode/

# Создаем минимальные файлы конфигурации компонентов
cat > /opt/securitycode/sns/etc/backup.d/core.conf << 'EOF'
[component]
name=core
flag=core
description=Core system configuration
enabled=1
EOF

cat > /opt/securitycode/sns/etc/backup.d/av.conf << 'EOF'
[component]
name=av
flag=av
description=Antivirus configuration
enabled=1
EOF

cat > /opt/securitycode/sns/etc/backup.d/firewall.conf << 'EOF'
[component]
name=firewall
flag=firewall
description=Firewall configuration
enabled=1
EOF

# Создаем файл версии
cat > /opt/securitycode/sns/sn-release << 'EOF'
VERSION=8.0.0
BUILD=test
EOF
