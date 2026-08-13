# Oracle EBS V1.1 / V2.2 实现计划

## 仓库概述

路径：`d:\TRAE_APPS\ORACLE_EBS_LINUX`

## 文件模块

- v1.0/oracle-ebs-setup.sh（685行，初始版，有致命Bug）
- v1.1/（需生成：修复Oracle JRE路径的6个问题）
- v2.1/oracle-ebs-setup.sh（增加OpenJDK选项，但11/17不可行）
- v2.2/（需生成：修复10个问题，保留OpenJDK 8）

## 实现步骤

1. 读取并理解 v1.0 和 v2.1 的代码
2. 生成 v1.1 修复版（Oracle JRE 路径）
3. 生成 v2.2 修复版（OpenJDK 8 路径）
4. 更新 README 和 方案分析.md
5. 静态验证（bash -n / grep 检查）

## 验证方法

- bash -n v1.1/oracle-ebs-setup.sh
- bash -n v2.2/oracle-ebs-setup.sh
- Grep 检查关键字段（SUDO、IS_64BIT、PKG_MGR默认值）

## 风险与约束

- WSL 未安装，无法运行 bash -n，仅能静态验证
- 需要确认的浏览器NPAPI支持版本

## 修复清单

### V1.0 → V1.1 (6个修复)

FIX-1: tee 权限修复 (致命) - 非root用户无法写入 /var/log
FIX-2: Firefox NPAPI 版本约束 (致命) - 用52 ESR而非最新ESR
FIX-3: .bin 安装器 sudo (致命) - 权限导致JRE安装失败
FIX-4: ARM分支 IS_64BIT 初始化 (重要)
FIX-5: 网络命令错误恢复 (重要)
FIX-6: PKG_MGR 默认值 (重要)

### V2.1 → V2.2 (10个修复)

FIX-1~FIX-6: 同V1.1
FIX-7: 移除OpenJDK 11/17选项
FIX-8: 统一版本号
FIX-9: 增强IcedTea插件路径探测
FIX-10: 修正方案选择提示
