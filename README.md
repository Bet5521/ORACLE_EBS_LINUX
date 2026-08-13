# Oracle EBS 信创兼容方案

在国产信创电脑（ARM64/X86 + 统信/麒麟）上运行Oracle EBS（Java Applet）。

## 目录结构

```
v1.0/  - 初始版本（有Bug）
v1.1/  - 修复Oracle JRE路径的6个问题
v2.1/  - 增加OpenJDK选项（有OpenJDK 11/17不可行问题）
v2.2/  - 修复10个问题，仅保留OpenJDK 8
v3.0/  - 统一版（合并v1.1+v2.2）
```

最新稳定版: **v3.0**

## 快速开始

```bash
cd v3.0
sudo bash oracle-ebs-setup.sh
```

## 技术要点

- ARM64架构需QEMU/Box64模拟层
- 仅Firefox <= 52 ESR / Pale Moon / SeaMonkey支持NPAPI Java插件
- Java运行环境支持Oracle JRE 6u7/7/8 和 OpenJDK 8 + IcedTea

详见各版本目录下的 README.md 和 方案分析.md。
