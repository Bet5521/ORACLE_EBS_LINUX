#!/bin/bash
#===============================================================================
# Oracle EBS 信创兼容方案 - 一键配置脚本
# 版本: V2.1
# 备注: 增加OpenJDK选项，但OpenJDK 11/17+IcedTea不可行
#===============================================================================
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
SCRIPT_VERSION="2.1"; LOG_FILE="/var/log/oracle-ebs.log"; WORK_DIR="/opt/oracle-ebs"; SUDO=""
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
header(){ echo -e "\n${CYAN}${BOLD}═══ $1 ═══${NC}\n"; }
check_root() { [[ $EUID -ne 0 ]] && command -v sudo &>/dev/null && { SUDO="sudo"; }; }
detect_system() { ARCH=$(uname -m); [[ -f /etc/os-release ]] && . /etc/os-release; echo "ARCH=$ARCH ID=$ID"; }
show_plans() { header "可用方案"; echo "OpenJDK + NPAPI方案"; }
install_openjdk() {
    echo "选择OpenJDK版本:"
    echo "  [1] OpenJDK 8 + IcedTea"
    echo "  [2] OpenJDK 11 + IcedTea (有问题 - IcedTea需要Java 8)"
    echo "  [3] OpenJDK 17 + IcedTea (有问题 - IcedTea需要Java 8)"
}
main() { echo "Oracle EBS V${SCRIPT_VERSION} (v2.1 - 有OpenJDK 11/17不可行问题)"; check_root; detect_system; show_plans; }
main "$@"
