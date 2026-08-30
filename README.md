# Oracle EBS 信创兼容方案

在国产信创电脑（ARM64/X86 + 统信/麒麟）上运行 Oracle EBS（Java Applet）。

## 快速开始

```bash
sudo bash oracle-ebs-setup.sh
```

脚本自动检测 CPU 架构，显示对应方案，引导安装 Java 环境和浏览器。

## 文件说明

| 文件 | 说明 |
|------|------|
| `oracle-ebs-setup.sh` | 一键配置脚本（自动检测架构 + 统一 Java 安装 + 浏览器配置） |
| `方案分析.md` | 完整技术方案分析（浏览器 NPAPI 矩阵、Java 环境选择、架构原理） |
| `README.md` | 本文件 |
| `archive/` | 历史版本存档（v1.0 ~ v3.0，仅保留参考，不建议使用） |

## 支持的方案

### X86/C86（原生运行，无需模拟）

| 方案 | 浏览器 | 推荐 | 说明 |
|------|--------|------|------|
| A | Firefox 52 ESR + Java | ⭐⭐⭐⭐⭐ | 最后支持 NPAPI 的官方 Firefox |
| B | Pale Moon + Java | ⭐⭐⭐⭐ | 官方持续支持 NPAPI/Java |
| C | SeaMonkey 2.49.5 + Java | ⭐⭐ | 必须锁定版本，2.53+ 已移除 Java NPAPI |
| D | 仅安装 Java 环境 | ⭐⭐ | 已有合适浏览器 |

### ARM64（需要模拟层）

| 方案 | 技术 | 推荐 |
|------|------|------|
| A | QEMU 全系统虚拟机 | ⭐⭐⭐⭐⭐ |
| B | QEMU 用户模式 + proot | ⭐⭐⭐⭐ |
| C | Box64 + Wine | ⭐⭐⭐ |
| D | Docker + QEMU | ⭐⭐⭐ |
| E | Box86 + JRE | ⭐⭐ |

## 关键约束

### 浏览器 NPAPI 支持

| 浏览器 | NPAPI Java | 版本范围 | 状态 |
|--------|-----------|---------|------|
| Firefox 52 ESR | ✅ | 52.0 ~ 52.9.0 | 最后官方支持 |
| Pale Moon | ✅ | 全部版本（34+ 仅 64 位） | 官方持续支持 |
| SeaMonkey 2.49.5 | ✅ | ≤ 2.49.5 | 最后支持版本，禁止升级 |
| SeaMonkey 2.53+ | ❌ | ≥ 2.53.5 | 官方 RN 已移除全部 NPAPI |
| Firefox ESR（新） | ❌ | ≥ 57 | 2017 年移除 |
| Chrome / Chromium | ❌ | ≥ 45 | 2015 年移除 |

> ⚠️ Debian/Ubuntu 仓库的 `firefox-esr` 是 57+ 版本（无 NPAPI），**所有场景**必须使用 Firefox 52.9.0esr 官方二进制。

### Java 运行环境

| 选项 | 类型 | 安装方式 | 说明 |
|------|------|---------|------|
| Oracle JRE 8 / 7 / 6u7 | Oracle | 手动下载 | 兼容性最好 |
| OpenJDK 8 + IcedTea | 开源 | apt/yum 自动 | **推荐，最便捷** |

> IcedTea-Web 需要 Java 8 运行时，OpenJDK 11/17 不支持 Java Applet。

## 系统要求

- **操作系统**：统信 UOS、麒麟、Ubuntu、Debian、CentOS、Fedora 等
- **权限**：root 或 sudo
- **网络**：安装时需联网下载浏览器和 Java 包
- **内存**：ARM64 方案 A 推荐 ≥ 4GB

## 项目结构

```
.
├── oracle-ebs-setup.sh    # 主脚本（V3.2，962 行）
├── 方案分析.md            # 技术方案文档
├── README.md              # 本文件
└── archive/               # 历史版本存档
    ├── v1.0/              # 初始版本（3 个致命 Bug）
    ├── v1.1/              # 修复 6 项问题
    ├── v2.1/              # 增加 OpenJDK（11/17 不可行）
    ├── v2.2/              # 修复 10 项问题
    └── v3.0/              # 统一版（已知 16 项缺陷）
```

## 下载源验证（2026-08-30 实测）

| 资源 | 状态 | 说明 |
|------|------|------|
| Firefox 52.9.0esr（mozilla 官方） | ✅ 200 | x86_64 / i686 zh-CN |
| SeaMonkey 2.49.5（archive.mozilla.org） | ✅ 200 | x86_64 / i686 zh-CN |
| Pale Moon 34.3.2.1（官网 US/EU 镜像） | ✅ 200 | x86_64 GTK3 |
| OpenJDK 8 + IcedTea | ✅ 包管理器 | 无网络依赖 |
