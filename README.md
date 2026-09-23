# MikroTik CHR Installer

[![Platform](https://img.shields.io/badge/platform-Debian-A81D33?style=flat-square)](#)
[![MikroTik](https://img.shields.io/badge/MikroTik-CHR-293239?style=flat-square)](#)
[![QEMU](https://img.shields.io/badge/QEMU-supported-FF6600?style=flat-square)](#)
[![LICENSE](https://img.shields.io/badge/LICENSE-MIT-FF6655?style=flat-square)](#)

Run **MikroTik Cloud Hosted Router (CHR)** on a Debian VPS using QEMU.

Automatically handles:

- QEMU setup
- TAP interface
- IP forwarding & NAT
- systemd service

## Install

```bash
chmod +x install.sh
./install.sh
```

Choose:

- `1` - Install
- `2` - Uninstall

## Setup

The CHR starts with a blank configuration. Open the console once:

```bash
systemctl stop mikrotik-chr.service
eval $(grep ExecStart /etc/systemd/system/mikrotik-chr.service | cut -d '=' -f 2-)
```

Login as `admin` with a blank password.

### 1. Configure RouterOS

Run first:

```routeros
/ip address add address=100.64.0.2/24 interface=ether1
/interface ethernet set ether1 arp=proxy-arp
/ip route add dst-address=0.0.0.0/0 gateway=100.64.0.1
```

Then configure SSTP:

```routeros
/ip pool add name=sstp-pool ranges=10.100.0.10-10.100.0.254
/ppp profile add name=sstp-profile local-address=10.100.0.1 remote-address=sstp-pool use-encryption=yes dns-server=8.8.8.8,8.8.4.4
/interface sstp-server server set enabled=yes default-profile=sstp-profile port=443 certificate=none authentication=mschap2
/ppp secret add name=testuser password=testpass profile=sstp-profile service=sstp
/ip firewall nat add chain=srcnat dst-address=10.100.0.0/24 action=masquerade
```

### 2. Restart CHR

Exit the console with `Ctrl + A`, then `X`.

```bash
systemctl start mikrotik-chr.service
```

CHR is now running in the background.

## Ports

| Port | Service |
|---:|---|
| `4443` | SSTP VPN |
| `7001` | Winbox |
| `7002` | WebFig |

## Support the Developer

If you found this project helpful for your business or personal use, consider supporting the development.

[![Support](https://img.shields.io/badge/SUPPORT-BUY%20ME%20A%20COFFEE-ff5f9e?style=for-the-badge&logo=buymeacoffee&logoColor=white&labelColor=4f4f4f)](https://linktr.ee/systik)
