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
lsblk_url="https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/mt-6000/lsblk.ipk"
install_lsblk() {
    # 查找 lsblk 包
    if opkg find lsblk | grep -q lsblk; then
        # 检查 lsblk 是否已经安装
        if opkg list-installed | grep -q lsblk; then
            blue "系统已包含必备组件lsblk"
        else
            blue "正在安装查找USB设备所需要的依赖 lsblk ..."
            opkg install lsblk >/dev/null 2>&1
            # 再次验证安装是否成功
            if opkg list-installed | grep -q lsblk; then
                green "lsblk 安装成功."
            else
                red "lsblk 安装失败."
                exit 1
            fi
        fi
    else
        echo "lsblk package not found, attempting to download and install from URL..."
        mkdir -p /tmp/mt6000
        wget -q -O /tmp/mt6000/lsblk.ipk $lsblk_url
        opkg install /tmp/mt6000/lsblk.ipk >/dev/null 2>&1
        if opkg list-installed | grep -q lsblk; then
            green "formURL lsblk 安装成功."
        else
            red "formURL lsblk 安装失败."
            exit 1
        fi
    fi
}

green "正在查找USB设备分区,请稍后......"
opkg update >/dev/null 2>&1
install_lsblk

# 查找USB设备分区
USB_DEVICES=$(lsblk -o NAME,RM,TYPE | grep '1 part' | awk '{print $1}')

if [ -z "$USB_DEVICES" ]; then
    echo "未找到USB设备分区。"
    exit 1
fi

# 遍历所有找到的USB设备分区
for USB_DEVICE_PART in $USB_DEVICES; do
    # 移除不必要的字符
    CORRECTED_PART=$(echo $USB_DEVICE_PART | sed 's/[^a-zA-Z0-9]//g')

    echo "找到USB设备分区: /dev/$CORRECTED_PART"

    # 检查USB设备分区是否已挂载,这是glinet自动挂载点 /tmp/mountd/diskX_partX
    AUTOMOUNT_POINT=$(mount | grep "/dev/$CORRECTED_PART " | awk '{print $3}')

    if [ -n "$AUTOMOUNT_POINT" ]; then
        echo "设备分区已挂载在 $AUTOMOUNT_POINT,正在尝试卸载..."
        if
            ! command -v docker &
            >/dev/null
        then
            echo "Docker is not installed, skipping Docker stop procedure."
            # 直接执行后续操作或退出
        else
            # 尝试停止 Docker 服务
            /etc/init.d/docker stop

            # 等待 docker 守护进程停止
            while true; do
                # 检查 docker 守护进程是否停止
                if ! docker ps >/dev/null 2>&1; then
                    echo "Docker daemon has stopped."
                    break # 跳出循环
                else
                    echo "Waiting for Docker daemon to stop..."
                    sleep 1 # 等待1秒再次检查
                fi
            done
        fi
        # 在此处执行卸载或其他操作
        umount /dev/$CORRECTED_PART
        if [ $? -eq 0 ]; then
            echo "卸载成功。"
        else
            echo "卸载失败，请检查设备是否正被使用。"
            exit 1
        fi
    else
        echo "设备分区未挂载。"
    fi

    # 格式化分区为EXT4，你可以根据需要更改为其他文件系统类型
    red "正在格式化U盘: /dev/$CORRECTED_PART 为 EXT4... 请耐心等待..."
    mkfs.ext4 -F -E lazy_itable_init=1,lazy_journal_init=1 /dev/$CORRECTED_PART >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        green "格式化成功。"
    else
        red "\n U盘格式化失败"
        exit 1
    fi
done
yellow "为Docker Root 创建挂载点..."
USB_MOUNT_POINT="/mnt/upan_data"
DOCKER_ROOT="$USB_MOUNT_POINT/docker"
mkdir -p $DOCKER_ROOT

green "将挂载 U 盘到 $DOCKER_ROOT..."
mount -t ext4 /dev/$CORRECTED_PART $USB_MOUNT_POINT

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
green "正在更新OPKG软件包..."
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

green "正在设置开机启动顺序的配置\n先挂载U盘,再启动Docker 修改/etc/rc.local后如下\n"
# 首先，备份 /etc/rc.local
cp /etc/rc.local /etc/rc.local.backup
# U盘分区 /dev/sdx
USB_DEVICE_PART="/dev/$CORRECTED_PART"
# glinet系统重启后的 USB自动挂载点
SYSTEM_USB_AUTO_MOUNTPOINT="/tmp/mountd/disk1_part1"
# 卸载USB自动挂载点 挂载自定义挂载点 /mnt/upan_data
if ! grep -q "umount $SYSTEM_USB_AUTO_MOUNTPOINT" /etc/rc.local; then
    sed -i '/exit 0/d' /etc/rc.local

    # 将新的命令添加到 /etc/rc.local，然后再加上 exit 0
    {
        echo "umount $SYSTEM_USB_AUTO_MOUNTPOINT || true"
        echo "mount $USB_DEVICE_PART $USB_MOUNT_POINT || true"
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
yellow "Docker 运行环境部署完毕,建议重启一次路由器"
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
        red "是否立即重启？(y/n)"
        read -r answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            red "正在重启..."
            reboot
        else
            yellow "选择了不立即重启。请手动重启以应用更改。"
        fi
    else
        green "设置正确,您可以直接使用啦～"
        light_yellow "不过为了验证下次启动docker的有效性 建议手动重启路由器一次 祝您使用愉快"
    fi
fi

