# Gl-iNet 系列路由器 一键iStoreOS风格化脚本
[![GitHub](https://img.shields.io/github/license/wukongdaily/gl-inet-onescript.svg?label=LICENSE&logo=github&logoColor=%20)](https://github.com/wukongdaily/gl-inet-onescript/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/wukongdaily/gl-inet-onescript.svg?style=flat&logo=appveyor&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/wukongdaily/gl-inet-onescript.svg?style=flat&logo=appveyor&label=Forks&logo=github)



## 🤔 这是什么？

该项目可以让MT2500/MT3000/MT6000路由器在不刷机情况下,一键变成iStoreOS风格。<br>

## 💡 特色功能

- 💻 支持`一键安装iStoreOS风格`
- 💻 支持`一键安装紫色的Argon主题`
- 💻 支持`一键安装文件管理器`
- 🔑 支持`一键设置MT-3000风扇开始工作的温度`
- 🌏 支持`一键部署Docker运行环境（开发中）`
- 🌏 支持`一键安装Docker Compose(开发中)`
- 🐋 支持`一键安装GL原厂adguardhome`
- 📕 支持`一键恢复原厂的OPKG软件源`
- ❓ 其他功能和特点会持续迭代
- GL-inet MT-6000✅
- GL-inet MT-3000 ✅
- GL-inet MT-2500 ✅



## 🚀 快速上手

### 1. SSH连接到路由器,或者在路由器终端执行如下命令

```bash
wget -O gl-inet.sh https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/gl-inet.sh?$(date +%s) && chmod +x gl-inet.sh && ./gl-inet.sh
```
### 或者是备用仓库地址（内地可用）

```bash
wget -O gl-inet.sh https://gitee.com/wukongdaily/gl_onescript/raw/master/gl-inet.sh?$(date +%s) && chmod +x gl-inet.sh && ./gl-inet.sh
```
### 下次如何调用,在当前目录下执行
```bash
sh gl-inet.sh
```


### 2.单独安装iStore商店
```bash
wget -O /tmp/reinstall_istore.sh https://gitee.com/wukongdaily/gl_onescript/raw/master/reinstall_istore.sh && chmod +x /tmp/reinstall_istore.sh && /tmp/reinstall_istore.sh

```

### 3.单独安装文件管理器
```bash
wget -O /tmp/reinstall_istore.sh https://gitee.com/wukongdaily/gl_onescript/raw/master/reinstall_istore.sh && chmod +x /tmp/reinstall_istore.sh && /tmp/reinstall_istore.sh
/tmp/is-opkg install app-meta-linkease

```

### 4.单独安装Docker
```bash
开发中...

```
### 5.新手ssh连接注意事项
https://github.com/wukongdaily/HowToUseSSH

### 辅助视频教程⬇️


## 🗂️ 引用项目

本项目的开发参照了以下项目，感谢这些开源项目的作者：
### istore
https://github.com/linkease/istore




