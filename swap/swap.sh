#!/bin/bash
#
# 配置 swap 文件（非交互，可重复执行）
#
# 用法：
#   bash swap.sh            # 按内存自动计算容量
#   bash swap.sh 2048       # 指定容量（MB）
#   bash swap.sh remove     # 卸载 /swap/swapfile
#
# 容量规则（内存先按 512MB 向上取整）：
#   内存 <= 2G   -> 内存 x 2
#   内存 2~8G    -> 等于内存
#   内存 > 8G    -> 4G
#
# 已有的 swap：swap 文件/分区会停用，并在 /etc/fstab 里注释掉（不删除分区）；
# zram 不动。剩余磁盘空间必须比 swap 多出 2G，否则退出。
# 同时把 vm.swappiness 设为 10（写入 /etc/sysctl.d/99-swap.conf）。

set -euo pipefail

SWAP_FILE=/swap/swapfile
SYSCTL_FILE=/etc/sysctl.d/99-swap.conf
SWAPPINESS=10
RESERVE_MB=2048

die() { echo "错误：$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "需要 root 权限"

backup_fstab() {
  local bk=/root/backups/swap-$(date +%Y%m%d-%H%M%S)
  mkdir -p "$bk"
  cp -a /etc/fstab "$bk/"
  echo "已备份 /etc/fstab 到 $bk"
}

# 本脚本自己的 swap 行直接删掉（后面会重新写入）；其他第 3 列是 swap、且未注释的行注释掉
comment_fstab_swap() {
  awk -v f="$SWAP_FILE" '
    $1 == f { next }
    { if ($0 !~ /^[[:space:]]*#/ && $3 == "swap") print "#" $0; else print }
  ' /etc/fstab > /etc/fstab.new
  cat /etc/fstab.new > /etc/fstab   # 用 cat 覆盖，保留原文件的权限和属主
  rm -f /etc/fstab.new
}

remove_swap() {
  backup_fstab
  if swapon --show=NAME --noheadings | grep -qx "$SWAP_FILE"; then
    swapoff "$SWAP_FILE"
  fi
  rm -f "$SWAP_FILE"
  awk -v f="$SWAP_FILE" '$1 != f' /etc/fstab > /etc/fstab.new
  cat /etc/fstab.new > /etc/fstab
  rm -f /etc/fstab.new
  echo "已卸载 $SWAP_FILE"
}

calc_size_mb() {
  local ram
  ram=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
  ram=$(( (ram + 511) / 512 * 512 ))
  if   (( ram <= 2048 )); then echo $(( ram * 2 ))
  elif (( ram <= 8192 )); then echo "$ram"
  else                         echo 4096
  fi
}

if [[ ${1:-} == remove ]]; then
  remove_swap
  exit 0
fi

if [[ -n ${1:-} ]]; then
  [[ $1 =~ ^[0-9]+$ ]] && (( $1 > 0 )) || die "容量必须是正整数（MB）：$1"
  SWAP_MB=$1
else
  SWAP_MB=$(calc_size_mb)
fi
echo "目标 swap 容量：${SWAP_MB}MB"

echo "当前 swap："
swapon --show || true

# 已经是目标状态就只更新 swappiness
CUR_MB=0
if swapon --show=NAME --noheadings | grep -qx "$SWAP_FILE"; then
  CUR_MB=$(( $(stat -c %s "$SWAP_FILE") / 1024 / 1024 ))
fi
OTHERS=$(swapon --show=NAME --noheadings | grep -vx "$SWAP_FILE" | grep -v zram || true)

if (( CUR_MB == SWAP_MB )) && [[ -z $OTHERS ]] && grep -q "^$SWAP_FILE[[:space:]]" /etc/fstab; then
  echo "$SWAP_FILE 已是 ${SWAP_MB}MB，跳过创建"
else
  backup_fstab

  # 1. 停用现有 swap（zram 除外），fstab 里的 swap 行注释掉
  for d in $(swapon --show=NAME --noheadings | grep -v zram || true); do
    swapoff "$d"
  done
  comment_fstab_swap
  rm -f "$SWAP_FILE"

  # 2. 检查磁盘空间
  mkdir -p "$(dirname "$SWAP_FILE")"
  AVAIL=$(df -m --output=avail "$(dirname "$SWAP_FILE")" | tail -1 | tr -d ' ')
  (( AVAIL > SWAP_MB + RESERVE_MB )) || die "磁盘空间不足：剩余 ${AVAIL}MB，需要大于 $(( SWAP_MB + RESERVE_MB ))MB"

  # 3. 创建 swap 文件（先建 600 权限的空文件再写入）
  FSTYPE=$(findmnt -no FSTYPE --target "$(dirname "$SWAP_FILE")")
  [[ $FSTYPE != btrfs ]] || die "文件系统是 btrfs，需要用 btrfs filesystem mkswapfile 单独处理"
  install -m 600 /dev/null "$SWAP_FILE"
  dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_MB" status=progress
  mkswap "$SWAP_FILE"
  swapon "$SWAP_FILE"
  echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
fi

# 4. swappiness
echo "vm.swappiness=$SWAPPINESS" > "$SYSCTL_FILE"
sysctl -q --system

echo "完成："
swapon --show
echo "vm.swappiness = $(sysctl -n vm.swappiness)"
