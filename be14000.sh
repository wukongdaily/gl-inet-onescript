#!/bin/sh
# be14000.sh — GL-BE14000 (Flint 4) 一键 iStoreOS 风格化
#
# 目标环境：GL.iNet 固件 4.9.x / OpenWrt 21.02-SNAPSHOT / 内核 5.4.281
#           busybox ash（无 bash）/ opkg / aarch64_cortex-a53
#
# 本脚本严格遵循 POSIX sh。目标机没有 bash，使用 [ ] 而不是双括号。
# 颜色输出用 printf：dash 的 echo 不支持扩展选项。

BOARD_EXPECTED="glinet,gl-be14000"
FEED_BASE="https://fw.gl-inet.com/releases/v21.02-SNAPSHOT/mt798x"

# ipk 资源基址。指向上游作者的 netlify 镜像，不是图省事——实测本机所在网络
# 对 GitHub 系 CDN 的可达率极低：raw.githubusercontent.com 1/3、jsDelivr 的
# 二进制 0/3，而 netlify、cpolar、fw.gl-inet.com 都稳定 3/3。argon 主题一次
# 要连下 3 个 ipk，按 1/3 算几乎必失败。两边文件内容一致（argon 包同为
# 467831 字节）。
# FEED_BASE 与 ISTORE_REPO 不在此列：那是 GL.iNet 和 linkease 的官方源。
ASSET_BASE="https://mt3000.netlify.app"

red()    { printf '\033[31;01m%s\033[0m\n' "$1"; }
green()  { printf '\033[32;01m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33;01m%s\033[0m\n' "$1"; }
cyan()   { printf '\033[38;2;0;255;255m%s\033[0m\n' "$1"; }

# 读取主板标识。用 board_name 而非 model：前者是稳定的机器标识，
# 后者是可能被改写的展示名。
get_board_name() {
    cat /tmp/sysinfo/board_name 2>/dev/null
}

# 判断是否为 Flint 4。可传入 board 字符串以便测试。
# 注意用 ${1-...} 而非 ${1:-...}：后者在 $1 为空字符串时也会回退去读
# board_name 文件，导致 is_flint4 '' 在真机上（board_name 恰好等于
# BOARD_EXPECTED）被误判为通过。只有「未传参」才该回退。
is_flint4() {
    _board="${1-$(get_board_name)}"
    [ "$_board" = "$BOARD_EXPECTED" ]
}

# 生成 distfeeds 内容。内联而非从 CDN 下载：只有 3 行文本，
# 不值得引入网络依赖，也避免脚本合并后等 CDN 部署的空窗期。
# kmod 路径带完整内核版本，随 uname -r 变化，固件升级后无需改脚本。
distfeeds_content() {
    _kver="${1:-$(uname -r)}"
    _kmaj=$(echo "$_kver" | cut -d. -f1,2)
    cat <<EOF
src/gz glinet_core $FEED_BASE/kmod-$_kver/aarch64_cortex-a53/kmod-$_kmaj
src/gz glinet_gli_pub $FEED_BASE/packages/aarch64_cortex-a53/glinet
src/gz glinet_gli_packages $FEED_BASE/packages/aarch64_cortex-a53/packages
EOF
}

# 写入软件源并刷新。写之前备份一次，便于回滚。
# 备份和写入都必须检查返回值：overlay 只读或写满是 OpenWrt 上真实存在的
# 故障模式，若不检查，函数会在文件其实没变的情况下打印「已写入」并 cat 出
# 旧内容，随后 opkg update 对着旧 feed 成功返回，整体报告成功。
setup_feeds() {
    if [ ! -f /etc/opkg/distfeeds.conf.bak ]; then
        if cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.bak 2>/dev/null; then
            cyan "原 distfeeds 已备份到 /etc/opkg/distfeeds.conf.bak"
        else
            red "备份 /etc/opkg/distfeeds.conf 失败，已中止"
            return 1
        fi
    fi
    if ! distfeeds_content >/etc/opkg/distfeeds.conf; then
        red "写入 /etc/opkg/distfeeds.conf 失败（overlay 只读或空间不足？）"
        return 1
    fi
    cyan "软件源已写入:"
    cat /etc/opkg/distfeeds.conf
    yellow "正在刷新软件包列表..."
    if opkg update >/dev/null 2>&1; then
        green "软件源刷新成功"
        return 0
    fi
    red "opkg update 失败，请检查网络"
    return 1
}

# 测试时可指向临时目录，正常运行为空（即真实根）
ROOT_PREFIX="${ROOT_PREFIX:-}"

# LuCI 核心包。Flint 4 源里没有 luci-lua-runtime（这套 LuCI 用
# lua 5.1 + luci-lib-base 的旧模型），也不要装 libopenssl3
# ——本机是 openssl 1.1，装 3 会冲突。
#
# 必须包含 luci-theme-bootstrap：luci-base 不依赖任何主题，而
# luci.main.mediaurlbase 默认指向 /luci-static/bootstrap。少了它，
# dispatcher.lua 会直接 assert 失败（"No valid theme found"），
# 整个 LuCI 返回 500。它同时也是 argon 安装失败时的兜底主题。
LUCI_PKGS="luci-base luci-compat luci-lib-ipkg luci-mod-admin-full luci-theme-bootstrap luci-i18n-base-zh-cn"

ISTORE_REPO="https://istore.linkease.com/repo/all/store"

# 安装和校验共用同一份清单，避免两处漂移
ISTORE_PKGS="luci-app-store luci-lib-taskd luci-lib-xterm taskd"

# /www/luci-static/ 下除 resources 外是否还有主题目录。
# resources 由 luci-base 提供，不是主题。
#
# 循环变量必须叫 _theme_dir 而不是 _d：测试里的 assert_ok/assert_fail
# 用全局 _d 存断言描述，被测函数若也用 _d 会把描述冲掉，失败时打印出
# 的是一个 glob 路径而不是「哪条断言挂了」。
has_luci_theme() {
    for _theme_dir in "$ROOT_PREFIX"/www/luci-static/*/; do
        [ -d "$_theme_dir" ] || continue
        case "${_theme_dir%/}" in
        */resources) ;;
        *) return 0 ;;
        esac
    done
    return 1
}

# 判断 LuCI 是否真的可用。检查标志文件而非 opkg 记录：opkg 会把
# 文件部署失败的包也记为已安装。
#   /www/cgi-bin/luci        luci-base 的 CGI 入口（nginx→fcgiwrap 执行它）
#   cbi.lua                  luci-compat 就位（实测此文件由 luci-compat 提供，
#                            不是 luci-base）
#   至少一个主题目录          没有主题时 dispatcher.lua 直接 assert 失败，
#                            LuCI 返回 500——此时「装好了」是假的
luci_installed() {
    [ -f "$ROOT_PREFIX/www/cgi-bin/luci" ] &&
        [ -f "$ROOT_PREFIX/usr/lib/lua/luci/cbi.lua" ] &&
        has_luci_theme
}

# 返回 $1 中未安装的包（前导空格分隔），空串表示全部就位。
# 一次性取 opkg list-installed，避免在循环里反复调用。
# 本函数总在 $( ) 里调用，所以 _installed/_m/_p 不会泄漏回调用方的循环变量。
pkgs_missing() {
    _installed=$(opkg list-installed)
    _m=""
    for _p in $1; do
        printf '%s\n' "$_installed" | grep -q "^$_p - " || _m="$_m $_p"
    done
    printf '%s' "$_m"
}

# 入口短路和出口校验必须用同一个判据。若短路条件比校验条件宽松，
# 一次「装了一半」的运行会在下次调用时被短路成功，缺失的包永远补不回来。
luci_ready() {
    [ -z "$(pkgs_missing "$LUCI_PKGS")" ] && luci_installed
}

istore_ready() {
    [ -z "$(pkgs_missing "$ISTORE_PKGS")" ] && [ -x /bin/is-opkg ]
}

# 安装 LuCI。GL.iNet 4.x 出厂不带 LuCI，必须先装它，
# 否则 argon 主题和 iStore 都无从谈起。
install_luci() {
    if luci_ready; then
        green "LuCI 已安装，跳过"
        return 0
    fi
    yellow "正在安装 LuCI 核心组件（Flint 4 出厂不带）..."
    for _p in $LUCI_PKGS; do
        cyan "  安装 $_p"
        opkg install "$_p" || yellow "  $_p 安装返回非 0，稍后统一校验"
    done

    # 逐包核实。上面的循环刻意不因单个包失败而中断（opkg 对「已是最新版」
    # 也可能返回非 0），但必须在这里把 LUCI_PKGS 全部核实一遍：
    # luci_installed 的三个标志文件只覆盖 luci-base、luci-compat、
    # luci-theme-bootstrap，漏掉 luci-mod-admin-full 这类包会造成假成功
    # ——管理界面缺失，脚本却报告安装成功。
    _missing=$(pkgs_missing "$LUCI_PKGS")
    if [ -n "$_missing" ]; then
        red "以下 LuCI 组件未安装成功:$_missing"
        red "后续步骤依赖 LuCI，已中止"
        return 1
    fi

    if luci_installed; then
        green "LuCI 安装成功"
        return 0
    fi
    red "LuCI 安装失败：缺少 CGI 入口、cbi.lua 或主题目录"
    red "后续步骤依赖 LuCI，已中止"
    return 1
}

# 安装 iStore 应用商店。参考 https://github.com/linkease/istore
# 与上游脚本的区别：先确认 LuCI 就位，否则 luci-app-store 装上也用不了。
install_istore() {
    if ! luci_installed; then
        red "LuCI 未就位，请先执行 LuCI 安装"
        return 1
    fi
    if istore_ready; then
        green "iStore 已安装，跳过"
        return 0
    fi

    command -v curl >/dev/null 2>&1 || {
        yellow "正在安装 curl"
        opkg install curl || { red "curl 安装失败"; return 1; }
    }

    yellow "正在获取 iStore 安装包..."
    _ipk=$(curl --fail --show-error "$ISTORE_REPO/Packages.gz" 2>/dev/null |
        zcat | grep -m1 '^Filename: luci-app-store.*\.ipk$' |
        sed -n -e 's/^Filename: \(.\+\)$/\1/p')
    if [ -z "$_ipk" ]; then
        red "无法从 iStore 源获取包名，请检查网络"
        return 1
    fi

    curl --fail --show-error "$ISTORE_REPO/$_ipk" 2>/dev/null |
        tar -xzO ./data.tar.gz | tar -xzO ./bin/is-opkg >/tmp/is-opkg
    if [ ! -s /tmp/is-opkg ]; then
        red "is-opkg 提取失败"
        return 1
    fi
    chmod 755 /tmp/is-opkg

    /tmp/is-opkg update
    /tmp/is-opkg opkg install --force-reinstall luci-lib-taskd luci-lib-xterm
    /tmp/is-opkg opkg install --force-reinstall luci-app-store || {
        red "luci-app-store 安装失败"
        return 1
    }
    [ -s /etc/init.d/tasks ] || /tmp/is-opkg opkg install --force-reinstall taskd

    # 逐项核实。上面几步刻意不因单个失败而中断，但 /bin/is-opkg 存在
    # 只说明商店主程序落地了，说明不了 taskd / xterm 是否就位——taskd
    # 缺失会让 iStore 的任务系统失效，后续 is-opkg install 行为异常，
    # 脚本却一路报告成功。
    _missing=$(pkgs_missing "$ISTORE_PKGS")
    if [ -n "$_missing" ]; then
        red "以下 iStore 组件未安装成功:$_missing"
        return 1
    fi

    if [ -x /bin/is-opkg ]; then
        green "iStore 安装成功"
        return 0
    fi
    red "iStore 安装后未找到 /bin/is-opkg"
    return 1
}

THEME_BASE="$ASSET_BASE/theme"

# 安装 argon 主题。官方源里只有 bootstrap/material/openwrt，没有 argon，
# 所以仍需从 CDN 取 ipk。
# 与 gl-inet.sh 的区别：不装 luci-lua-runtime（本机无此包）和
# libopenssl3（本机是 openssl 1.1，装 3 会冲突），luci-compat 走官方源。
install_theme() {
    if ! luci_installed; then
        red "LuCI 未就位，无法安装主题"
        return 1
    fi

    opkg install luci-lib-ipkg >/dev/null 2>&1

    yellow "正在下载 argon 主题..."
    for _f in luci-theme-argon-master_2.2.9.4_all.ipk \
        luci-app-argon-config_0.9_all.ipk \
        luci-i18n-argon-config-zh-cn.ipk; do
        if ! wget -q -O "/tmp/$_f" "$THEME_BASE/$_f"; then
            red "下载 $_f 失败"
            return 1
        fi
    done

    if opkg install /tmp/luci-theme-argon-master_2.2.9.4_all.ipk \
        /tmp/luci-app-argon-config_0.9_all.ipk \
        /tmp/luci-i18n-argon-config-zh-cn.ipk; then
        # opkg 的退出码不足以证明主题真的落地：opkg install 对多个 ipk 是
        # 逐个处理并累计错误的，postinst 出问题也未必反映在退出码上。
        # 必须确认主题真实可用再切 mediaurlbase——否则会把 LuCI 指向一个
        # 不存在的主题，重现 Task 4 那个 "No valid theme found" 的 500。
        #
        # 查具体文件而不是只查目录：闪存写满或解包中断会留下一个空的
        # argon/ 目录，[ -d ] 会放行，结果是主题「装上了」却完全没有样式。
        # cascade.css 是 argon 的主样式表，它存在就等于主题真的可用。
        #
        # 注意 ROOT_PREFIX 只作用于这一处检查；本函数里的 wget/opkg/uci
        # 始终操作真实根，整个函数并不是可重定位的。
        if [ ! -f "$ROOT_PREFIX/www/luci-static/argon/css/cascade.css" ]; then
            red "argon 包已安装但主样式表缺失（可能解包中断或空间不足）"
            yellow "保留当前主题，未修改 mediaurlbase"
            return 1
        fi
        uci set luci.main.mediaurlbase='/luci-static/argon'
        uci set luci.main.lang='zh_cn'
        if ! uci commit luci; then
            red "保存 LuCI 配置失败，主题未切换"
            return 1
        fi
        # 回读确认：提交成功不等于值真的写进去了
        if [ "$(uci -q get luci.main.mediaurlbase)" != "/luci-static/argon" ]; then
            red "mediaurlbase 未写入，主题可能未生效"
            return 1
        fi
        green "argon 主题安装成功，重新登录 LuCI 生效"
        return 0
    fi

    red "argon 主题安装失败，保留当前主题（bootstrap）"
    yellow "这不影响已完成的步骤，可稍后单独重试"
    return 1
}

FILETRANSFER_BASE="$ASSET_BASE/luci-app-filetransfer"

# 安装体积很小的文件传输插件，默认上传位置 /tmp/upload/
install_filetransfer() {
    # 先清空：上一轮残留的同名/异名 ipk 会被下面的 *.ipk 通配一起装进去
    rm -rf /tmp/luci-app-filetransfer
    mkdir -p /tmp/luci-app-filetransfer
    for _f in luci-app-filetransfer_all.ipk luci-lib-fs_1.0-14_all.ipk; do
        wget -q -O "/tmp/luci-app-filetransfer/$_f" "$FILETRANSFER_BASE/$_f" ||
            { red "下载 $_f 失败"; return 1; }
    done
    opkg install /tmp/luci-app-filetransfer/*.ipk --force-depends
}

# 安装常用插件。is-opkg 来自 iStore。
install_apps() {
    yellow "正在安装终端组件 ttyd"
    opkg install ttyd || yellow "ttyd 安装失败，继续"

    yellow "正在安装文件传输"
    install_filetransfer || yellow "文件传输安装失败，继续"

    if [ -x /bin/is-opkg ]; then
        for _a in app-meta-sftp app-meta-ddnsto app-meta-diskman; do
            cyan "  iStore 安装 $_a"
            is-opkg install "$_a" || yellow "  $_a 安装失败，继续"
        done
        _checklist="ttyd luci-lib-fs luci-app-filetransfer \
            app-meta-sftp app-meta-ddnsto app-meta-diskman"
    else
        yellow "未检测到 is-opkg，跳过 iStore 插件（app-meta-* 不计入核实）"
        _checklist="ttyd luci-lib-fs luci-app-filetransfer"
    fi

    # 核实清单随 is-opkg 是否可用而变：没有 iStore 时 app-meta-* 是「跳过」
    # 而不是「失败」，混为一谈会误导用户去排查一个根本没发生的安装。
    _failed=$(pkgs_missing "$_checklist")
    if [ -n "$_failed" ]; then
        yellow "以下插件未安装成功:$_failed"
        yellow "它们不是必需组件，可稍后重试本项或在 iStore 中手动安装"
        return 1
    fi
    green "插件全部安装成功"
    return 0
}

# 防止误操作：隐藏 iStore 首页上的磁盘格式化按钮
hide_format_button() {
    _target="$ROOT_PREFIX/www/luci-static/quickstart/style.css"
    _marker="/* hide quickstart disk button */"
    if [ ! -f "$_target" ]; then
        yellow "未找到 $_target，跳过（quickstart 可能尚未安装）"
        return 0
    fi
    # 必须用 -F。marker 里的 `*` 在 BRE 里是元字符，grep -q 永远匹配不上，
    # 幂等守卫形同虚设——每跑一次就往 style.css 追加一份重复的 CSS。
    # （上游 gl-inet.sh 的 hide_homepage_format_button 有同样的缺陷。）
    if grep -qF "$_marker" "$_target"; then
        cyan "格式化按钮已隐藏，无需重复操作"
        return 0
    fi
    cat >>"$_target" <<EOF

$_marker
.value-data button {
  display: none !important;
}
EOF
    green "格式化按钮已隐藏"
}

# 安装 iStore 风格首页
setup_quickstart() {
    if [ ! -x /bin/is-opkg ]; then
        red "未检测到 iStore，请先执行菜单第 1 项（一键 iStoreOS 风格化）"
        return 1
    fi
    is-opkg update
    is-opkg install luci-i18n-quickstart-zh-cn --force-depends >/dev/null 2>&1

    # 同样不能只凭 is-opkg 的退出码：实测 luci-app-filetransfer 就在这台
    # 机器上被同一套机制静默装失败过。首页真正生效的标志是前端资源落地，
    # index.js 是 quickstart 的主脚本，它在才算配置成功。
    if [ ! -f "$ROOT_PREFIX/www/luci-static/quickstart/index.js" ]; then
        red "quickstart 前端资源缺失，iStore 首页未生效"
        return 1
    fi

    hide_format_button
    green "iStore 首页已配置"
    return 0
}

# 安装文件管理器（linkease）。体积较大，不进一键流程，只作独立菜单项。
install_filemanager() {
    if [ ! -x /bin/is-opkg ]; then
        red "未检测到 iStore，请先执行菜单第 1 项（一键 iStoreOS 风格化）"
        return 1
    fi
    yellow "正在安装文件管理器..."
    if is-opkg install app-meta-linkease; then
        green "文件管理器安装成功"
        printf '访问路径: http://192.168.8.1/cgi-bin/luci/admin/services/linkease/file/?path=/root\n'
        return 0
    fi
    red "文件管理器安装失败"
    return 1
}

# 添加主机名映射，解决部分安卓电视首次连 WiFi 卡在时间同步的问题
add_dhcp_domain() {
    _name="time.android.com"
    _ip="203.107.6.88"
    if uci show dhcp | grep -q "\.name='$_name'"; then
        cyan "DHCP 域名映射已存在，跳过"
        return 0
    fi
    uci add dhcp domain >/dev/null
    uci set "dhcp.@domain[-1].name=$_name"
    uci set "dhcp.@domain[-1].ip=$_ip"
    uci commit dhcp
    green "已添加 $_name 域名映射"
}

# 基础配置。
# 刻意不做两件事：
#   1. 不设置时区 —— Flint 4 出厂已是 CST-8 / Asia/Shanghai
#   2. 不修改防火墙 —— firewall.@zone[1] 是 wan，改成 ACCEPT 会把
#      路由器自身端口暴露到公网。gl-inet.sh 这么做是因为 MT3000
#      常被当旁路由，Flint 4 是主路由，不适用。
base_init() {
    uci set system.@system[0].description='wukongdaily'
    uci set system.@system[0].notes='文档说明:
    https://tvhelper.cpolar.cn/'
    uci commit system
    add_dhcp_domain
    green "基础配置完成（未修改防火墙与时区）"
}

FAN_TEMP_MAX=95

# 温度合法性校验。用 case 做数字判断，不能用双括号正则（本机无 bash）。
is_valid_temp() {
    _t="$1"
    _min="${2:-70}"
    case "$_t" in
        '' | *[!0-9]*) return 1 ;;
    esac
    [ "$_t" -ge "$_min" ] && [ "$_t" -le "$FAN_TEMP_MAX" ]
}

# 设置风扇启动温度。
# Flint 4 的 glfan schema 与 MT3000 不同：
#   有 minimum_temperature / div，没有 integration / differential。
# 出厂默认 temperature=75、minimum_temperature=70。
set_fan_temp() {
    _min=$(uci -q get glfan.@globals[0].minimum_temperature)
    [ -n "$_min" ] || _min=70
    _cur=$(uci -q get glfan.@globals[0].temperature)

    printf '当前风扇启动温度: %s°C（下限 %s°C，上限 %s°C）\n' \
        "${_cur:-未知}" "$_min" "$FAN_TEMP_MAX"
    printf '请输入新的风扇启动温度: '
    read -r _temp

    if ! is_valid_temp "$_temp" "$_min"; then
        red "无效输入：请输入 $_min 到 $FAN_TEMP_MAX 之间的整数"
        return 1
    fi

    uci set glfan.@globals[0].temperature="$_temp"
    uci set glfan.@globals[0].warn_temperature="$_temp"
    uci commit glfan
    if [ "$(uci -q get glfan.@globals[0].temperature)" != "$_temp" ]; then
        red "风扇温度未写入，请手动检查 uci show glfan"
        return 1
    fi
    /etc/init.d/gl_fan restart
    green "风扇启动温度已设为 ${_temp}°C"
}

# 输出 LuCI 访问方式。
# Flint 4 的 uhttpd 只监听 127.0.0.1:8080，nginx 在 80/443 通过
# fcgiwrap 执行 /www/cgi-bin/luci，并由 oui-access.lua 做后台会话鉴权。
# 所以其他机型常用的 http://192.168.8.1:8080 在这里永远连不上。
print_access_info() {
    printf '\n'
    green "风格化流程结束。访问 LuCI 的方式："
    printf '  1. 浏览器打开 http://192.168.8.1 登录后台\n'
    printf '  2. 系统 → 高级设置\n'
    printf '     （直达地址 http://192.168.8.1/cgi-bin/luci ，需先登录后台）\n'
    printf '\n'
    yellow "注意：Flint 4 的 uhttpd 仅监听回环，端口 8080 无法从局域网访问。"
    yellow "如需直连，使用菜单项「把 LuCI 开放到局域网」。"
}

# 把 uhttpd 从回环改到局域网，使 http://192.168.8.1:8080 可直接访问。
# 这会绕过 GL.iNet 后台的会话鉴权，等于把 LuCI 登录页直接暴露在内网，
# 同时也会开放 HTTPS 8443 端口。
# 所以默认不做，且执行前必须确认。

# 回读 uhttpd 实际监听的 8080 地址。只查 uci 不够：uci 反映的是配置，
# 若 restart 失败，配置已变而进程仍绑在旧地址上——那正是最危险的情形。
# netstat 看到的才是真的。重启后端口需要一点时间，重试几次。
uhttpd_listen_addr() {
    _try=0
    while [ "$_try" -lt 5 ]; do
        _addr=$(netstat -ln 2>/dev/null | awk '$4 ~ /:8080$/ {print $4; exit}')
        if [ -n "$_addr" ]; then
            printf '%s\n' "$_addr"
            return 0
        fi
        _try=$((_try + 1))
        sleep 1
    done
    return 1
}

expose_luci_lan() {
    red "警告：此操作会让 LuCI 绕过后台登录鉴权，直接暴露在局域网。"
    red "局域网内任何设备都能访问 http://192.168.8.1:8080 的 LuCI 登录页；"
    red "HTTPS 端口 8443 也会一并开放。"
    printf '确定继续吗？(y/N): '
    read -r _ans
    if [ "$_ans" != "y" ] && [ "$_ans" != "Y" ]; then
        yellow "已取消"
        return 0
    fi
    uci set uhttpd.main.listen_http='0.0.0.0:8080'
    uci set uhttpd.main.listen_https='0.0.0.0:8443'
    uci commit uhttpd
    /etc/init.d/uhttpd restart

    if [ "$(uhttpd_listen_addr)" != "0.0.0.0:8080" ]; then
        red "uhttpd 未按预期改绑，开放可能未生效"
        red "请手动检查: netstat -ln | grep 8080"
        return 1
    fi
    green "LuCI 已开放到局域网: http://192.168.8.1:8080（HTTPS 为 8443）"
    yellow "如需还原，使用菜单项「还原 LuCI 为仅本机访问」。"
}

# 还原 uhttpd 只监听回环
restore_luci_loopback() {
    uci set uhttpd.main.listen_http='127.0.0.1:8080'
    uci set uhttpd.main.listen_https='127.0.0.1:8443'
    uci commit uhttpd
    /etc/init.d/uhttpd restart

    # 还原路径尤其不能假装成功：若实际没生效，用户以为已经关上了，
    # 而 LuCI 仍暴露在局域网——这是最坏的一种误导。
    if [ "$(uhttpd_listen_addr)" != "127.0.0.1:8080" ]; then
        red "还原失败：uhttpd 仍未绑回回环，LuCI 可能仍暴露在局域网！"
        red "请手动检查: netstat -ln | grep 8080"
        return 1
    fi
    green "已还原：LuCI 仅本机可访问，请通过后台「高级设置」进入"
}

# 与其他机型脚本保持同一分发路径。实测该主机可达性良好（3/3），
# 而 GitHub 系 CDN 在国内网络下只有 0~1/3。
SCRIPT_URL="https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/be14000.sh"

# 解析脚本自身路径：裸文件名补 ./ 前缀，带斜杠的原样返回。
# 用 ${1-$0} 而非 ${1:-$0}——空串是调用方显式传进来的，不该回退到 $0。
# 注意通过 `curl | sh` 运行时 $0 是解释器名（sh），不是路径；本函数
# 无法分辨，由调用方检查结果是否真的存在。
resolve_self_path() {
    _p="${1-$0}"
    case "$_p" in
    */*) printf '%s\n' "$_p" ;;
    *) printf '%s\n' "./$_p" ;;
    esac
}

update_myself() {
    # 用 $0 而不是写死 ./be14000.sh。本项目文档里的常见跑法是
    # `sh /tmp/be14000.sh`，登录目录通常是 /root——写死 ./ 会把新版本
    # 存到一个用户下次根本不会执行的路径上，却报告「已更新」。
    _self=$(resolve_self_path)

    # 通过 curl | sh 跑的时候 $0 是 "sh"，上面会解析成 ./sh——那不是本脚本。
    # 与其在当前目录留下一个名叫 sh 的文件，不如直接说明情况。
    if [ ! -f "$_self" ]; then
        red "无法定位脚本自身（通常是用 curl | sh 方式运行的）"
        yellow "请直接重新执行安装命令来获取最新版本"
        return 1
    fi

    # 临时文件放在 $_self 同目录，而不是 /tmp。实测本机 /tmp 是 tmpfs、
    # / 是 overlayfs，跨文件系统时 mv 会退化成「复制+删除源」，就不再是
    # 原子替换了；同目录才能保证 rename 语义。
    _new="$_self.new"

    if ! wget -q -O "$_new" "$SCRIPT_URL"; then
        red "下载失败，请检查网络"
        rm -f "$_new"
        return 1
    fi

    # wget 对被截断的响应、或一个 HTTP 200 的错误页，同样会返回 0。
    # 覆盖掉正在运行的脚本之前必须自检内容。
    if [ ! -s "$_new" ] || ! sh -n "$_new" 2>/dev/null; then
        red "下载到的内容不是可用脚本（可能被截断或是错误页），已放弃更新"
        rm -f "$_new"
        return 1
    fi

    cp "$_self" "$_self.bak" 2>/dev/null ||
        yellow "无法备份当前脚本，继续更新"

    # 同目录 mv 是原子的 rename：只替换目录项，正在运行的 shell 仍持有
    # 旧 inode，不会读到写了一半的文件。
    if ! mv "$_new" "$_self"; then
        red "写入 $_self 失败。原脚本未改动，备份在 $_self.bak"
        rm -f "$_new"
        return 1
    fi
    chmod +x "$_self" 2>/dev/null
    green "脚本已更新: $_self（旧版备份在 $_self.bak），正在重新执行"
    exec sh "$_self"
}

# 一键风格化主流程。任一关键步骤失败即中止，避免在半成品状态上继续叠加。
one_click_style() {
    setup_feeds || return 1
    install_luci || return 1
    install_istore || return 1
    install_theme || yellow "主题安装失败，流程继续"
    install_apps || yellow "部分插件未安装成功，流程继续"
    setup_quickstart || yellow "首页配置失败，流程继续"
    base_init || yellow "基础配置未完全生效，流程继续"
    print_access_info
}

# 恢复原厂软件源。Flint 4 的原厂源就是脚本内联的这份，
# 所以「恢复」等同于重写一次并清空自定义源。
recovery_opkg_settings() {
    if ! printf '# add your custom package feeds here\n' >/etc/opkg/customfeeds.conf; then
        red "写入 /etc/opkg/customfeeds.conf 失败"
        return 1
    fi
    setup_feeds
}

add_custom_feed() {
    printf '请输入自定义软件源地址（通常以 aarch64_cortex-a53 结尾）: '
    read -r _url
    if [ -z "$_url" ]; then
        red "未输入地址，未做任何修改"
        return 1
    fi
    if ! printf '# add your custom package feeds here\n' >/etc/opkg/customfeeds.conf; then
        red "写入 /etc/opkg/customfeeds.conf 失败"
        return 1
    fi
    printf 'src/gz custom_feed %s\n' "$_url" >>/etc/opkg/customfeeds.conf || {
        red "写入 /etc/opkg/customfeeds.conf 失败"
        return 1
    }
    if opkg update; then
        green "已添加并更新软件包列表"
    else
        yellow "已添加，但更新失败，请检查地址或网络"
    fi
}

remove_custom_feed() {
    if ! printf '# add your custom package feeds here\n' >/etc/opkg/customfeeds.conf; then
        red "写入 /etc/opkg/customfeeds.conf 失败"
        return 1
    fi
    if opkg update; then
        green "已删除自定义软件源并更新列表"
    else
        yellow "已删除，但更新失败，请检查网络"
    fi
}

toggle_adguardhome() {
    _status=$(uci -q get adguardhome.config.enabled)
    if [ -z "$_status" ]; then
        red "未检测到 adguardhome 配置"
        return 1
    fi
    if [ "$_status" = "1" ]; then
        _want=0
    else
        _want=1
    fi

    uci set adguardhome.config.enabled="$_want"
    uci commit adguardhome
    if [ "$_want" = "1" ]; then
        /etc/init.d/adguardhome enable >/dev/null 2>&1
        /etc/init.d/adguardhome start >/dev/null 2>&1
    else
        /etc/init.d/adguardhome disable >/dev/null 2>&1
        /etc/init.d/adguardhome stop >/dev/null 2>&1
    fi

    # 回读确认再报告。这是个隐私相关的服务：告诉用户「已关闭」而它其实
    # 还在跑，比直接报错糟糕得多。
    if [ "$(uci -q get adguardhome.config.enabled)" != "$_want" ]; then
        red "AdGuardHome 状态未变更，请手动检查 uci show adguardhome"
        return 1
    fi
    if [ "$_want" = "1" ]; then
        green "AdGuardHome 已开启，访问 http://192.168.8.1:3000"
    else
        green "AdGuardHome 已关闭"
    fi
}

main_menu() {
    while true; do
        clear
        printf '**********************************************************\n'
        green '   GL-BE14000 (Flint 4) 一键 iStoreOS 风格化工具箱'
        printf '**********************************************************\n'
        printf '   机型: %s   固件: %s\n' \
            "$(cat /tmp/sysinfo/model 2>/dev/null)" \
            "$(cat /etc/glversion 2>/dev/null)"
        printf '\n'
        cyan  ' 1. 一键 iStoreOS 风格化'
        printf '\n'
        printf ' 2. 设置自定义软件源\n'
        printf ' 3. 删除自定义软件源\n'
        printf ' 4. 恢复原厂 OPKG 配置\n'
        printf '\n'
        printf ' 5. 安装 LuCI（Flint 4 出厂不带）\n'
        printf ' 6. 安装 Argon 紫色主题\n'
        printf ' 7. 安装文件管理器\n'
        printf ' 8. 设置风扇启动温度\n'
        printf ' 9. 启用/关闭 AdGuardHome\n'
        printf '10. 隐藏首页格式化按钮\n'
        printf '\n'
        yellow '11. 把 LuCI 开放到局域网（默认关闭，有安全影响）'
        printf '12. 还原 LuCI 为仅本机访问\n'
        printf '13. 查看 LuCI 访问方式\n'
        printf '14. 更新本脚本\n'
        printf '\n'
        printf ' Q. 退出\n\n'
        printf '请选择一个选项: '
        # stdin 关闭时 read 立刻返回非 0；不判断的话 while 会空转成死循环
        read -r _choice || exit 0
        printf '\n'

        case "$_choice" in
            1) one_click_style ;;
            2) add_custom_feed ;;
            3) remove_custom_feed ;;
            4) recovery_opkg_settings ;;
            5) install_luci ;;
            6) install_theme ;;
            7) install_filemanager ;;
            8) set_fan_temp ;;
            9) toggle_adguardhome ;;
            10) hide_format_button ;;
            11) expose_luci_lan ;;
            12) restore_luci_loopback ;;
            13) print_access_info ;;
            14) update_myself ;;
            q | Q) printf '退出\n'; exit 0 ;;
            *) red "无效选项，请重新选择" ;;
        esac

        printf '\n按 Enter 键继续...'
        read -r _ || exit 0
    done
}

# 被 source 时只定义函数，便于单元测试
if [ "${BE14000_LIB_ONLY:-0}" != "1" ]; then
    is_flint4 || {
        red "本脚本仅适用于 GL-BE14000 (Flint 4)。"
        red "当前机型: $(get_board_name)"
        exit 1
    }
    main_menu
fi
