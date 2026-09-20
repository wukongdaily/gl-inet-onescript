#!/bin/sh
# 语法 + bashism 检查。注意：dash -n 抓不住 [[ ]]（它当成命令名解析），
# 所以必须另外用 grep 检测 bashism。
set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

fail=0

# 仓库里要检查的脚本。gl-inet.sh 和 mt-3000/mt3000.sh 是历史遗留，
# 由独立任务处理，此处不纳入门禁。
TARGETS="be14000.sh"

for f in $TARGETS; do
    [ -f "$f" ] || continue

    printf 'syntax  %s ... ' "$f"
    if dash -n "$f" 2>/tmp/lint-err; then
        printf 'ok\n'
    else
        printf 'FAIL\n'
        cat /tmp/lint-err
        fail=1
    fi

    printf 'bashism %s ... ' "$f"
    if grep -nE '\[\[|\]\]|=~|<<<|\becho[[:space:]]+-e\b|\bfunction[[:space:]]+[A-Za-z_]+[[:space:]]*\(' "$f" >/tmp/lint-bash; then
        printf 'FAIL\n'
        cat /tmp/lint-bash
        fail=1
    else
        printf 'ok\n'
    fi
done

if [ "$fail" -eq 0 ]; then
    printf '\nlint: all checks passed\n'
else
    printf '\nlint: FAILED\n'
fi
exit "$fail"
