#!/bin/bash

DOCKER_REPO="https://download.docker.com"

# 获取 Linux 发行版
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
if [[ "${release}" != 'debian' && "${release}" != 'ubuntu' ]]; then
    echo "仅支 Debian/Ubuntu"
fi

echo "正在更新包列表..."
apt update

echo "正在安装必要的工具..."
apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

read -p "是否使用阿里云镜像源安装 Docker? (y/n) " use_mirror
if [[ "$use_mirror" == "y" ]]; then
    DOCKER_REPO="https://mirrors.aliyun.com/docker-ce"
fi

# 添加 Docker 的 GPG 密钥
echo "正在添加 Docker 的 GPG 密钥..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "${DOCKER_REPO}/linux/${release}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 向 sources.list 中添加 Docker 软件源
echo "正在向 sources.list 中添加 Docker 软件源..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] ${DOCKER_REPO}/linux/${release} $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新 apt 软件包缓存
echo "正在更新 apt 软件包缓存..."
apt update

# 安装 Docker
echo "正在安装 Docker..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker 并设置开机自启
echo "正在启动 Docker 并设置开机自启..."
systemctl start docker
systemctl enable docker

# 创建默认网络
echo "正在创建默认网络..."
docker network create --subnet=172.18.0.0/16 my_network

echo "Docker 安装完成！"
echo "请注销并重新登录以使组更改生效。"
