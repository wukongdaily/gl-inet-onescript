#!/bin/bash
proxy_github="https://ghproxy.com/"
setup_base_init() {

	#添加出处信息
	add_author_info
	#添加安卓时间服务器
	add_dhcp_domain
	##设置时区
	uci set system.@system[0].zonename='Asia/Shanghai'
	uci set system.@system[0].timezone='CST-8'
	uci commit system
	/etc/init.d/system reload

	## 设置防火墙wan 打开,方便主路由访问
	uci set firewall.@zone[1].input='ACCEPT'
	uci commit firewall
}

## 安装应用商店和主题
install_istore() {
	##设置Argon 紫色主题 并且 设置第三方软件源
	setup_software_source 1
	opkg install luci-app-argon-config
	uci set luci.main.mediaurlbase='/luci-static/argon'
	uci set luci.main.lang='zh_cn'
	uci commit
	##安装完毕之后 还原软件源
	setup_software_source 0

	do_istore
	#升级iStore商店到最新版
	is-opkg do_self_upgrade
	#安装首页风格
	is-opkg install luci-app-quickstart
	is-opkg install 'app-meta-ddnsto'
	#安装首页需要的文件管理功能
	is-opkg install 'app-meta-linkease'
	# 安装磁盘管理
	is-opkg install 'app-meta-diskman'
	# 若已安装iStore商店则在概览中追加iStore字样
	if ! grep -q " like iStoreOS" /tmp/sysinfo/model; then
		sed -i '1s/$/ like iStoreOS/' /tmp/sysinfo/model
	fi
}
# 安装iStore 参考 https://github.com/linkease/istore
do_istore() {
	echo "do_istore method==================>"
	ISTORE_REPO=https://istore.linkease.com/repo/all/store
	FCURL="curl --fail --show-error"

	curl -V >/dev/null 2>&1 || {
		echo "prereq: install curl"
		opkg info curl | grep -Fqm1 curl || opkg update
		opkg install curl
	}

	IPK=$($FCURL "$ISTORE_REPO/Packages.gz" | zcat | grep -m1 '^Filename: luci-app-store.*\.ipk$' | sed -n -e 's/^Filename: \(.\+\)$/\1/p')

	[ -n "$IPK" ] || exit 1

	$FCURL "$ISTORE_REPO/$IPK" | tar -xzO ./data.tar.gz | tar -xzO ./bin/is-opkg >/tmp/is-opkg

	[ -s "/tmp/is-opkg" ] || exit 1

	chmod 755 /tmp/is-opkg
	/tmp/is-opkg update
	# /tmp/is-opkg install taskd
	/tmp/is-opkg opkg install --force-reinstall luci-lib-taskd luci-lib-xterm
	/tmp/is-opkg opkg install --force-reinstall luci-app-store || exit $?
	[ -s "/etc/init.d/tasks" ] || /tmp/is-opkg opkg install --force-reinstall taskd
	[ -s "/usr/lib/lua/luci/cbi.lua" ] || /tmp/is-opkg opkg install luci-compat >/dev/null 2>&1
}

#设置风扇工作温度
setup_cpu_fans() {
	#设定温度阀值,cpu高于48度,则风扇开始工作
	uci set glfan.@globals[0].temperature=48
	uci set glfan.@globals[0].warn_temperature=48
	uci set glfan.@globals[0].integration=4
	uci set glfan.@globals[0].differential=20
	uci commit glfan
	/etc/init.d/gl_fan restart
}

# 判断系统是否为iStoreOS
is_iStoreOS() {
	DISTRIB_ID=$(cat /etc/openwrt_release | grep "DISTRIB_ID" | cut -d "'" -f 2)
	# 检查DISTRIB_ID的值是否等于'iStoreOS'
	if [ "$DISTRIB_ID" = "iStoreOS" ]; then
		return 0 # true
	else
		return 1 # false
	fi
}

## 去除opkg签名
remove_check_signature_option() {
	local opkg_conf="/etc/opkg.conf"
	sed -i '/option check_signature/d' "$opkg_conf"
}

## 添加opkg签名
add_check_signature_option() {
	local opkg_conf="/etc/opkg.conf"
	echo "option check_signature 1" >>"$opkg_conf"
}

#设置第三方软件源
setup_software_source() {
	## 传入0和1 分别代表原始和第三方软件源
	if [ "$1" -eq 0 ]; then
		echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
		##如果是iStoreOS系统,还原软件源之后，要添加签名
		if is_iStoreOS; then
			add_check_signature_option
		else
			echo
		fi
		# 还原软件源之后更新
		opkg update
	elif [ "$1" -eq 1 ]; then
		#传入1 代表设置第三方软件源 先要删掉签名
		remove_check_signature_option
		# 先删除再添加以免重复
		echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
		echo "src/gz dllkids https://op.dllkids.xyz/packages/aarch64_cortex-a53" >>/etc/opkg/customfeeds.conf
		# 设置第三方源后要更新
		opkg update
	else
		echo "Invalid option. Please provide 0 or 1."
	fi
}

# 添加主机名映射(解决安卓原生TV首次连不上wifi的问题)
add_dhcp_domain() {
	local domain_name="time.android.com"
	local domain_ip="203.107.6.88"

	# 检查是否存在相同的域名记录
	existing_records=$(uci show dhcp | grep "dhcp.@domain\[[0-9]\+\].name='$domain_name'")
	if [ -z "$existing_records" ]; then
		# 添加新的域名记录
		uci add dhcp domain
		uci set "dhcp.@domain[-1].name=$domain_name"
		uci set "dhcp.@domain[-1].ip=$domain_ip"
		uci commit dhcp
		echo
		echo "已添加新的域名记录"
	else
		echo "相同的域名记录已存在，无需重复添加"
	fi
	echo -e "\n"
	echo -e "time.android.com    203.107.6.88 "
}

#添加出处信息
add_author_info() {
	uci set system.@system[0].description='wukongdaily'
	uci set system.@system[0].notes='文档说明:
    https://github.com/wukongdaily/gl-inet-onescript'
	uci commit system
}

##获取软路由型号信息
get_router_name() {
	model_info=$(cat /tmp/sysinfo/model)
	echo "$model_info"
}

get_router_hostname() {
	hostname=$(uci get system.@system[0].hostname)
	echo "$hostname 路由器"
}

add_custom_feed() {
	# 先清空配置
	echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
	# Prompt the user to enter the feed URL
	echo "请输入自定义软件源的地址(通常是https开头 aarch64_cortex-a53 结尾):"
	read feed_url
	if [ -n "$feed_url" ]; then
		echo "src/gz dllkids $feed_url" >>/etc/opkg/customfeeds.conf
		opkg update
		if [ $? -eq 0 ]; then
			echo "已添加并更新列表."
		else
			echo "已添加但更新失败,请检查网络或重试."
		fi
	else
		echo "Error: Feed URL not provided. No changes were made."
	fi
}

remove_custom_feed() {
	echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
	opkg update
	if [ $? -eq 0 ]; then
		echo "已删除并更新列表."
	else
		echo "已删除了自定义软件源但更新失败,请检查网络或重试."
	fi
}

# 检查是否安装了 whiptail
check_whiptail_installed() {
	if [ -e /usr/bin/whiptail ]; then
		return 0
	else
		return 1
	fi
}

#定义一个通用的Dialog
show_whiptail_dialog() {
	#判断是否具备whiptail dialog组件
	if check_whiptail_installed; then
		echo "whiptail has installed"
	else
		echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
		opkg update
		opkg install whiptail
	fi
	local title="$1"
	local message="$2"
	local function_definition="$3"
	whiptail --title "$title" --yesno "$message" 15 60 --yes-button "是" --no-button "否"
	if [ $? -eq 0 ]; then
		eval "$function_definition"
	else
		echo "退出"
		exit 0
	fi
}

# 执行重启操作
do_reboot() {
	reboot
}

#提示用户要重启
show_reboot_tips() {
	reboot_code='do_reboot'
	show_whiptail_dialog "重启提醒" "           $(get_router_hostname)\n           一键风格化运行完成.\n           为了更好的清理临时缓存,\n           您是否要重启路由器?" "$reboot_code"
}

#自定义风扇开始工作的温度
set_glfan_temp() {

	is_integer() {
		if [[ $1 =~ ^[0-9]+$ ]]; then
			return 0 # 是整数
		else
			return 1 # 不是整数
		fi
	}
	echo "兼容带风扇机型的GL-iNet路由器"
	echo "请输入风扇开始工作的温度(建议40-70之间的整数):"
	read temp

	if is_integer "$temp"; then
		uci set glfan.@globals[0].temperature="$temp"
		uci set glfan.@globals[0].warn_temperature="$temp"
		uci set glfan.@globals[0].integration=4
		uci set glfan.@globals[0].differential=20
		uci commit glfan
		/etc/init.d/gl_fan restart
		echo "设置成功！稍等片刻,请查看风扇转动情况"
	else
		echo "错误: 请输入整数."
	fi
}

rollback_old_version() {
	download_url="https://ghproxy.com/https://github.com/wukongdaily/gl-inet-onescript/raw/1f25c161512e9b416227f60656e8c2139c993f69/gl-inet.run"
	local_file_path="/tmp/gl-inet.run"
	wget -O "$local_file_path" "$download_url"
	chmod +x "$local_file_path"
	"$local_file_path"
}

recovery_opkg_settings() {
	echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
	router_name=$(get_router_name)
	case "$router_name" in
	*3000*)
		echo "Router name contains '3000'."
		mt3000_opkg="https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/mt-3000/distfeeds.conf"
		wget -O /etc/opkg/distfeeds.conf ${proxy_github}${mt3000_opkg}
		;;
	*2500*)
		echo "Router name contains '2500'."
		mt2500a_opkg="https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/mt-2500a/distfeeds.conf"
		wget -O /etc/opkg/distfeeds.conf ${proxy_github}${mt2500a_opkg}
		;;
	*)
		echo "Router name does not contain '3000' or '2500'."
		;;
	esac
	echo "再次更新首页luci-app-quickstart"
	is-opkg install luci-app-quickstart
	echo "Tips: 重启路由器后才能完全生效"
}

do_luci_app_adguardhome(){
	setup_software_source 0
	opkg install adguardhome
	echo "请访问 http://192.168.8.1:3000  初始化设置adguardhome "
}

while true; do
	clear
	echo "***********************************************************************"
	echo "*      一键安装工具箱(for gl-inet Router) v1.0        "
	echo "*      Developed by @wukongdaily        "
	echo "**********************************************************************"
	echo
	echo "*      当前的路由器型号: $(get_router_name)"
	echo
	echo "**********************************************************************"
	echo
	echo " 1. MT2500A一键iStore风格化"
	echo
	echo " 2. MT3000一键iStore风格化"
	echo
	echo " 3. 设置自定义软件源"
	echo
	echo " 4. 删除自定义软件源"
	echo
	echo " 5. 设置风扇开始工作的温度"
	echo
	echo " 6. 恢复原厂OPKG配置(软件包)"
	echo
	echo " 7. 安装去广告adguardhome(10MB)"
	echo 
	echo " Q. 退出本程序"
	echo
	read -p "请选择一个选项: " choice

	case $choice in
	1)
		echo "MT2500A一键iStore风格化"
		#基础必备设置
		setup_base_init
		#安装Argon主题和iStore商店风格
		install_istore
		show_reboot_tips
		;;
	2)
		echo "MT3000一键iStore风格化"
		#设置风扇工作温度
		setup_cpu_fans
		#基础必备设置
		setup_base_init
		#安装Argon主题和iStore商店风格
		install_istore
		show_reboot_tips
		;;
	3)
		add_custom_feed
		;;
	4)
		remove_custom_feed
		;;
	5)
		set_glfan_temp
		;;
	6)
		recovery_opkg_settings
		;;
	7)
		do_luci_app_adguardhome
		;;
	h | H)
		rollback_old_version
		exit 0
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
