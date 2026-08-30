#!/bin/bash
#===============================================================================
# Oracle EBS 信创兼容方案 - 一键配置脚本
# 版本: V3.1 (统一版，在V3.0基础上修复16项问题)
# 日期: 2026-08-30
# 用途: 在ARM64/X86/C86 + 统信/麒麟系统上运行Oracle EBS
# Java: 支持Oracle JRE 6u7/7/8 + OpenJDK 8 + IcedTea (自动安装)
# 架构: 自动检测ARM64/X86/C86，切换对应方案
# 作者: KTT
# 合并: v1.1(Oracle JRE) + v2.2(OpenJDK 8+IcedTea) → 统一单文件 (V3.0)
# 修复: FIX-1~10 继承自v1.1/v2.2 (日志/Firefox52/sudo/IS_64BIT/错误恢复/PKG_MGR/IcedTea)
#       FIX-11~26 V3.1新增:
#         FIX-11 JRE .bin绝对路径执行错误    FIX-12 JRE6u7解压目录嵌套
#         FIX-13 启动脚本export展开顺序      FIX-14 deployment.properties文件名
#         FIX-15 sudo下HOME=/root站点例外错位 FIX-16 sudo模式WORK_DIR写入权限
#         FIX-17 SeaMonkey下载404            FIX-18 Pale Moon镜像失效→官网US/EU镜像
#         FIX-19 os-release缺VERSION_ID崩溃  FIX-20 apt-get update失败崩溃
#         FIX-21 IcedTea插件缺失不中断       FIX-22 VM/chroot/Docker内浏览器指引
#         FIX-23 浏览器检测补全              FIX-24 VM内存自适应
#         FIX-25 Box64/Wine按PKG_MGR分支
#         FIX-26 SeaMonkey 2.53.18已移除所有NPAPI(Java不工作)→降级至2.49.5(最后支持Java NPAPI)
#===============================================================================

set -euo pipefail

# ==================== 颜色和样式 ====================