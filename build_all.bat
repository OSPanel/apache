#!/usr/bin/env bash
# build_all.sh
# Переписанная версия build_all.bat под MSYS2 bash + MSVC (VS17).
# Логика сборки и патчи сохранены. Генератор CMake: NMake Makefiles (MSVC).
set -euo pipefail

# -----------------------------
# Константы и окружение
# -----------------------------
BUILD_BASE="${BUILD_BASE:-C:/Development/Apache24/build}"
PREFIX="${PREFIX:-C:/Apache24}"
SRC_ROOT="C:/Development/Apache24/src"
PLATFORM="${PLATFORM:-x64}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
INSTALL_PDB="${INSTALL_PDB:-OFF}"
CURL_USE_OPENSSL="${CURL_USE_OPENSSL:-ON}"
CURL_DEFAULT_SSL_BACKEND="${CURL_DEFAULT_SSL_BACKEND:-SCHANNEL}"

# Преобразование путей в msys (для bash-утилит). CMake/NMake понимают Windows пути.
BUILD_BASE_WIN="$BUILD_BASE"
PREFIX_WIN="$PREFIX"
SRC_ROOT_WIN="$SRC_ROOT"

# Создание директорий
mkdir -p "/c/Development" "/c/Development/Apache24" "/c/Development/Apache24/src" "/c/Development/Apache24/build"
mkdir -p "$(cygpath -u "$PREFIX_WIN")"/{bin,lib,include,conf,cgi-bin} || true

# Проверки инструментов
command -v perl >/dev/null 2>&1 || { echo "perl not found"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "tar not found"; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "cmake (Windows) not found in PATH"; exit 1; }
# Проверим cl/nmake через cmd.exe (они Windows-инструменты)
cmd.exe /c "where cl" >/dev/null || { echo "MSVC cl not found"; exit 1; }
cmd.exe /c "where nmake" >/dev/null || { echo "MSVC nmake not found"; exit 1; }

# -----------------------------
# Релизы и URL
# -----------------------------
ZLIB="zlib-1.3.1"
PCRE2="pcre2-10.45"
EXPAT="expat-2.7.1"
OPENSSL="openssl-3.5.2"
LIBXML2="libxml2-2.14.5"
JANSSON="jansson-2.14.1"
BROTLI="brotli-1.1.0"
LUA="lua-5.4.8"
APR="apr-1.7.6"
APR_UTIL="apr-util-1.6.3"
NGHTTP2="nghttp2-1.66.0"
CURL="curl-8.15.0"
HTTPD="httpd-2.4.65"
MOD_FCGID="mod_fcgid-2.3.9"

URL_ZLIB="https://zlib.net/zlib-1.3.1.tar.gz"
URL_PCRE2="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz"
URL_EXPAT="https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz"
URL_OPENSSL="https://www.openssl.org/source/openssl-3.5.2.tar.gz"
URL_LIBXML2="https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz"
URL_JANSSON="https://github.com/akheron/jansson/releases/download/v2.14.1/jansson-2.14.1.tar.gz"
URL_BROTLI="https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
URL_LUA="https://www.lua.org/ftp/lua-5.4.8.tar.gz"
URL_APR="https://downloads.apache.org/apr/apr-1.7.6.tar.gz"
URL_APR_UTIL="https://downloads.apache.org/apr/apr-util-1.6.3.tar.gz"
URL_NGHTTP2="https://github.com/nghttp2/nghttp2/releases/download/v1.66.0/nghttp2-1.66.0.tar.xz"
URL_CURL="https://curl.se/download/curl-8.15.0.tar.xz"
URL_HTTPD="https://downloads.apache.org/httpd/httpd-2.4.65.tar.bz2"
URL_MOD_FCGID="https://downloads.apache.org/httpd/mod_fcgid/mod_fcgid-2.3.9.tar.gz"

# -----------------------------
# Функции
# -----------------------------
status=0
get_status() { status=$?; return $status; }

get_package_details() {
  local release="$1"
  # PACKAGE: часть до первого '-'
  PACKAGE="${release%%-*}"
  # VERSION: всё после первого '-'
  VERSION="${release#*-}"
}

check_package_source() {
  local release="$1"
  local src_dir="$SRC_ROOT_WIN/$release"
  if [ ! -d "$src_dir" ]; then
    echo "Warning for package $release"
    echo "Could not find package source folder \"$src_dir\""
    status=1
  else
    cd "$(cygpath -u "$src_dir")"
    status=0
  fi
  return $status
}

fetch_and_unpack() {
  # $1 want dir, $2 url, $3 override name (opt), $4 strip flag (1=yes) (opt)
  local want="$1" url="$2" override="${3:-}" strip="${4:-}"
  local dest="$SRC_ROOT_WIN/$want"
  echo "Downloading: $url"
  local tmp="$(cygpath -u "$(cmd.exe /c echo %TEMP% 2>/dev/null | tr -d '\r')")/dl-$$-$RANDOM"
  mkdir -p "$tmp/x"
  local fname="$tmp/$(basename "$url")"
  # Скачивание через curl
  curl -fsSL "$url" -o "$fname"

  # Определение расширения
  local lower="$(echo "$fname" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" =~ \.zip$ ]]; then
    7z x -y -o"$tmp/x" "$fname" >/dev/null
  else
    # .tar.* или одиночные .gz/.xz/.bz2
    if [[ "$lower" =~ \.tar\.gz$ || "$lower" =~ \.tgz$ || "$lower" =~ \.tar\.xz$ || "$lower" =~ \.txz$ || "$lower" =~ \.tar\.bz2$ || "$lower" =~ \.tbz2$ || "$lower" =~ \.tar$ ]]; then
      tar -xf "$fname" -C "$tmp/x"
    else
      # одиночный gz/xz/bz2 — распакуем и если получился .tar, развернём
      case "$lower" in
        *.gz)  gunzip -c "$fname" > "$tmp/x/payload" ;;
        *.xz)  xz -dc "$fname" > "$tmp/x/payload" ;;
        *.bz2) bzip2 -dc "$fname" > "$tmp/x/payload" ;;
        *)     echo "Unknown archive type: $fname"; rm -rf "$tmp"; return 1 ;;
      esac
      if file "$tmp/x/payload" | grep -qi 'tar archive'; then
        tar -xf "$tmp/x/payload" -C "$tmp/x"
        rm -f "$tmp/x/payload"
      else
        mkdir -p "$(cygpath -u "$dest")"
        cp -f "$tmp/x/payload" "$(cygpath -u "$dest")/"
      fi
    fi
  fi

  # Определить верхний каталог
  local top=""
  top="$(find "$tmp/x" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n1 || true)"

  local final
  if [ -n "$override" ]; then
    final="$SRC_ROOT_WIN/$override"
  else
    final="$SRC_ROOT_WIN/$top"
  fi
  mkdir -p "$(cygpath -u "$SRC_ROOT_WIN")"

  if [ "$strip" = "1" ]; then
    if [ -z "$top" ]; then
      echo "Extraction failed for $want"
      rm -rf "$tmp"
      return 1
    fi
    if [ "$top" = "$want" ]; then
      mkdir -p "$(dirname "$(cygpath -u "$dest")")"
      mv "$tmp/x/$top" "$(cygpath -u "$dest")"
    else
      mv "$tmp/x/$top" "$(cygpath -u "$final")"
      if [ "$(cygpath -w "$final")" != "$(cygpath -w "$dest")" ]; then
        (cd "$(cygpath -u "$SRC_ROOT_WIN")" && mv "$override" "$want")
      fi
    fi
  else
    if [ -n "$top" ]; then
      mkdir -p "$(dirname "$(cygpath -u "$dest")")"
      mv "$tmp/x/$top" "$(cygpath -u "$dest")"
    else
      mkdir -p "$(cygpath -u "$dest")"
      (shopt -s dotglob nullglob; cp -r "$tmp/x/"* "$(cygpath -u "$dest")"/)
    fi
  fi

  if [ ! -d "$(cygpath -u "$dest")" ]; then
    echo "Failed to prepare source folder: $dest"
    rm -rf "$tmp"
    return 1
  fi

  echo "Source ready: $dest"
  rm -rf "$tmp"
  return 0
}

cmake_build_install() {
  # $1 release, $2 cmake opts, $3 optional subdir
  local release="$1" cmake_opts="$2" subdir="${3:-}"
  get_package_details "$release"
  local src_dir="$SRC_ROOT_WIN/$release"
  if [ -n "$subdir" ]; then
    src_dir="$src_dir/$subdir"
  fi
  if [ ! -d "$src_dir" ]; then
    echo "Source dir not found: $src_dir"
    return 0 # как в батнике: не фатально
  fi

  local build_dir="$BUILD_BASE_WIN/$PACKAGE"
  if [ -d "$build_dir" ]; then
    cmd.exe /c "rmdir /s /q \"$(cygpath -w "$build_dir")\"" || true
  fi
  mkdir -p "$(cygpath -u "$build_dir")"

  # Патч убирающий DEBUG_POSTFIX
  local cmakelists="$(cygpath -u "$src_dir")/CMakeLists.txt"
  if [ -f "$cmakelists" ]; then
    perl -pi -e 's{((DEBUG_POSTFIX|POSTFIX_DEBUG)\s+)(["]*)[-_]*(|s)d(["]*)}{$1"$4"}' "$cmakelists" || true
  fi

  echo
  echo "Building $release"
  pushd "$(cygpath -u "$build_dir")" >/dev/null

  # Генерация и сборка (Windows пути, генератор NMake)
  cmake -G "NMake Makefiles" \
    $cmake_opts \
    -DCMAKE_IGNORE_PATH="C:/Program Files/OpenSSL" \
    -DCMAKE_EXE_LINKER_FLAGS="/DYNAMICBASE" \
    -DCMAKE_SHARED_LINKER_FLAGS="/DYNAMICBASE" \
    -DCMAKE_C_FLAGS="/DFD_SETSIZE=32768" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -S "$(cygpath -w "$src_dir")" -B . || { status=$?; echo "cmake for $PACKAGE failed with exit status $status"; popd >/dev/null; return $status; }

  nmake || { status=$?; echo "nmake for $PACKAGE failed with exit status $status"; popd >/dev/null; return $status; }
  nmake install || { status=$?; echo "nmake install for $PACKAGE failed with exit status $status"; popd >/dev/null; return $status; }

  popd >/dev/null
  return 0
}

# -----------------------------
# Загрузка исходников (всегда)
# -----------------------------
fetch_and_unpack "$ZLIB"      "$URL_ZLIB"
fetch_and_unpack "$PCRE2"     "$URL_PCRE2"
fetch_and_unpack "$EXPAT"     "$URL_EXPAT"
fetch_and_unpack "$OPENSSL"   "$URL_OPENSSL"
fetch_and_unpack "$LIBXML2"   "$URL_LIBXML2"
fetch_and_unpack "$JANSSON"   "$URL_JANSSON"
fetch_and_unpack "$BROTLI"    "$URL_BROTLI" "brotli-1.1.0" "1"
fetch_and_unpack "$LUA"       "$URL_LUA"
fetch_and_unpack "$APR"       "$URL_APR"
fetch_and_unpack "$APR_UTIL"  "$URL_APR_UTIL"
fetch_and_unpack "$NGHTTP2"   "$URL_NGHTTP2"
fetch_and_unpack "$CURL"      "$URL_CURL"
fetch_and_unpack "$HTTPD"     "$URL_HTTPD"
fetch_and_unpack "$MOD_FCGID" "$URL_MOD_FCGID"

# -----------------------------
# Вызов vcvarsall для среды MSVC
# -----------------------------
# Найти путь установки VS и вызвать vcvarsall для PLATFORM
VS_INST_PATH="$(/c/ProgramData/chocolatey/bin/vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>/dev/null || true)"
if [ -z "$VS_INST_PATH" ]; then
  VS_INST_PATH="$(
    cmd.exe /c "vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath" 2>/dev/null | tr -d '\r'
  )"
fi
if [ -z "$VS_INST_PATH" ]; then
  echo "Could not find Visual Studio installation via vswhere"
  exit 1
fi
VCVARSALL_WIN="${VS_INST_PATH}\\VC\\Auxiliary\\Build\\vcvarsall.bat"
if [ ! -f "$(cygpath -u "$VCVARSALL_WIN")" ]; then
  echo "Could not find vcvarsall.bat at $VCVARSALL_WIN"
  exit 1
fi
echo "Using \"$VCVARSALL_WIN\""
# Применяем окружение vcvarsall к текущему процессу bash:
# Получаем вывод 'set' после вызова vcvarsall и экспортируем переменные в MSYS2
eval "$(
  cmd.exe /c "\"$VCVARSALL_WIN\" $PLATFORM >nul && set" | tr -d '\r' | awk -F= '
    /^[A-Za-z0-9_]+=/ {
      # Экранируем для bash
      gsub("%","%%",$2);
      gsub(/\\/, "\\\\", $2);
      gsub(/"/, "\\\"", $2);
      printf("export %s=\"%s\"\n", $1, $2);
    }'
)"

# -----------------------------
# Пакетные сборки
# -----------------------------
# ZLIB
if check_package_source "$ZLIB"; then
  ZLIB_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DBUILD_SHARED_LIBS=ON -DINSTALL_PKGCONFIG_DIR=$PREFIX_WIN/lib/pkgconfig"
  cmake_build_install "$ZLIB" "$ZLIB_CMAKE_OPTS"
fi

# PCRE2 (патч CMakeLists.txt путей установки)
if check_package_source "$PCRE2"; then
  perl -pi.bak -e 's{(^.+DESTINATION )(man)}{$1share/$2}; s{(^install.+DESTINATION )(cmake)}{$1lib/$2/pcre2-${PCRE2_MAJOR}.${PCRE2_MINOR}}' CMakeLists.txt
  PCRE2_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DBUILD_SHARED_LIBS=ON -DPCRE2_BUILD_TESTS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_SUPPORT_JIT=OFF -DPCRE2_SUPPORT_UNICODE=ON -DPCRE2_NEWLINE=CRLF -DINSTALL_MSVC_PDB=$INSTALL_PDB"
  cmake_build_install "$PCRE2" "$PCRE2_CMAKE_OPTS"
fi

# EXPAT
if check_package_source "$EXPAT"; then
  EXPAT_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
  cmake_build_install "$EXPAT" "$EXPAT_CMAKE_OPTS"
fi

# OPENSSL (nmake)
if check_package_source "$OPENSSL"; then
  echo
  echo "Building $OPENSSL"
  if [ "$PLATFORM" = "x64" ]; then
    OS_COMPILER="VC-WIN64A"
  else
    OS_COMPILER="VC-WIN32"
  fi
  if [ "$BUILD_TYPE" = "Release" ]; then
    OPENSSL_BUILD_TYPE="--release"
  else
    OPENSSL_BUILD_TYPE="--debug"
  fi
  OPENSSL_CONFIGURE_OPTS="--prefix=$PREFIX_WIN --libdir=lib --openssldir=$PREFIX_WIN/conf --with-zlib-include=$PREFIX_WIN/include shared zlib-dynamic enable-camellia no-idea no-mdc2 $OPENSSL_BUILD_TYPE -DFD_SETSIZE=32768"
  perl Configure "$OS_COMPILER" $OPENSSL_CONFIGURE_OPTS
  if [ -f "makefile" ]; then
    if [ "$INSTALL_PDB" = "OFF" ]; then
      perl -pi.bak -e 's{^(INSTALL_.*PDBS=).*}{$1nul}' makefile
    fi
    cmd.exe /c "nmake clean" >/dev/null 2>&1 || true
    cmd.exe /c "nmake" || { echo "nmake for $OPENSSL failed"; exit 1; }
    cmd.exe /c "nmake install" || { echo "nmake install for $OPENSSL failed"; exit 1; }
  else
    echo "Cannot find Makefile for $OPENSSL"
    exit 1
  fi
fi

# LIBXML2
if check_package_source "$LIBXML2"; then
  if [ "$BUILD_TYPE" = "Release" ]; then
    LIBXML2_DEBUG_MODULE="OFF"
  else
    LIBXML2_DEBUG_MODULE="ON"
  fi
  LIBXML2_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DBUILD_SHARED_LIBS=ON -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_ZLIB=ON -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_DEBUG=$LIBXML2_DEBUG_MODULE"
  cmake_build_install "$LIBXML2" "$LIBXML2_CMAKE_OPTS"
fi

# JANSSON
if check_package_source "$JANSSON"; then
  JANSSON_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DJANSSON_BUILD_SHARED_LIBS=ON -DJANSSON_BUILD_DOCS=OFF -DJANSSON_INSTALL_CMAKE_DIR=lib/cmake/jansson"
  cmake_build_install "$JANSSON" "$JANSSON_CMAKE_OPTS"
fi

# BROTLI
if check_package_source "$BROTLI"; then
  BROTLI_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
  cmake_build_install "$BROTLI" "$BROTLI_CMAKE_OPTS"
fi

# LUA (замена CMakeLists.txt + патч LUA_COMPАТ)
if check_package_source "$LUA"; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -f "$SCRIPT_DIR/CMakeLists.txt" ]; then
    cp -f "$SCRIPT_DIR/CMakeLists.txt" ./CMakeLists.txt
  else
    echo "CMakeLists.txt not found: \"$SCRIPT_DIR/CMakeLists.txt\""
    exit 1
  fi
  perl -pi.bak -e 's{( LUA_COMPAT_ALL )(\)\))}{$1LUA_COMPAT_5_1 LUA_COMPAT_5_2 LUA_COMPAT_5_3 $2}' CMakeLists.txt
  LUA_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
  cmake_build_install "$LUA" "$LUA_CMAKE_OPTS"
fi

# APR
if check_package_source "$APR"; then
  APR_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DMIN_WINDOWS_VER=0x0600 -DAPR_HAVE_IPV6=ON -DAPR_INSTALL_PRIVATE_H=ON -DAPR_BUILD_TESTAPR=OFF -DINSTALL_PDB=$INSTALL_PDB"
  cmake_build_install "$APR" "$APR_CMAKE_OPTS"
fi

# APR-UTIL
if check_package_source "$APR_UTIL"; then
  APR_UTIL_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DAPU_HAVE_CRYPTO=ON -DAPR_BUILD_TESTAPR=OFF -DINSTALL_PDB=$INSTALL_PDB"
  cmake_build_install "$APR_UTIL" "$APR_UTIL_CMAKE_OPTS"
fi

# NGHTTP2
if check_package_source "$NGHTTP2"; then
  NGHTTP2_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DSTATIC_LIB_SUFFIX=_static -DENABLE_LIB_ONLY=ON"
  cmake_build_install "$NGHTTP2" "$NGHTTP2_CMAKE_OPTS"
fi

# CURL (патчи и сборка)
if check_package_source "$CURL"; then
  if [ "$CURL_USE_OPENSSL" = "ON" ]; then
    perl -0777 -Mopen=OUT,:raw -pi.bak -e 's{(return result;\n#endif\n#endif$)\n  \}}{$1 
#if defined(USE_WIN32_CRYPTO)
/* Mandate Windows CA store to be used */
if(!set->ssl.primary.CAfile && !set->ssl.primary.CApath) {
  /* User and environment did not specify any CA file or path.*/
  set->ssl.native_ca_store = TRUE;
}
#endif
  }}smg' lib/url.c
  else
    perl -0777 -Mopen=OUT,:raw -pi.bak -e 's{(return result;\n#endif\n#endif) \n.+native_ca_store = TRUE;\n    \}\n#endif}{$1}smg' lib/url.c
  fi

  if [ "$CURL_USE_OPENSSL" = "ON" ] && [ "$CURL_DEFAULT_SSL_BACKEND" = "SCHANNEL" ]; then
    perl -pi.bak -e 's{(if\(CURL_USE_OPENSSL\))\n}{$1 \n  add_definitions(-DCURL_DEFAULT_SSL_BACKEND="schannel")\n}m' CMakeLists.txt
  else
    perl -pi.bak -e 's{(if\(CURL_USE_OPENSSL\)) \n}{$1\n}m; s{[ ]+add_definitions\(-DCURL_DEFAULT_SSL_BACKEND="schannel"\)\n}{}m' CMakeLists.txt
  fi

  perl -pi.bak -e 's{(_files_per_batch[\s]+)200(\))}{$1 100 $2}m' docs/libcurl/CMakeLists.txt

  CURL_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCURL_USE_OPENSSL=$CURL_USE_OPENSSL -DCURL_USE_SCHANNEL=ON -DCURL_WINDOWS_SSPI=ON -DCURL_BROTLI=ON -DUSE_NGHTTP2=ON -DHAVE_LDAP_SSL=ON -DENABLE_UNICODE=ON -DCURL_STATIC_CRT=OFF -DUSE_WIN32_CRYPTO=ON -DUSE_LIBIDN2=OFF -DCURL_USE_LIBPSL=OFF -DCURL_USE_LIBSSH2=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON"
  cmake_build_install "$CURL" "$CURL_CMAKE_OPTS"
fi

# HTTPD (патчи и сборка)
if check_package_source "$HTTPD"; then
  perl -pi.bak -e 's{(^# )(.*ApacheMonitor.*)}{$2}' CMakeLists.txt
  perl -pi.bak -e 's{(^CREATEPROCESS_MANIFEST)}{// $1}' support/win32/ApacheMonitor.rc
  perl -pi.bak -e 's{(wtsapi32\))\n}{$1 \n\n# Build WinTTY console binary\nADD_EXECUTABLE(WinTTY support/win32/wintty.c)\nSET(install_targets ${install_targets} WinTTY)\nSET_TARGET_PROPERTIES(WinTTY PROPERTIES WIN32_EXECUTABLE TRUE)\nSET_TARGET_PROPERTIES(WinTTY PROPERTIES COMPILE_FLAGS "${EXTRA_COMPILE_FLAGS}")\nSET_TARGET_PROPERTIES(WinTTY PROPERTIES LINK_FLAGS "/subsystem:console")\n}m' CMakeLists.txt

  if [[ "$HTTPD" == *"2.4.62"* ]]; then
    perl -0777 -Mopen=OUT,:raw -pi.bak -e '
      s{^(\h+)(int is_proxyreq = 0;\n)(\n\h+ctx)}{$1$2$1int prefix_added = 0;\n$3}smg;
      s{^(\h+)(newuri = apr_pstrcat[^^;]+;\n)(\h+\})}{$1$2$1prefix_added = 1;\n$3}smg;
    ' modules/mappers/mod_rewrite.c
  fi

  if [ -f "modules/loggers/mod_log_rotate.c" ]; then
    perl -pi.bak -e 's{(.+)(forensic\+I\+)(.+)(")\n}{$1$2$3$4 \n$1rotate\+I\+log rotation through server process$4\n}m' CMakeLists.txt
  fi

  HTTPD_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DENABLE_MODULES=i -DINSTALL_PDB=$INSTALL_PDB"
  cmake_build_install "$HTTPD" "$HTTPD_CMAKE_OPTS"

  # Доп. скрипты
  perl -pe 's{#.+perlbin.+\n}{}m' "$(cygpath -u "$SRC_ROOT_WIN/$HTTPD")/support/dbmmanage.in" >"$(cygpath -u "$PREFIX_WIN")/bin/dbmmanage.pl"
  cp -f "$(cygpath -u "$SRC_ROOT_WIN/$HTTPD")/docs/cgi-examples/printenv" "$(cygpath -u "$PREFIX_WIN")/cgi-bin/printenv.pl" 2>/dev/null || true
fi

# MOD_FCGID (CMake experimental)
if check_package_source "$MOD_FCGID"; then
  MOD_FCGID_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX_WIN -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DINSTALL_PDB=NO"
  cmake_build_install "$MOD_FCGID" "$MOD_FCGID_CMAKE_OPTS" "modules/fcgid"
fi

echo "Build finished."