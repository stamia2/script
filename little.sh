#!/bin/sh

# Alpine Startup Manager
# GitHub: https://github.com/你的用户名/你的仓库名
# 一键添加Alpine系统开机启动命令

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 显示用法
show_usage() {
    echo -e "${GREEN}Alpine Startup Manager${NC}"
    echo -e "Usage: $0 [option] [command]"
    echo -e ""
    echo -e "Options:"
    echo -e "  add \"<command>\"   添加开机启动命令"
    echo -e "  remove            移除开机启动"
    echo -e "  status            查看服务状态"
    echo -e "  list              列出所有自定义启动项"
    echo -e "  help              显示帮助信息"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0 add \"curl -s https://example.com/script.sh | bash\""
    echo -e "  $0 add 'bash <(curl -Ls https://main.ssss.nyc.mn/sb.sh)'"
    echo -e "  $0 remove"
    echo -e "  $0 status"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Error: This script requires root privileges${NC}"
        exit 1
    fi
}

# 检查Alpine系统
check_alpine() {
    if ! grep -q "Alpine" /etc/os-release 2>/dev/null; then
        echo -e "${RED}Error: This script only works on Alpine Linux${NC}"
        exit 1
    fi
}

# 添加启动命令
add_startup() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: Please provide a command to run${NC}"
        show_usage
        exit 1
    fi

    local COMMAND="$*"
    local SERVICE_NAME="custom_startup"
    local LOCAL_SCRIPT="/usr/local/bin/${SERVICE_NAME}.sh"
    local SERVICE_FILE="/etc/init.d/${SERVICE_NAME}"

    echo -e "${BLUE}📝 Adding startup command...${NC}"

    # 创建本地执行脚本
    cat > "$LOCAL_SCRIPT" << EOF
#!/bin/sh
# Auto-generated startup script
# Created on $(date)

# Wait for network
sleep 15

# Execute user command
echo "[$(date)] Starting custom startup command..." >> /var/log/${SERVICE_NAME}.log
exec >> /var/log/${SERVICE_NAME}.log 2>&1

$COMMAND
EOF

    chmod +x "$LOCAL_SCRIPT"

    # 创建OpenRC服务
    cat > "$SERVICE_FILE" << EOF
#!/sbin/openrc-run
# Auto-generated OpenRC service
# Created on $(date)

name="${SERVICE_NAME}"
description="Custom startup command"

command="${LOCAL_SCRIPT}"
command_background=true
pidfile="/var/run/\${name}.pid"

depend() {
    need net
    after firewall
    before local
}

start() {
    ebegin "Starting custom startup command"
    start-stop-daemon --start --exec \$command --make-pidfile --pidfile \$pidfile --background
    eend \$?
}

stop() {
    ebegin "Stopping custom startup command"
    start-stop-daemon --stop --pidfile \$pidfile
    eend \$?
}
EOF

    chmod +x "$SERVICE_FILE"

    # 添加到启动项
    rc-update add "$SERVICE_NAME" default >/dev/null 2>&1

    echo -e "${GREEN}✅ Startup command added successfully!${NC}"
    echo -e "${YELLOW}📋 Command:${NC} $COMMAND"
    echo -e "${YELLOW}📁 Script:${NC} $LOCAL_SCRIPT"
    echo -e "${YELLOW}🔧 Service:${NC} $SERVICE_FILE"
    echo -e "${YELLOW}📊 Log:${NC} /var/log/${SERVICE_NAME}.log"
    echo -e ""
    echo -e "${BLUE}To start immediately:${NC} /etc/init.d/${SERVICE_NAME} start"
    echo -e "${BLUE}To check status:${NC} /etc/init.d/${SERVICE_NAME} status"
}

# 移除启动命令
remove_startup() {
    local SERVICE_NAME="custom_startup"
    local LOCAL_SCRIPT="/usr/local/bin/${SERVICE_NAME}.sh"
    local SERVICE_FILE="/etc/init.d/${SERVICE_NAME}"

    echo -e "${BLUE}🗑️ Removing startup command...${NC}"

    # 停止服务
    if [ -f "$SERVICE_FILE" ]; then
        rc-update del "$SERVICE_NAME" default >/dev/null 2>&1
        /etc/init.d/"$SERVICE_NAME" stop >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
    fi

    # 删除脚本
    rm -f "$LOCAL_SCRIPT"
    rm -f "/var/log/${SERVICE_NAME}.log"

    echo -e "${GREEN}✅ Startup command removed successfully!${NC}"
}

# 查看状态
check_status() {
    local SERVICE_NAME="custom_startup"
    
    if [ -f "/etc/init.d/$SERVICE_NAME" ]; then
        echo -e "${GREEN}✅ Startup service is installed${NC}"
        /etc/init.d/"$SERVICE_NAME" status
    else
        echo -e "${RED}❌ No startup service found${NC}"
    fi
}

# 主程序
case "${1:-}" in
    add|install)
        check_root
        check_alpine
        shift
        add_startup "$@"
        ;;
    remove|uninstall)
        check_root
        check_alpine
        remove_startup
        ;;
    status)
        check_status
        ;;
    list)
        echo -e "${BLUE}Custom startup services:${NC}"
        ls /etc/init.d/ | grep -E '(custom|startup)' || echo "No custom startup services found"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        if [ $# -eq 0 ]; then
            show_usage
        else
            check_root
            check_alpine
            add_startup "$@"
        fi
        ;;
esac
