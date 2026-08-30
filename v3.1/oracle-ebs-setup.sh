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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ==================== 全局变量 ====================
SCRIPT_VERSION="3.1"
LOG_FILE="/var/log/oracle-ebs.log"
WORK_DIR="/opt/oracle-ebs"
SUDO=""
PKG_MGR="apt"

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
        if command -v sudo &>/dev/null; then
            if sudo -n true 2>/dev/null; then
                log "检测到sudo权限，将以sudo模式运行"
                SUDO="sudo"
            else
                err "需要root权限或sudo权限才能执行此脚本"
                err "请使用以下方式之一运行："
                err "  1. sudo bash $0"
                err "  2. su -c 'bash $0'"
                exit 1
            fi
        else
            err "当前非root用户且未安装sudo，请以root身份执行"
            exit 1
        fi
    else
        log "已确认root权限"
    fi
    $SUDO mkdir -p /var/log
}

# ==================== 系统检测 ====================
detect_system() {
    header "系统环境检测"

    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64)
            ARCH_TYPE="arm64"
            IS_64BIT=true
            log "✅ 检测到ARM64架构"
            ;;
        x86_64)
            ARCH_TYPE="x86_64"
            IS_64BIT=true
            log "✅ 检测到X86_64架构"
            ;;
        x86|i686|i386)
            ARCH_TYPE="x86"
            IS_64BIT=false
            log "✅ 检测到X86(32位)架构"
            ;;
        *)
            ARCH_TYPE="unknown"
            IS_64BIT=true
            warn "未知架构: ${ARCH}"
            ;;
    esac

    if [[ -f /etc/os-release ]]; then
        # FIX-19: 使用默认值防止os-release缺少VERSION_ID时set -u崩溃
        . /etc/os-release
        OS_NAME="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-}"
        OS_PRETTY="${PRETTY_NAME:-${OS_NAME}}"
        log "操作系统: ${OS_PRETTY}"
        # 统一转小写匹配，兼容UOS/Uos、kylin/Kylin等大小写差异
        OS_NAME_LC="${OS_NAME,,}"
        case "$OS_NAME_LC" in
            uos|uniontech|deepin)   log "✅ 统信UOS/Deepin"; PKG_MGR="apt" ;;
            kylin|openkylin)        log "✅ 麒麟系统"; PKG_MGR="apt" ;;
            ubuntu|debian|linuxmint) log "✅ Debian系"; PKG_MGR="apt" ;;
            centos|rhel|fedora|rocky|almalinux) log "RedHat系"; PKG_MGR="yum" ;;
            openeuler|euleros|opensusel|sles)   log "openEuler/SUSE系"; PKG_MGR="yum" ;;
            *)              warn "未知系统: ${OS_NAME}"; PKG_MGR="apt" ;;
        esac
    else
        warn "未找到 /etc/os-release，使用默认 apt 包管理器"
    fi

    # FIX-23补充: 按实际可用的包管理器兜底
    if [[ "$PKG_MGR" == "apt" ]] && ! command -v apt-get &>/dev/null && command -v yum &>/dev/null; then
        PKG_MGR="yum"
        warn "apt-get不可用，切换为yum"
    fi

    TOTAL_MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}')
    [[ -z "$TOTAL_MEM" ]] && TOTAL_MEM=4096
    AVAIL_DISK=$(df -BG / 2>/dev/null | awk 'NR==2{print $4}' | tr -d 'G')
    [[ -z "$AVAIL_DISK" ]] && AVAIL_DISK=50
    log "内存: ${TOTAL_MEM}MB | 可用磁盘: ${AVAIL_DISK}GB"

    if [[ $TOTAL_MEM -lt 2048 ]]; then MEM_LEVEL="low"
    elif [[ $TOTAL_MEM -lt 4096 ]]; then MEM_LEVEL="medium"
    else MEM_LEVEL="high"; fi

    KVM_SUPPORT=false
    if [[ -e /dev/kvm ]]; then
        KVM_SUPPORT=true
        [[ "$ARCH_TYPE" == "arm64" ]] && log "✅ KVM硬件加速可用"
    fi

    HAS_JRE=false
    HAS_BROWSER=false
    JRE_VERSION=""
    BROWSER_CMD=""
    for jpath in /usr/bin/java /opt/jre*/bin/java /opt/java*/bin/java; do
        if [[ -x "$jpath" ]]; then
            HAS_JRE=true; JRE_PATH="$jpath"
            JRE_VERSION=$("$jpath" -version 2>&1 | head -1)
            log "发现Java: ${JRE_PATH} - ${JRE_VERSION}"; break
        fi
    done
    # FIX-23: 补充seamonkey和firefox-52检测
    for browser in firefox firefox-esr firefox-52 palemoon seamonkey; do
        if command -v "$browser" &>/dev/null; then
            HAS_BROWSER=true; BROWSER_CMD="$browser"
            log "发现浏览器: $browser"; break
        fi
    done
}

# ==================== 方案展示 ====================
show_plans() {
    header "可用方案"

    echo -e "${BOLD}当前环境:${NC} ${ARCH_TYPE} | ${OS_PRETTY:-未知} | 内存${TOTAL_MEM}MB(${MEM_LEVEL})"
    echo ""

    if [[ "$ARCH_TYPE" == "arm64" ]]; then
        show_arm_plans
    else
        show_x86_plans
    fi
}

show_arm_plans() {
    echo -e "${MAGENTA}${BOLD}═══ ARM64方案 (需要模拟层) ═══${NC}"
    echo ""
    echo -e "${BOLD}┌──────┬────────────────────────┬──────────┬──────────────────────────┐${NC}"
    echo -e "${BOLD}│ 方案 │ 名称                   │ 推荐     │ 说明                     │${NC}"
    echo -e "${BOLD}├──────┼────────────────────────┼──────────┼──────────────────────────┤${NC}"
    echo -e "${BOLD}│${NC} ${GREEN}[A]${NC}  │ QEMU全系统虚拟机       │ ${GREEN}⭐⭐⭐⭐⭐${NC} │ 内存≥4GB，最稳定         ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${GREEN}[B]${NC}  │ QEMU用户模式+proot     │ ${GREEN}⭐⭐⭐⭐${NC}   │ 内存有限，轻量           ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${YELLOW}[C]${NC}  │ Box64+Wine             │ ${YELLOW}⭐⭐⭐${NC}     │ 有Wine经验               ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${YELLOW}[D]${NC}  │ Docker+QEMU            │ ${YELLOW}⭐⭐⭐${NC}     │ 有Docker经验             ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${RED}[E]${NC}  │ Box86+JRE              │ ${RED}⭐⭐${NC}       │ 仅作备选                 ${BOLD}│${NC}"
    echo -e "${BOLD}└──────┴────────────────────────┴──────────┴──────────────────────────┘${NC}"
    echo ""
    echo -e "  ${GREEN}[A]${NC} QEMU模拟完整x86_64硬件，安装轻量Linux，运行Firefox 52 ESR + Java  ${GREEN}强烈推荐${NC}"
    echo -e "  ${GREEN}[B]${NC} QEMU用户模式透明翻译x86指令，proot提供文件系统隔离"
    echo -e "  ${YELLOW}[C]${NC} Box64翻译x86_64指令，Wine运行Windows版JRE和浏览器"
    echo -e "  ${YELLOW}[D]${NC} Docker容器 + QEMU多架构模拟"
    echo -e "  ${RED}[E]${NC} Box86翻译x86(32位)指令，直接运行x86 JRE"
    echo ""
    if [[ "$MEM_LEVEL" == "high" ]]; then
        echo -e "  ${GREEN}${BOLD}💡 推荐方案A (QEMU全系统虚拟机) - 内存充足，稳定性最佳${NC}"
    else
        echo -e "  ${YELLOW}${BOLD}💡 推荐方案B (QEMU用户模式) - 内存适中，轻量级${NC}"
    fi
}

show_x86_plans() {
    echo -e "${CYAN}${BOLD}═══ X86/C86方案 (原生运行，无需模拟) ═══${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}⚠️ 重要: 仅Firefox ≤52 ESR与Pale Moon仍支持完整NPAPI Java插件${NC}"
    echo -e "${YELLOW}${BOLD}   SeaMonkey需用2.49.5旧版(2.53+已移除Java NPAPI)${NC}"
    echo -e "${YELLOW}${BOLD}   最新Firefox ESR (≥57)与Chrome已完全移除NPAPI，无法加载Java Applet${NC}"
    echo ""
    echo -e "${BOLD}┌──────┬────────────────────────┬──────────┬────────────────────────────┐${NC}"
    echo -e "${BOLD}│ 方案 │ 名称                   │ 推荐     │ 说明                       │${NC}"
    echo -e "${BOLD}├──────┼────────────────────────┼──────────┼────────────────────────────┤${NC}"
    echo -e "${BOLD}│${NC} ${GREEN}[A]${NC}  │ Firefox 52 ESR + Java   │ ${GREEN}⭐⭐⭐⭐⭐${NC} │ 最后支持NPAPI的官方版      ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${GREEN}[B]${NC}  │ Pale Moon + Java        │ ${GREEN}⭐⭐⭐⭐${NC}   │ 官方持续支持NPAPI/Java    ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${YELLOW}[C]${NC}  │ SeaMonkey 2.49.5 + Java │ ${YELLOW}⭐⭐${NC}       │ 2.49.5旧版, 2.53+已无Java ${BOLD}│${NC}"
    echo -e "${BOLD}│${NC} ${CYAN}[D]${NC}  │ 仅安装Java环境         │ ${CYAN}⭐⭐${NC}       │ 已有合适浏览器             ${BOLD}│${NC}"
    echo -e "${BOLD}└──────┴────────────────────────┴──────────┴────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${GREEN}[A]${NC} Firefox 52.9.0 ESR + Oracle JRE/OpenJDK 8  ${GREEN}强烈推荐${NC}"
    echo -e "  ${GREEN}[B]${NC} Pale Moon官方仍完整支持NPAPI和Java (https://www.palemoon.org/technical.shtml，仅x86_64)"
    echo -e "  ${YELLOW}[C]${NC} SeaMonkey必须锁定2.49.5版本(2.53+官方RN明确移除全部NPAPI含Java)"
    echo -e "  ${CYAN}[D]${NC} 已有浏览器，仅需安装Java环境"
    echo ""
    echo -e "  ${GREEN}${BOLD}💡 推荐方案A + OpenJDK 8 + IcedTea (包管理器一键安装)${NC}"
}

# ==================== Java环境主入口 ====================
install_java() {
    header "安装Java运行环境"

    if [[ "$HAS_JRE" == "true" ]]; then
        log "已安装Java: ${JRE_VERSION}"
        read -p "是否重新安装? [y/N]: " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            return 0
        fi
    fi

    echo -e "${BOLD}Java运行环境选择:${NC}"
    echo ""
    echo -e "  ${GREEN}── Oracle JRE (手动下载，兼容性最好) ──${NC}"
    echo "  [1] Oracle JRE 8"
    echo "  [2] Oracle JRE 7"
    echo "  [3] Oracle JRE 6u7 (最低要求)"
    echo ""
    echo -e "  ${CYAN}── OpenJDK (包管理器自动安装，更便捷) ──${NC}"
    echo "  [4] OpenJDK 8 + IcedTea插件 (${GREEN}推荐${NC}，一键安装，完整支持Applet)"
    echo ""
    echo "  [5] 跳过，手动配置"
    echo ""
    echo -e "  ${YELLOW}说明: Oracle JRE需手动下载; OpenJDK 8 + IcedTea通过包管理器一键安装${NC}"
    echo -e "  ${YELLOW}      IcedTea-Web需要Java 8运行时(OpenJDK 11/17不支持Applet)${NC}"
    echo ""
    read -p "选择 [1/2/3/4/5] (默认4): " java_choice
    java_choice=${java_choice:-4}

    case "$java_choice" in
        1) install_oracle_jre "8" ;;
        2) install_oracle_jre "7" ;;
        3) install_oracle_jre "6u7" ;;
        4) install_openjdk "8" ;;
        5) return 0 ;;
        *) err "无效选择"; return 1 ;;
    esac
}

# ==================== 安装Oracle JRE ====================
install_oracle_jre() {
    local ver="$1"
    local JRE_INSTALL_DIR="/opt/jre"
    local JRE_DESC=""

    case "$ver" in
        8)    JRE_DESC="jre-8u*-linux-*.tar.gz" ;;
        7)    JRE_DESC="jre-7u*-linux-*.tar.gz" ;;
        6u7)  JRE_DESC="jre-6u7-linux-*.bin" ;;
    esac

    echo ""
    echo -e "${YELLOW}下载Oracle JRE ${ver}:${NC}"
    echo -e "  地址: ${BOLD}https://www.oracle.com/java/technologies/javase-downloads.html${NC}"
    echo -e "  归档: ${BOLD}https://www.oracle.com/java/technologies/oracle-java-archive-downloads.html${NC}"
    echo -e "  文件: ${BOLD}${JRE_DESC}${NC}"
    echo -e "  放入: ${BOLD}/tmp/${NC}"
    echo ""
    read -p "下载完成后按回车 (输入q跳过): " skip
    if [[ "$skip" == "q" ]]; then
        return 0
    fi

    JRE_FILE=""
    for f in /tmp/jre-*.tar.gz /tmp/jre-*.bin; do
        if [[ -f "$f" ]]; then JRE_FILE="$f"; break; fi
    done
    if [[ -z "$JRE_FILE" ]]; then
        read -p "请输入JRE文件路径: " JRE_FILE
    fi
    if [[ ! -f "$JRE_FILE" ]]; then
        err "文件不存在: ${JRE_FILE}"; return 1
    fi
    # FIX-11: 转为绝对路径，确保sudo可直接执行
    JRE_FILE=$(readlink -f "$JRE_FILE")

    log "安装Oracle JRE: ${JRE_FILE}"
    $SUDO mkdir -p "$JRE_INSTALL_DIR"
    if [[ "$JRE_FILE" == *.tar.gz ]]; then
        $SUDO tar xzf "$JRE_FILE" -C "$JRE_INSTALL_DIR" --strip-components=1 || { err "JRE解压失败"; return 1; }
    elif [[ "$JRE_FILE" == *.bin ]]; then
        # FIX-11: 使用绝对路径直接执行(.bin为自解压脚本)，解压产物落在/tmp
        ( cd /tmp && $SUDO chmod +x "$JRE_FILE" && $SUDO "$JRE_FILE" ) || { err "JRE .bin安装失败"; return 1; }
        # FIX-12: 将解压出的jre1.x目录整体作为安装目录，避免嵌套导致验证失败
        EXTRACTED_DIR=$(ls -d /tmp/jre1.* 2>/dev/null | head -n1 || true)
        if [[ -n "$EXTRACTED_DIR" ]]; then
            $SUDO rm -rf "$JRE_INSTALL_DIR"
            $SUDO mv "$EXTRACTED_DIR" "$JRE_INSTALL_DIR" || { err "JRE目录移动失败"; return 1; }
        fi
    fi

    set_java_env "$JRE_INSTALL_DIR"
    "$JRE_INSTALL_DIR/bin/java" -version 2>&1 && log "✅ Oracle JRE ${ver}安装成功" || { err "安装验证失败"; return 1; }
    HAS_JRE=true
    JAVA_TYPE="oracle"
    configure_java_plugin
}

# ==================== 安装OpenJDK 8 + IcedTea ====================
install_openjdk() {
    local ver="$1"
    local PKG_NAME="openjdk-8-jre"
    local PLUGIN_PKG="icedtea-8-plugin"

    echo ""
    log "通过包管理器安装 OpenJDK 8 + IcedTea插件..."

    if [[ "$PKG_MGR" == "apt" ]]; then
        # FIX-20: update失败不应终止(可使用现有索引)
        $SUDO apt-get update -qq || warn "apt-get update失败，尝试使用现有软件源索引继续..."
        $SUDO apt-get install -y -qq "$PKG_NAME" "$PLUGIN_PKG" 2>/dev/null || {
            warn "icedtea-8-plugin包不可用，尝试替代方案..."
            $SUDO apt-get install -y -qq "$PKG_NAME" icedtea-web 2>/dev/null || {
                $SUDO apt-get install -y -qq "$PKG_NAME" icedtea-plugin 2>/dev/null || {
                    err "OpenJDK 8 安装失败，请检查软件源是否包含openjdk-8-jre"
                    err "  或手动添加: ppa:openjdk-r/ppa"
                    return 1
                }
            }
        }
    elif [[ "$PKG_MGR" == "yum" ]]; then
        $SUDO yum install -y "java-1.8.0-openjdk" "icedtea-web" 2>/dev/null || {
            $SUDO yum install -y "java-1.8.0-openjdk" 2>/dev/null || {
                err "OpenJDK 8 安装失败"
                return 1
            }
        }
    fi

    JAVA_HOME_DIR=""
    for d in /usr/lib/jvm/java-8-openjdk-* /usr/lib/jvm/java-1.8.0-openjdk-* /usr/lib/jvm/java-8-openjdk /usr/lib/jvm/jre-8-openjdk; do
        if [[ -d "$d" ]]; then JAVA_HOME_DIR="$d"; break; fi
    done
    if [[ -z "$JAVA_HOME_DIR" ]]; then
        JAVA_BIN=$(command -v java 2>/dev/null || true)
        if [[ -n "$JAVA_BIN" ]]; then
            JAVA_HOME_DIR=$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")
        fi
    fi

    if [[ -z "$JAVA_HOME_DIR" ]]; then
        err "无法定位OpenJDK安装路径"
        return 1
    fi

    set_java_env "$JAVA_HOME_DIR"
    java -version 2>&1 && log "✅ OpenJDK 8安装成功" || { err "安装验证失败"; return 1; }
    HAS_JRE=true
    JAVA_TYPE="openjdk"
    configure_icedtea_plugin
}

# ==================== 设置Java环境变量 ====================
set_java_env() {
    local java_dir="$1"
    $SUDO tee /etc/profile.d/java.sh > /dev/null << EOF
export JAVA_HOME=${java_dir}
export PATH=\${JAVA_HOME}/bin:\${PATH}
EOF
    $SUDO chmod 644 /etc/profile.d/java.sh
    export JAVA_HOME="$java_dir" PATH="${java_dir}/bin:${PATH}"
    log "Java路径: ${java_dir}"
}

# ==================== 配置IcedTea浏览器插件 ====================
configure_icedtea_plugin() {
    header "配置IcedTea浏览器插件"

    PLUGIN_SO=""
    for d in \
        /usr/lib/icedtea-web \
        /usr/lib64/icedtea-web \
        /usr/lib/IcedTeaPlugin.so \
        /usr/lib/mozilla/plugins \
        /usr/lib/jvm/java-8-openjdk-*/jre/lib/*/ \
        /usr/lib/jvm/java-1.8.0-openjdk-*/jre/lib/*/ \
        /usr/lib/jvm/openjdk-8/jre/lib/*/ \
        /usr/lib/jvm/*/jre/lib/*/; do
        for f in IcedTeaPlugin.so libjavaplugin.so libnpjp2.so; do
            if [[ -f "${d}/${f}" ]]; then PLUGIN_SO="${d}/${f}"; break 2; fi
        done
    done

    if [[ -z "$PLUGIN_SO" ]]; then
        # FIX-21: Java本体已安装成功，插件缺失不应终止整个流程
        warn "未找到IcedTea插件文件，Java已装好，可稍后手动补装插件"
        echo -e "  ${YELLOW}手动安装:${NC}"
        echo -e "    sudo apt-get install icedtea-8-plugin  # Debian系"
        echo -e "    sudo yum install icedtea-web            # RedHat系"
        echo -e "  ${YELLOW}插件路径探测:${NC} find /usr -name '*IcedTea*' -o -name '*javaplugin*'"
        return 0
    fi

    for d in ~/.mozilla/plugins /usr/lib/mozilla/plugins /usr/lib64/mozilla/plugins; do
        $SUDO mkdir -p "$d" 2>/dev/null
        $SUDO ln -sf "$PLUGIN_SO" "$d/IcedTeaPlugin.so" 2>/dev/null
        $SUDO ln -sf "$PLUGIN_SO" "$d/libnpjp2.so" 2>/dev/null
    done
    log "✅ IcedTea插件配置完成: ${PLUGIN_SO}"
}

# ==================== 配置Oracle Java浏览器插件 ====================
configure_java_plugin() {
    header "配置Java浏览器插件"
    [[ "$HAS_JRE" != "true" ]] && { warn "未安装JRE"; return 0; }

    PLUGIN_SO=""
    for d in "${JAVA_HOME:-/opt/jre}" "${JRE_INSTALL_DIR:-/opt/jre}"; do
        for p in lib/i386 lib/amd64 lib; do
            if [[ -f "${d}/${p}/libnpjp2.so" ]]; then PLUGIN_SO="${d}/${p}/libnpjp2.so"; break 2; fi
        done
    done

    if [[ -z "$PLUGIN_SO" ]]; then
        warn "未找到libnpjp2.so (JRE 9+已移除NPAPI，请使用JRE 8或更低)"
        return 1
    fi

    for d in ~/.mozilla/plugins /usr/lib/mozilla/plugins /usr/lib64/mozilla/plugins; do
        $SUDO mkdir -p "$d" 2>/dev/null
        $SUDO ln -sf "$PLUGIN_SO" "$d/libnpjp2.so" 2>/dev/null
    done
    log "✅ Java插件配置完成: ${PLUGIN_SO}"
}

# ==================== Java控制面板 ====================
configure_java_control_panel() {
    header "配置Java控制面板"
    [[ "$HAS_JRE" != "true" ]] && return 0

    # FIX-15: sudo运行时$HOME为/root，必须定位真实桌面用户的家目录
    REAL_USER="${SUDO_USER:-$(id -un)}"
    if [[ "$REAL_USER" == "root" ]]; then
        USER_HOME="$HOME"
    else
        USER_HOME=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)
        [[ -z "$USER_HOME" ]] && USER_HOME="$HOME"
    fi
    if [[ "${JAVA_TYPE:-oracle}" == "openjdk" ]]; then
        info "IcedTea-Web通常无需站点例外，如遇安全提示可同样配置"
    fi

    echo -e "${BOLD}JRE 7/8 需要添加Oracle EBS站点例外 (用户: ${REAL_USER}):${NC}"
    echo -e "  ${GREEN}方法一:${NC} 运行 ControlPanel → 安全 → 编辑站点列表"
    echo -e "  ${GREEN}方法二:${NC} 自动配置(推荐)"
    echo ""
    read -p "是否自动配置? [Y/n]: " ans
    ans=${ans:-Y}

    if [[ "$ans" == "Y" || "$ans" == "y" ]]; then
        read -p "请输入Oracle EBS地址 (如 https://ebs.example.com): " EBS_URL
        if [[ -n "$EBS_URL" ]]; then
            DEPLOY_DIR="${USER_HOME}/.java/deployment"
            $SUDO mkdir -p "$DEPLOY_DIR"
            echo "$EBS_URL" | $SUDO tee -a "$DEPLOY_DIR/exception.sites" > /dev/null
            # FIX-14: 正确文件名为deployment.properties (v3.0误写为deployment.security，配置无效)
            printf '%s\n' \
                "deployment.security.level=MEDIUM" \
                "deployment.security.sandbox.aws.warning.level=allow_unsigned" \
                | $SUDO tee "$DEPLOY_DIR/deployment.properties" > /dev/null
            if [[ "$REAL_USER" != "root" ]]; then
                $SUDO chown -R "${REAL_USER}:" "$DEPLOY_DIR" 2>/dev/null || true
            fi
            log "✅ 已添加站点例外: ${EBS_URL} (用户: ${REAL_USER})"
            log "   配置文件: ${DEPLOY_DIR}/exception.sites + deployment.properties"
            if [[ "${JAVA_TYPE:-oracle}" == "oracle" ]]; then
                info "注意: JRE 8u60+已废弃MEDIUM级别，站点例外(exception.sites)仍必需"
            fi
        fi
    fi
}

# ==================== 生成启动器 ====================
create_launcher() {
    header "生成启动器"

    cat > "${WORK_DIR}/oracle-ebs.sh" << 'LAUNCH'
#!/bin/bash
WORK_DIR="/opt/oracle-ebs"
echo "=== Oracle EBS 启动器 ==="
echo ""
ls -1 "${WORK_DIR}"/start-*.sh 2>/dev/null | while read f; do
    echo "  - $(basename "$f")"
done
echo ""
read -p "输入启动脚本名: " script
[[ -n "$script" && -f "${WORK_DIR}/${script}" ]] && bash "${WORK_DIR}/${script}"
LAUNCH
    $SUDO chmod +x "${WORK_DIR}/oracle-ebs.sh"

    if [[ -d /usr/share/applications ]]; then
        cat > /tmp/oracle-ebs.desktop << EOF
[Desktop Entry]
Name=Oracle EBS
Comment=Oracle EBS兼容方案
Exec=bash ${WORK_DIR}/oracle-ebs.sh
Icon=applications-internet
Terminal=true
Type=Application
Categories=Network;
EOF
        $SUDO cp /tmp/oracle-ebs.desktop /usr/share/applications/ 2>/dev/null
        rm -f /tmp/oracle-ebs.desktop
        log "✅ 桌面快捷方式已创建"
    fi
    log "✅ 启动器: ${WORK_DIR}/oracle-ebs.sh"
}

# ============================================================
#                    ARM64 方案区
# ============================================================

arm_plan_a() {
    header "ARM方案A: QEMU全系统虚拟机"
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get update -qq || true
        $SUDO apt-get install -y -qq qemu-system-x86 qemu-utils wget || { err "QEMU安装失败"; return 1; }
    else
        $SUDO yum install -y qemu-system-x86 qemu-img wget || { err "QEMU安装失败"; return 1; }
    fi
    $SUDO mkdir -p "${WORK_DIR}/vm"
    VM_DIR="${WORK_DIR}/vm"

    [[ ! -f "${VM_DIR}/disk.qcow2" ]] && $SUDO qemu-img create -f qcow2 "${VM_DIR}/disk.qcow2" 8G

    # FIX-24: VM内存按主机内存等级自适应
    VM_MEM=2048
    [[ "$MEM_LEVEL" == "low" ]] && VM_MEM=1024
    [[ "$MEM_LEVEL" == "high" ]] && VM_MEM=4096

    cat > "${WORK_DIR}/start-vm.sh" << VMEOF
#!/bin/bash
WORK_DIR="${WORK_DIR}"; VM_DIR="\${WORK_DIR}/vm"
KVM_OPT=""; [[ -e /dev/kvm ]] && KVM_OPT="-enable-kvm"
qemu-system-x86_64 \${KVM_OPT} -m ${VM_MEM} -smp 2 -cpu qemu64 \\
    -drive file="\${VM_DIR}/disk.qcow2",format=qcow2 \\
    -net nic -net user -display gtk \\
    -name "Oracle EBS" &>/dev/null &
echo "虚拟机已启动(PID:\$!) 内存:${VM_MEM}MB"
echo "在VM中安装: Firefox 52 ESR + Java 8"
VMEOF
    $SUDO chmod +x "${WORK_DIR}/start-vm.sh"

    # FIX-22: 修正错误指引(仓库firefox-esr为78+无NPAPI；java -jar不能装tar.gz)
    cat > "${WORK_DIR}/vm-guide.txt" << 'GUIDE'
=== 虚拟机内部配置 ===
1. 安装Firefox 52 ESR (注意: Debian仓库的firefox-esr是78+，已无NPAPI，必须用52 ESR二进制):
   # 32位VM系统:
   wget -O /tmp/ff52.tar.bz2 https://ftp.mozilla.org/pub/firefox/releases/52.9.0esr/linux-i686/zh-CN/firefox-52.9.0esr.tar.bz2
   # 64位VM系统改用: .../linux-x86_64/zh-CN/firefox-52.9.0esr.tar.bz2
   sudo mkdir -p /opt/firefox52
   sudo tar xjf /tmp/ff52.tar.bz2 -C /opt/firefox52 --strip-components=1
   sudo ln -sf /opt/firefox52/firefox /usr/local/bin/firefox
2. 安装Java (二选一):
   a) OpenJDK 8 (推荐): sudo apt-get install openjdk-8-jre icedtea-8-plugin
   b) Oracle JRE 8: 手动下载jre-8u*-linux-i586.tar.gz到/tmp
      sudo mkdir -p /opt/jre && sudo tar xzf /tmp/jre-*.tar.gz -C /opt/jre --strip-components=1
3. Oracle JRE 7/8: ControlPanel → 安全 → 添加EBS站点例外
   (配置文件: ~/.java/deployment/exception.sites + deployment.properties)
4. 访问EBS: firefox https://your-ebs-server
GUIDE

    log "✅ ARM方案A配置完成"
    echo -e "  启动: ${BOLD}bash ${WORK_DIR}/start-vm.sh${NC}"
    echo -e "  VM指南: ${BOLD}${WORK_DIR}/vm-guide.txt${NC}"
}

arm_plan_b() {
    header "ARM方案B: QEMU用户模式+proot"
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get update -qq || true
        $SUDO apt-get install -y -qq qemu-user-static proot debootstrap || { err "依赖安装失败"; return 1; }
    else
        $SUDO yum install -y qemu-user-static proot debootstrap || { err "依赖安装失败"; return 1; }
    fi

    $SUDO mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true
    echo ':qemu-x86_64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-x86_64-static:' | $SUDO tee /proc/sys/fs/binfmt_misc/register 2>/dev/null || true

    CHROOT_DIR="${WORK_DIR}/chroot"
    $SUDO mkdir -p "$CHROOT_DIR"

    if [[ ! -f "${CHROOT_DIR}/etc/os-release" ]]; then
        log "创建x86_64根文件系统(debootstrap)..."
        $SUDO debootstrap --arch=amd64 bullseye "$CHROOT_DIR" http://deb.debian.org/debian/ || {
            warn "debootstrap失败，请检查网络"; return 1
        }
    fi
    $SUDO cp /usr/bin/qemu-x86_64-static "${CHROOT_DIR}/usr/bin/" 2>/dev/null || true

    # FIX-22: chroot内仓库firefox-esr为78+无NPAPI，指引必须用FF52二进制
    cat > "${WORK_DIR}/enter-chroot.sh" << CHRTEOF
#!/bin/bash
proot -R "${CHROOT_DIR}" -b /proc -b /sys -b /dev -b /tmp/.X11-unix:/tmp/.X11-unix -w /root /bin/bash -c "
    export DISPLAY=\${DISPLAY:-:0}
    echo '=== x86_64 chroot环境 ==='
    echo 'Java: apt-get install openjdk-8-jre icedtea-8-plugin'
    echo '浏览器必须用Firefox 52 ESR二进制(仓库firefox-esr≥60无NPAPI):'
    echo '  wget -O /tmp/ff52.tar.bz2 https://ftp.mozilla.org/pub/firefox/releases/52.9.0esr/linux-x86_64/zh-CN/firefox-52.9.0esr.tar.bz2'
    echo '  mkdir -p /opt/firefox52 && tar xjf /tmp/ff52.tar.bz2 -C /opt/firefox52 --strip-components=1'
    exec /bin/bash
"
CHRTEOF
    $SUDO chmod +x "${WORK_DIR}/enter-chroot.sh"

    log "✅ ARM方案B配置完成"
    echo -e "  进入: ${BOLD}bash ${WORK_DIR}/enter-chroot.sh${NC}"
}

arm_plan_c() {
    header "ARM方案C: Box64+Wine"
    # FIX-25: 编译依赖和Wine按PKG_MGR分支
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get install -y -qq build-essential cmake git || { err "编译依赖安装失败"; return 1; }
    else
        $SUDO yum install -y gcc gcc-c++ make cmake git wget || { err "编译依赖安装失败"; return 1; }
    fi
    log "编译Box64..."
    ( cd /tmp && [[ -d box64 ]] && rm -rf box64
      git clone https://github.com/ptitSeb/box64.git || { err "git clone 失败，请检查网络"; exit 1; }
      cd box64 && mkdir -p build && cd build \
      && cmake .. -DARM_DYNAREC=ON && make -j"$(nproc)" ) || { err "Box64编译失败"; return 1; }
    ( cd /tmp/box64/build && $SUDO make install ) || { err "Box64安装失败"; return 1; }
    $SUDO rm -rf /tmp/box64
    log "安装Wine..."
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get install -y -qq wine wine64 2>/dev/null || warn "Wine安装失败，请手动安装"
    else
        $SUDO yum install -y wine 2>/dev/null || warn "Wine安装失败，请手动安装"
    fi

    cat > "${WORK_DIR}/start-box64-wine.sh" << 'BWEOF'
#!/bin/bash
echo "初始化Wine..."; box64 wine wineboot --init
echo "请下载Windows版JRE并用Wine安装"
echo "运行: box64 wine firefox"
BWEOF
    $SUDO chmod +x "${WORK_DIR}/start-box64-wine.sh"
    log "✅ ARM方案C配置完成"
}

arm_plan_d() {
    header "ARM方案D: Docker+QEMU"
    command -v docker &>/dev/null || {
        if [[ "$PKG_MGR" == "apt" ]]; then $SUDO apt-get install -y -qq docker.io || { err "Docker安装失败"; return 1; }
        else $SUDO yum install -y docker || { err "Docker安装失败"; return 1; }
        fi
        $SUDO systemctl start docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true
    }
    $SUDO docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true

    DOCKER_DIR="${WORK_DIR}/docker"
    $SUDO mkdir -p "$DOCKER_DIR"
    # FIX-22: 基础镜像改为buster(i386有openjdk-8)，浏览器必须用FF52二进制
    #        (bullseye的firefox-esr为78+无NPAPI；bullseye i386无openjdk-8)
    cat > "${DOCKER_DIR}/Dockerfile" << 'DEOF'
FROM i386/debian:buster-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends wget bzip2 ca-certificates libgtk2.0-0 libdbus-glib-1-2 libxt6 libasound2 \
 && (apt-get install -y --no-install-recommends openjdk-8-jre icedtea-8-plugin \
     || apt-get install -y --no-install-recommends openjdk-8-jre icedtea-plugin) \
 && wget -qO /tmp/ff52.tar.bz2 https://ftp.mozilla.org/pub/firefox/releases/52.9.0esr/linux-i686/zh-CN/firefox-52.9.0esr.tar.bz2 \
 && mkdir -p /opt/firefox52 \
 && tar xjf /tmp/ff52.tar.bz2 -C /opt/firefox52 --strip-components=1 \
 && ln -sf /opt/firefox52/firefox /usr/local/bin/firefox \
 && rm -f /tmp/ff52.tar.bz2 && rm -rf /var/lib/apt/lists/*
ENV DISPLAY=:0
CMD ["firefox"]
DEOF
    cat > "${DOCKER_DIR}/run.sh" << 'DREOF'
#!/bin/bash
xhost +local:docker 2>/dev/null
docker build -t oracle-ebs /opt/oracle-ebs/docker
docker run -it --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix oracle-ebs
DREOF
    $SUDO chmod +x "${DOCKER_DIR}/run.sh"
    log "✅ ARM方案D配置完成"
    echo -e "  运行: ${BOLD}bash ${DOCKER_DIR}/run.sh${NC}"
}

arm_plan_e() {
    header "ARM方案E: Box86+JRE"
    # FIX-25: 编译依赖按PKG_MGR分支
    if [[ "$PKG_MGR" == "apt" ]]; then
        $SUDO apt-get install -y -qq build-essential cmake git || { err "编译依赖安装失败"; return 1; }
    else
        $SUDO yum install -y gcc gcc-c++ make cmake git wget || { err "编译依赖安装失败"; return 1; }
    fi
    ( cd /tmp && [[ -d box86 ]] && rm -rf box86
      git clone https://github.com/ptitSeb/box86.git || { err "git clone 失败，请检查网络"; exit 1; }
      cd box86 && mkdir -p build && cd build \
      && cmake .. -DARM_DYNAREC=ON && make -j"$(nproc)" ) || { err "Box86编译失败"; return 1; }
    ( cd /tmp/box86/build && $SUDO make install ) || { err "Box86安装失败"; return 1; }
    $SUDO rm -rf /tmp/box86

    cat > "${WORK_DIR}/start-box86.sh" << 'B8EOF'
#!/bin/bash
echo "请下载x86 JRE 8并安装"
echo "测试: box86 /opt/jre/bin/java -version"
echo "运行: box86 palemoon"
B8EOF
    $SUDO chmod +x "${WORK_DIR}/start-box86.sh"
    log "✅ ARM方案E配置完成"
}

# ============================================================
#                    X86/C86 方案区
# ============================================================

x86_plan_a() {
    header "X86方案A: Firefox 52 ESR + Java (NPAPI支持)"
    ARCH_SUF="x86_64"; [[ "$IS_64BIT" == "false" ]] && ARCH_SUF="i686"
    log "下载Firefox 52 ESR (最后支持NPAPI的官方版本)..."
    $SUDO wget -q --timeout=60 -O /tmp/ff52.tar.bz2 "https://ftp.mozilla.org/pub/firefox/releases/52.9.0esr/linux-${ARCH_SUF}/zh-CN/firefox-52.9.0esr.tar.bz2" || {
        err "Firefox 52 ESR下载失败，请检查网络"
        return 1
    }
    [[ -s /tmp/ff52.tar.bz2 ]] || { err "下载文件为空，请检查网络"; return 1; }
    $SUDO mkdir -p /opt/firefox-52 && $SUDO tar xjf /tmp/ff52.tar.bz2 -C /opt/firefox-52 --strip-components=1 || { err "Firefox解压失败"; return 1; }
    $SUDO ln -sf /opt/firefox-52/firefox /usr/local/bin/firefox-52

    install_java
    configure_java_control_panel

    # FIX-13: export拆为两行(单行export时${JAVA_HOME}在赋值前展开，PATH不含java)
    cat > "${WORK_DIR}/start-firefox.sh" << 'FF'
#!/bin/bash
export JAVA_HOME="${JAVA_HOME:-/opt/jre}"
export PATH="${JAVA_HOME}/bin:${PATH}"
FFOX=$(command -v firefox-52 || echo "/opt/firefox-52/firefox")
echo "Firefox: $("$FFOX" --version 2>/dev/null)"
echo "Java: $(java -version 2>&1 | head -1)"
exec "$FFOX" "$@"
FF
    $SUDO chmod +x "${WORK_DIR}/start-firefox.sh"
    log "✅ X86方案A配置完成"
    echo -e "  启动: ${BOLD}bash ${WORK_DIR}/start-firefox.sh${NC}"
}

x86_plan_b() {
    header "X86方案B: Pale Moon + Java (NPAPI完整支持)"
    # FIX-18: 原镜像rm-kr02已失效，改用官网download.php镜像入口(US+EU双兜底，官网持久可更新)
    #        Pale Moon 34+ 仅提供x86_64构建
    if [[ "$IS_64BIT" != "true" ]]; then
        warn "Pale Moon 34+官方不再提供Linux 32位构建"
        echo -e "  ${YELLOW}请改用方案A/C，或从以下页面获取社区构建:${NC}"
        echo -e "  ${BOLD}https://www.palemoon.org/download.shtml${NC}"
        install_java
        configure_java_control_panel
        log "已跳过浏览器下载，仅完成Java配置"
        return 0
    fi
    PM_US="https://www.palemoon.org/download.php?mirror=us&bits=64&type=linuxgtk3"
    PM_EU="https://www.palemoon.org/download.php?mirror=eu&bits=64&type=linuxgtk3"
    log "下载Pale Moon Linux (官方入口US/EU双镜像)..."
    PM_OK=false
    for pmurl in "$PM_US" "$PM_EU"; do
        $SUDO wget -q --timeout=60 -O /tmp/palemoon.tar.xz "$pmurl" || {
            warn "镜像失败，切换下一个: ${pmurl}"
            continue
        }
        if [[ -s /tmp/palemoon.tar.xz ]]; then PM_OK=true; break; fi
        warn "下载为空，切换镜像重试"
    done
    if [[ "$PM_OK" != "true" ]]; then
        err "Pale Moon下载失败(所有镜像不可达)"
        echo -e "  ${YELLOW}请手动下载GTK3版: ${BOLD}https://www.palemoon.org/download.shtml${NC}"
        echo -e "  ${YELLOW}手动安装: sudo mkdir -p /opt/palemoon && sudo tar xJf palemoon-*.tar.xz -C /opt/palemoon --strip-components=1${NC}"
        return 1
    fi
    [[ -s /tmp/palemoon.tar.xz ]] || { err "下载文件为空，请检查网络"; return 1; }
    $SUDO mkdir -p /opt/palemoon && $SUDO tar xJf /tmp/palemoon.tar.xz -C /opt/palemoon --strip-components=1 || { err "Pale Moon解压失败"; return 1; }
    $SUDO ln -sf /opt/palemoon/palemoon /usr/local/bin/palemoon
    install_java
    configure_java_control_panel

    # FIX-13: export拆为两行
    cat > "${WORK_DIR}/start-palemoon.sh" << 'PM'
#!/bin/bash
export JAVA_HOME="${JAVA_HOME:-/opt/jre}"
export PATH="${JAVA_HOME}/bin:${PATH}"
exec /opt/palemoon/palemoon "$@"
PM
    $SUDO chmod +x "${WORK_DIR}/start-palemoon.sh"
    log "✅ X86方案B配置完成"
    echo -e "  启动: ${BOLD}bash ${WORK_DIR}/start-palemoon.sh${NC}"
}

x86_plan_c() {
    # FIX-26: SeaMonkey 2.53+官方RN明确移除全部NPAPI(2.53.5.1/2.53.18/2.53.24均如此)
    #         Java NPAPI最后可用版本为2.49.5 (legacy页面: seamonkey-project.org/releases/legacy)
    #         2.49.5文件名格式: seamonkey-2.49.5.tar.bz2 (无.zh-CN段)
    header "X86方案C: SeaMonkey 2.49.5 + Java (NPAPI支持，已锁定版本)"
    warn "SeaMonkey 2.53+已全部移除Java NPAPI！请不要升级浏览器，否则Java Applet将不可用"
    info "证据: https://www.seamonkey-project.org/releases/seamonkey2.53.18/ 「Support for all NPAPI plugins like Flash, Java and Silverlight has been removed」"
    ARCH_SUF="x86_64"; [[ "$IS_64BIT" == "false" ]] && ARCH_SUF="i686"
    log "下载SeaMonkey 2.49.5 (最后支持Java NPAPI的官方版本)..."
    $SUDO wget -q --timeout=60 -O /tmp/seamonkey.tar.bz2 \
        "https://archive.mozilla.org/pub/seamonkey/releases/2.49.5/linux-${ARCH_SUF}/zh-CN/seamonkey-2.49.5.tar.bz2" || {
        err "SeaMonkey 2.49.5下载失败，请检查网络"
        return 1
    }
    [[ -s /tmp/seamonkey.tar.bz2 ]] || { err "下载文件为空，请检查网络"; return 1; }
    $SUDO mkdir -p /opt/seamonkey && $SUDO tar xjf /tmp/seamonkey.tar.bz2 -C /opt/seamonkey --strip-components=1 || { err "SeaMonkey解压失败"; return 1; }
    $SUDO ln -sf /opt/seamonkey/seamonkey /usr/local/bin/seamonkey
    # 防止自动升级到2.53+导致NPAPI丢失（2.49.5默认配置app.update.enabled=false一般关闭，但此处再加固）
    PROFILE_BASE="${HOME}/.mozilla/seamonkey"
    [[ -d "$PROFILE_BASE" ]] && find "$PROFILE_BASE" -maxdepth 2 \( -name "user.js" -o -name "prefs.js" \) 2>/dev/null | while read -r f; do
        grep -q "app.update.enabled" "$f" 2>/dev/null || echo 'user_pref("app.update.enabled", false);' > "$f"
    done
    install_java
    configure_java_control_panel

    # FIX-13: export拆为两行
    cat > "${WORK_DIR}/start-seamonkey.sh" << 'SM'
#!/bin/bash
export JAVA_HOME="${JAVA_HOME:-/opt/jre}"
export PATH="${JAVA_HOME}/bin:${PATH}"
exec /opt/seamonkey/seamonkey "$@"
SM
    $SUDO chmod +x "${WORK_DIR}/start-seamonkey.sh"
    warn "SeaMonkey 2.49.5为旧版，请禁用自动升级，以免被升级到2.53+丢失Java NPAPI"
    log "✅ X86方案C配置完成（SeaMonkey 2.49.5）"
    echo -e "  启动: ${BOLD}bash ${WORK_DIR}/start-seamonkey.sh${NC}"
}

x86_plan_d() {
    header "X86方案D: 仅安装Java环境"
    install_java
    configure_java_control_panel
    log "✅ X86方案D配置完成"
    echo -e "  Java路径: ${BOLD}${JAVA_HOME:-/opt/jre}${NC}"
    if [[ "${JAVA_TYPE:-oracle}" == "openjdk" ]]; then
        echo -e "  插件: ${BOLD}IcedTeaPlugin.so${NC} (已自动链接到浏览器插件目录)"
    else
        echo -e "  插件路径: ${BOLD}${JAVA_HOME:-/opt/jre}/lib/*/libnpjp2.so${NC}"
    fi
}

# ==================== 主流程 ====================
main() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║       Oracle EBS 信创兼容方案 - 一键配置脚本 V${SCRIPT_VERSION}       ║"
    echo "  ║       统一版: 自动检测ARM64/X86，支持Oracle JRE+OpenJDK ║"
    echo "  ║       Firefox 52 ESR/NPAPI + IcedTea 自动安装          ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_root
    detect_system

    $SUDO mkdir -p "$WORK_DIR"
    $SUDO chmod 755 "$WORK_DIR"
    # FIX-16: sudo模式下将WORK_DIR归属当前用户，否则后续cat >写入会被拒(set -e崩溃)
    $SUDO chown "$(id -u):$(id -g)" "$WORK_DIR" 2>/dev/null || true

    show_plans

    echo ""
    if [[ "$ARCH_TYPE" == "arm64" ]]; then
        PLAN_OPTIONS="A/B/C/D/E"
    else
        PLAN_OPTIONS="A/B/C/D"
    fi
    read -p "$(echo -e "${BOLD}请选择方案 [${PLAN_OPTIONS}] (默认A): ${NC}")" CHOICE
    CHOICE=${CHOICE:-A}

    if [[ "$ARCH_TYPE" == "arm64" ]]; then
        case "$CHOICE" in
            A|a) arm_plan_a ;;
            B|b) arm_plan_b ;;
            C|c) arm_plan_c ;;
            D|d) arm_plan_d ;;
            E|e) arm_plan_e ;;
            *) err "无效选择"; exit 1 ;;
        esac
    else
        case "$CHOICE" in
            A|a) x86_plan_a ;;
            B|b) x86_plan_b ;;
            C|c) x86_plan_c ;;
            D|d) x86_plan_d ;;
            *) err "无效选择"; exit 1 ;;
        esac
    fi

    create_launcher

    header "配置完成"
    echo -e "${GREEN}${BOLD}Oracle EBS兼容方案已配置完成！${NC}"
    echo ""
    echo -e "  架构: ${BOLD}${ARCH_TYPE}${NC}"
    echo -e "  目录: ${BOLD}${WORK_DIR}${NC}"
    echo -e "  启动: ${BOLD}${WORK_DIR}/oracle-ebs.sh${NC}"
    echo -e "  日志: ${BOLD}${LOG_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}提示:${NC}"
    echo -e "  ${YELLOW}- Firefox 52 ESR / Pale Moon 仍完整支持NPAPI Java插件${NC}"
    echo -e "  ${YELLOW}- SeaMonkey方案使用2.49.5旧版 (2.53+已移除Java NPAPI，请勿升级)${NC}"
    echo -e "  ${YELLOW}- OpenJDK 8 + IcedTea 自动支持Applet，无需额外配置${NC}"
    echo -e "  ${YELLOW}- Oracle JRE 7/8 需通过 ControlPanel 添加EBS站点例外${NC}"
    echo ""
}
main "$@"
