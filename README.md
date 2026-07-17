# 实时网速监控 for macOS

一个使用 Objective-C/AppKit 原生界面的轻量级 macOS 网速监控工具，不依赖 Python、Tk 或第三方运行库。

## 功能

- 每秒更新当前下载和上传速度
- 自动识别正在传输数据的活动网卡
- 显示系统网卡累计收发流量
- 深色 macOS 原生界面

## 使用方法

下载 GitHub Release 中的压缩包，解压后双击 `实时网速监控.app`。

从源码使用时，也可以双击 `启动实时网速.command`。第一次启动会自动构建应用。

## 从源码构建

```bash
./build_app.sh
open "实时网速监控.app"
```

构建要求：macOS 11 或更高版本，以及 Apple Command Line Tools。构建脚本会同时生成 Apple Silicon（arm64）和 Intel（x86_64）架构的通用 App。

## 项目结构

- `NetworkSpeedMonitor.m`：应用源代码
- `实时网速监控.app/Contents/Info.plist`：应用元数据
- `build_app.sh`：构建脚本
- `package_release.sh`：生成经过验证的 Universal App 发布压缩包
- `启动实时网速.command`：自动构建并启动

## 说明

- 速度采用 `1 KB = 1024 B` 计算。
- 累计流量来自 macOS 网卡计数器，不等同于运营商账单流量。
- VPN、虚拟网卡同时工作时，累计值可能包含虚拟接口流量。
- 发布包不包含构建者的用户名、主目录路径或其他本机信息。
