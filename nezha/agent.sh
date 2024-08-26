#!/bin/bash
# 当前脚本仅适用 Debian 11

# 目录
NZ_BASE_PATH="/data/script/nezha"
NZ_AGENT_PATH="${NZ_BASE_PATH}/agent"

pre_check() {
    # 必须 root 用户运行
    [[ $EUID -ne 0 ]] && log "ERROR" "必须使用 root 用户运行此脚本！\n" && exit 1
    # 获取系统架构
    os_arch=""
    if [[ $(uname -m | grep 'x86_64') != "" ]]; then
        os_arch="amd64"
    elif [[ $(uname -m | grep 'i386\|i686') != "" ]]; then
        os_arch="386"
    elif [[ $(uname -m | grep 'aarch64\|armv8b\|armv8l') != "" ]]; then
        os_arch="arm64"
    elif [[ $(uname -m | grep 'arm') != "" ]]; then
        os_arch="arm"
    elif [[ $(uname -m | grep 's390x') != "" ]]; then
        os_arch="s390x"
    elif [[ $(uname -m | grep 'riscv64') != "" ]]; then
        os_arch="riscv64"
    else
        log "ERROR" "获取系统架构失败"
        return 0
    fi
    log "INFO" "当前系统架构: ${os_arch}"
    log "INFO" "当前脚本位置: ${PWD}"
    log "INFO" "Agent 安装位置: ${NZ_AGENT_PATH}"
    log "INFO" "----------------------------------------"
}

pre_install_base() {
    # 检查 unzip 命令是否存在
    if ! command -v unzip &> /dev/null; then
        log "WARN" "unzip 未安装，正在安装..."
        apt update > /dev/null 2>&1
        apt install -y unzip > /dev/null 2>&1
        log "WARN" "unzip 安装完成"
    fi
}

install() {
    log "INFO" "开始安装 Agent"
    
    # 检查必要参数
    check_agent_param
    
    # 初始化 Agent 文件夹
    mkdir -p ${NZ_AGENT_PATH}
    
    # 初始化 Agent 版本
    if [ -n "${version}" ]; then
        # 手动指定 Agent 版本
        log "INFO" "指定安装 Agent 版本: ${version}"
    else
        # 获取 Agent 最新版本
        log "INFO" "正在获取 Agent 最新版本..."
        version=$(curl -m 10 -sL "https://api.github.com/repos/nezhahq/agent/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        if [ ! -n "$version" ]; then
            version=$(curl -m 10 -sL "https://fastly.jsdelivr.net/gh/nezhahq/agent/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/nezhahq\/agent@/v/g')
        fi
        if [ ! -n "$version" ]; then
            version=$(curl -m 10 -sL "https://gcore.jsdelivr.net/gh/nezhahq/agent/" | grep "option\.value" | awk -F "'" '{print $2}' | sed 's/nezhahq\/agent@/v/g')
        fi
        if [ ! -n "$version" ]; then
            log "ERROR" "获取 Agent 最新版本失败"
            exit 1
        else
            log "INFO" "当前 Agent 最新版本为: ${version}"
        fi
    fi
    
    # 下载文件
    log "INFO" "开始下载 Agent..."
    log "INFO" "------------------------------ 下载信息 START ------------------------------"
    wget -t 2 -T 60 --no-check-certificate -O ${PWD}/nezha-agent_linux_${os_arch}.zip https://gh.linzeliang.site/https://github.com/nezhahq/agent/releases/download/${version}/nezha-agent_linux_${os_arch}.zip
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Agent 下载失败，请检查网络连接或版本是否存在"
        exit 1
    fi
    log "INFO" "------------------------------  下载信息 END  ------------------------------"

    # 解压移动程序到指定位置
    log "INFO" "解压并移动 Agent 到 ${NZ_AGENT_PATH}"
    unzip -qo ${PWD}/nezha-agent_linux_${os_arch}.zip -d ${PWD}/tmp
    mv ${PWD}/tmp/nezha-agent ${NZ_AGENT_PATH}
    rm -rf ${PWD}/nezha-agent_linux_${os_arch}.zip ${PWD}/tmp

    # 开始安装并配置
    update_config

    log "INFO" "Agent 安装成功"
}

uninstall() {
    log "INFO" "开始卸载 Agent"

    check_application_exist
    
    ${NZ_AGENT_PATH}/nezha-agent service uninstall
    if [[ $? -eq 0 ]]; then
        rm -rf ${NZ_AGENT_PATH}
        log "INFO" "Agent 卸载完成"
    else
        log "ERROR" "Agent 卸载失败"
    fi
}

restart() {
    log "INFO" "重启 Agent 中..."

    check_application_exist
    
    ${NZ_AGENT_PATH}/nezha-agent service restart
    if [[ $? -eq 0 ]]; then
        log "INFO" "Agent 重启完成"
    else
        log "ERROR" "Agent 重启失败"
    fi
}

update() {
    # 其实就是重新 install
    install "$@"
}

update_config() {
    check_agent_param
    
    log "INFO" "正在配置 Agent..."
    
    check_application_exist
    
    # 禁止 自动更新 和 强制更新
    ${NZ_AGENT_PATH}/nezha-agent service install -s "${host}:${port}" -p ${secret} --tls --disable-auto-update --disable-force-update ${skip_conn} >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        ${NZ_AGENT_PATH}/nezha-agent service uninstall >/dev/null 2>&1
        ${NZ_AGENT_PATH}/nezha-agent service install -s "${host}:${port}" -p ${secret} --tls --disable-auto-update --disable-force-update ${skip_conn} >/dev/null 2>&1
    fi
    
    log "INFO" "Agent 配置完成"
}

show_log() {
    log "INFO" "获取 Agent 日志 ↓↓↓\n"
    journalctl -xf -u nezha-agent.service
}

check_application_exist() {
    if [[ ! -x "${NZ_AGENT_PATH}/nezha-agent" ]]; then
        log "ERROR" "应用程序文件不存在: ${NZ_AGENT_PATH}/nezha-agent"
        exit 1
    fi
}

check_agent_param() {
    if [[ -z "${host}" || -z "${port}" || -z "${secret}" ]]; then
        log "ERROR" "参数: --host --port --secret 不能为空"
        exit 1
    fi
}

show_usage() {
    log "INFO" ""
    log "INFO" "Usage:"
    log "INFO" "  install          - 安装 Agent"
    log "INFO" "  uninstall        - 卸载 Agent"
    log "INFO" "  restart          - 重启 Agent"
    log "INFO" "  update           - 更新 Agent"
    log "INFO" "  update_config    - 更新 Agent 配置"
    log "INFO" "  show_log         - 查看 Agent 日志"
}

log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level=$1
    local message=$2

    local red='\033[0;31m'
    local green='\033[0;32m'
    local yellow='\033[0;33m'
    local plain='\033[0m'

    case $level in
        "INFO")
            echo -e "[${timestamp}] ${green}[INFO]${plain} ${message}"
            ;;
        "WARN")
            echo -e "[${timestamp}] ${yellow}[WARN]${plain} ${message}"
            ;;
        "ERROR")
            echo -e "[${timestamp}] ${red}[ERROR]${plain} ${message}"
            ;;
        *)
            echo "[${timestamp}] [INFO] ${message}"
            ;;
    esac
}

# ------------------------------开始执行------------------------------
pre_check
pre_install_base

action=$1
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            shift
            host="$1"
            ;;
        --port)
            shift
            port="$1"
            ;;
        --secret)
            shift
            secret="$1"
            ;;
        --version)
            shift
            version="$1"
            ;;
        --isvpn)
            skip_conn="--skip-conn"
            ;;
        *)
            log "WARN" "未知参数: $1"
            ;;
    esac
    shift
done

case "$action" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    restart)
        restart
        ;;
    update)
        update
        ;;
    update_config)
        update_config
        ;;
    show_log)
        show_log
        ;;
    *)
        log "ERROR" "无效命令: $action"
        show_usage
        exit 1
        ;;
esac
