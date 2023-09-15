#!/bin/sh
opkg update
opkg install bash
wget -O /tmp/gl-inet.run https://ghproxy.com/https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/gl-inet.run && chmod +x /tmp/gl-inet.run && /tmp/gl-inet.run
