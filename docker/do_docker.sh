#!/bin/sh

# 定义颜色输出函数
red() { echo -e "\033[31m\033[01m[WARNING] $1\033[0m"; }
green() { echo -e "\033[32m\033[01m[INFO] $1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m[NOTICE] $1\033[0m"; }
blue() { echo -e "\033[34m\033[01m[MESSAGE] $1\033[0m"; }
light_magenta() { echo -e "\033[95m\033[01m[NOTICE] $1\033[0m"; }
light_yellow() { echo -e "\033[93m\033[01m[NOTICE] $1\033[0m"; }

# 获取路由器型号信息
get_router_name() {
    cat /tmp/sysinfo/model
}

# 安装依赖应用
install_depends_apps() {
    blue "正在安装 部署docker环境所需的工具 lsblk 和 fdisk..."
    local router_name=$(get_router_name)
    opkg update >/dev/null 2>&1
    if opkg install lsblk fdisk >/dev/null 2>&1; then
        green "$router_name 的 lsblk 和 fdisk 工具安装成功。"
    else
        red "安装失败。"
        exit 1
    fi
}

# 准备USB设备
prepare_usb_device() {
    green "现在开始查找USB设备分区，请稍后......"
    local usb_disk=$(lsblk -dn -o NAME,RM,TYPE | awk '$2=="1" && $3=="disk" {print "/dev/"$1; exit}')
    if [ -z "$usb_disk" ]; then
        red "未找到USB磁盘。"
        exit 1
    fi
    yellow "找到USB磁盘：$usb_disk"

    # 清零磁盘开始部分以清除分区表和文件系统签名
    dd if=/dev/zero of=$usb_disk bs=1M count=10
    sync

    # 卸载所有与该磁盘相关的挂载点
    unmount_usb_device "$usb_disk"

    red "正在重新分区并格式化$usb_disk..."
    create_and_format_partition "$usb_disk"
}

# 卸载USB设备
unmount_usb_device() {
    for mount in $(mount | grep "$1" | awk '{print $3}'); do
        yellow "正在尝试卸载U盘挂载点：$mount"
        umount $mount || {
            red "警告：无法卸载挂载点 $mount。可能有文件正在被访问或权限不足。"
            exit 1
        }
        green "U盘挂载点 $mount 卸载成功。"
    done
}

# 创建并格式化分区
create_and_format_partition() {
    {
        echo o # 创建一个新的空DOS分区表
        echo n # 添加一个新分区
        echo p # 主分区
        echo 1 # 分区号1
        echo   # 第一个可用扇区（默认）
        echo   # 最后一个扇区（默认，使用剩余空间）
        echo w # 写入并退出
    } | fdisk $1 >/dev/null 2>&1

    sleep 5

    local new_partition="${1}1"
    red "正在将U盘 $new_partition 格式化为EXT4文件系统..."
    mkfs.ext4 -F $new_partition >/dev/null 2>&1
    green "$new_partition 已成功格式化为EXT4文件系统。"
    configure_and_start_docker $new_partition
}

# 配置并启动Docker
configure_and_start_docker() {
    local new_partition="$1"
    local usb_mount_point="/mnt/upan_data"
    local docker_root="$usb_mount_point/docker"

    mkdir -p $docker_root
    green "将U盘 挂载到 $usb_mount_point..."
    mount -t ext4 $new_partition $usb_mount_point
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
      "data-root": "'$docker_root'"
    }' >/etc/docker/daemon.json

    install_docker
    configure_docker_to_start_on_boot "$new_partition" "$usb_mount_point"
    start_docker_and_check
}

# 安装 Docker 和 dockerd
install_docker() {
    green "正在更新 OPKG 软件包..."
    opkg update >/dev/null 2>&1
    green "正在安装 Docker 及相关服务...请耐心等待一会...大约需要1分钟\n"
    opkg install luci-app-dockerman >/dev/null 2>&1
    opkg install luci-i18n-dockerman-zh-cn >/dev/null 2>&1
    opkg install dockerd --force-depends >/dev/null 2>&1
}

# 配置 Docker 开机启动
configure_docker_to_start_on_boot() {
    local new_partition="$1"
    local usb_mount_point="$2"
    # 创建并配置启动脚本
    green "正在设置 Docker 跟随系统启动的文件:/etc/init.d/docker"
    cat <<EOF >/etc/init.d/docker
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1
PROG="/usr/bin/dockerd"

start_service() {
    procd_open_instance
    procd_set_param command \$PROG --config-file /etc/docker/daemon.json
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

    chmod +x /etc/init.d/docker
    /etc/init.d/docker enable
}

# 启动 Docker 并检查
start_docker_and_check() {
    /etc/init.d/docker start
    sleep 5
    if ! docker info >/dev/null 2>&1; then
        red "Docker 启动失败,您可以手动启动docker 执行 /etc/init.d/docker start"
    else
        green "Docker 启动成功并设置正确,您可以直接使用啦～\n"
        DOCKER_ROOT_DIR=$(docker info 2>&1 | grep -v "WARNING" | grep "Docker Root Dir" | awk '{print $4}')
        light_magenta "当前Docker根目录为: $DOCKER_ROOT_DIR"
        light_yellow "Docker根目录剩余空间:$(df -h $DOCKER_ROOT_DIR | awk 'NR==2{print $4}')"
        yellow "不过为了验证下次启动docker的有效性 建议手动重启路由器一次 祝您使用愉快\n"
        red "是否立即重启？(y/n)"
        read -r answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            red "正在重启..."
            reboot
        else
            yellow "您选择了不重启"
        fi
    fi
}

# START
install_depends_apps
prepare_usb_device