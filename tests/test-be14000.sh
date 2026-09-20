#!/bin/sh
# be14000.sh 纯函数单元测试。不需要 stub 框架：
# 被测函数都接受参数或读 ROOT_PREFIX，可在本地直接调用。
set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
pass=0
fail=0

assert_eq() {
    # assert_eq <描述> <期望> <实际>
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
        printf '  ok   %s\n' "$1"
    else
        fail=$((fail + 1))
        printf '  FAIL %s\n       期望: [%s]\n       实际: [%s]\n' "$1" "$2" "$3"
    fi
}

assert_ok() {
    # assert_ok <描述> <命令...>  —— 命令退出码应为 0
    _d="$1"; shift
    if "$@"; then
        pass=$((pass + 1)); printf '  ok   %s\n' "$_d"
    else
        fail=$((fail + 1)); printf '  FAIL %s (退出码非 0)\n' "$_d"
    fi
}

assert_fail() {
    # assert_fail <描述> <命令...>  —— 命令退出码应非 0
    _d="$1"; shift
    if "$@"; then
        fail=$((fail + 1)); printf '  FAIL %s (期望非 0，实际 0)\n' "$_d"
    else
        pass=$((pass + 1)); printf '  ok   %s\n' "$_d"
    fi
}

# 以 lib 模式载入被测脚本（不进菜单循环）
BE14000_LIB_ONLY=1
export BE14000_LIB_ONLY
# shellcheck source=/dev/null
. "$REPO_ROOT/be14000.sh"

printf '\n-- is_flint4 --\n'
assert_ok   'glinet,gl-be14000 应判定为 Flint 4' is_flint4 'glinet,gl-be14000'
assert_fail 'glinet,gl-mt6000 应拒绝'            is_flint4 'glinet,gl-mt6000'
assert_fail 'glinet,gl-be9300 应拒绝'            is_flint4 'glinet,gl-be9300'
assert_fail '空字符串应拒绝'                      is_flint4 ''
assert_fail '前缀相同但不完整应拒绝'              is_flint4 'glinet,gl-be1400'

# 上面那条「空字符串」断言在开发机上会因为 /tmp/sysinfo/board_name 不存在
# 而恰好通过，掩盖 ${1:-} 与 ${1-} 的区别。这条 grep 断言是确定性守卫：
assert_eq 'is_flint4 必须用 ${1-} 而非 ${1:-}（空串不得回退读文件）' '0' \
    "$(grep '_board="\${1:-' "$REPO_ROOT/be14000.sh" | wc -l | tr -d ' ')"

printf '\n-- 颜色输出用 printf 而非 echo -e --\n'
assert_eq 'green 输出不含字面量 -e' '0' \
    "$(green test | grep -c -- '-e')"

printf '\n-- distfeeds_content --\n'
assert_eq 'feed 应为 3 行' '3' "$(distfeeds_content 5.4.281 | wc -l | tr -d ' ')"

assert_eq 'kmod 行完整匹配' \
    'src/gz glinet_core https://fw.gl-inet.com/releases/v21.02-SNAPSHOT/mt798x/kmod-5.4.281/aarch64_cortex-a53/kmod-5.4' \
    "$(distfeeds_content 5.4.281 | sed -n 1p)"

assert_eq 'glinet 行完整匹配' \
    'src/gz glinet_gli_pub https://fw.gl-inet.com/releases/v21.02-SNAPSHOT/mt798x/packages/aarch64_cortex-a53/glinet' \
    "$(distfeeds_content 5.4.281 | sed -n 2p)"

assert_eq 'packages 行完整匹配' \
    'src/gz glinet_gli_packages https://fw.gl-inet.com/releases/v21.02-SNAPSHOT/mt798x/packages/aarch64_cortex-a53/packages' \
    "$(distfeeds_content 5.4.281 | sed -n 3p)"

assert_eq '内核版本变化时 kmod 路径跟随' \
    'src/gz glinet_core https://fw.gl-inet.com/releases/v21.02-SNAPSHOT/mt798x/kmod-6.6.12/aarch64_cortex-a53/kmod-6.6' \
    "$(distfeeds_content 6.6.12 | sed -n 1p)"

assert_eq '域名必须是 .com 不是 .cn' '0' \
    "$(distfeeds_content 5.4.281 | grep -c 'fw\.gl-inet\.cn')"

printf '\n-- luci_installed --\n'
_tmp=$(mktemp -d)

ROOT_PREFIX="$_tmp"
assert_fail '空目录应判定为未安装' luci_installed

mkdir -p "$_tmp/www/cgi-bin"
touch "$_tmp/www/cgi-bin/luci"
assert_fail '只有 cgi 入口、缺 cbi.lua 应判定为未安装' luci_installed

mkdir -p "$_tmp/usr/lib/lua/luci"
touch "$_tmp/usr/lib/lua/luci/cbi.lua"
assert_fail '核心文件齐备但无主题应判定为未安装' luci_installed

mkdir -p "$_tmp/www/luci-static/resources"
assert_fail 'resources 不算主题，仍应判定为未安装' luci_installed

mkdir -p "$_tmp/www/luci-static/bootstrap"
assert_ok '核心文件 + 主题齐备才判定为已安装' luci_installed

ROOT_PREFIX=""
rm -rf "$_tmp"

printf '\n-- resolve_self_path --\n'
assert_eq '绝对路径原样返回' '/tmp/be14000.sh' "$(resolve_self_path /tmp/be14000.sh)"
assert_eq '裸文件名补 ./'    './be14000.sh'    "$(resolve_self_path be14000.sh)"
assert_eq './ 前缀保持不变'  './be14000.sh'    "$(resolve_self_path ./be14000.sh)"
assert_eq '../ 前缀保持不变' '../be14000.sh'   "$(resolve_self_path ../be14000.sh)"
assert_eq 'curl|sh 时 $0=sh 会变成 ./sh（调用方须自行判存在）' './sh' \
    "$(resolve_self_path sh)"

printf '\n-- hide_format_button 幂等性 --\n'
_hf=$(mktemp -d)
mkdir -p "$_hf/www/luci-static/quickstart"
ROOT_PREFIX="$_hf"

assert_ok '目标文件不存在时应安全跳过' hide_format_button
assert_eq '不存在时不应创建文件' '0' \
    "$(ls "$_hf/www/luci-static/quickstart" | wc -l | tr -d ' ')"

printf 'body{}\n' > "$_hf/www/luci-static/quickstart/style.css"
hide_format_button >/dev/null
assert_eq '首次运行应追加一份标记' '1' \
    "$(grep -cF 'hide quickstart disk button' "$_hf/www/luci-static/quickstart/style.css")"

hide_format_button >/dev/null
hide_format_button >/dev/null
assert_eq '重复运行仍只有一份（grep -qF 守卫生效）' '1' \
    "$(grep -cF 'hide quickstart disk button' "$_hf/www/luci-static/quickstart/style.css")"

ROOT_PREFIX=""
rm -rf "$_hf"

printf '\n-- has_luci_theme --\n'
_ht=$(mktemp -d)
ROOT_PREFIX="$_ht"
assert_fail '无 luci-static 目录时应为否' has_luci_theme
mkdir -p "$_ht/www/luci-static/resources"
assert_fail '只有 resources 时应为否' has_luci_theme
mkdir -p "$_ht/www/luci-static/argon"
assert_ok '存在真实主题目录时应为是' has_luci_theme
ROOT_PREFIX=""
rm -rf "$_ht"

printf '\n-- 安全约束 --\n'
# 这两条守卫是本脚本最重要的不变量：绝不改防火墙、绝不设时区。
#
# 不要再用「枚举危险动词」的写法。uci 的写操作是一个开放集合
# （set/add/delete/commit/rename/reorder/add_list/del_list/import…），
# 手工枚举必然漏——这里已经因此漏过两次（uci -q set、uci -q batch），
# 而 `uci import firewall` 更是毫无技巧地直接replace整份配置。
#
# 改为反向白名单：只读动词是一个短小稳定的封闭集合，放行它们，
# 其余任何 uci ... firewall 一律报警。uci batch 单独拦，因为 heredoc
# 里的 set 行没有 uci 前缀，逐行匹配看不见它。
#
# 注意：grep 不区分注释与代码。不要在 be14000.sh 的注释里原样写出
# `uci <动词> firewall` 这种连续字面量，否则会误报。
_UCI='uci([[:space:]]+-[a-zA-Z-]+)*[[:space:]]+'
_UCI_RO="${_UCI}(get|show|export|changes|revert)[[:space:]]"

assert_eq '脚本中不得出现任何 firewall 写操作' '0' \
    "$(grep -oE "${_UCI}[a-z_]+[[:space:]]+firewall|${_UCI}batch" \
        "$REPO_ROOT/be14000.sh" | grep -cvE "$_UCI_RO")"

assert_eq '脚本中不得设置时区（出厂已是 CST-8）' '0' \
    "$(grep -oE "${_UCI}[a-z_]+[[:space:]]+system.*\.(timezone|zonename)|${_UCI}batch|${_UCI}import[[:space:]]+system" \
        "$REPO_ROOT/be14000.sh" | grep -cvE "$_UCI_RO")"

printf '\n-- is_valid_temp --\n'
assert_ok   '75 合法'                 is_valid_temp 75 70
assert_ok   '等于下限 70 合法'         is_valid_temp 70 70
assert_ok   '上限 95 合法'             is_valid_temp 95 70
assert_fail '69 低于下限'              is_valid_temp 69 70
assert_fail '96 超过上限'              is_valid_temp 96 70
assert_fail '空值非法'                 is_valid_temp '' 70
assert_fail '非数字非法'               is_valid_temp 'abc' 70
assert_fail '带小数点非法'             is_valid_temp '75.5' 70
assert_fail '负数非法'                 is_valid_temp '-5' 70
assert_fail '带空格非法'               is_valid_temp '7 5' 70

printf '\n-- 风扇 schema --\n'
assert_eq '不得写入 MT3000 专有的 integration 键' '0' \
    "$(grep -c 'glfan.*integration' "$REPO_ROOT/be14000.sh")"
assert_eq '不得写入 MT3000 专有的 differential 键' '0' \
    "$(grep -c 'glfan.*differential' "$REPO_ROOT/be14000.sh")"

printf '\n-- 访问方式提示 --\n'
assert_eq '不得提示 192.168.8.1:8080（uhttpd 绑回环，该地址不可达）' '0' \
    "$(print_access_info | grep -c '192\.168\.8\.1:8080')"
assert_eq '应提示 /cgi-bin/luci 路径' '1' \
    "$(print_access_info | grep -c 'cgi-bin/luci')"

printf '\n== 测试汇总: %d 通过, %d 失败 ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
