#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)
DATA_DIR=${CURRENT_DIR}/data
LOGS_DIR=${CURRENT_DIR}/logs
DATETIME=$(date +"%Y%m%d_%H%M%S")
MIN_FILES=10
MIN_DAYS=7

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 初始化目录
mkdir -p ${DATA_DIR}
mkdir -p ${LOGS_DIR}

log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level=$1
    local message=$2

    case $level in
        "INFO")
            echo -e "[${timestamp}] ${GREEN}[INFO]${PLAIN} ${message}" | tee -a ${LOGS_DIR}/mysqldump.log
            ;;
        "WARN")
            echo -e "[${timestamp}] ${YELLOW}[WARN]${PLAIN} ${message}" | tee -a ${LOGS_DIR}/mysqldump.log
            ;;
        "ERROR")
            echo -e "[${timestamp}] ${RED}[ERROR]${PLAIN} ${message}" | tee -a ${LOGS_DIR}/mysqldump.log
            ;;
    esac
}

log_info() {
    log "INFO" "$*"
}

log_warn() {
    log "WARN" "$*"
}

log_error() {
    log "ERROR" "$*"
}

backup() {
    local database=$1
    
    log_info "开始备份数据库: ${database}"
    
    # 判断数据库是否存在
    if echo "${databases[@]}" | grep -vwq "${database}"; then
        log_warn "数据库 ${database} 不存在"
        exit 0
    fi
    
    # 当前备份目录
    local backup_dir=${DATA_DIR}/${database}
    
    # 创建备份目录
    mkdir -p ${backup_dir}
    
    # 文件名
    local backup_filename=mysqldump-${database}-${DATETIME}.sql
    
    # 备份为 SQL 文件
    docker exec mysql mysqldump --login-path=dumper --databases ${database} > "${backup_dir}/${backup_filename}"
}

backup_all() {
    log_info "开始备份全部数据库～"
    
    # 循环遍历每个数据库
    for i in ${!databases[@]}; do
        local database=${databases[i]}
        
        log_info "当前正在备份第 $((i+1)) 个数据库: ${database}"
        
        # 当前备份目录
        local backup_dir=${DATA_DIR}/${database}
        
        # 创建备份目录
        mkdir -p ${backup_dir}
        
        # 文件名
        local backup_filename=mysqldump-${database}-${DATETIME}.sql
    
        # 备份为 SQL 文件
        docker exec mysql mysqldump --login-path=dumper --databases ${database} > "${backup_dir}/${backup_filename}"
        
        # 获取备份数量，如果数量小于 ${MIN_FILES} 不进行清理
        local file_num=$(find ${backup_dir} -maxdepth 1 -type f | wc -l)
        if (( ${file_num} > ${MIN_FILES} )); then
            # 清理 ${MIN_DAYS} 天之前的文件
            find ${backup_dir} -maxdepth 1 -type f -mtime +${MIN_DAYS} -delete
        else
            log_info "数据库 ${database} 备份数量小于 ${MIN_FILES}，跳过清理！"
        fi
    done
}

log_info "-------------------- 开始备份 MySQL... --------------------"

# 获取所有数据库列表
databases=$(docker exec mysql mysql --login-path=dumper -N -e "SHOW DATABASES")
if [[ $? -ne 0 ]]; then
    log_error "获取数据库列表失败"
    exit 1
fi
databases=($(echo ${databases} | tr ' ' '\n' | grep -Ev "^(information_schema|mysql|performance_schema|sys)$"))
if [[ ${#databases[@]} -eq 0 ]]; then
    log_warn "待备份的数据库列表为空"
    exit 0
fi

# 无入参备份所有，否则指定备份数据库
if [[ $# > 0 ]]; then
    backup $1
else
    backup_all
fi

log_info "-------------------- MySQL 备份完成！ --------------------"
