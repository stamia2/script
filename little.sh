#!/bin/sh

# 检查输入参数
if [ $# -eq 0 ]; then
    echo "用法: $0 \"要开机启动的完整命令\""
    echo "示例: $0 
    exit 1
fi

COMMAND="$1"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
    echo "错误: 此脚本需要root权限运行"
    exit 1
fi

# 检查Alpine系统
if ! grep -q "Alpine" /etc/os-release; then
    echo "错误: 此脚本仅适用于Alpine系统"
    exit 1
fi

# 创建本地启动脚本
LOCAL_SCRIPT="/usr/local/bin/startup_command.sh"

cat > "$LOCAL_SCRIPT" << EOF
#!/bin/sh
# 开机启动脚本
# 由一键脚本生成于 $(date)

# 等待网络就绪
sleep 10

# 执行用户命令
$COMMAND
EOF

chmod +x "$LOCAL_SCRIPT"

# 创建OpenRC服务文件
SERVICE_FILE="/etc/init.d/startup_command"

cat > "$SERVICE_FILE" << EOF
#!/sbin/openrc-run
# 开机启动服务
# 由一键脚本生成于 $(date)

name="startup_command"
description="用户自定义开机启动命令"

command="$LOCAL_SCRIPT"
command_background=true
pidfile="/var/run/\${name}.pid"

depend() {
    need net
    after firewall
}
EOF

chmod +x "$SERVICE_FILE"

# 添加服务到启动项
rc-update add startup_command default

echo "✅ 开机启动已设置完成!"
echo "📝 服务名称: startup_command"
echo "📋 启动命令: $COMMAND"
echo "📁 本地脚本: $LOCAL_SCRIPT"
echo "🔧 服务文件: $SERVICE_FILE"
echo ""
echo "重启后生效，如需立即测试可运行: $LOCAL_SCRIPT"
echo "如需移除服务，请运行: rc-update del startup_command"
