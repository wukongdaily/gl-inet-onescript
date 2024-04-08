#!/bin/sh
# 定义颜色输出函数
red() { echo -e "\033[31m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
greeninfo() { echo -e "\033[32m\033[01m[INFO] $1\033[0m"; }
blueinfo() { echo -e "\033[32m\033[01m$1\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$1\033[0m"; }
blue() { echo -e "\033[34m\033[01m$1\033[0m"; }
light_magenta() { echo -e "\033[95m\033[01m$1\033[0m"; }
light_yellow() { echo -e "\033[93m\033[01m$1\033[0m"; }
purple() { echo -e "\033[38;5;141m$1\033[0m"; }
cyan() { echo -e "\033[38;2;0;255;255m$1\033[0m"; }

install_depends_apps() {
    cyan "正在安装必备工具...."
    opkg update >/dev/null 2>&1
    for pkg in lsblk fdisk; do
        if opkg list-installed | grep -qw "$pkg"; then
            cyan "$pkg 已安装。"
        else
            if opkg install "$pkg" >/dev/null 2>&1; then
                green "$pkg 安装成功。"
            else
                red "$pkg 安装失败。"
                exit 1
            fi
        fi
    done
}

# 卸载USB设备
unmount_usb_device() {
    for mount in $(mount | grep "$1" | awk '{print $3}'); do
        yellow "正在尝试卸载U盘挂载点：$mount"
        umount $mount || {
            red "警告：无法卸载挂载点 $mount。可能有文件正在被访问或权限不足。"
            exit 1
        }
        blueinfo "U盘挂载点 $mount 卸载成功。"
    done
}

create_and_format_partitions() {
    local device=$1
    # 使用fdisk -l获取设备的总容量（以字节为单位）并转换为GB
    local total_bytes=$(fdisk -l $device | grep "Disk $device:" | awk '{print $5}')
    local total_gb=$(echo "$total_bytes" | awk '{print int($1/(1024*1024*1024))}')

    if [ -n "$CUSTOM_OPKG_SIZE" ]; then
        part1_gb=$CUSTOM_OPKG_SIZE
        yellow "U盘总容量约为 $total_gb GB,您设置的自定义软件包大小为 ${part1_gb}GB。"
    else
        # 计算10%的大小，以GB为单位
        part1_gb=$((total_gb / 10))
        yellow "U盘总容量约为 $total_gb GB,第一分区大小设置为U盘容量的10% 即 ${part1_gb}GB。"
    fi
    green "计划将第一分区分配给软件包 其大小为 ${part1_gb}GB"
    cyan "没错～你没有看错,让我们任性的告别 容 量 焦 虑！"
    # 创建分区并分配空间
    {
        echo g             # 创建一个新的空DOS分区表
        echo n             # 添加一个新分区
        echo p             # 主分区
        echo 1             # 分区号1
        echo               # 第一个可用扇区（默认）
        echo +${part1_gb}G # 为第一个分区分配计算出的GB数
        echo n             # 添加第二个新分区
        echo p             # 主分区
        echo 2             # 分区号2
        echo               # 第一个可用扇区（默认，自动）
        echo               # 最后一个扇区（默认，使用剩余空间）
        echo w             # 写入并退出
    } | fdisk $device >/dev/null 2>&1

    # 给系统一点时间来识别新分区
    sleep 5

    # 格式化第一个分区为EXT4
    local new_partition1="${device}1"
    cyan "正在将 $new_partition1 格式化为EXT4文件系统..."
    mkfs.ext4 -F $new_partition1 >/dev/null 2>&1
    cyan "$new_partition1 已成功格式化为EXT4文件系统。"
    green "第2分区 ${device}2 暂不格式化,未来您可分配给docker使用"
}

# 换区到U盘
change_overlay_usb() {
    install_depends_apps
    blueinfo "现在开始查找USB设备分区 请稍后......"
    local USB_PARTITION=$(lsblk -dn -o NAME,RM,TYPE | awk '$2=="1" && $3=="disk" {print "/dev/"$1; exit}')
    if [ -z "$USB_PARTITION" ]; then
        red "未找到USB磁盘。"
        exit 1
    fi
    yellow "找到USB磁盘 $USB_PARTITION"
    # 清零磁盘开始部分以清除分区表和文件系统签名
    dd if=/dev/zero of=$USB_PARTITION bs=1M count=10
    sync
    # 卸载所有与该磁盘相关的挂载点
    unmount_usb_device "$USB_PARTITION"
    red "正在将U盘${USB_PARTITION}分为2个区 ..."
    create_and_format_partitions "$USB_PARTITION"

    # U盘分区的挂载点
    MOUNT_POINT="/mnt/usb_overlay"
    # 临时目录用于复制数据
    TMP_DIR="/tmp/overlay_backup"
    # 创建挂载点目录
    mkdir -p $MOUNT_POINT
    # 挂载U盘分区
    cyan "重新挂载第一分区 ${USB_PARTITION}1 到  $MOUNT_POINT"
    mount ${USB_PARTITION}1 $MOUNT_POINT >/dev/null 2>&1
    # 创建临时目录用于备份overlay数据
    mkdir -p $TMP_DIR
    # 复制当前overlay到临时目录
    cp -a /overlay/. $TMP_DIR
    # 将临时目录的数据复制到U盘
    blueinfo "正在拷贝 当前系统文件到U盘"
    cp -a $TMP_DIR/. $MOUNT_POINT
    # 更新fstab配置，以便在启动时自动挂载U盘为overlay
    blueinfo "正在更新启动时的配置文件"
    uci set fstab.overlay=mount
    uci set fstab.overlay.uuid="$(blkid -o value -s UUID ${USB_PARTITION}1)"
    uci set fstab.overlay.target="/overlay"
    uci commit fstab
    # 清理临时目录
    rm -rf $TMP_DIR
    cyan "overlay更换分区完成 重启验证是否成功."
    red "是否立即重启？(y/n)"
    read -r answer
    if [ "$answer" = "y" ] || [ -z "$answer" ]; then
        red "正在重启..."
        reboot
    else
        yellow "您选择了不重启"
    fi
}

check_overlay_size() {
    # 使用df命令获取/overlay分区的总大小（以1K块为单位）
    OVERLAY_SIZE=$(df /overlay | awk '/\/overlay/{print $2}')
    # 将1GB转换为1K块单位，即1GB = 1*1024*1024 1K块
    ONE_GB_IN_1K_BLOCKS=$((1024 * 1024))
    # 比较/overlay分区的大小是否大于1GB
    if [ "$OVERLAY_SIZE" -gt "$ONE_GB_IN_1K_BLOCKS" ]; then
        yellow "检测到您已经换区到U盘啦,可以继续"
    else
        echo "您还没有换区到U盘,请先执行选项1."
        exit 1
    fi
}

# 安装 Docker 和 dockerd
install_docker() {
    check_overlay_size
    green "正在更新 OPKG 软件包..."
    opkg update >/dev/null 2>&1
    cyan "正在安装 Docker 及相关服务...请耐心等待一会...大约需要1-2分钟\n"
    opkg install luci-app-dockerman >/dev/null 2>&1
    opkg install luci-i18n-dockerman-zh-cn >/dev/null 2>&1
    opkg install dockerd --force-depends >/dev/null 2>&1
    cyan "Docker 运行环境部署完成 重启后生效\n"
    red "正在重启..."
    reboot
}

# 重新绑定
rebind_usb_overlay() {
    cyan "正在重新绑定U盘设备...."
    if opkg list-installed | grep -qw "lsblk"; then
        echo
    else
        opkg update >/dev/null 2>&1
        if opkg install "lsblk" >/dev/null 2>&1; then
            echo
        else
            red "$pkg 安装失败。"
            exit 1
        fi
    fi
    local USB_DEVICE=$(lsblk -dn -o NAME,RM,TYPE | awk '$2=="1" && $3=="disk" {print "/dev/"$1; exit}')
    if [ -z "$USB_DEVICE" ]; then
        red "未找到USB磁盘。"
        exit 1
    fi
    uci set fstab.overlay=mount
    uci set fstab.overlay.uuid="$(blkid -o value -s UUID ${USB_DEVICE}1)"
    uci set fstab.overlay.target="/overlay"
    uci commit fstab
    green "重新绑定成功！ 重启后生效"
    red "正在重启..."
    reboot
}

#自定义软件包的大小
#默认为U盘容量的10%
custom_package_size() {
    while :; do
        echo "请输入想分配的软件包的大小(数字,单位:GB):"
        read size
        # 检查输入是否为数字
        if [[ $size =~ ^[0-9]+$ ]]; then
            CUSTOM_OPKG_SIZE=$size
            yellow "已设置软件包大小为:$CUSTOM_OPKG_SIZE GB"
            green "接下来,您可以执行第一项啦"
            break # 跳出循环
        else
            red "错误: 请输入一个有效的数字。"
        fi
    done
}

while true; do
    clear
    echo "***********************************************************************"
    green "      MT-3000 软件包更换分区助手         "
    echo "**********************************************************************"
    echo
    cyan " 1. MT-3000 一键更换overlay分区到U盘"
    cyan " 2. MT-3000 安装Docker"
    cyan " 3. 自定义设置软件包大小(GB)"
    light_yellow " 4. 重新绑定U盘"
    echo
    echo " Q. 退出本程序"
    echo
    read -p "请选择一个选项: " choice
    echo

    case $choice in

    1)
        change_overlay_usb
        ;;
    2)
        install_docker
        ;;
    3)
        custom_package_size
        ;;
    4)
        rebind_usb_overlay
        ;;

    q | Q)
        echo "退出"
        exit 0
        ;;
    *)
        echo "无效选项，请重新选择。"
        ;;
    esac
    read -p "按 Enter 键继续..."
done
