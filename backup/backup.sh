#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0);pwd)
source ${CURRENT_DIR}/.env
mkdir -p ${CURRENT_DIR}/logs
mkdir -p ${CURRENT_DIR}/tmp
DATETIME_1=$(date +"%Y%m%d_%H%M%S")
DATETIME_2=$(date +"%Y-%m-%d %H:%M:%S")
LOG_FILE_PATH=${CURRENT_DIR}/logs/backup.log
SERVER_IP_STR="${SERVER_IP//./_}"
UPLOAD_PATH="/${SERVER_ID}-${SERVER_NAME}/${SERVER_IP_STR}/"
COMPRESS_FILE_PATH=${CURRENT_DIR}/tmp/backup-${SERVER_IP_STR}-${DATETIME_1}.7z
# 获取多个备份路径
OLD_IFS=$IFS
IFS=','
read -ra TARGET_PATH_ARR_TMP <<< "$TARGET_PATH_LIST"
IFS=$OLD_IFS
TARGET_PATH_ARR=${TARGET_PATH_ARR_TMP[@]}
COMPRESS_PASSWORD="${COMPRESS_PASSWORD_PREFIX}_${SERVER_IP_STR}"

compress() {
    log "INFO" "开始压缩备份数据: ${TARGET_PATH_LIST}"
    7z a -p${COMPRESS_PASSWORD} ${COMPRESS_FILE_PATH} ${TARGET_PATH_ARR} >> ${LOG_FILE_PATH} 2>&1
    if [ $? -eq 0 ]; then
        log "INFO" "压缩备份数据成功"
    else
        log "ERROR" "压缩备份数据失败"
        return 1
    fi
}

delete_compress_file() {
    log "INFO" "开始清理压缩文件: ${COMPRESS_FILE_PATH}"
    if [ -f ${COMPRESS_FILE_PATH} ]; then
        rm ${COMPRESS_FILE_PATH}
        if [ $? -eq 0 ]; then
            log "INFO" "清理压缩文件成功"
        else
            log "ERROR" "清理压缩文件失败"
        fi
    else
        log "INFO" "压缩文件未找到，跳过清理"
    fi
}

upload_compress_file() {
    log "INFO" "开始上传压缩文件: ${COMPRESS_FILE_PATH}"
    ossutil -e ${OSS_ENDPOINT} -i ${OSS_ACCESS_KEY_ID} -k ${OSS_ACCESS_KEY_SECRET} cp ${COMPRESS_FILE_PATH} oss://${OSS_BUCKET}${UPLOAD_PATH} >> ${LOG_FILE_PATH} 2>&1
    if [ $? -eq 0 ]; then
        log "INFO" "上传压缩文件成功"
    else
        log "ERROR" "上传压缩文件失败"
        delete_compress_file
        return 1
    fi
}

send_message() {
    local request_body="{\"msgtype\":\"text\",\"text\":{\"content\":\"$1\"}}"
    log "INFO" "开始发送消息"
    log "INFO" "消息请求体：${request_body}"
    # 以POST的方式请求
    local response=$(http_request "POST" "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=${WECHAT_KEY}" "${request_body}")
    # 保存响应结果到日志文件
    log "INFO" "响应结果：$response"
    local errcode=$(echo "${response}" | jq -r '.errcode')
    local errmsg=$(echo "${response}" | jq -r '.errmsg')
    if [ $? -eq 0 ] && [ ${errcode} -eq 0 ]; then
        log "INFO" "消息发送成功"
    else
        log "ERROR" "消息发送失败：${errmsg}"
        return 1
    fi
}

http_request() {
    local method=$1
    local url=$2
    local body=$3
    local response
    if [ "$1" = 'GET' ]; then
        response=$(curl -s -X GET "$2")
    elif [ "$1" = 'POST' ]; then
        response=$(curl -s -X POST -d "$3" "$2")
    fi
    echo "${response}"
}

check_params() {
    if [ -z ${COMPRESS_PASSWORD} ]; then
        log "ERROR" "压缩密码未设置，请在配置文件中设置压缩密码"
        return 1
    fi

    if [[ -z ${UPLOAD_PATH} || ${UPLOAD_PATH} != /* || ${UPLOAD_PATH} != */ ]]; then
        log "ERROR" "无效的上传路径: ${UPLOAD_PATH}，路径名必须以 '/' 开始，且必须以 '/' 结束，不能为空"
        return 1
    fi

    if [ -z ${OSS_ACCESS_KEY_ID} ] || [ -z ${OSS_ACCESS_KEY_SECRET} ] || [ -z ${OSS_BUCKET} ] || [ -z ${OSS_ENDPOINT} ]; then
        log "ERROR" "OSS配置缺失，请在配置文件中填写"
        return 1
    fi

    if [ -z "${TARGET_PATH_ARR}" ]; then
        log "ERROR" "待上传资源路径不能为空"
        return 1
    fi

    for path in "${TARGET_PATH_ARR_TMP[@]}"; do
        if [ ! -e ${path} ]; then
            log "ERROR" "资源路径不存在或不合法：${path}"
            return 1
        fi
    done
}

log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [$1] $2" | tee -a ${LOG_FILE_PATH}
}


log "INFO" "----------开始执行备份任务----------"
START_TIME=$(date +%s)

check_params
if [ $? -ne 0 ]; then
    send_message "备份任务执行失败 (T_T)\n\n服务器：${SERVER_IP}\n备份时间：${DATETIME_2}\n备份路径：${TARGET_PATH_LIST}\n失败原因：参数校验失败"
    exit 1
fi

compress
if [ $? -ne 0 ]; then
    send_message "备份任务执行失败 (T_T)\n\n服务器：${SERVER_IP}\n备份时间：${DATETIME_2}\n备份路径：${TARGET_PATH_LIST}\n失败原因：压缩备份目录失败"
    exit 1
fi

upload_compress_file
if [ $? -ne 0 ]; then
    send_message "备份任务执行失败 (T_T)\n\n服务器：${SERVER_IP}\n备份时间：${DATETIME_2}\n备份路径：${TARGET_PATH_LIST}\n失败原因：上传压缩文件失败"
    exit 1
fi

END_TIME=$(date +%s)
TAKE=$(( END_TIME - START_TIME ))
COMPRESS_FILE_SIZE=$(du -sk ${COMPRESS_FILE_PATH} | awk '{printf "%.2f", $1/1024}')
delete_compress_file
if [ $? -ne 0 ]; then
    send_message "备份任务执行完成 (^_^)\n\nID：${SERVER_ID}\n名称：${SERVER_NAME}\n服务器：${SERVER_IP}\n备份时间：${DATETIME_2}\n备份路径：${TARGET_PATH_LIST}\n备份耗时：${TAKE} s\n备份大小：${COMPRESS_FILE_SIZE} MB\n注意：备份压缩文件未清理成功"
else
    send_message "备份任务执行完成 (^_^)\n\nID：${SERVER_ID}\n名称：${SERVER_NAME}\n服务器：${SERVER_IP}\n备份时间：${DATETIME_2}\n备份路径：${TARGET_PATH_LIST}\n备份耗时：${TAKE} s\n备份大小：${COMPRESS_FILE_SIZE} MB"
fi

log "INFO" "----------备份任务执行完成----------"
