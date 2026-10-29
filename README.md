# arg-qt-6.8.3

Qt 6.8.3 para Android compilado con librerías alineadas a páginas de 16 KB,
para la app [INHALA](https://play.google.com/store/apps/details?id=mx.ugto.inahala)
(proyecto ARG, Universidad de Guanajuato).

## ¿Por qué existe?

Google Play exige que las apps con `targetSdk` 35 o mayor tengan sus librerías
nativas de 64 bits alineadas a páginas de 16 KB. A partir del **1 de febrero
de 2027** no se pueden publicar actualizaciones que no lo cumplan
([guía oficial](https://developer.android.com/guide/practices/page-sizes)).

Los binarios oficiales de Qt 6.8.3 para Android están alineados a 4 KB.
Subir a una versión más nueva de Qt no es opción porque eleva el iOS mínimo
(Qt 6.8 soporta iOS 16+), y eso dejaría fuera a estudiantes con iPhones más
antiguos. Por eso compilamos **la misma versión 6.8.3**, sin cambios en el
código fuente, solo con distintas opciones de compilación.

## Qué contiene

| | Qt oficial 6.8.3 | Este Qt |
|---|---|---|
| Código fuente | Qt 6.8.3 | Qt 6.8.3 oficial, sin modificar |
| NDK | r26b | r27c (27.2.12479018), soportado por Qt 6.8 |
| Alineación de `.so` | 4 KB | 16 KB |
| Módulos | Todos | qtbase, qtshadertools, qtsvg, qtdeclarative, qtlottie, qtmultimedia, qtnetworkauth |
| Backend de Qt Multimedia | FFmpeg + Android | Solo Android (sin FFmpeg) |
| ABIs | arm64-v8a, armeabi-v7a, x86, x86_64 | arm64-v8a, armeabi-v7a |

Solo incluye los módulos que usa INHALA. Para otros proyectos sigue usando el
Qt oficial.

## Instalación (macOS y Linux)

Requisitos:

- Qt 6.8.3 oficial instalado con el instalador de Qt: el de escritorio
  (macOS o Desktop gcc_64) y los componentes **Android ARMv8** y **Android
  ARMv7**. De ahí se toman las herramientas host.
- Android NDK **27.2.12479018** (r27c), desde el SDK Manager de Android Studio
  o con `sdkmanager "ndk;27.2.12479018"`.

Pasos:

1. Descarga del [último release](../../releases/latest) los dos `.tar.xz`, sus
   `.sha256` y `install-qt-android.sh`.
2. Ejecuta:
   ```sh
   chmod +x install-qt-android.sh
   ./install-qt-android.sh qt-6.8.3-android_arm64_v8a-16kb.tar.xz qt-6.8.3-android_armv7-16kb.tar.xz
   ```
   Se instala en `~/Qt/6.8.3-16kb/`, junto a tu Qt oficial, sin modificarlo.
   Si instalaste Qt en otra carpeta usa `QT_ROOT=/ruta/a/Qt ./install-qt-android.sh ...`.
3. En Qt Creator:
   1. *Preferences → Kits → Qt Versions → Add*:
      `~/Qt/6.8.3-16kb/android_armv7/bin/qmake`.
   2. *Preferences → Devices → Android*: agrega el NDK 27.2.12479018 y
      márcalo como predeterminado para esa versión de Qt.
   3. Crea un kit **Android Qt 6.8.3 16KB** con esa versión de Qt y úsalo para
      compilar los releases que se suben a Play Store.

`arg-app` compila los dos ABIs a partir del Qt seleccionado en el kit y espera
las carpetas `android_armv7` y `android_arm64_v8a` como hermanas, igual que en
la instalación oficial.

## Compilar este Qt

El workflow [`build.yml`](.github/workflows/build.yml) compila cada ABI en
GitHub Actions, verifica la alineación de todas las `.so` y, al crear un tag
`v*`, publica un release con los paquetes.

Para compilar localmente (macOS; en Linux define `QT_HOST_PATH`):

```sh
sdkmanager "ndk;27.2.12479018" "platforms;android-34"
./build-qt-android.sh arm64-v8a armeabi-v7a   # instala en ~/Qt/6.8.3-16kb
./package-qt-android.sh arm64-v8a armeabi-v7a # genera dist/*.tar.xz
```

Variables útiles: `ANDROID_SDK`, `ANDROID_NDK`, `QT_HOST_PATH`,
`OPENSSL_INCLUDE` (headers de [KDAB/android_openssl](https://github.com/KDAB/android_openssl)),
`PREFIX_BASE`, `WORK_DIR` y `JOBS`.

## Pendientes

- [ ] Instalador para Windows (`install-qt-android.ps1`). Por ahora ningún
      estudiante desarrolla en Windows; hay que escribirlo y probarlo en una
      computadora con Windows y el Qt oficial 6.8.3 (`mingw_64` o `msvc2022_64`).

## Licencia

Qt se usa bajo la licencia LGPLv3. Los binarios de los releases se compilan a
partir del código fuente oficial de Qt 6.8.3, disponible en
<https://download.qt.io/archive/qt/6.8/6.8.3/submodules/>, con los scripts de
este repositorio. Los scripts de este repositorio se distribuyen bajo la
licencia MIT (ver `LICENSE`).
