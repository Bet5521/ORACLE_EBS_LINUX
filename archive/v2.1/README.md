# Oracle EBS 信创兼容方案 V2.1

## 概述

V2.1 增加了 OpenJDK 替代路径（除 Oracle JRE 外）。

## ⚠️ 已知问题

- OpenJDK 11/17 + IcedTea 不可行，因为 IcedTea-Web 要求 Java 8
- Firefox ESR 描述未修正（仍说最新ESR支持NPAPI）
- README / 方案分析.md 未同步更新
- 版本号不统一（脚本内有时称 2.0）

## 关键约束

- 仅 Firefox 52 ESR、Pale Moon、SeaMonkey 支持 NPAPI
- OpenJDK 只能用 8（配合 IcedTea-Web）
- Oracle JRE 8/7/6u7 均可
