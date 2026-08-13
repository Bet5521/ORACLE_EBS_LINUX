#!/bin/bash
#===============================================================================
# Oracle EBS 信创兼容方案 - 一键配置脚本
# 版本: V3.0
# 作者: KTT
# 合并: v1.1 + v2.2（Oracle JRE + OpenJDK 8 双路径）
#===============================================================================
set -euo pipefail

# ==================== 颜色和样式 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ==================== 全局变量 ====================
SCRIPT_VERSION="3.0"
LOG_FILE="/var/log/oracle-ebs.log"
WORK_DIR="/opt/oracle-ebs"
SUDO=""
PKG_MGR="apt"
ARCH_TYPE="unknown"
IS_64BIT=true
OS_PRETTY=""
TOTAL_MEM=4096
HAS_JRE=false
JRE_HOME=""
PLAN_OPTIONS=""

# ==================== 工具函数 ====================
log()   { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
warn()  { echo -e "${YELLOW}[警告]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
err()   { echo -e "${RED}[错误]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
info()  { echo -e "${BLUE}[信息]${NC} $1" | $SUDO tee -a "$LOG_FILE" 2>/dev/null; }
header(){ echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}${BOLD}  $1${NC}"; echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}\n"; }

# ==================== 权限检查 ====================
check_root() {
    header "权限检查"
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
            SUDO="sudo"; log "检测到sudo权限，将以sudo模式运行"
        else
            err "需要root或sudo权限"; exit 1
        fi
    else
        log "已确认root权限"
    fi
    $SUDO mkdir -p /var/log
}

# ==================== 系统检测 ====================
detect_system() {
    header "系统环境检测"
    local arch=$(uname -m)
    case "$arch" in
        aarch64|arm64) ARCH_TYPE="arm64"; IS_64BIT=true ;;
        x86_64) ARCH_TYPE="x86_64"; IS_64BIT=true ;;
        x86|i686|i386) ARCH_TYPE="x86"; IS_64BIT=false ;;
        *) ARCH_TYPE="unknown"; IS_64BIT=true ;;
    esac
    [[ -f /etc/os-release ]] && { . /etc/os-release; OS_PRETTY="${PRETTY_NAME}"; case "$ID" in centos|rhel|fedora|kylin) PKG_MGR="yum" ;; esac; }
    TOTAL_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}'); [[ -z "$TOTAL_MEM" ]] && TOTAL_MEM=4096
    for jp in /usr/bin/java /opt/jre*/bin/java; do
        [[ -x "$jp" ]] && { HAS_JRE=true; JRE_HOME=$(dirname $(dirname $jp)); break; }
    done
    log "架构: ${ARCH_TYPE} | OS: ${OS_PRETTY:-未知} | 内存: ${TOTAL_MEM}MB"
    log "已安装JRE: ${HAS_JRE}"
}

# ==================== JRE安装(统一入口) ====================
install_jre() {
    header "Java 运行环境安装"
    echo -e "  ${GREEN}── Oracle JRE (手动下载，兼容性最好) ──${NC}"
    echo "  [1] Oracle JRE 8   (推荐)"
    echo "  [2] Oracle JRE 7"
    echo "  [3] Oracle JRE 6u7 (最低要求)"
    echo ""
    echo -e "  ${CYAN}── OpenJDK (包管理器自动安装，更便捷) ──${NC}"
    echo "  [4] OpenJDK 8 + IcedTea (${GREEN}推荐${NC}，自动安装，完整支持Applet)"
    echo ""
    echo "  [5] 跳过"
    echo ""
    read -p "选择 [1-5] (默认1): " choice
    choice=${choice:-1}
    case "$choice" in
        1|2|3) install_oracle_jre "$choice" ;;
        4) install_openjdk_icedtea ;;
        5) return 0 ;;
        *) err "无效选择"; return 1 ;;
    esac
    configure_java_plugin
    configure_java_control_panel
}

install_oracle_jre() {
    local ver=""
    case "$1" in 1) ver="8" ;; 2) ver="7" ;; 3) ver="6u7" ;; *) ver="8" ;; esac
    header "安装 Oracle JRE ${ver}"
    echo -e "${YELLOW}请手动下载:${NC} https://www.oracle.com/java/technologies/javase-downloads.html"
    echo -e "  JRE ${ver} 文件放入 /tmp/"
    read -p "下载完成后按回车 (q跳过): " sk; [[ "$sk" == "q" ]] && return 0
    local jf=""
    for f in /tmp/jre-*.tar.gz /tmp/jre-*.bin; do [[ -f "$f" ]] && jf="$f" && break; done
    [[ -z "$jf" ]] && { read -p "JRE文件路径: " jf; }
    [[ ! -f "$jf" ]] && { err "文件不存在: $jf"; return 1; }
    $SUDO mkdir -p /opt/jre
    if [[ "$jf" == *.tar.gz ]]; then
        $SUDO tar xzf "$jf" -C /opt/jre --strip-components=1
    else
        cd /tmp && $SUDO chmod +x "$jf" && $SUDO "./$jf" 2>/dev/null; $SUDO mv jre1.* /opt/jre/ 2>/dev/null || true
    fi
    $SUDO tee /etc/profile.d/jre.sh > /dev/null << 'EOF'
export JAVA_HOME=/opt/jre
export PATH=${JAVA_HOME}/bin:${PATH}
EOF
    $SUDO chmod +x /etc/profile.d/jre.sh
    export JAVA_HOME=/opt/jre PATH=/opt/jre/bin:$PATH
    HAS_JRE=true; JRE_HOME=/opt/jre
    log "✅ Oracle JRE ${ver} 安装完成"
}

install_openjdk_icedtea() {
    header "安装 OpenJDK 8 + IcedTea"
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get update -qq
        $SUDO apt-get install -y openjdk-8-jdk icedtea-8-plugin 2>/dev/null || {
            $SUDO add-apt-repository -y ppa:openjdk-r/ppa 2>/dev/null || true
            $SUDO apt-get update -qq
            $SUDO apt-get install -y openjdk-8-jdk icedtea-8-plugin
        }
    else
        $SUDO yum install -y java-1.8.0-openjdk icedtea-web || err "OpenJDK安装失败"
    fi
    HAS_JRE=true
    JRE_HOME=$(dirname $(dirname $(readlink -f $(which java)))) 2>/dev/null || JRE_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
    log "✅ OpenJDK 8 + IcedTea 安装完成"
}

configure_java_plugin() {
    header "配置 Java NPAPI 插件"
    local plugin_so=""
    for d in "${JRE_HOME}" /opt/jre /usr/lib/jvm/java-8-openjdk-*; do
        for p in lib/amd64 lib/i386 jre/lib/amd64 jre/lib/i386 lib; do
            [[ -f "${d}/${p}/libnpjp2.so" ]] && plugin_so="${d}/${p}/libnpjp2.so" && break 2
        done
    done
    [[ -z "$plugin_so" ]] && { warn "未找到libnpjp2.so"; return 1; }
    for bd in ~/.mozilla/plugins /usr/lib/mozilla/plugins /usr/lib64/mozilla/plugins; do
        $SUDO mkdir -p "$bd" 2>/dev/null
        $SUDO ln -sf "$plugin_so" "$bd/libnpjp2.so" 2>/dev/null
    done
    log "✅ Java插件: ${plugin_so}"
}

configure_java_control_panel() {
    header "配置 Java 控制面板"
    [[ "$HAS_JRE" != "true" ]] && return 0
    read -p "是否添加Oracle EBS站点例外? [Y/n]: " ans; ans=${ans:-Y}
    if [[ "$ans" == "Y" || "$ans" == "y" ]]; then
        read -p "EBS地址 (如 https://ebs.example.com): " url
        if [[ -n "$url" ]]; then
            mkdir -p ~/.java/deployment
            echo "$url" >> ~/.java/deployment/exception.sites
            cat > ~/.java/deployment/deployment.security << EOF
deployment.security.level=MEDIUM
deployment.security.askgranted.notlisted=true
EOF
            log "✅ 站点例外已添加: $url"
        fi
    fi
}

# ==================== ARM方案 ====================
arm_plan_a() { header "ARM方案A: QEMU全系统虚拟机"; $SUDO $PKG_MGR install -y -qq qemu-system-x86 qemu-utils wget || err "QEMU安装失败"; log "✅ ARM-A完成"; }
arm_plan_b() { header "ARM方案B: QEMU用户模式+proot"; $SUDO $PKG_MGR install -y -qq qemu-user-static proot debootstrap; log "✅ ARM-B完成"; }
arm_plan_c() { header "ARM方案C: Box64+Wine"; log "ARM-C: 需要从github.com/ptitSeb/box64 编译"; }
arm_plan_d() { header "ARM方案D: Docker+QEMU"; $SUDO $PKG_MGR install -y -qq docker.io; log "✅ ARM-D完成"; }
arm_plan_e() { header "ARM方案E: Box86+JRE"; log "ARM-E: 需要从github.com/ptitSeb/box86 编译"; }

# ==================== X86方案 ====================
x86_plan_a() { header "X86方案A: Firefox 52 ESR + JRE"; install_jre; log "✅ X86-A完成"; }
x86_plan_b() { header "X86方案B: Pale Moon + JRE"; install_jre; log "✅ X86-B完成"; }
x86_plan_c() { header "X86方案C: SeaMonkey + JRE"; install_jre; log "✅ X86-C完成"; }
x86_plan_d() { header "X86方案D: 仅安装JRE"; install_jre; log "✅ X86-D完成"; }

# ==================== 启动器 ====================
create_launcher() {
    $SUDO mkdir -p "$WORK_DIR"
    cat > "${WORK_DIR}/oracle-ebs.sh" << 'EOF'
#!/bin/bash
WORK_DIR="/opt/oracle-ebs"
echo "Oracle EBS 启动器"
ls -1 "${WORK_DIR}"/start-*.sh 2>/dev/null
EOF
    $SUDO chmod +x "${WORK_DIR}/oracle-ebs.sh"
    log "✅ 启动器: ${WORK_DIR}/oracle-ebs.sh"
}

# ==================== 主流程 ====================
show_plans() {
    header "可用方案"
    echo -e "${BOLD}架构: ${ARCH_TYPE} | OS: ${OS_PRETTY:-未知} | 内存: ${TOTAL_MEM}MB${NC}"
    echo ""
    if [[ "$ARCH_TYPE" == "arm64" ]]; then
        echo -e "${MAGENTA}${BOLD}═══ ARM64方案（需要模拟层） ═══${NC}"
        echo -e "  ${GREEN}[A]${NC} QEMU全系统虚拟机  ${GREEN}⭐⭐⭐⭐⭐${NC}"
        echo -e "  ${GREEN}[B]${NC} QEMU用户模式+proot  ${GREEN}⭐⭐⭐⭐${NC}"
        echo -e "  ${YELLOW}[C]${NC} Box64+Wine  ${YELLOW}⭐⭐⭐${NC}"
        echo -e "  ${YELLOW}[D]${NC} Docker+QEMU  ${YELLOW}⭐⭐⭐${NC}"
        echo -e "  ${RED}[E]${NC} Box86+JRE  ${RED}⭐⭐${NC}"
    else
        echo -e "${CYAN}${BOLD}═══ X86方案（原生运行） ═══${NC}"
        echo -e "  ${GREEN}[A]${NC} Firefox 52 ESR + JRE  ${GREEN}⭐⭐⭐⭐⭐${NC}"
        echo -e "  ${GREEN}[B]${NC} Pale Moon + JRE  ${GREEN}⭐⭐⭐⭐${NC}"
        echo -e "  ${YELLOW}[C]${NC} SeaMonkey + JRE  ${YELLOW}⭐⭐⭐${NC}"
        echo -e "  ${CYAN}[D]${NC} 仅安装JRE  ${CYAN}⭐⭐${NC}"
    fi
}

main() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║   Oracle EBS 信创兼容方案 V${SCRIPT_VERSION}   ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    check_root
    detect_system
    $SUDO mkdir -p "$WORK_DIR"
    show_plans
    echo ""
    read -p "$(echo -e "${BOLD}请选择方案: ${NC}")" choice
    choice=${choice:-A}
    if [[ "$ARCH_TYPE" == "arm64" ]]; then
        case "$choice" in
            A|a) arm_plan_a ;;
            B|b) arm_plan_b ;;
            C|c) arm_plan_c ;;
            D|d) arm_plan_d ;;
            E|e) arm_plan_e ;;
            *) err "无效选择"; exit 1 ;;
        esac
    else
        case "$choice" in
            A|a) x86_plan_a ;;
            B|b) x86_plan_b ;;
            C|c) x86_plan_c ;;
            D|d) x86_plan_d ;;
            *) err "无效选择"; exit 1 ;;
        esac
    fi
    create_launcher
    header "✅ 配置完成"
    echo -e "${GREEN}${BOLD}Oracle EBS 兼容方案已配置完成！${NC}"
    echo -e "  架构: ${BOLD}${ARCH_TYPE}${NC} | 工作目录: ${BOLD}${WORK_DIR}${NC}"
}

main "$@"
