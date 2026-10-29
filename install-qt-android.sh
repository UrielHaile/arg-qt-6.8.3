#!/usr/bin/env bash
# Instala el Qt para Android alineado a 16 KB junto al Qt oficial (macOS/Linux).
#
# Uso:
#   ./install-qt-android.sh <archivo.tar.xz> [<archivo.tar.xz> ...]
#
# Requisitos: tener instalado con el instalador oficial de Qt el mismo Qt
# (6.8.3) para escritorio y para el ABI de Android correspondiente. De ahí se
# toman las herramientas host y los scripts de bin/ ya ajustados a esta máquina.
#
# Resultado (con QT_ROOT=~/Qt):
#   ~/Qt/6.8.3/macos                 Qt oficial de escritorio (sin cambios)
#   ~/Qt/6.8.3/android_arm64_v8a     Qt oficial de Android (sin cambios)
#   ~/Qt/6.8.3-16kb/android_arm64_v8a   este Qt; registrarlo en Qt Creator
set -euo pipefail

QT_VERSION="${QT_VERSION:-6.8.3}"
QT_ROOT="${QT_ROOT:-$HOME/Qt}"

case "$(uname -s)" in
    Darwin) HOST_DIR="${HOST_DIR:-macos}" ;;
    Linux)  HOST_DIR="${HOST_DIR:-gcc_64}" ;;
    *) echo "Sistema no soportado: este script funciona solo en macOS y Linux." >&2; exit 1 ;;
esac

if [ "$#" -eq 0 ]; then
    echo "Uso: $0 <qt-$QT_VERSION-android_<abi>-16kb.tar.xz> [...]" >&2
    exit 1
fi

OFFICIAL="$QT_ROOT/$QT_VERSION"
TARGET_BASE="$QT_ROOT/$QT_VERSION-16kb"
[ -d "$OFFICIAL/$HOST_DIR/bin" ] || {
    echo "No se encontró el Qt oficial de escritorio en $OFFICIAL/$HOST_DIR." >&2
    echo "Instálalo con el instalador de Qt o define QT_ROOT / HOST_DIR." >&2
    exit 1
}

sha256_check() {
    if command -v sha256sum >/dev/null; then sha256sum -c "$1"; else shasum -a 256 -c "$1"; fi
}

mkdir -p "$TARGET_BASE"
for archive in "$@"; do
    abi_dir="$(basename "$archive" | sed -E "s/^qt-$QT_VERSION-(android_[a-z0-9_]+)-16kb\.tar\.xz$/\1/")"
    case "$abi_dir" in android_*) ;; *) echo "Nombre de archivo inesperado: $archive" >&2; exit 1 ;; esac

    if [ -f "$archive.sha256" ]; then
        (cd "$(dirname "$archive")" && sha256_check "$(basename "$archive").sha256")
    else
        echo "Aviso: no se encontró $archive.sha256; no se verificó la integridad." >&2
    fi

    official_bin="$OFFICIAL/$abi_dir/bin"
    [ -d "$official_bin" ] || {
        echo "No se encontró $official_bin." >&2
        echo "Instala el componente oficial de Android para $abi_dir con el instalador de Qt." >&2
        exit 1
    }

    dest="$TARGET_BASE/$abi_dir"
    echo "=== $abi_dir -> $dest"
    rm -rf "$dest"
    tar -C "$TARGET_BASE" -xJf "$archive"

    # bin/: scripts del Qt oficial (ya apuntan a las herramientas de esta
    # máquina) con un target_qt.conf que apunta a este directorio.
    mkdir -p "$dest/bin"
    for script in "$official_bin"/*; do
        case "$(basename "$script")" in
            target_qt.conf*|qt.conf|*.bat) ;;
            *) cp -p "$script" "$dest/bin/" ;;
        esac
    done
    cat > "$dest/bin/target_qt.conf" <<EOF
[Paths]
Prefix=../
Documentation=doc
Headers=include
Libraries=lib
LibraryExecutables=libexec
Binaries=bin
Plugins=plugins
QmlImports=qml
ArchData=.
Data=.
Translations=translations
Examples=examples
Tests=tests
Settings=etc/xdg
HostPrefix=../../../$QT_VERSION/$HOST_DIR
HostBinaries=bin
HostLibraries=lib
HostLibraryExecutables=libexec
HostData=../../$QT_VERSION-16kb/$abi_dir
Sysroot=
SysrootifyPrefix=false
TargetSpec=android-clang
HostSpec=
EOF
    # Este Qt se compiló en otra máquina: la ruta por defecto del Qt de
    # escritorio debe apuntar al de esta (el instalador oficial hace lo mismo).
    host_path="$(cd "$OFFICIAL/$HOST_DIR" && pwd)"
    deps="$dest/lib/cmake/Qt6/Qt6Dependencies.cmake"
    sed -i.bak -E \
        -e "s|^set\(__qt_platform_initial_qt_host_path \"[^\"]*\"\)|set(__qt_platform_initial_qt_host_path \"$host_path\")|" \
        -e "s|^set\(__qt_platform_initial_qt_host_path_cmake_dir \"[^\"]*\"\)|set(__qt_platform_initial_qt_host_path_cmake_dir \"$host_path/lib/cmake\")|" \
        "$deps"
    rm -f "$deps.bak"

    "$dest/bin/qmake" -query QT_VERSION >/dev/null \
        && echo "OK: $dest/bin/qmake -> Qt $("$dest/bin/qmake" -query QT_VERSION)"
done

cat <<EOF

Listo. En Qt Creator:
  1. Preferences > Kits > Qt Versions > Add: $TARGET_BASE/android_arm64_v8a/bin/qmake
     (y lo mismo para android_armv7).
  2. Preferences > Devices > Android: selecciona el NDK 27.2.12479018 (r27c)
     para esta versión de Qt.
  3. Crea un kit "Android Qt $QT_VERSION 16KB" con esa versión de Qt y úsalo
     para compilar los releases.
EOF
