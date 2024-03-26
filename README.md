# Gl-iNet 系列路由器 一键iStoreOS风格化脚本
[![GitHub](https://img.shields.io/github/license/wukongdaily/gl-inet-onescript.svg?label=LICENSE&logo=github&logoColor=%20)](https://github.com/wukongdaily/gl-inet-onescript/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/wukongdaily/gl-inet-onescript.svg?style=flat&logo=appveyor&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/wukongdaily/gl-inet-onescript.svg?style=flat&logo=appveyor&label=Forks&logo=github)



## 🤔 这是什么？

该项目可以让MT2500/MT3000/MT6000路由器在不刷机情况下,一键变成iStoreOS风格。<br><br>
<img alt="Static Badge" src="https://img.shields.io/badge/MT6000-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=336666">
<img alt="Static Badge" src="https://img.shields.io/badge/MT2500A-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=D94600"> 
<img alt="Static Badge" src="https://img.shields.io/badge/MT3000-0?style=flat-square&logoColor=8A2BE2&label=%E5%9E%8B%E5%8F%B7&labelColor=000000&color=2828FF"> 
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
### 2.单独安装Docker
```bash
wget -O do_docker.sh https://raw.githubusercontent.com/wukongdaily/gl-inet-onescript/master/docker/do_docker.sh?$(date +%s) && chmod +x do_docker.sh && ./do_docker.sh
```

### 3.单独安装iStore商店
```bash
wget -O /tmp/reinstall_istore.sh https://gitee.com/wukongdaily/gl_onescript/raw/master/reinstall_istore.sh && chmod +x /tmp/reinstall_istore.sh && /tmp/reinstall_istore.sh

```

### 4.单独安装文件管理器
```bash
wget -O /tmp/reinstall_istore.sh https://gitee.com/wukongdaily/gl_onescript/raw/master/reinstall_istore.sh && chmod +x /tmp/reinstall_istore.sh && /tmp/reinstall_istore.sh
/tmp/is-opkg install app-meta-linkease

```


### 5.新手ssh连接注意事项
https://github.com/wukongdaily/HowToUseSSH

### 辅助视频教程⬇️
https://www.bilibili.com/video/BV1YJ4m1L7A3/
# Docker面板的选择
## 🔑 安装1panel 面板 来管理Docker 容器

### 可以使用 docker离线包加载
```bash
https://pan.baidu.com/s/1Lm9dkXhvPionZPVXOBXCjw?pwd=1111

```
### 上传到U盘其他空间
```bash
docker load < /mnt/upan_data/1panel.tar
```

```bash
docker run -d \
    --name 1panel \
    --restart always \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /www/data/1panel-data:/opt \
    -e TZ=Asia/Shanghai \
    moelin/1panel:latest
```

- 默认端口：10086
- 默认账户：1panel
- 默认密码：1panel_password
- 默认入口：entrance

## 访问地址
```bash
http://192.168.8.1:10086/entrance
```

## 🔑 安装Fast OS面板 来管理Docker 容器
```bash
docker run -d \
--name fastos \
--restart always \
-p 8081:8081 \
-p 8082:8082 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /etc/docker/:/etc/docker/ \
-v /root/data:/fast/data \
-e FAST_STORE=http://dockernb.com:8300 \
wangbinxingkong/fast:latest
```
### Fast OS 面板离线包
```bash
https://pan.baidu.com/s/1S5jxahCzE-HyIa-mUvOcZQ?pwd=1111
```
  
## 🗂️ 引用项目

本项目的开发参照了以下项目，感谢这些开源项目的作者：
### istore
https://github.com/linkease/istore

![mt3000](https://github.com/wukongdaily/gl-inet-onescript/assets/143675923/0ff6cb12-0812-4198-b97b-30698da6a8c4)


