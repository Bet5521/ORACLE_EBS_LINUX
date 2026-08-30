# Oracle EBS 信创兼容方案 V2.2

## 概述

V2.2 基于 V2.1 修复 10 个问题。

## Java 运行环境双路径

| 路径 | 说明 | 推荐 |
|------|------|------|
| Oracle JRE 8/7/6u7 | 手动下载，兼容性最好 | ⭐⭐⭐⭐⭐ |
| OpenJDK 8 + IcedTea | 包管理器自动安装 | ⭐⭐⭐⭐ |

**⚠️ OpenJDK 11/17 不可行**（IcedTea-Web 要求 Java 8）

## 浏览器约束

仅 Firefox 52 ESR / Pale Moon / SeaMonkey 支持 NPAPI。

## V2.2 修复清单

| 编号 | 修复 |
|------|------|
| FIX-1 | 保留 v1.1 全部修复（日志权限/Firefox 52 ESR/.bin sudo等） |
| FIX-2 | 移除 OpenJDK 11/17 选项 |
| FIX-3 | 统一版本号为 2.2 |
| FIX-4 | add-apt-repository 添加 sudo |
| FIX-5 | 增强 IcedTea 插件路径探测 |
| FIX-6 | 更新 README / 方案分析.md |
| FIX-7 | 修正 Firefox ESR 描述 |
| FIX-8 | 统一 SUDO 使用 |
| FIX-9 | 增加 Java 安装选择菜单 |
| FIX-10 | 修复方案选择提示动态显示 |

## 快速开始

```bash
cd v2.2
sudo bash oracle-ebs-setup.sh
```
