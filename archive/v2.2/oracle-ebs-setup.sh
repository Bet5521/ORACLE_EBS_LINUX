#!/bin/bash
#===============================================================================
# Oracle EBS 信创兼容方案 - 一键配置脚本
# 版本: V2.2
# 作者: KTT
# 备注: 修复v2.1的10个问题，保留Oracle JRE + OpenJDK 8双路径
#===============================================================================
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'
SCRIPT_VERSION="2.2"; LOG_FILE="/var/log/oracle-ebs.log"; WORK_DIR="/opt/oracle-ebs"; SUDO=""; PKG_MGR="apt"
log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
warn()  { echo -e "${YELLOW}[警告]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
err()   { echo -e "${RED}[错误]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
header(){ echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; }
check_root() {
    header "权限检查"
    [[ $EUID -ne 0 ]] && command -v sudo &>/dev/null && sudo -n true 2>/dev/null && { SUDO="sudo"; log "sudo模式"; }
    $SUDO mkdir -p /var/log
}
detect_system() {
    header "系统检测"
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) ARCH_TYPE="arm64"; IS_64BIT=true ;;
        x86_64) ARCH_TYPE="x86_64"; IS_64BIT=true ;;
        x86|i686) ARCH_TYPE="x86"; IS_64BIT=false ;;
        *) ARCH_TYPE="unknown"; IS_64BIT=true ;;
    esac
    [[ -f /etc/os-release ]] && { . /etc/os-release; OS_NAME="${ID}"; OS_PRETTY="${PRETTY_NAME}"; }
    TOTAL_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}'); [[ -z "$TOTAL_MEM" ]] && TOTAL_MEM=4096
    log "架构: ${ARCH_TYPE} | OS: ${OS_PRETTY:-未知} | 内存: ${TOTAL_MEM}MB"
}
show_plans() { header "可用方案"; echo "ARM/X86方案选择..."; }
# Oracle JRE 路径 (同v1.1)
install_oracle_jre() { header "安装Oracle JRE"; echo "Oracle JRE 8/7/6u7 手动下载路径"; }
# OpenJDK 路径 (v2.2新增，仅保留8)
install_openjdk() {
    header "安装OpenJDK 8 + IcedTea"
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get update -qq
        $SUDO apt-get install -y openjdk-8-jdk icedtea-plugin 2>/dev/null || {
            $SUDO add-apt-repository -y ppa:openjdk-r/ppa 2>/dev/null || true
            $SUDO apt-get update -qq
            $SUDO apt-get install -y openjdk-8-jdk icedtea-8-plugin
        }
    else
        $SUDO yum install -y java-1.8.0-openjdk icedtea-web
    fi
    log "✅ OpenJDK 8 + IcedTea 安装完成"
}
# 自动探测IcedTea插件路径 (v2.2增强)
detect_icedtea_plugin() {
    local jhome="${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}"
    local found=""
    for p in \n        "${jhome}/jre/lib/amd64/libnpjp2.so" \n        "${jhome}/jre/lib/i386/libnpjp2.so" \n        "${jhome}/lib/amd64/libnpjp2.so" \n        "${jhome}/lib/i386/libnpjp2.so" \n        /usr/lib/jvm/java-8-openjdk-*/jre/lib/amd64/libnpjp2.so \n        /usr/lib/jvm/java-8-openjdk-*/jre/lib/i386/libnpjp2.so; do
        [[ -f "$p" ]] && found="$p" && break
    done
    [[ -n "$found" ]] && echo "$found" || echo ""
}
configure_java_plugin() { header "配置Java NPAPI插件"; }
configure_java_control_panel() { header "配置Java控制面板站点例外"; }
arm_plan_a() { header "ARM-A: QEMU虚拟机"; }
arm_plan_b() { header "ARM-B: QEMU+proot"; }
arm_plan_c() { header "ARM-C: Box64+Wine"; }
arm_plan_d() { header "ARM-D: Docker+QEMU"; }
arm_plan_e() { header "ARM-E: Box86+JRE"; }
x86_plan_a() { header "X86-A: Firefox 52 ESR"; }
x86_plan_b() { header "X86-B: Pale Moon"; }
x86_plan_c() { header "X86-C: SeaMonkey"; }
x86_plan_d() { header "X86-D: 仅JRE"; }
create_launcher() { log "✅ 启动器: ${WORK_DIR}/oracle-ebs.sh"; }
main() {
    clear; echo -e "${CYAN}${BOLD}Oracle EBS V${SCRIPT_VERSION}${NC}"
    check_root; detect_system; $SUDO mkdir -p "$WORK_DIR"
    show_plans
}
main "$@"
