#!/bin/sh
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}

# 找到挂载在 /tmp/mountd 下的 U 盘设备
MOUNT_BASE="/tmp/mountd"
AUTOMOUNT_POINT=$(find $MOUNT_BASE -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ -z "$AUTOMOUNT_POINT" ]; then
    red "没有找到 U 盘的挂载点。请重新插拔U盘再试试"
    exit 1
fi

# 使用 df 来找到设备文件，这假设挂载点的路径不含空格
DEVICE=$(df | grep "$AUTOMOUNT_POINT" | awk '{ print $1 }')
if [ -z "$DEVICE" ]; then
    yellow "无法找到 U 盘。"
    exit 1
fi

# 此处设备路径已经找到，可以继续执行格式化和挂载等操作
yellow "找到 U 盘设备：$DEVICE,挂载在:$AUTOMOUNT_POINT"

# 卸载自动挂载的 U 盘
umount $AUTOMOUNT_POINT

# 检查并格式化 U 盘为 ext4
FORMAT_DISK=$DEVICE  
MOUNT_POINT="/mnt/upan_data"
DOCKER_ROOT="$MOUNT_POINT/docker"

echo "格式化 $FORMAT_DISK 为 ext4 ..."
yellow "如果您确定要格式化U盘,请输入 y 来确认"
if mkfs.ext4 $FORMAT_DISK; then
    echo "U盘格式化成功。"
else
    red "U盘格式化失败,请确保刚才输入y确认。再次尝试需要重新插拔一次U盘"
    exit 1
fi

yellow "为Docker Root 创建挂载点..."
mkdir -p $DOCKER_ROOT

echo "将挂载 U 盘到 $DOCKER_ROOT..."
mount $FORMAT_DISK $MOUNT_POINT

green "正在创建 Docker 配置文件 /etc/docker/daemon.json"
mkdir -p /etc/docker
echo '{
  "bridge": "docker0",
  "storage-driver": "overlay2",
  "data-root": "'$DOCKER_ROOT'"
}' > /etc/docker/daemon.json

# 安装 Docker 和 dockerd
green "正在安装 Docker..."
opkg update
opkg install luci-app-dockerman
opkg install luci-i18n-dockerman-zh-cn
opkg install dockerd --force-depends >/dev/null 2>&1

# 创建并配置启动脚本
green "设置 Docker 跟随系统启动"
cat << 'EOF' > /etc/init.d/docker
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1
PROG="/usr/bin/dockerd"

start_service() {
    procd_open_instance
    procd_set_param command $PROG --config-file /etc/docker/daemon.json
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall dockerd
}

restart() {
    stop
    start
}
EOF

# 使启动脚本可执行并启用自启动
chmod +x /etc/init.d/docker
/etc/init.d/docker enable
/etc/init.d/docker start

green "设置开机挂载U盘后 再启动Docker"
# 首先，备份 /etc/rc.local
cp /etc/rc.local /etc/rc.local.backup

# 删除原有的 exit 0
sed -i '/exit 0/d' /etc/rc.local

# 将新的命令添加到 /etc/rc.local，然后再加上 exit 0
{
    echo "umount $AUTOMOUNT_POINT || true"
    echo "mount $FORMAT_DISK $MOUNT_POINT || true"
    echo "/etc/init.d/docker start || true"
    echo "exit 0"
} >> /etc/rc.local

cat /etc/rc.local

# 修改 /etc/config/dockerd 文件中的 data_root 配置
sed -i "/option data_root/c\	option data_root '/mnt/upan_data/docker/'" /etc/config/dockerd

yellow "Docker 部署完毕，请重启路由器来使更改生效。现在重启吗？(y/n)"
read -r answer
if [ "$answer" = "y" ] || [ -z "$answer" ]; then
    yellow "正在重启路由器..."
    reboot
else
    echo "更改将在下次重启后生效。建议立刻重启"
fi
