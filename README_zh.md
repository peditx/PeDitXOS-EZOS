![PeDitX Banner](https://raw.githubusercontent.com/peditx/luci-theme-peditx/refs/heads/main/luasrc/brand.png)

## 语言选择:

[**English**](README.md) | [**فارسی**](README_fa.md) | [**中文**](README_zh.md) | [**Русский**](README_ru.md)

---

# PeDitXOS-EZOS：适用于 OpenWrt x86-64 的图形化安装系统

**PeDitXOS-EZOS** 是一个轻量级、智能并且用户友好的 OpenWrt x86-64 安装程序，支持 **SSH 无头安装** 和 **使用显示器+键盘的 CLI 图形界面安装**。

此项目特别适合需要自定义网络配置的用户，尤其是在仅有一个以太网端口的设备上设置 VLAN。

---

## ⚙️ 功能特点

- 每次启动自动运行基于 Whiptail 的图形化 CLI 安装器（无论是 SSH 还是本地终端）
- 每次通过 SSH 登录时自动进入安装界面
- 网络控制面板，包括：
  - 启用 WAN 端口上的 LuCI（Web 管理界面）访问
  - 使用多个预设快速切换 DNS
  - 自动识别并显示 WAN/LAN 状态
- 图形化 VLAN 设置界面，适用于仅有一个网口的 OpenWrt 设备
- 动态切换网桥和 WAN 功能，完全可视化控制
- 全部基于终端界面，无需浏览器参与
- 可搭配 EZPasswall 项目将整个硬盘作为存储空间并自动安装 Passwall

---

## 📥 安装步骤

1. 从以下地址下载最新版本：  
   👉 [https://github.com/peditx/PeDitXOS-EZOS/releases](https://github.com/peditx/PeDitXOS-EZOS/releases)

2. 使用 [**Rufus**](https://rufus.ie/) 将镜像写入 USB 启动盘。

3. 使用此 USB 启动 x86 设备。

4. 系统安装完成并重启后，前往：  
   👉 [https://github.com/peditx/ezpasswall](https://github.com/peditx/ezpasswall)  
   运行脚本，将整个磁盘格式化为 OpenWrt 存储空间并自动安装 Passwall。

---

## 📜 许可证

本项目采用 [Apache 2.0 License](LICENSE) 许可证开源。

---

> 有问题或建议欢迎提交 issue 或 pull request。  
> 由 [PeDitX](https://github.com/peditx) 倾情开发 ❤️
