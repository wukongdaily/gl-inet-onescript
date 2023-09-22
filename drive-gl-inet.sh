#!/bin/sh
opkg update
opkg install bash
wget -O /tmp/gl-inet.sh https://ghproxy.com/https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/gl-inet.sh && chmod +x /tmp/gl-inet.sh && /tmp/gl-inet.sh
