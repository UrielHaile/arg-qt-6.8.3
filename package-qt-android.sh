#!/usr/bin/env bash
# Empaqueta una instalación de Qt para Android generada por build-qt-android.sh.
#
# Uso:
#   ./package-qt-android.sh <abi> [<abi> ...]
#
# Genera dist/qt-<versión>-android_<abi>-16kb.tar.xz y su .sha256. El
# directorio bin/ no se incluye porque contiene rutas absolutas de la máquina
# donde se compiló; install-qt-android.sh lo reconstruye a partir del Qt
# oficial de cada desarrollador.
set -euo pipefail

QT_VERSION="${QT_VERSION:-6.8.3}"
PREFIX_BASE="${PREFIX_BASE:-$HOME/Qt/$QT_VERSION-16kb}"
DIST_DIR="${DIST_DIR:-$PWD/dist}"

if [ "$#" -eq 0 ]; then
    echo "Uso: $0 <abi> [<abi> ...]" >&2
    exit 1
fi

sha256_of() {
    if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi
}

mkdir -p "$DIST_DIR"
for abi in "$@"; do
    abi_dir="android_${abi//-/_}"
    [ "$abi" = "armeabi-v7a" ] && abi_dir="android_armv7"
    [ -d "$PREFIX_BASE/$abi_dir" ] || { echo "No existe: $PREFIX_BASE/$abi_dir" >&2; exit 1; }

    archive="qt-$QT_VERSION-$abi_dir-16kb.tar.xz"
    echo "=== $archive"
    XZ_OPT="${XZ_OPT:--T0 -9}" tar -C "$PREFIX_BASE" --exclude="$abi_dir/bin" -cJf "$DIST_DIR/$archive" "$abi_dir"
    (cd "$DIST_DIR" && sha256_of "$archive" > "$archive.sha256")
done
ls -la "$DIST_DIR"
