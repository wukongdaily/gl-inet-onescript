#!/bin/sh
red() {
    echo -e "\033[31m\033[01m[WARNING] $1\033[0m"
}
green() {
    echo -e "\033[32m\033[01m[INFO] $1\033[0m"
}
yellow() {
    echo -e "\033[33m\033[01m[NOTICE] $1\033[0m"
}
blue() {
    echo -e "\033[34m\033[01m[MESSAGE] $1\033[0m"
}
light_magenta() {
    echo -e "\033[95m\033[01m[NOTICE] $1\033[0m"
}
light_yellow() {
    echo -e "\033[93m\033[01m[NOTICE] $1\033[0m"
}

##获取路由型号信息
get_router_name() {
    model_info=$(cat /tmp/sysinfo/model)
    echo "$model_info"
}

# 安装必备工具lsblk和fdisk等
install_depends_apps() {
    blue "正在安装部署环境的所需要的工具 lsblk 和fdisk ..."
    router_name=$(get_router_name)
    case "$router_name" in
    *3000*)
        opkg update >/dev/null 2>&1
        if opkg install lsblk fdisk >/dev/null 2>&1; then
            green "$router_name 的 lsblk fdisk 工具 安装成功。"
        else
            red "安装失败。"
            exit 1
        fi
        ;;
    *2500*)
        opkg update >/dev/null 2>&1
        if opkg install lsblk fdisk >/dev/null 2>&1; then
            green "$router_name 的 lsblk fdisk 工具 安装成功。"
        else
            red "安装失败。"
            exit 1
        fi
        ;;
    *6000*)
        red "由于 mt6000 的软件源中没有找到 lsblk 和fdisk ..."
        yellow "因此先借用mt3000的软件源来安装lsblk 和fdisk工具"
        # 备份 /etc/opkg/distfeeds.conf
        cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.backup
        # 先替换为mt3000的软件源来安装lsblk 和fdisk工具
        mt3000_opkg="https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/mt-3000/distfeeds.conf"
        wget -q -O /etc/opkg/distfeeds.conf ${mt3000_opkg}
        green "正在更新为mt3000的软件源"
        opkg update >/dev/null 2>&1
        green "再次尝试安装 lsblk 和fdisk工具"
        if opkg install lsblk fdisk >/dev/null 2>&1; then
            green "$router_name 的 lsblk fdisk 工具 安装成功。"
            #还原软件源
            cp /etc/opkg/distfeeds.conf.backup /etc/opkg/distfeeds.conf
        else
            red "安装失败。"
            #还原软件源
            cp /etc/opkg/distfeeds.conf.backup /etc/opkg/distfeeds.conf
            exit 1
        fi
        ;;
    *)
        echo "Router name does not contain '3000' 6000 or '2500'."
        ;;
    esac
}

# START
install_depends_apps
green "现在开始查找USB设备分区,请稍后......"
# 自动识别第一个可移除的USB磁盘
USB_DISK=$(lsblk -dn -o NAME,RM,TYPE | awk '$2=="1" && $3=="disk" {print "/dev/"$1; exit}')
if [ -z "$USB_DISK" ]; then
    echo "未找到USB磁盘。"
    exit 1
fi
yellow "找到USB磁盘：$USB_DISK"
# 清零磁盘开始部分以清除分区表和文件系统签名
dd if=/dev/zero of=$USB_DISK bs=1M count=10
sync
# 卸载所有与该磁盘相关的挂载点
for mount in $(mount | grep "$USB_DISK" | awk '{print $3}'); do
    yellow "正在尝试卸载U盘挂载点：$mount"
    if ! umount $mount; then
        red "警告：无法卸载挂载点 $mount。可能有文件正在被访问或权限不足。"
        exit 1
    else
        green "U盘挂载点 $mount 卸载成功。"
    fi
done

red "正在重新分区并格式化$USB_DISK..."
# 使用fdisk清除所有分区并创建一个新的主分区
{
    echo o # 创建一个新的空DOS分区表
    echo n # 添加一个新分区
    echo p # 主分区
    echo 1 # 分区号1
    echo   # 第一个可用扇区（默认）
    echo   # 最后一个扇区（默认，使用剩余空间）
    echo w # 写入并退出
} | fdisk $USB_DISK >/dev/null 2>&1

# 等待磁盘分区表更新
sleep 5

# 格式化新分区为EXT4文件系统
NEW_PARTITION="${USB_DISK}1"
red "正在将U盘 $NEW_PARTITION 格式化为EXT4文件系统..."
mkfs.ext4 -F $NEW_PARTITION >/dev/null 2>&1
green "$NEW_PARTITION 已成功格式化为EXT4文件系统。"

# 卸载所有与该磁盘相关的挂载点
for mount in $(mount | grep "$USB_DISK" | awk '{print $3}'); do
    echo "再次卸载U盘的自动挂载点：$mount"
    umount $mount
done

yellow "为Docker Root 创建挂载点..."
USB_MOUNT_POINT="/mnt/upan_data"
DOCKER_ROOT="$USB_MOUNT_POINT/docker"
mkdir -p $DOCKER_ROOT

green "将U盘 挂载到 $USB_MOUNT_POINT..."
mount -t ext4 $NEW_PARTITION $USB_MOUNT_POINT
# 检查挂载命令的退出状态
if [ $? -ne 0 ]; then
    red "挂载失败，脚本退出。"
    exit 1
fi
green "U盘挂载成功啦\n"
green "正在创建 Docker 配置文件 /etc/docker/daemon.json"
mkdir -p /etc/docker
echo '{
  "bridge": "docker0",
  "storage-driver": "overlay2",
  "data-root": "'$DOCKER_ROOT'"
}' >/etc/docker/daemon.json

# 安装 Docker 和 dockerd
green "正在更新 OPKG 软件包..."
opkg update >/dev/null 2>&1
green "正在安装 Docker及相关服务...请耐心等待一会...大约需要1分钟\n"
opkg install luci-app-dockerman >/dev/null 2>&1
opkg install luci-i18n-dockerman-zh-cn >/dev/null 2>&1
opkg install dockerd --force-depends >/dev/null 2>&1

# 创建并配置启动脚本
green "正在设置 Docker 跟随系统启动的文件:/etc/init.d/docker"
cat <<'EOF' >/etc/init.d/docker
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

green "正在设置开机启动顺序的配置\n\n先挂载U盘,再启动Docker 修改/etc/rc.local后如下\n"
# 首先，备份 /etc/rc.local
cp /etc/rc.local /etc/rc.local.backup
# U盘分区 /dev/sdx=$NEW_PARTITION
# glinet系统重启后的 USB自动挂载点
SYSTEM_USB_AUTO_MOUNTPOINT="/tmp/mountd/disk1_part1"
# 卸载USB自动挂载点 挂载自定义挂载点 /mnt/upan_data
if ! grep -q "umount $SYSTEM_USB_AUTO_MOUNTPOINT" /etc/rc.local; then
    sed -i '/exit 0/d' /etc/rc.local

    # 将新的命令添加到 /etc/rc.local，然后再加上 exit 0
    {
        echo "umount $SYSTEM_USB_AUTO_MOUNTPOINT || true"
        echo "mount $NEW_PARTITION $USB_MOUNT_POINT || true"
        echo "/etc/init.d/docker start || true"
        echo "exit 0"
    } >>/etc/rc.local
fi

cat /etc/rc.local

# 修改 /etc/config/dockerd 文件中的 data_root 配置
sed -i "/option data_root/c\	option data_root '/mnt/upan_data/docker/'" /etc/config/dockerd
# 安装完毕后
green "正在尝试启动Docker....请稍后"
# 初始化计数器
counter=0
# 循环检查 Docker 守护进程是否已经启动
until docker info >/dev/null 2>&1; do
    counter=$((counter + 1))
    echo "Waiting for Docker daemon to start..."
    sleep 1
    # 如果等待时间达到10秒，则跳出循环
    if [ $counter -eq 10 ]; then
        echo "Failed to start Docker daemon within 10 seconds."
        exit 1
    fi
done
/etc/init.d/docker stop
yellow "正在重启Docker 守护进程...."
sleep 2
/etc/init.d/docker start
sleep 5
green "Docker 运行环境部署完毕"
yellow "正在帮您启动Docker....若出现卡住现象 20s都没反应。建议手动重启路由器"
# 检查Docker是否正在运行
if ! docker info >/dev/null 2>&1; then
    red "Docker 启动失败,您可以手动启动docker 执行 /etc/init.d/docker start"
else
    DOCKER_ROOT_DIR=$(docker info 2>&1 | grep -v "WARNING" | grep "Docker Root Dir" | awk '{print $4}')
    light_magenta "当前Docker根目录为: $DOCKER_ROOT_DIR"
    light_yellow "Docker根目录剩余空间:$(df -h $DOCKER_ROOT_DIR | awk 'NR==2{print $4}')"
    # 检查DOCKER_ROOT_DIR是否为"/opt/docker"
    if [ "$DOCKER_ROOT_DIR" = "/opt/docker" ]; then
        yellow "虽然Docker启动成功了,但是Docker根目录不正确 $DOCKER_ROOT_DIR 。建议立即重启以修正。"
    else
        green "Docker启动成功并设置正确,您可以直接使用啦～\n"
        light_yellow "不过为了验证下次启动docker的有效性 建议手动重启路由器一次 祝您使用愉快"
    fi
    echo
    red "是否立即重启？(y/n)"
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        red "正在重启..."
        reboot
    else
        yellow "您选择了不重启"
    fi
fi
