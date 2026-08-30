# Oracle EBS 信创兼容方案 V3.1 (统一版)

## 概述

在国产信创电脑（ARM64/X86 + 统信/麒麟）上运行Oracle EBS（Java Applet）。

**V3.1** 在 V3.0（合并 v1.1 + v2.2 的统一版）基础上完成全面验证，修复 16 项缺陷（10 项致命 + 6 项健壮性），并核实全部下载链接有效性与浏览器 NPAPI 官方声明真实性。

## 文件

| 文件 | 说明 |
|------|------|
| `oracle-ebs-setup.sh` | 一键配置脚本（自动检测架构+统一Java安装） |
| `方案分析.md` | 完整技术方案分析 |
| `README.md` | 本文件 |

## 使用

```bash
sudo bash oracle-ebs-setup.sh
```

脚本自动检测CPU架构，根据架构显示对应方案并引导安装Java环境。

## ⚠️ 关键约束

### 浏览器NPAPI支持

| 浏览器 | NPAPI Java支持 | 版本范围 | 推荐 | 证据 |
|--------|---------------|---------|------|------|
| Firefox 52 ESR | ✅ | 52.0 ~ 52.9.0 | ⭐⭐⭐⭐⭐ | 历史上最后官方支持版 |
| Pale Moon | ✅ **持续支持** | 全部版本（34+仅64位） | ⭐⭐⭐⭐ | [官方Technical Details](https://www.palemoon.org/technical.shtml)："Full and ongoing support for NPAPI plugins (Java, Flash, Silverlight, etc.)" |
| SeaMonkey 2.49.5 | ✅ | ≤2.49.5 | ⭐⭐ | [Legacy页面](https://www.seamonkey-project.org/releases/legacy)：「The last version supporting plugins other than Flash on Windows and Linux was SeaMonkey 2.49.5.」|
| **SeaMonkey 2.53+** | ❌ **已全部移除Java NPAPI** | 2.53.5+ | 不可用 | [2.53.18 RN](https://www.seamonkey-project.org/releases/seamonkey2.53.18/)：「Support for all NPAPI plugins like Flash, Java and Silverlight has been removed」 |
| Firefox ESR (新) | ❌ | ≥ 57 | 不可用 | |
| Chrome | ❌ | ≥ 45 | 不可用 | |

> **重要更正（v3.1 FIX-26）：SeaMonkey 2.53.5+（含 2.53.18 / 2.53.24）官方 Release Notes 明确移除了所有 NPAPI 插件（Java/Silverlight）**。脚本中的方案C 已经降级到 SeaMonkey 2.49.5，这是 Linux 上支持 Java NPAPI 的最后官方版本；请注意禁止 SeaMonkey 自动升级。
>
> Firefox 52 ESR、Pale Moon 的 Java NPAPI 支持经官方文档确认仍然成立（Pale Moon 首页、技术细节、开发者文档均写明「持续保留并维护完整NPAPI实现」）。
>
> ⚠️ Debian/Ubuntu 仓库的 `firefox-esr` 是 57+ 版本（无NPAPI），**所有场景**（原生/VM/chroot/Docker）都必须使用 Firefox 52.9.0esr 官方二进制（脚本内置 mozilla FTP 直链，已实测200）。

### Java运行环境

| 选项 | 类型 | 安装方式 | 说明 |
|------|------|---------|------|
| [1] Oracle JRE 8 | Oracle | 手动下载 | 兼容性最好 |
| [2] Oracle JRE 7 | Oracle | 手动下载 | |
| [3] Oracle JRE 6u7 | Oracle | 手动下载 | 最低要求 |
| [4] OpenJDK 8 + IcedTea | 开源 | apt/yum自动 | **推荐，最便捷** |

**OpenJDK 8 优势：**
- 包管理器一键安装，无需手动下载
- IcedTea插件自动提供NPAPI支持
- 无需额外配置Java控制面板（Applet安全提示更少）

> IcedTea-Web需要Java 8运行时，OpenJDK 11/17不支持Java Applet。

## 下载源验证状态（2026-08-30 三次验证，curl HEAD 实测 + 官方RN确认）

| 资源 | 状态 | 说明 |
|------|------|------|
| Firefox 52.9.0esr (x86_64/i686 zh-CN, mozilla官方) | ✅ 200 | 最后官方支持NPAPI的Firefox版本 |
| SeaMonkey 2.49.5 (x86_64/i686 zh-CN, archive.mozilla.org) | ✅ 200 | **最后支持Java NPAPI的SeaMonkey官方版本**；必须锁定版本，禁止自动升级 |
| Pale Moon 34.3.2.1 (官网download.php US镜像 Linux x86_64 GTK3) | ✅ 200 | 官方持续支持NPAPI（含Java） |
| Pale Moon 34.3.2.1 (官网download.php EU镜像 Linux x86_64 GTK3) | ✅ 200 | 官网第二镜像，脚本自动兜底 |
| OpenJDK 8 + IcedTea | ✅ 包管理器安装，无网络依赖问题 | - |

> **SeaMonkey 2.53.18 已弃用（v3.1 FIX-26）：2.53+ 官方 Release Notes 明确移除了全部 NPAPI（含Java）**。脚本中的 x86_plan_c 已经降级到 2.49.5（文件名：seamonkey-2.49.5.tar.bz2，无 `.zh-CN.` 段）。
>
> Pale Moon 说明：linux.palemoon.org/data 直链在本次验证网络不可达，**最终脚本** 已改为 `www.palemoon.org/download.php?mirror=us|eu` 官方入口（随官网版本自动更新，US/EU 双镜像兜底）；Pale Moon 官方 Technical Details（v34.3.2.1同期）和开发者文档明确声明「Pale Moon 会完整保留并持续支持 NPAPI 和所有基于它的原生插件（含Java/Flash/Silverlight）」，无需降级。32 位系统给出提示并跳过下载。

## 架构自动检测

```
检测uname -m
  ├─ aarch64/arm64 → ARM方案(A-E)
  └─ x86_64/x86/i686 → X86方案(A-D)
```

## ARM64方案（需要模拟层）

| 方案 | 技术 | 推荐 |
|------|------|------|
| A | QEMU全系统虚拟机 | ⭐⭐⭐⭐⭐ |
| B | QEMU用户模式+proot | ⭐⭐⭐⭐ |
| C | Box64+Wine | ⭐⭐⭐ |
| D | Docker+QEMU | ⭐⭐⭐ |
| E | Box86+JRE | ⭐⭐ |

## X86方案（原生运行）

| 方案 | 浏览器 | 推荐 | 说明 |
|------|--------|------|------|
| A | Firefox 52 ESR + Java | ⭐⭐⭐⭐⭐ | 最后官方支持NPAPI的Firefox |
| B | Pale Moon + Java | ⭐⭐⭐⭐ | 官方Technical Details确认：Full and ongoing NPAPI/Java支持 |
| C | SeaMonkey **2.49.5** + Java | ⭐⭐ | 必须锁定版本；2.53.5+官方RN已移除Java NPAPI，绝对不能升级 |
| D | 仅安装Java环境 | ⭐⭐ | 已有合适浏览器 |

## 共同功能

- root/sudo权限检查（sudo模式自动定位真实桌面用户）
- 系统架构/OS/内存自动检测（含包管理器兜底）
- 统一Java安装入口（Oracle JRE + OpenJDK 8）
- Java浏览器插件自动配置（Oracle NPAPI / IcedTea）
- Java控制面板自动配置（exception.sites + deployment.properties，写入正确用户目录）
- 通用启动器+桌面快捷方式

## 版本演进历史

| 版本 | 日期 | 主要变更 |
|------|------|---------|
| **v1.0** | 2026-08-13 | 初始版本。仅支持Oracle JRE。存在3个致命Bug（Firefox NPAPI错误、日志权限、.bin sudo缺失）|
| **v1.1** | 2026-08-13 | 修复v1.0的6个问题：Firefox改用52 ESR、日志tee加$SUDO、.bin安装加sudo、变量初始化、错误恢复、PKG_MGR默认值 |
| **v2.1** | 2026-08-13 | 在v1.0基础上新增OpenJDK 8/11/17 + IcedTea选项。但OpenJDK 11/17方案技术上不可行 |
| **v2.2** | 2026-08-13 | 修复v2.1的全部10个问题：移除OpenJDK 11/17、IcedTea路径增强、同v1.1的6个修复 |
| **v3.0** | 2026-08-13 | **统一版本**。合并v1.1（Oracle JRE）+ v2.2（OpenJDK 8 + IcedTea）为单一脚本。统一Java安装入口，消除两个并行版本 |
| **v3.1** | 2026-08-30 | **验证修复版**。全面验证v3.0并修复16项缺陷（见下表），官网RN核实浏览器NPAPI真实性（FIX-26 SeaMonkey降级2.49.5），Pale Moon确认仍完整支持NPAPI，全部下载链接实测200 |

## V3.1 修复清单（共16项）

### 致命缺陷（10项，修复前核心功能必然失败或给用户错误预期）

| 编号 | 问题 | 影响 | 修复 | 证据 |
|------|------|------|------|------|
| FIX-11 | JRE .bin安装用`./`拼接绝对路径 | JRE 6u7安装100%失败 | 转绝对路径+readlink -f后直接执行 | — |
| FIX-12 | JRE 6u7解压目录嵌套进/opt/jre内部 | 安装后验证必失败 | rmdir后整体mv | — |
| FIX-13 | 启动脚本单行export展开顺序错误 | start-firefox/palemoon/seamonkey中PATH缺java，Applet无法加载 | 拆分为两行export（3处） | — |
| FIX-14 | 配置文件误写为`deployment.security` | 站点例外配置完全无效 | 更正为`deployment.properties` | — |
| FIX-15 | sudo运行时HOME=/root | 站点例外写到root目录，桌面用户浏览器读不到 | SUDO_USER定位真实用户+chown | — |
| FIX-16 | sudo模式下/opt/oracle-ebs(root:755)不可写 | 非root运行脚本直接崩溃 | main中chown给当前用户 | — |
| FIX-17 | SeaMonkey URL文件名缺少`.zh-CN.`段（v3.0针对2.53.18） | 下载404（实测确认） | FIX-26整体将SM降级至2.49.5，URL同步重写（`/2.49.5/.../seamonkey-2.49.5.tar.bz2` 不带`.zh-CN.`段，已实测200） | — |
| FIX-18 | Pale Moon镜像rm-kr02失效 | 下载失败（实测000） | 改用官网`download.php?mirror=us\|eu`双镜像入口（脚本自动兜底；US/EU均已实测200） | — |
| FIX-22 | VM/chroot/Docker内指引安装仓库firefox-esr | bullseye的firefox-esr为78+无NPAPI，方案内浏览器必然不可用 | 全部改为Firefox 52 ESR二进制下载指引；Docker改buster-slim+FF52 | — |
| **FIX-26** | **SeaMonkey 2.53+官方RN明确已移除Java NPAPI** | **用户按旧脚本下载的2.53.18里Applet必定加载失败，v3.0给的预期完全错误** | **x86_plan_c 降级至 SeaMonkey 2.49.5；X86方案表⭐⭐⭐→⭐⭐并标注禁止升级；启动脚本追加自动升级禁用；脚本提示明确告知RN原文** | [seamonkey-project.org/releases/seamonkey2.53.18](https://www.seamonkey-project.org/releases/seamonkey2.53.18/) 原文："Support for all NPAPI plugins like Flash, Java and Silverlight has been removed"；[Legacy](https://www.seamonkey-project.org/releases/legacy) 确认2.49.5为最后支持 |

### 健壮性修复（6项）

| 编号 | 问题 | 修复 |
|------|------|------|
| FIX-19 | os-release缺VERSION_ID时set -u崩溃 | 全部变量加默认值 |
| FIX-20 | apt-get update失败直接终止 | 改为warn后继续（使用现有索引） |
| FIX-21 | IcedTea插件缺失时return 1终止全流程 | 改为warn+手动指引，Java本体成果保留 |
| FIX-23 | 浏览器检测缺seamonkey/firefox-52；OS ID大小写敏感 | 检测列表补全；ID转小写匹配；增加yum兜底 |
| FIX-24 | start-vm.sh固定2048MB内存 | 按MEM_LEVEL自适应(1024/2048/4096) |
| FIX-25 | Box64/Box86方案编译依赖和Wine仅apt分支 | 按PKG_MGR完整分支 |

### Pale Moon 确认项（非修复，仅核实澄清）

Pale Moon 34.3.2.1（2026-08最新点版本）仍 **完整并持续支持 NPAPI + Java**，无需降级：
- [Pale Moon 官方 Technical Details](https://www.palemoon.org/technical.shtml)："Full and ongoing support for NPAPI plugins (Java, Flash, Silverlight, etc.)"
- [Pale Moon 首页](https://www.palemoon.org/)："Pale Moon also supports legacy, native plugins like Java and Flash through the Netscape Plugin API (NPAPI)."
- [Pale Moon 开发者文档 Add-ons Overview](https://developer.palemoon.org/addons/)："Nevertheless, Pale Moon and all applications will retain the full implementation and freedom of the NPAPI and plugins written for it."

## V3.0 技术决策说明

### 为什么合并？
- v1.1 和 v2.2 的ARM方案代码完全相同
- v1.1 的 `install_jre` 功能是 v2.2 `install_java` + `install_oracle_jre` 的子集
- 维护两份几乎相同的代码（685行 vs 818行）成本高且容易遗漏修复
- 统一后用户只需看一份文档、跑一个脚本

### 合并策略
- 以 v2.2 为基础（它包含v1.1的全部功能，并增加了OpenJDK路径）
- 版本号升至 3.0
- `install_java()` 作为统一入口，`[1-3]`选Oracle JRE、`[4]`选OpenJDK 8 + IcedTea
- X86 方案D标题从"仅JRE"改为"仅Java环境"以覆盖两种路径
- 统一 README 和 方案分析

### 为什么不支持OpenJDK 11/17？
IcedTea-Web（Java Applet的NPAPI实现）是基于Java 8运行时开发的。OpenJDK 11+ 移除了javax插件API，IcedTea-Web无法工作。实际上没有任何现代浏览器能在Java 11+上运行Applet。
