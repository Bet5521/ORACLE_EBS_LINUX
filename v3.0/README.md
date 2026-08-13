# Oracle EBS 信创兼容方案 V3.0

## 概述

V3.0 是统一版本，合并了 v1.1（Oracle JRE 路径）和 v2.2（OpenJDK 8 + IcedTea 路径）。

## 快速开始

```bash
cd v3.0
sudo bash oracle-ebs-setup.sh
```

## Java 运行环境双路径

| 路径 | 说明 | 推荐 |
|------|------|------|
| Oracle JRE 8/7/6u7 | 手动下载，兼容性最好 | ⭐⭐⭐⭐⭐ |
| OpenJDK 8 + IcedTea | 包管理器自动安装 | ⭐⭐⭐⭐ |

## 浏览器约束

**仅 Firefox 52 ESR / Pale Moon / SeaMonkey 支持 NPAPI Java 插件！**

## 版本历史

| 版本 | 说明 |
|------|------|
| v1.0 | 初始版本，存在致命 Bug |
| v1.1 | 修复 Oracle JRE 路径的 6 个问题 |
| v2.1 | 增加 OpenJDK 选项，但 OpenJDK 11/17 不可行 |
| v2.2 | 修复 10 个问题，仅保留 OpenJDK 8 |
| **v3.0** | **统一版，合并 v1.1 + v2.2** |

## 目录结构

```
v1.0/  初始版本
v1.1/  Oracle JRE 修复版
v2.1/  有问题的 OpenJDK 版本
v2.2/  OpenJDK 修复版
v3.0/  统一版（推荐使用）
```
