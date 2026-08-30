# Oracle EBS 信创兼容方案 V1.1

## 概述

在国产信创电脑（ARM64/X86 + 统信/麒麟）上运行Oracle EBS（JRE 6u7/7/8 + Java Applet）。

V1.1 基于 V1.0 修复6个致命/重要问题，专注于 Oracle JRE 场景。

## 关键约束

**仅Firefox 52 ESR、Pale Moon、SeaMonkey可加载Java Applet！**

| 浏览器 | NPAPI支持 | 版本范围 | 推荐 |
|--------|----------|---------|------|
| Firefox 52 ESR | ✅ | 52.0 ~ 52.9.0 | ⭐⭐⭐⭐⭐ |
| Pale Moon | ✅ | 全部版本 | ⭐⭐⭐⭐ |
| SeaMonkey | ✅ | 2.53+ | ⭐⭐⭐ |
| Firefox ESR (新) | ❌ | ≥ 57 | 不可用 |
| Chrome | ❌ | ≥ 45 | 不可用 |

## V1.1 相对 V1.0 的修复

| 编号 | 严重度 | 修复 |
|------|--------|------|
| FIX-1 | 🔴 致命 | 日志tee权限修复（添加$SUDO + mkdir /var/log） |
| FIX-2 | 🔴 致命 | Firefox NPAPI版本约束修复（方案A改用52 ESR） |
| FIX-3 | 🔴 致命 | JRE .bin安装器添加sudo |
| FIX-4 | 🟡 重要 | ARM分支初始化IS_64BIT |
| FIX-5 | 🟡 重要 | 网络命令错误恢复 |
| FIX-6 | 🟡 重要 | PKG_MGR默认值 |

## Oracle JRE路径

```
手动下载 Oracle JRE 6u7/7/8 → 解压到 /opt/jre → 配置 NPAPI 插件软链接
```
