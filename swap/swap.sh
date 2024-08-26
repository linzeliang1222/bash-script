#!/bin/bash

# 检查是否是 root 账户
if [[ $EUID != 0 ]];then
  echo -e " 当前非 root 账号，无法继续操作。" 
  exit 1
fi

# 输入交换内存容量
read -p " 请输入需要添加的虚拟内存容量(MB): " swap_capacity
# 创建交换分区文件
mkdir /swap
dd if=/dev/zero  of=/swap/swapfile bs=1MB count=$swap_capacity
# 修改权限
chmod 600 /swap/swapfile
# 设置 swap 分区
mkswap /swap/swapfile
# 激活 swap 分区
swapon /swap/swapfile
# 设置开机自启
echo "/swap/swapfile swap swap defaults 0 0" >>/etc/fstab

# 检查是否配置成功
if [[ `free | grep -i swap | awk -F " " '{print $2}'` -ne 0 ]];then
	echo -e "虚拟内存设置完成"
else
	echo -e "设置失败，启动删除程序"
fi
