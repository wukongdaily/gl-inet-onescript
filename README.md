
# GL-iNet 系列路由器 一键iStoreOS风格化脚本
[![GitHub](https://img.shields.io/github/license/wukongdaily/gl-inet-onescript.svg?label=LICENSE&logo=github&logoColor=%20)](https://github.com/wukongdaily/gl-inet-onescript/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/wukongdaily/gl-inet-onescript.svg?style=flat&logo=appveyor&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/wukongdaily/gl-inet-onescript.svg?style=flat&logo=appveyor&label=Forks&logo=github)
[![YouTube](https://img.shields.io/badge/YouTube-123456?logo=youtube&labelColor=ff0000)](https://www.youtube.com/watch?v=YlhIdizH0hM)
[![Bilibili](https://img.shields.io/badge/Bilibili-123456?logo=bilibili&logoColor=fff&labelColor=fb7299)](https://www.bilibili.com/video/BV1GyqmBEEsq/)


## 🤔 这是什么？

该项目可以让GL-iNet旗下ARM64平台的路由器在不刷机情况下,一键变成iStoreOS最新风格。<br><br>
<img alt="Static Badge" src="https://img.shields.io/badge/MT3000-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=D94600"> 
<img alt="Static Badge" src="https://img.shields.io/badge/MT6000-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=ff9300">
<img alt="Static Badge" src="https://img.shields.io/badge/MT2500A-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=fffb0d"> 
<img alt="Static Badge" src="https://img.shields.io/badge/BE3600-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=07755a"> 
<img alt="Static Badge" src="https://img.shields.io/badge/BE6500-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=84dce5"> 
<img alt="Static Badge" src="https://img.shields.io/badge/BE9300-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=235ab8"> 
<img alt="Static Badge" src="https://img.shields.io/badge/MT3600BE-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=5e0774"> 
<img alt="Static Badge" src="https://img.shields.io/badge/MT5000-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=8d8ab9"> 
<img alt="Static Badge" src="https://img.shields.io/badge/Mudi7^E5800-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=316EE8"> 

## 💡 特色功能

- 💻 支持`一键安装iStoreOS风格 新首页风格 支持按需显示UI模块`
- 💻 支持`一键安装紫色的Argon主题`
- 💻 支持`一键安装文件管理器`
- 🔑 支持`一键设置MT-3000风扇开始工作的温度`
- 🌏 支持`一键部署Docker运行环境`
- 🌏 支持`一键安装docker-compose`
- ✅ 新增`高级卸载插件 by VedioTalk` 🆕
- ✅ 新增`个性化辅助UI插件的安装` 🆕
- 📕 支持`一键恢复原厂的OPKG软件源`
- 🔑 支持`MT-3000 一键更换分区到U盘`
- 💡 使用条件：GL-iNet 原厂固件（非测试版、预览版）
- GL-inet MT-6000✅
- GL-inet MT-3000 ✅
- GL-inet MT-2500 ✅ 固件版本4.5.0（最好降级到此版本）
- OrangePi Zero3(官方Openwrt镜像)
- 🌟✨🌟[已经刷了iStoreOS固件的MT3000点击这里](https://github.com/wukongdaily/istoreos-mt3000-script)

- ❤️ 新增  [内网版本glibox 用于局域网调用 本脚本 ](https://github.com/wukongdaily/gl-inet-onescript/releases/tag/20250805)


<a href="https://wkdaily.cpolar.top/01" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png"
       alt="Buy Me A Coffee"
       style="width:20%; height:auto;">
</a>

## 🚀 快速上手

### 1. SSH连接到路由器,或者在路由器终端执行如下命令 (MT2500/3000/6000) Wi-Fi 6 luci 21

```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/gl-inet.sh)"

```

#### 新增 兼容原厂【op24固件】的脚本 (MT3000/6000) Wi-Fi 6 luci 24.10
> 如果是【MT3000 原厂4.8.3-op24 固件】 你可以先替换为阿里云软件源 再执行脚本 这样在国内访问会快很多<br>
> 进入luci界面，系统——软件包——配置OPKG 将最后的 /etc/opkg/distfeeds.conf 下面的文本框替换为如下 阿里云的软件源
```bash
src/gz core https://fw.gl-inet.cn/releases/v24.x/24.10.4/mediatek/filogic
src/gz base https://mirrors.aliyun.com/openwrt/releases/24.10.4/packages/aarch64_cortex-a53/base
src/gz luci https://mirrors.aliyun.com/openwrt/releases/24.10.4/packages/aarch64_cortex-a53/luci
src/gz packages https://mirrors.aliyun.com/openwrt/releases/24.10.4/packages/aarch64_cortex-a53/packages
src/gz routing https://mirrors.aliyun.com/openwrt/releases/24.10.4/packages/aarch64_cortex-a53/routing
src/gz telephony https://mirrors.aliyun.com/openwrt/releases/24.10.4/packages/aarch64_cortex-a53/telephony
```
#### 然后再执行脚本 gl-inet-op24.sh 换源后这样速度就快很多 （luci 24.10）
```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/gl-inet-op24.sh)"

```

#### 新增 BE6500脚本 (GL-BE6500) ❤️ Wi-Fi 7 (同BE9300通用)
```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/be6500.sh)"

```
#### 新增 BE3600脚本 (GL-BE3600) Wi-Fi 7
```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/be3600.sh)"

```
---
#### ❤️新增 MT-3600BE脚本 (GL-MT3600BE) Wi-Fi 7
```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/mt3600.sh)"

```

#### ❤️新增 MT-5000脚本 (GL-MT5000) 三个2.5G 有线
```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/mt5000.sh)"
```

#### ❤️新增 Mudi 7 (GL-E5800) _ 5G NR Tri-band Wi-Fi 7 Travel Router (同mt3600脚本通用)
```bash
sh -c "$(curl -fsSL https://cafe.cpolar.cn/wkdaily/gl/raw/branch/main/mt3600.sh)"
```

## 新手ssh连接注意事项 （known_hosts重复的问题）
https://github.com/wukongdaily/HowToUseSSH

## 常见问题 https://github.com/wukongdaily/gl-inet-onescript/discussions/53 如8080端口提示拒绝访问
## 新增：❤️如何使用内网版本的脚本 👉 https://github.com/wukongdaily/gl-inet-onescript/discussions/44
### 新增：❤️如何下载run格式安装包 👉 [#45](https://github.com/wkccd/CloudRunFilesBuilder/releases)
### 注意⚠️4.7.0以上版本。如何访问luci界面？
http://192.168.8.1:8080



### 辅助视频教程⬇️
https://www.bilibili.com/video/BV1312bYZEjE

## 🗂️ 引用项目

本项目的开发参照了以下项目，感谢这些开源项目的作者：
### istore
https://github.com/linkease/istore

![mt3000](https://github.com/wukongdaily/gl-inet-onescript/assets/143675923/0ff6cb12-0812-4198-b97b-30698da6a8c4)

# 参考视频 点击直达
[![B 站视频封面](https://i2.hdslb.com/bfs/archive/2fda32c5af12d06fdf5f95afd8384796ac6ec61c.jpg@560w_350h_1c_!web-space-index-topvideo.avif)](https://www.bilibili.com/video/BV1312bYZEjE)

## 更多完整版
https://www.youtube.com/watch?v=YlhIdizH0hM

## 注意事项

![luci](https://github.com/user-attachments/assets/50fb4566-dbeb-4b32-bec0-9b88e2af098c)


# 新增❤️ 使用glibox 内网版的 脚本服务器
> 支持x86-64 和 arm64 两种平台来搭建，glibox 是基于dufs 制作的内网文件服务器 用于托管本项目的脚本。免得因为网络问题下载失败。看到许多人 不断复用我的脚本 干脆搭建一个内网版本 。

**视频教学**：https://www.bilibili.com/video/BV1eWt3zCE2y
**视频教学**： https://youtu.be/ee4fANDk_CM

```bash
docker run -d \
  --restart unless-stopped \
  --name glibox \
  -p 15050:15050 \
  wukongdaily/glibox

```


### 对于MT3000/2500/6000  （ssh连接到路由器内 在路由器内执行）

```bash
read -p "请输入glibox局域网 IP: " ip && wget -O /tmp/gl.sh http://$ip:15050/glinet/gl-inet.sh && sh /tmp/gl.sh $ip

```

### 对于be3600 （ssh连接到路由器内 在路由器内执行）

```bash
read -p "请输入glibox局域网 IP: " ip && wget -O /tmp/gl.sh http://$ip:15050/glinet/be3600.sh && sh /tmp/gl.sh $ip
```


### https://hub.docker.com/r/wukongdaily/glibox/tags

<img width="70%" height="70%" alt="image" src="https://github.com/user-attachments/assets/b13fada3-6d5c-4427-b20e-16e44ada5276" />




### 鸣谢
- https://github.com/VMatrices
- [高级卸载插件作者VedioTalk](https://xz.vumstar.com/)
- iStoreOS https://site.istoreos.com

### ✨创意应用-开关快捷定制
https://github.com/parentalclash/gl-inet-mt3000-openclash-switch



### 更换最新iStoreOS首页 <2025-12-17> 支持按需显示UI模块
<img width="3412" height="1472" alt="image" src="https://github.com/user-attachments/assets/9c807485-3e9a-46a5-8f0c-97cdf41053eb" />

---

<img width="2648" height="1666" alt="image" src="https://github.com/user-attachments/assets/e1728a7a-26fc-4bd4-8cb6-43ba20c4b651" />

![截图](https://github.com/user-attachments/assets/93cbe29b-965c-4ff5-9ae9-db23c0066bf7)

![6500](https://github.com/user-attachments/assets/3cc74252-4641-4a39-b01a-6c5ebb13021c)

<img width="3784" height="1740" alt="CleanShot 2026-02-26 at 11 15 41@2x" src="https://github.com/user-attachments/assets/ee1c2898-28dd-43db-82c2-e3756c5be52a" />
