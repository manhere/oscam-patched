#!/usr/bin/env bash
#
# 构建 OSCam 的 .deb 包。
#
# 目录约定（与 D:\tmp\extra-main\payload\oscam 保持一致）：
#   packaging/deb/payload/lib/systemd/system/oscam.service   -> /lib/systemd/system/oscam.service
#   packaging/deb/payload/usr/local/etc/oscam.*              -> /usr/local/etc/oscam.*
#   <binary>                                                 -> /usr/local/bin/oscam
#
# 用法：
#   bash packaging/deb/build-deb.sh --arch arm64 \
#        --binary artifacts/oscam-linux-arm64/oscam --output release
#
# 可选：
#   --version <ver>        包版本（默认取 UTC 当天日期 YYYYMMDD，与 Release tag 对齐）
#   --maintainer "<who>"   默认 dabing <manhere@gmail.com>
#   --homepage <url>       默认 https://github.com/manhere/oscam-patched
#
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)

PKG_NAME=oscam
ARCH=""
BINARY=""
OUTPUT="dist"
VERSION=""
MAINTAINER="dabing <manhere@gmail.com>"
HOMEPAGE="https://github.com/manhere/oscam-patched"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)       ARCH="${2:-}";       shift 2 ;;
        --binary)     BINARY="${2:-}";     shift 2 ;;
        --output)     OUTPUT="${2:-}";     shift 2 ;;
        --version)    VERSION="${2:-}";    shift 2 ;;
        --maintainer) MAINTAINER="${2:-}"; shift 2 ;;
        --homepage)   HOMEPAGE="${2:-}";   shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "未知参数: $1" >&2; usage >&2; exit 2 ;;
    esac
done

die() { echo "错误: $*" >&2; exit 1; }

[ -n "$ARCH" ]   || die "缺少 --arch（只支持 arm64）"
[ -n "$BINARY" ] || die "缺少 --binary（oscam 可执行文件路径）"
[ -f "$BINARY" ] || die "找不到二进制: $BINARY"

case "$ARCH" in
    arm64) ;;
    *) die "不支持的 --arch: $ARCH（本仓库只发布 arm64）" ;;
esac

if [ -z "$VERSION" ]; then
    VERSION=$(date -u +%Y%m%d)
fi
case "$VERSION" in
    *[!0-9A-Za-z.+~-]*) die "版本号含非法字符: $VERSION" ;;
esac

# ---------------------------------------------------------------------------
# 上游 OSCam 版本（仅用于 description）
# ---------------------------------------------------------------------------
CS_VERSION="unknown"
if [ -f "$REPO_ROOT/globals.h" ]; then
    parsed=$(sed -n 's/^#define[[:space:]][[:space:]]*CS_VERSION[[:space:]][[:space:]]*"\([^"]*\)".*/\1/p' \
        "$REPO_ROOT/globals.h" | head -1)
    [ -n "$parsed" ] && CS_VERSION="$parsed"
fi

COMMIT="unknown"
if [ -d "$REPO_ROOT/.git" ] && command -v git >/dev/null 2>&1; then
    parsed=$(git -C "$REPO_ROOT" rev-parse --short=10 HEAD 2>/dev/null || true)
    [ -n "$parsed" ] && COMMIT="$parsed"
fi

# ---------------------------------------------------------------------------
# 静态链接断言
#
# 本仓库只发布 arm64，且要求全静态（无 NEEDED ⇒ deb 无需任何 Depends）。
# 这里不是可选项检查而是硬断言：上游 CMakeLists.txt 在构建类型分支里
# 整体硬覆盖 CMAKE_EXE_LINKER_FLAGS，会冲掉交叉工具链注入的 "-static"
# （历史上就因此产出过要 GLIBC_2.38 的动态二进制）。一旦那条 sed 补丁
# 失效，这里会立刻拦下来，而不是发一个装不上老盒子的包。
# ---------------------------------------------------------------------------
if command -v readelf >/dev/null 2>&1; then
    needed=$(readelf -d --wide "$BINARY" 2>/dev/null \
        | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort -u || true)
    if [ -n "$needed" ]; then
        echo "检测到动态依赖：" >&2
        printf '  %s\n' $needed >&2
        die "arm64 产物必须是全静态链接，但存在 NEEDED 条目（检查构建期的 -static 是否被 CMakeLists 覆盖）"
    fi
else
    echo "::warning::找不到 readelf，无法断言静态链接" >&2
fi

# ---------------------------------------------------------------------------
# 组装 deb 根目录
# ---------------------------------------------------------------------------
STAGE=$(mktemp -d)
trap 'rm -rf -- "$STAGE" 2>/dev/null || true' EXIT

ROOT="$STAGE/root"
mkdir -p "$ROOT/DEBIAN"

# 1) 静态 payload（systemd 单元 + 默认配置），原样铺开成根文件系统布局
cp -a "$SCRIPT_DIR/payload/." "$ROOT/"

# 1b) Windows 工作区可能带 CRLF；deb 里的配置/单元必须是 LF。
#     必须放在 chmod 之前，也必须放在安装二进制之前：sed -i 会重建文件，
#     把已有权限丢掉，而且绝不能拿去处理二进制。
find "$ROOT" -type f -exec sed -i 's/\r$//' {} +

# 2) 权限：配置文件 0600（与 install.sh 一致），单元文件 0644
chmod 0644 "$ROOT/lib/systemd/system/oscam.service"
for f in oscam.conf oscam.server oscam.user oscam.dvbapi; do
    chmod 0600 "$ROOT/usr/local/etc/$f"
done

# 3) 二进制（install 直接给 0755；二进制不做任何文本处理）
install -d "$ROOT/usr/local/bin"
install -m 0755 "$BINARY" "$ROOT/usr/local/bin/oscam"

# 4) 维护脚本
for s in postinst prerm postrm; do
    src="$SCRIPT_DIR/DEBIAN/$s"
    [ -f "$src" ] || die "缺少维护脚本: $src"
    sed 's/\r$//' "$src" > "$ROOT/DEBIAN/$s"
    chmod 0755 "$ROOT/DEBIAN/$s"
done
sed 's/\r$//' "$SCRIPT_DIR/DEBIAN/conffiles" > "$ROOT/DEBIAN/conffiles"
chmod 0644 "$ROOT/DEBIAN/conffiles"

# 5) Installed-Size（dpkg 的口径就是 KiB，du -sk 直接给 KiB，不要再换算）
#    DEBIAN/ 是控制信息，不计入解包体积。
TREE_KB=$(du -sk "$ROOT" | awk '{print $1}')
CTRL_KB=$(du -sk "$ROOT/DEBIAN" | awk '{print $1}')
INSTALLED_SIZE=$(( TREE_KB - CTRL_KB ))
[ "$INSTALLED_SIZE" -gt 0 ] || INSTALLED_SIZE=1

# 6) control
#
# 全静态产物 -> 不写 Depends 字段（上面已硬断言动态依赖为空）。
{
    echo "Package: $PKG_NAME"
    echo "Version: $VERSION"
    echo "Architecture: $ARCH"
    echo "Maintainer: $MAINTAINER"
    echo "Installed-Size: $INSTALLED_SIZE"
    echo "Section: net"
    echo "Priority: optional"
    echo "Homepage: $HOMEPAGE"
    echo "Description: OSCam softcam for StreamGuard / Tongfang smart cards"
    echo " OSCam is an open source conditional access module (CAM) server."
    echo " ."
    echo " This build targets HiSilicon Hi3798CV200 (DVB-IP1002) set-top boxes"
    echo " with the on-board SCI reader (/dev/ttySCI0) and ships the StreamGuard"
    echo " (4AD2) and Jet (DVN) card systems."
    echo " ."
    echo " The binary is statically linked, so the package has no runtime"
    echo " library dependencies."
    echo " ."
    echo " Upstream version: $CS_VERSION"
    echo " Git commit: $COMMIT"
} > "$ROOT/DEBIAN/control"
chmod 0644 "$ROOT/DEBIAN/control"

# ---------------------------------------------------------------------------
# 打包
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT"
OUT_DEB="$OUTPUT/${PKG_NAME}_${VERSION}_${ARCH}.deb"
rm -f "$OUT_DEB"

dpkg-deb --build --root-owner-group "$ROOT" "$OUT_DEB"

echo "=== control ==="
dpkg-deb -f "$OUT_DEB"
echo
echo "=== 内容 ==="
dpkg-deb -c "$OUT_DEB"
echo
echo "已生成: $OUT_DEB ($(du -h "$OUT_DEB" | awk '{print $1}'))"
