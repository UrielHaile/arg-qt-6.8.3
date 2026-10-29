#!/usr/bin/env bash
# Compila Qt 6.8.3 para Android con librerías alineadas a 16 KB
# (requisito de Google Play para apps con targetSdk >= 35).
#
# Uso:
#   ./build-qt-android.sh <abi> [<abi> ...]      # p. ej. arm64-v8a armeabi-v7a
#
# Variables de entorno (con valores por defecto para macOS):
#   QT_VERSION       versión de Qt (6.8.3)
#   ANDROID_SDK      ruta del Android SDK
#   ANDROID_NDK      ruta del NDK (r27c = 27.2.12479018)
#   QT_HOST_PATH     Qt de escritorio de la misma versión (herramientas host)
#   OPENSSL_INCLUDE  headers de OpenSSL 3 de KDAB android_openssl
#   PREFIX_BASE      dónde instalar (se crea <PREFIX_BASE>/android_<abi>)
#   WORK_DIR         fuentes descargadas y árboles de compilación
#   JOBS             trabajos en paralelo
set -euo pipefail

QT_VERSION="${QT_VERSION:-6.8.3}"
QT_MINOR="${QT_VERSION%.*}"
ANDROID_SDK="${ANDROID_SDK:-$HOME/Library/Android/sdk}"
ANDROID_NDK="${ANDROID_NDK:-$ANDROID_SDK/ndk/27.2.12479018}"
# qt.toolchain.cmake (usado por qt-configure-module) da prioridad a
# ANDROID_NDK_ROOT; si apunta a otro NDK, los módulos se compilarían con él.
export ANDROID_NDK_ROOT="$ANDROID_NDK"
# Qt 6.8.3 compila su código Java contra android-34 y no reconoce carpetas
# nuevas como "android-37.0", así que esa plataforma debe estar instalada:
#   sdkmanager "platforms;android-34"
ANDROID_PLATFORM="android-34"
QT_HOST_PATH="${QT_HOST_PATH:-$HOME/Qt/$QT_VERSION/macos}"
OPENSSL_INCLUDE="${OPENSSL_INCLUDE:-$ANDROID_SDK/android_openssl/ssl_3/include}"
PREFIX_BASE="${PREFIX_BASE:-$HOME/Qt/$QT_VERSION-16kb}"
WORK_DIR="${WORK_DIR:-$PWD/work}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN)}"

# Orden de dependencias: cada módulo requiere los anteriores.
MODULES=(qtbase qtshadertools qtsvg qtdeclarative qtlottie qtmultimedia qtnetworkauth)

# Flags de 16 KB para NDK r27 (r28+ ya alinea a 16 KB por defecto).
PAGE_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

SRC_URL="https://download.qt.io/archive/qt/$QT_MINOR/$QT_VERSION/submodules"

if [ "$#" -eq 0 ]; then
    echo "Uso: $0 <abi> [<abi> ...]   (arm64-v8a, armeabi-v7a, x86_64, x86)" >&2
    exit 1
fi

for path in "$ANDROID_SDK" "$ANDROID_NDK" "$QT_HOST_PATH" "$OPENSSL_INCLUDE" \
            "$ANDROID_SDK/platforms/$ANDROID_PLATFORM"; do
    [ -d "$path" ] || { echo "No existe: $path" >&2; exit 1; }
done

md5_of() {
    if command -v md5sum >/dev/null; then md5sum "$1" | awk '{print $1}'; else md5 -q "$1"; fi
}

download_sources() {
    mkdir -p "$WORK_DIR/dl" "$WORK_DIR/src"
    cd "$WORK_DIR/dl"
    [ -f md5sums.txt ] || curl -fsSL -o md5sums.txt "$SRC_URL/md5sums.txt"
    for module in "${MODULES[@]}"; do
        local archive="$module-everywhere-src-$QT_VERSION.tar.xz"
        [ -f "$archive" ] || curl -fsSL -o "$archive" "$SRC_URL/$archive"
        local expected
        expected="$(grep " $archive\$" md5sums.txt | awk '{print $1}')"
        if [ -z "$expected" ] || [ "$expected" != "$(md5_of "$archive")" ]; then
            echo "Checksum inválido para $archive" >&2
            exit 1
        fi
        if [ ! -d "$WORK_DIR/src/$module" ]; then
            mkdir -p "$WORK_DIR/src/$module"
            tar -xf "$archive" -C "$WORK_DIR/src/$module" --strip-components=1
        fi
    done
}

build_abi() {
    local abi="$1"
    local abi_dir="${abi//-/_}"
    [ "$abi" = "armeabi-v7a" ] && abi_dir="armv7"
    local prefix="$PREFIX_BASE/android_$abi_dir"
    local build_root="$WORK_DIR/build/$abi"
    mkdir -p "$build_root"

    echo "=== qtbase ($abi) -> $prefix"
    mkdir -p "$build_root/qtbase"
    cd "$build_root/qtbase"
    "$WORK_DIR/src/qtbase/configure" \
        -prefix "$prefix" \
        -platform android-clang \
        -android-ndk "$ANDROID_NDK" \
        -android-sdk "$ANDROID_SDK" \
        -android-abis "$abi" \
        -qt-host-path "$QT_HOST_PATH" \
        -release \
        -openssl-runtime \
        -nomake tests -nomake examples \
        -- \
        -DOPENSSL_INCLUDE_DIR="$OPENSSL_INCLUDE" \
        -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON \
        -DCMAKE_SHARED_LINKER_FLAGS="$PAGE_FLAGS" \
        -DCMAKE_MODULE_LINKER_FLAGS="$PAGE_FLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$PAGE_FLAGS"
    cmake --build . --parallel "$JOBS"
    cmake --install .

    for module in "${MODULES[@]:1}"; do
        echo "=== $module ($abi)"
        local extra=()
        # La app usa el backend nativo de Android (QT_MEDIA_BACKEND=android);
        # sin FFmpeg se evitan sus librerías, que no están alineadas a 16 KB.
        [ "$module" = "qtmultimedia" ] && extra=(-no-feature-ffmpeg)
        mkdir -p "$build_root/$module"
        cd "$build_root/$module"
        "$prefix/bin/qt-configure-module" "$WORK_DIR/src/$module" ${extra[@]+"${extra[@]}"} -- \
            -DCMAKE_SHARED_LINKER_FLAGS="$PAGE_FLAGS" \
            -DCMAKE_MODULE_LINKER_FLAGS="$PAGE_FLAGS"
        cmake --build . --parallel "$JOBS"
        cmake --install .
    done
}

download_sources
for abi in "$@"; do
    build_abi "$abi"
done
echo "Qt $QT_VERSION para Android instalado en $PREFIX_BASE"
