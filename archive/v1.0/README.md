# Oracle EBS 信创兼容方案

## 概述

在国产信创电脑（ARM64/X86/C86 + 统信/麒麟）上运行Oracle EBS（JRE 6u7/7/8 + Java Applet）。

## 文件

| 文件 | 说明 |
|------|------|
| `oracle-ebs-setup.sh` | 一键配置脚本（685行，自动检测架构） |
| `方案分析.md` | 技术方案分析 |
| `README.md` | 本文件 |

## 使用

```bash
sudo bash oracle-ebs-setup.sh
```

## 架构自动检测

```
检测uname -m
  ├─ aarch64/arm64 → ARM方案(A-E)
  └─ x86_64/x86/i686 → X86方案(A-E)
```

## ARM64方案（需要模拟层）

| 方案 | 技术 | 推荐 |
|------|------|------|
| A | QEMU全系统虚拟机 | ⭐⭐⭐⭐⭐ |
| B | QEMU用户模式+proot | ⭐⭐⭐⭐ |
| C | Box64+Wine | ⭐⭐⭐ |
| D | Docker+QEMU | ⭐⭐⭐ |
| E | Box86+JRE | ⭐⭐ |

## X86/C86方案（原生运行）

| 方案 | 浏览器 | 推荐 |
|------|--------|------|
| A | Firefox ESR | ⭐⭐⭐⭐⭐ |
| B | Pale Moon | ⭐⭐⭐⭐ |
| C | Firefox 52 ESR | ⭐⭐⭐ |
| D | SeaMonkey | ⭐⭐⭐ |
| E | 仅JRE | ⭐⭐ |

## V1.0 说明

初始版本，存在3个致命Bug：Firefox NPAPI错误、日志权限、.bin sudo缺失。

详见代码注释。
