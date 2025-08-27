#!/bin/bash

# Universal Startup Manager
# 支持 Alpine, Ubuntu, Debian 系统的一键开机启动管理脚本

set -e

# 显示用法
show_usage() {
    echo "================================================"
    echo "           Universal Startup Manager"
    echo "================================================"
    echo "用法: $0 [选项] [命令]"
    echo ""
    echo "选项:"
    echo "  add \"<命令>\"     添加开机启动命令"
    echo "  remove           移除开机启动"
    echo "  status           查看服务状态"
    echo "  list             列出所有自定义启动项"
    echo "  help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 add \"你的命令\""
    echo "  $0 add 'bash <(curl -Ls https://main.ssss.nyc.mn/sb.sh)'"
    echo "  $0 remove"
    echo "  $0 status"
    echo ""
    echo "或者直接运行 $0 进入交互模式"
    echo "================================================"
}

# 检测系统类型
detect_os() {
    if [ -f /etc/alpine-release ]; then
        echo "alpine"
    elif [ -f /etc/debian_version ]; then
        if grep -q "Ubuntu" /etc/os-release; then
            echo "ubuntu"
        else
            echo "debian"
        fi
    else
        echo "unknown"
    fi
}

# 检查root权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "错误: 此脚本需要root权限运行"
        exit 1
    fi
}

# 检查系统支持
check_os_support() {
    local os_type=$(detect_os)
    case "$os_type" in
        alpine|ubuntu|debian)
            echo "检测到系统: $os_type"
            ;;
        *)
            echo "错误: 不支持的系统类型"
            echo "仅支持 Alpine, Ubuntu, Debian 系统"
            exit 1
            ;;
    esac
}

# 交互式输入命令
interactive_input() {
    echo ""
    echo "🎯 交互式开机启动设置"
    echo "请输入要开机启动的命令:"
    echo "(支持复杂命令和环境变量)"
    echo ""
    echo "示例: UUID=xxx DOMAIN=example.com bash <(curl -Ls URL)"
    echo ""
    read -p "请输入命令: " user_command
    
    if [ -z "$user_command" ]; then
        echo "错误: 命令不能为空"
        exit 1
    fi
    
    echo ""
    echo "您输入的命令是:"
    echo "$user_command"
    echo ""
    read -p "确认添加此命令到开机启动吗? (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        add_startup "$user_command"
    else
        echo "操作已取消"
        exit 0
    fi
}

# 创建执行脚本（通用）
create_startup_script() {
    local command="$1"
    local script_path="$2"
    
    cat > "$script_path" << EOF
#!/bin/bash
# 自动生成的开机启动脚本
# 创建于 $(date)

# 设置环境变量
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 创建日志目录
mkdir -p /var/log/custom_startup
LOG_FILE="/var/log/custom_startup/custom_startup.log"

# 等待网络就绪
echo "[$(date)] 等待网络就绪..." >> "\$LOG_FILE"
sleep 20

# 检查网络连接
for i in {1..10}; do
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        echo "[$(date)] 网络连接正常" >> "\$LOG_FILE"
        break
    else
        echo "[$(date)] 网络未就绪，等待中... (\$i/10)" >> "\$LOG_FILE"
        sleep 5
    fi
    if [ \$i -eq 10 ]; then
        echo "[$(date)] 警告: 网络连接超时，继续执行..." >> "\$LOG_FILE"
    fi
done

# 执行用户命令
echo "[$(date)] 开始执行自定义启动命令..." >> "\$LOG_FILE"
echo "[$(date)] 命令: $command" >> "\$LOG_FILE"

# 切换到根目录，确保正确的工作目录
cd /

# 执行命令并记录输出
{
    echo "=== 命令开始执行 ==="
    $command
    echo "=== 命令执行完成，退出码: \$? ==="
} >> "\$LOG_FILE" 2>&1

echo "[$(date)] 命令执行完成" >> "\$LOG_FILE"
EOF

    chmod +x "$script_path"
}

# 添加启动命令 (Alpine)
add_startup_alpine() {
    local command="$1"
    local service_name="custom_startup"
    local local_script="/usr/local/bin/${service_name}.sh"
    local service_file="/etc/init.d/${service_name}"

    echo "正在为Alpine系统配置开机启动..."

    # 创建执行脚本
    create_startup_script "$command" "$local_script"

    # 创建OpenRC服务
    cat > "$service_file" << EOF
#!/sbin/openrc-run
# 自动生成的OpenRC服务
# 创建于 $(date)

name="${service_name}"
description="自定义开机启动命令"

command="${local_script}"
command_background=true
pidfile="/var/run/\${name}.pid"

depend() {
    need net
    after firewall
    before local
}

start() {
    ebegin "启动自定义启动命令"
    start-stop-daemon --start --exec \$command --make-pidfile --pidfile \$pidfile --background
    eend \$?
}

stop() {
    ebegin "停止自定义启动命令"
    start-stop-daemon --stop --pidfile \$pidfile
    eend \$?
}
EOF

    chmod +x "$service_file"

    # 添加到启动项
    rc-update add "$service_name" default >/dev/null 2>&1
    /etc/init.d/"$service_name" start >/dev/null 2>&1

    echo "✅ Alpine开机启动配置完成!"
}

# 添加启动命令 (Ubuntu/Debian)
add_startup_debian() {
    local command="$1"
    local service_name="custom-startup"
    local local_script="/usr/local/bin/${service_name}.sh"
    local service_file="/etc/systemd/system/${service_name}.service"

    echo "正在为Ubuntu/Debian系统配置开机启动..."

    # 创建执行脚本
    create_startup_script "$command" "$local_script"

    # 创建systemd服务
    cat > "$service_file" << EOF
[Unit]
Description=Custom Startup Command
After=network.target network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
ExecStart=/bin/bash $local_script
Restart=always
RestartSec=10
TimeoutStartSec=300
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=custom-startup

[Install]
WantedBy=multi-user.target
EOF

    # 重载systemd并启用服务
    systemctl daemon-reload
    systemctl enable "$service_name" >/dev/null 2>&1
    systemctl start "$service_name" >/dev/null 2>&1

    # 等待一下让服务启动
    sleep 2
    
    echo "✅ Ubuntu/Debian开机启动配置完成!"
}

# 添加启动命令
add_startup() {
    if [ $# -eq 0 ]; then
        echo "错误: 请提供要运行的命令"
        show_usage
        exit 1
    fi

    local command="$*"
    local os_type=$(detect_os)

    check_root
    check_os_support

    echo "📋 命令: $command"

    case "$os_type" in
        alpine)
            add_startup_alpine "$command"
            ;;
        ubuntu|debian)
            add_startup_debian "$command"
            ;;
    esac

    echo ""
    echo "🎉 开机启动命令添加成功!"
    echo "📁 脚本: /usr/local/bin/custom_startup.sh"
    echo "📊 日志: /var/log/custom_startup/custom_startup.log"
    echo ""
    echo "立即查看日志: tail -f /var/log/custom_startup/custom_startup.log"
    echo "查看服务状态: systemctl status custom-startup"
}

# 移除启动命令
remove_startup() {
    local os_type=$(detect_os)
    local service_name="custom_startup"
    local local_script="/usr/local/bin/${service_name}.sh"

    check_root
    check_os_support

    echo "正在移除开机启动命令..."

    case "$os_type" in
        alpine)
            local service_file="/etc/init.d/${service_name}"
            if [ -f "$service_file" ]; then
                rc-update del "$service_name" default >/dev/null 2>&1
                /etc/init.d/"$service_name" stop >/dev/null 2>&1
                rm -f "$service_file"
                echo "✅ Alpine服务已移除"
            fi
            ;;
        ubuntu|debian)
            local service_file="/etc/systemd/system/custom-startup.service"
            if systemctl is-active custom-startup >/dev/null 2>&1; then
                systemctl stop custom-startup >/dev/null 2>&1
                systemctl disable custom-startup >/dev/null 2>&1
                rm -f "$service_file"
                systemctl daemon-reload
                systemctl reset-failed
                echo "✅ systemd服务已移除"
            fi
            ;;
    esac

    # 删除脚本和日志
    rm -f "$local_script"
    rm -rf "/var/log/custom_startup"

    echo "✅ 开机启动命令移除完成!"
}

# 查看状态
check_status() {
    local os_type=$(detect_os)
    
    case "$os_type" in
        alpine)
            if [ -f "/etc/init.d/custom_startup" ]; then
                echo "✅ 开机启动服务已安装"
                /etc/init.d/custom_startup status
            else
                echo "❌ 未找到开机启动服务"
            fi
            ;;
        ubuntu|debian)
            if systemctl is-active custom-startup >/dev/null 2>&1; then
                echo "✅ 开机启动服务运行中"
                systemctl status custom-startup --no-pager -l
            else
                echo "❌ 开机启动服务未运行或未安装"
            fi
            ;;
    esac
    
    # 显示日志文件信息
    if [ -f "/var/log/custom_startup/custom_startup.log" ]; then
        echo ""
        echo "📊 日志文件最后几行:"
        tail -10 "/var/log/custom_startup/custom_startup.log"
    fi
}

# 查看日志
view_log() {
    if [ -f "/var/log/custom_startup/custom_startup.log" ]; then
        echo "📊 查看日志:"
        tail -20 "/var/log/custom_startup/custom_startup.log"
    else
        echo "❌ 日志文件不存在"
        echo "可能的原因:"
        echo "1. 服务尚未运行"
        echo "2. 服务启动失败"
        echo "3. 日志路径: /var/log/custom_startup/custom_startup.log"
    fi
}

# 主程序
main() {
    case "${1}" in
        add|install)
            shift
            if [ $# -eq 0 ]; then
                interactive_input
            else
                add_startup "$@"
            fi
            ;;
        remove|uninstall)
            remove_startup
            ;;
        status)
            check_status
            ;;
        log)
            view_log
            ;;
        list)
            echo "自定义启动服务:"
            if [ -f /etc/alpine-release ]; then
                ls /etc/init.d/ | grep -E '(custom|startup)' || echo "未找到自定义启动服务"
            else
                systemctl list-unit-files | grep -E '(custom|startup)' || echo "未找到自定义启动服务"
            fi
            ;;
        help|--help|-h|"")
            show_usage
            if [ $# -eq 0 ]; then
                echo ""
                read -p "是否进入交互模式? (y/N): " choice
                if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
                    interactive_input
                fi
            fi
            ;;
        *)
            # 如果没有参数，直接添加命令
            add_startup "$@"
            ;;
    esac
}

# 运行主程序
main "$@"
