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
