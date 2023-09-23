#!/bin/sh
# 默认情况下MT3000和MT2500A的环境是ash
# 建议安装bash 满足更多的函数调用
check_bash_installed() {
  if [ -x "/bin/bash" ]; then
    echo "downloading prepare.sh ......"
  else
    opkg update
    opkg install bash
  fi
}
check_bash_installed
