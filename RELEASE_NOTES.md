Qt 6.8.3 para Android con librerías alineadas a 16 KB (arm64-v8a y armeabi-v7a).

- Compilado a partir del código fuente oficial de Qt 6.8.3, sin modificaciones.
- NDK r27c (27.2.12479018) con `-Wl,-z,max-page-size=16384`.
- Módulos: qtbase, qtshadertools, qtsvg, qtdeclarative, qtlottie, qtmultimedia
  (solo el backend Android, sin FFmpeg) y qtnetworkauth.

Instalación: ver el README. Verifica cada paquete con su archivo `.sha256`.

Qt se distribuye bajo la licencia LGPLv3. Código fuente:
https://download.qt.io/archive/qt/6.8/6.8.3/submodules/
