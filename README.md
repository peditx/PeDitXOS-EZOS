![PeDitX Banner](https://raw.githubusercontent.com/peditx/luci-theme-peditx/refs/heads/main/luasrc/brand.png)

## Language Selection:

[**English**](README.md) | [**فارسی**](README_fa.md) | [**中文**](README_zh.md) | [**Русский**](README_ru.md)

---

# PeDitXOS-EZOS for OpenWrt x86-64

**PeDitXOS-EZOS** is a minimal and user-friendly OpenWrt x86-64 installer that supports both **SSH-based headless installation** and **CLI graphical installation using monitor and keyboard**.  
It is designed for advanced control over your OpenWrt setup, especially for routers with a single port and custom VLAN needs.

---

## 🔧 Features

- **Interactive CLI graphical installer** (Whiptail) launches automatically at every boot (either via SSH or directly).
- **SSH login always opens the installer UI** to help first-time setup or maintenance.
- **Network control panel** with:
  - Enable LuCI access on WAN
  - Change DNS with pre-configured presets
  - Automatic WAN/LAN detection
- **VLAN setup** in graphical interface to use OpenWrt with only one physical port
- **Bridge ↔ WAN role switching**, dynamically detected and manageable from installer UI
- Full control through Whiptail-based text interface – no need for browser at installation time
- Ready for extended disk usage and persistent storage via EZPasswall integration

---

## 📥 Installation

1. Download the latest release of **PeDitXOS-EZOS** from:  
   👉 [https://github.com/peditx/PeDitXOS-EZOS/releases](https://github.com/peditx/PeDitXOS-EZOS/releases)

2. Flash the image to a USB drive using [**Rufus**](https://rufus.ie/) or similar tools.

3. Boot your x86 device from the USB drive.

4. Once installation is complete and the system reboots:
   - Visit: [https://github.com/peditx/ezpasswall](https://github.com/peditx/ezpasswall)  
     to run the setup script and convert the full disk to OpenWrt with **EZPasswall** installed and storage fully allocated.

---

## 🧾 License

This project is licensed under the [Apache 2.0 License](LICENSE).

---

> For any questions, feedback, or contributions, feel free to open an issue or pull request.  
> Made with ❤️ by [PeDitX](https://github.com/peditx)
