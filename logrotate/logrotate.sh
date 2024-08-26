#/bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)
mkdir -p ${CURRENT_DIR}/logs
LOG_FILE_PATH=${CURRENT_DIR}/logs/logrotate.log
LOGROTATE_FILE_DIR=/data/logrotate
TASK_ARR=($(find $LOGROTATE_FILE_DIR -type f))

# 清空运行日志
> ${LOG_FILE_PATH}

log() {
    echo -e "[$(date +"%Y-%m-%d %H:%M:%S")] [$1] $2" | tee -a ${LOG_FILE_PATH}
}

log "INFO" "------------------------------ 开始执行日志切割任务 ------------------------------"
for ((i=0; i<${#TASK_ARR[@]}; i++))
do
  log "INFO" "任务$(($i+1)) -----> ${TASK_ARR[$i]}"
  logrotate_output=$(/usr/sbin/logrotate -v ${TASK_ARR[$i]} 2>&1)
  log "INFO" "$logrotate_output"
  log "INFO" "--------------------------------------------------------------------------------"
done
