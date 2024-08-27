#!/usr/bin/env bash
# Name: BASH 脚本模版
# Auth: linzeliang.com
# Date: 2024-08-26

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 解析的参数
X1=
X2=

# 自定义变量
DATETIME_1=$(date +"%Y%m%d_%H%M%S")
DATETIME_2=$(date +"%Y-%m-%d %H:%M:%S")
CURRENT_DIR=$(cd $(dirname $0);pwd)
LOG_PATH=${CURRENT_DIR}/logs
LOG_FILENAME=output.log

# 初始化
init() {
  # 日志文件夹
  mkdir -p ${LOG_PATH}
  # 其他初始化操作...
  # xxx
}

# 检查是否 root 用户登录
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log "ERROR" "Fatal error: Please run this script with root privilege!\n"
    exit 1
  fi
}

# 检查操作系统类型
check_os() {
  OS="$(uname)"
  case $OS in
    Linux)
      OS='linux'
      ;;
    FreeBSD)
      OS='freebsd'
      ;;
    NetBSD)
      OS='netbsd'
      ;;
    OpenBSD)
      OS='openbsd'
      ;;  
    Darwin)
      OS='osx'
      binTgtDir=/usr/local/bin
      man1TgtDir=/usr/local/share/man/man1
      ;;
    SunOS)
      OS='solaris'
      log "ERROR" "当前操作系统不支持"
      exit 1
      ;;
    *)
      log "ERROR" "当前操作系统不支持"
      exit 1
      ;;
  esac
}

check_os_release() {
  # Check OS and set release variable
  if [[ -f /etc/os-release ]]; then
      source /etc/os-release
      RELEASE=$ID
  elif [[ -f /usr/lib/os-release ]]; then
      source /usr/lib/os-release
      RELEASE=$ID
  else
      log "ERROR" "Failed to check the system OS, please contact the author!"
      exit 1
  fi
  log "INFO" "The OS release is: $RELEASE"
}

# 检查操作系统版本
check_os_version() {
  OS_VERSION=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
  if [[ "${RELEASE}" == "arch" ]]; then
      log "INFO" "Your OS is Arch Linux"
  elif [[ "${RELEASE}" == "parch" ]]; then
      log "INFO" "Your OS is Parch linux"
  elif [[ "${RELEASE}" == "manjaro" ]]; then
      log "INFO" "Your OS is Manjaro"
  elif [[ "${RELEASE}" == "armbian" ]]; then
      log "INFO" "Your OS is Armbian"
  elif [[ "${RELEASE}" == "opensuse-tumbleweed" ]]; then
      log "INFO" "Your OS is OpenSUSE Tumbleweed"
  elif [[ "${RELEASE}" == "centos" ]]; then
      if [[ ${OS_VERSION} -lt 8 ]]; then
          log "ERROR" "Please use CentOS 8 or higher!\n"
          exit 1
      fi
  elif [[ "${RELEASE}" == "ubuntu" ]]; then
      if [[ ${OS_VERSION} -lt 20 ]]; then
          log "ERROR" "Please use Ubuntu 20 or higher version!\n"
          exit 1
      fi
  elif [[ "${RELEASE}" == "fedora" ]]; then
      if [[ ${OS_VERSION} -lt 36 ]]; then
          log "ERROR" "Please use Fedora 36 or higher version!\n"
          exit 1
      fi
  elif [[ "${RELEASE}" == "debian" ]]; then
      if [[ ${OS_VERSION} -lt 11 ]]; then
          log "ERROR" "Please use Debian 11 or higher!\n"
          exit 1
      fi
  elif [[ "${RELEASE}" == "almalinux" ]]; then
      if [[ ${OS_VERSION} -lt 9 ]]; then
          log "ERROR" "Please use AlmaLinux 9 or higher!\n"
          exit 1
      fi
  elif [[ "${RELEASE}" == "rocky" ]]; then
      if [[ ${OS_VERSION} -lt 9 ]]; then
          log "ERROR" "Please use Rocky Linux 9 or higher!\n"
          exit 1
      fi
  elif [[ "${RELEASE}" == "oracle" ]]; then
      if [[ ${OS_VERSION} -lt 8 ]]; then
          log "ERROR" "Please use Oracle Linux 8 or higher!\n"
          exit 1
      fi
  else
      log "ERROR" "Your operating system is not supported by this script.\n"
      log "INFO" "Please ensure you are using one of the following supported operating systems:"
      log "INFO" "- Ubuntu 20.04+"
      log "INFO" "- Debian 11+"
      log "INFO" "- CentOS 8+"
      log "INFO" "- Fedora 36+"
      log "INFO" "- Arch Linux"
      log "INFO" "- Parch Linux"
      log "INFO" "- Manjaro"
      log "INFO" "- Armbian"
      log "INFO" "- AlmaLinux 9+"
      log "INFO" "- Rocky Linux 9+"
      log "INFO" "- Oracle Linux 8+"
      log "INFO" "- OpenSUSE Tumbleweed"
      exit 1
  fi
}

# 检查 CPU 架构
check_cpu_arch() {
  CPU_ARCH="$(uname -m)"
  case "$CPU_ARCH" in
    x86_64|amd64)
      CPU_ARCH='amd64'
      ;;
    i?86|x86)
      CPU_ARCH='386'
      ;;
    aarch64|arm64)
      CPU_ARCH='arm64'
      ;;
    armv7*)
      CPU_ARCH='arm-v7'
      ;;
    armv6*)
      CPU_ARCH='arm-v6'
      ;;
    arm*)
      CPU_ARCH='arm'
      ;;
    *)
      log "ERROR" '当前 CPU 架构不支持'
      exit 1
      ;;
  esac
}

# 安装基础软件
install_base() {
  case "${release}" in
  ubuntu | debian | armbian)
    apt-get update && apt-get install -y -q wget curl tar tzdata
    ;;
  centos | almalinux | rocky | oracle)
    yum -y update && yum install -y -q wget curl tar tzdata
    ;;
  fedora)
    dnf -y update && dnf install -y -q wget curl tar tzdata
    ;;
  arch | manjaro | parch)
    pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
    ;;
  opensuse-tumbleweed)
    zypper refresh && zypper -q install -y wget curl tar timezone
    ;;
  *)
    apt-get update && apt install -y -q wget curl tar tzdata
    ;;
  esac
}

# 打印日志
log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local level=$1
  local message=$2

  case $level in
    "INFO")
      echo -e "[${timestamp}] ${GREEN}[INFO]${PLAIN} ${message}" | tee -a ${LOGS_PATH}/${LOG_FILENAME}
      ;;
    "WARN")
      echo -e "[${timestamp}] ${YELLOW}[WARN]${PLAIN} ${message}" | tee -a ${LOGS_PATH}/${LOG_FILENAME}
      ;;
    "ERROR")
      echo -e "[${timestamp}] ${RED}[ERROR]${PLAIN} ${message}" | tee -a ${LOGS_DIR}/${LOG_FILENAME}
      ;;
    *)
      echo "[${timestamp}] [INFO] ${message}" | tee -a ${LOGS_PATH}/${LOG_FILENAME}
      ;;
  esac
}

# 安装
install() {
  return 0
}

# 卸载
uninstall() {
  return 0
}

# 更新
update() {
  return 0
}

# 启动
start() {
  return 0
}

# 停止
stop() {
  return 0
}

# 重启
restart() {
  return 0
}

# 参数检查
check_params() {
  return 0
}

# 解析参数
parse_params() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --xxx1)
          shift
          X1="$1"
          ;;
      --xxx2)
          shift
          X2="$1"
          ;;
      *)
          log "WARN" "未知参数: $1"
          ;;
    esac
    shift
  done
}

process() {
  case "$COMMAND" in
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
    show_log)
      show_log
      ;;
    *)
      log "ERROR" "无效命令: $COMMAND"
      usage
      exit 1
      ;;
  esac
}

# 使用方式
function usage() {
  echo "XXX 脚本"
  echo
  echo "Usage: "
  echo "  ./xxx [COMMAND] [ARGS...]"
  echo "  ./xxx --help"
  echo
  echo "Commands: "
  echo "  status              查看 XXX 服务运行状态"
  echo "  start               启动 XXX 服务"
  echo "  stop                停止 XXX 服务"
  echo "  restart             重启 XXX 服务"
  echo "  install             安装 XXX 服务"
  echo "  uninstall           卸载 XXX 服务"
}

main() {
  init
  COMMAND=$1
  shift
  parse_params
  check_params
  process
  # 需要执行的方法...
  # xxx
}
main
