#!/bin/bash

# build_all.sh - Apache build script for MSYS2
# Based on build_all.bat version 3.9

set -e  # Exit on any error

# ---------------------------------------------------------------------------
# Ensure base folder structure exists and download all sources unconditionally
# ---------------------------------------------------------------------------

BUILD_BASE="/c/Development/Apache24/build"
PREFIX="/c/Apache24"
SRC_ROOT="/c/Development/Apache24/src"

# Create directories
mkdir -p "/c/Development/Apache24/"{src,build}
mkdir -p "$PREFIX/"{bin,lib,include,conf,cgi-bin}

# Package versions
declare -A PACKAGES=(
    ["ZLIB"]="zlib-1.3.1"
    ["PCRE2"]="pcre2-10.45"
    ["EXPAT"]="expat-2.7.1"
    ["OPENSSL"]="openssl-3.5.2"
    ["LIBXML2"]="libxml2-2.14.5"
    ["JANSSON"]="jansson-2.14.1"
    ["BROTLI"]="brotli-1.1.0"
    ["LUA"]="lua-5.4.8"
    ["APR"]="apr-1.7.6"
    ["APR_UTIL"]="apr-util-1.6.3"
    ["NGHTTP2"]="nghttp2-1.66.0"
    ["CURL"]="curl-8.15.0"
    ["HTTPD"]="httpd-2.4.65"
    ["MOD_FCGID"]="mod_fcgid-2.3.9"
)

declare -A URLS=(
    ["ZLIB"]="https://zlib.net/zlib-1.3.1.tar.gz"
    ["PCRE2"]="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz"
    ["EXPAT"]="https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz"
    ["OPENSSL"]="https://www.openssl.org/source/openssl-3.5.2.tar.gz"
    ["LIBXML2"]="https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz"
    ["JANSSON"]="https://github.com/akheron/jansson/releases/download/v2.14.1/jansson-2.14.1.tar.gz"
    ["BROTLI"]="https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
    ["LUA"]="https://www.lua.org/ftp/lua-5.4.8.tar.gz"
    ["APR"]="https://downloads.apache.org/apr/apr-1.7.6.tar.gz"
    ["APR_UTIL"]="https://downloads.apache.org/apr/apr-util-1.6.3.tar.gz"
    ["NGHTTP2"]="https://github.com/nghttp2/nghttp2/releases/download/v1.66.0/nghttp2-1.66.0.tar.xz"
    ["CURL"]="https://curl.se/download/curl-8.15.0.tar.xz"
    ["HTTPD"]="https://downloads.apache.org/httpd/httpd-2.4.65.tar.bz2"
    ["MOD_FCGID"]="https://downloads.apache.org/httpd/mod_fcgid/mod_fcgid-2.3.9.tar.gz"
)

# Build configuration
PLATFORM="${PLATFORM:-x64}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
INSTALL_PDB="${INSTALL_PDB:-OFF}"
CURL_USE_OPENSSL="${CURL_USE_OPENSSL:-ON}"
CURL_DEFAULT_SSL_BACKEND="${CURL_DEFAULT_SSL_BACKEND:-SCHANNEL}"

# Functions
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

fetch_and_unpack() {
    local package="$1"
    local url="$2"
    local override_dir="$3"
    local strip_top="${4:-0}"
    
    local dest_dir="$SRC_ROOT/$package"
    
    log_info "Downloading: $url"
    local tmp_dir=$(mktemp -d)
    local filename=$(basename "$url")
    
    # Download
    if ! curl -L -o "$tmp_dir/$filename" "$url"; then
        log_error "Download failed: $url"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # Extract
    local extract_dir="$tmp_dir/extract"
    mkdir -p "$extract_dir"
    
    case "$filename" in
        *.tar.gz|*.tgz)
            tar -xzf "$tmp_dir/$filename" -C "$extract_dir"
            ;;
        *.tar.xz|*.txz)
            tar -xJf "$tmp_dir/$filename" -C "$extract_dir"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xjf "$tmp_dir/$filename" -C "$extract_dir"
            ;;
        *.zip)
            unzip -q "$tmp_dir/$filename" -d "$extract_dir"
            ;;
        *)
            log_error "Unsupported archive format: $filename"
            rm -rf "$tmp_dir"
            return 1
            ;;
    esac
    
    # Handle directory structure
    local top_dir=$(ls "$extract_dir" | head -n1)
    local final_dir="${override_dir:-$package}"
    
    if [[ "$strip_top" == "1" ]]; then
        mv "$extract_dir/$top_dir" "$SRC_ROOT/$final_dir"
    else
        mv "$extract_dir/$top_dir" "$dest_dir"
    fi
    
    if [[ ! -d "$dest_dir" ]]; then
        log_error "Failed to prepare source folder: $dest_dir"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    log_info "Source ready: $dest_dir"
    rm -rf "$tmp_dir"
    return 0
}

check_package_source() {
    local package="$1"
    local src_dir="$SRC_ROOT/$package"
    
    if [[ ! -d "$src_dir" ]]; then
        log_warn "Could not find package source folder: $src_dir"
        return 1
    fi
    
    cd "$src_dir"
    return 0
}

build_package() {
    local package="$1"
    local cmake_opts="$2"
    local subfolder="$3"
    
    local package_name="${package%%-*}"
    local src_dir="$SRC_ROOT/$package"
    
    if [[ -n "$subfolder" ]]; then
        src_dir="$src_dir/$subfolder"
    fi
    
    if ! check_package_source "$package"; then
        return 0  # Non-fatal
    fi
    
    # Clean previous build
    rm -rf "$BUILD_BASE/$package_name"
    mkdir -p "$BUILD_BASE/$package_name"
    
    cd "$BUILD_BASE/$package_name"
    log_info "Building $package"
    
    # Patch CMakeLists.txt to remove debug suffix
    if [[ -f "$src_dir/CMakeLists.txt" ]]; then
        sed -i 's/\(DEBUG_POSTFIX\|POSTFIX_DEBUG\)\s\+"\?[-_]*\(s\)\?d"\?/\1 ""/g' "$src_dir/CMakeLists.txt"
    fi
    
    # Configure with CMake
    if ! cmake -G "MSYS Makefiles" $cmake_opts \
        -DCMAKE_IGNORE_PATH="/c/Program Files/OpenSSL" \
        -DCMAKE_EXE_LINKER_FLAGS="/DYNAMICBASE" \
        -DCMAKE_SHARED_LINKER_FLAGS="/DYNAMICBASE" \
        -DCMAKE_C_FLAGS="/DFD_SETSIZE=32768" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -S "$src_dir" -B .; then
        log_error "CMake configuration failed for $package"
        return 1
    fi
    
    # Build
    if ! make -j$(nproc); then
        log_error "Build failed for $package"
        return 1
    fi
    
    # Install
    if ! make install; then
        log_error "Install failed for $package"
        return 1
    fi
    
    log_info "Successfully built and installed $package"
    return 0
}

# Download all sources
log_info "Downloading all source packages..."
for pkg in "${!PACKAGES[@]}"; do
    package="${PACKAGES[$pkg]}"
    url="${URLS[$pkg]}"
    
    if [[ "$pkg" == "BROTLI" ]]; then
        fetch_and_unpack "$package" "$url" "brotli-1.1.0" 1
    else
        fetch_and_unpack "$package" "$url"
    fi
done

# Build packages in order
log_info "Starting build process..."

# ZLIB
if check_package_source "${PACKAGES[ZLIB]}"; then
    ZLIB_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DBUILD_SHARED_LIBS=ON -DINSTALL_PKGCONFIG_DIR=$PREFIX/lib/pkgconfig"
    build_package "${PACKAGES[ZLIB]}" "$ZLIB_CMAKE_OPTS"
fi

# PCRE2
if check_package_source "${PACKAGES[PCRE2]}"; then
    # Patch CMakeLists.txt
    cd "$SRC_ROOT/${PACKAGES[PCRE2]}"
    sed -i 's/\(^.*DESTINATION \)\(man\)/\1share\/\2/' CMakeLists.txt
    sed -i 's/\(^install.*DESTINATION \)\(cmake\)/\1lib\/\2\/pcre2-${PCRE2_MAJOR}.${PCRE2_MINOR}/' CMakeLists.txt
    
    PCRE2_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DBUILD_SHARED_LIBS=ON -DPCRE2_BUILD_TESTS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_SUPPORT_JIT=OFF -DPCRE2_SUPPORT_UNICODE=ON -DPCRE2_NEWLINE=CRLF -DINSTALL_MSVC_PDB=$INSTALL_PDB"
    build_package "${PACKAGES[PCRE2]}" "$PCRE2_CMAKE_OPTS"
fi

# EXPAT
if check_package_source "${PACKAGES[EXPAT]}"; then
    EXPAT_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    build_package "${PACKAGES[EXPAT]}" "$EXPAT_CMAKE_OPTS"
fi

# OPENSSL
if check_package_source "${PACKAGES[OPENSSL]}"; then
    cd "$SRC_ROOT/${PACKAGES[OPENSSL]}"
    log_info "Building ${PACKAGES[OPENSSL]}"
    
    if [[ "$PLATFORM" == "x64" ]]; then
        OS_COMPILER="linux-x86_64"
    else
        OS_COMPILER="linux-x86"
    fi
    
    if [[ "$BUILD_TYPE" == "Release" ]]; then
        OPENSSL_BUILD_TYPE="--release"
    else
        OPENSSL_BUILD_TYPE="--debug"
    fi
    
    OPENSSL_CONFIGURE_OPTS="--prefix=$PREFIX --libdir=lib --openssldir=$PREFIX/conf --with-zlib-include=$PREFIX/include shared zlib-dynamic enable-camellia no-idea no-mdc2 $OPENSSL_BUILD_TYPE -DFD_SETSIZE=32768"
    
    ./Configure $OS_COMPILER $OPENSSL_CONFIGURE_OPTS
    make clean 2>/dev/null || true
    make -j$(nproc)
    make install
fi

# Continue with other packages...
# LIBXML2
if check_package_source "${PACKAGES[LIBXML2]}"; then
    if [[ "$BUILD_TYPE" == "Release" ]]; then
        LIBXML2_DEBUG_MODULE="OFF"
    else
        LIBXML2_DEBUG_MODULE="ON"
    fi
    LIBXML2_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DBUILD_SHARED_LIBS=ON -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_ZLIB=ON -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_DEBUG=$LIBXML2_DEBUG_MODULE"
    build_package "${PACKAGES[LIBXML2]}" "$LIBXML2_CMAKE_OPTS"
fi

# JANSSON
if check_package_source "${PACKAGES[JANSSON]}"; then
    JANSSON_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DJANSSON_BUILD_SHARED_LIBS=ON -DJANSSON_BUILD_DOCS=OFF -DJANSSON_INSTALL_CMAKE_DIR=lib/cmake/jansson"
    build_package "${PACKAGES[JANSSON]}" "$JANSSON_CMAKE_OPTS"
fi

# BROTLI
if check_package_source "${PACKAGES[BROTLI]}"; then
    BROTLI_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    build_package "${PACKAGES[BROTLI]}" "$BROTLI_CMAKE_OPTS"
fi

# LUA
if check_package_source "${PACKAGES[LUA]}"; then
    cd "$SRC_ROOT/${PACKAGES[LUA]}"
    if [[ -f "$(dirname "$0")/CMakeLists.txt" ]]; then
        cp "$(dirname "$0")/CMakeLists.txt" ./
    else
        log_error "CMakeLists.txt not found for LUA"
        exit 1
    fi
    
    # Patch CMakeLists.txt for LUA compatibility
    sed -i 's/\( LUA_COMPAT_ALL \)\()\)/\1LUA_COMPAT_5_1 LUA_COMPAT_5_2 LUA_COMPAT_5_3 \2/' CMakeLists.txt
    
    LUA_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    build_package "${PACKAGES[LUA]}" "$LUA_CMAKE_OPTS"
fi

# APR
if check_package_source "${PACKAGES[APR]}"; then
    APR_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DMIN_WINDOWS_VER=0x0600 -DAPR_HAVE_IPV6=ON -DAPR_INSTALL_PRIVATE_H=ON -DAPR_BUILD_TESTAPR=OFF -DINSTALL_PDB=$INSTALL_PDB"
    build_package "${PACKAGES[APR]}" "$APR_CMAKE_OPTS"
fi

# APR-UTIL
if check_package_source "${PACKAGES[APR_UTIL]}"; then
    APR_UTIL_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DAPU_HAVE_CRYPTO=ON -DAPR_BUILD_TESTAPR=OFF -DINSTALL_PDB=$INSTALL_PDB"
    build_package "${PACKAGES[APR_UTIL]}" "$APR_UTIL_CMAKE_OPTS"
fi

# NGHTTP2
if check_package_source "${PACKAGES[NGHTTP2]}"; then
    NGHTTP2_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DSTATIC_LIB_SUFFIX=_static -DENABLE_LIB_ONLY=ON"
    build_package "${PACKAGES[NGHTTP2]}" "$NGHTTP2_CMAKE_OPTS"
fi

# CURL
if check_package_source "${PACKAGES[CURL]}"; then
    cd "$SRC_ROOT/${PACKAGES[CURL]}"
    
    # Apply patches based on configuration
    if [[ "$CURL_USE_OPENSSL" == "ON" ]]; then
        # Patch lib/url.c for native CA store
        sed -i '/return result;/,/#endif$/{
            /return result;/a\
#if defined(USE_WIN32_CRYPTO)\
/* Mandate Windows CA store to be used */\
if(!set->ssl.primary.CAfile && !set->ssl.primary.CApath) {\
  /* User and environment did not specify any CA file or path.*/\
  set->ssl.native_ca_store = TRUE;\
}\
#endif
        }' lib/url.c
    fi
    
    if [[ "$CURL_USE_OPENSSL" == "ON" && "$CURL_DEFAULT_SSL_BACKEND" == "SCHANNEL" ]]; then
        # Patch CMakeLists.txt for default SSL backend
        sed -i '/if(CURL_USE_OPENSSL)/a\
  add_definitions(-DCURL_DEFAULT_SSL_BACKEND="schannel")' CMakeLists.txt
    fi
    
    # Reduce batch size in docs
    sed -i 's/\(_files_per_batch\s\+\)200\()\)/\1100\2/' docs/libcurl/CMakeLists.txt
    
    CURL_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCURL_USE_OPENSSL=$CURL_USE_OPENSSL -DCURL_USE_SCHANNEL=ON -DCURL_WINDOWS_SSPI=ON -DCURL_BROTLI=ON -DUSE_NGHTTP2=ON -DHAVE_LDAP_SSL=ON -DENABLE_UNICODE=ON -DCURL_STATIC_CRT=OFF -DUSE_WIN32_CRYPTO=ON -DUSE_LIBIDN2=OFF -DCURL_USE_LIBPSL=OFF -DCURL_USE_LIBSSH2=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON"
    build_package "${PACKAGES[CURL]}" "$CURL_CMAKE_OPTS"
fi

# HTTPD
if check_package_source "${PACKAGES[HTTPD]}"; then
    cd "$SRC_ROOT/${PACKAGES[HTTPD]}"
    
    # Apply various patches
    sed -i 's/\(^# \)\(.+ApacheMonitor.+\)/\2/' CMakeLists.txt
    sed -i 's/\(^CREATEPROCESS_MANIFEST\)/\/\/ \1/' support/win32/ApacheMonitor.rc
    
    # Add WinTTY console binary build
    sed -i '/wtsapi32)/a\
\
# Build WinTTY console binary\
ADD_EXECUTABLE(WinTTY support/win32/wintty.c)\
SET(install_targets ${install_targets} WinTTY)\
SET_TARGET_PROPERTIES(WinTTY PROPERTIES WIN32_EXECUTABLE TRUE)\
SET_TARGET_PROPERTIES(WinTTY PROPERTIES COMPILE_FLAGS "${EXTRA_COMPILE_FLAGS}")\
SET_TARGET_PROPERTIES(WinTTY PROPERTIES LINK_FLAGS "/subsystem:console")' CMakeLists.txt
    
    # Check for mod_rewrite patch for version 2.4.62
    if [[ "${PACKAGES[HTTPD]}" == *"2.4.62"* ]]; then
        # Apply Eric Coverner's patch r1919860
        sed -i '/int is_proxyreq = 0;/a\
    int prefix_added = 0;' modules/mappers/mod_rewrite.c
        
        sed -i '/newuri = apr_pstrcat.*$/a\
        prefix_added = 1;' modules/mappers/mod_rewrite.c
    fi
    
    # Check for mod_log_rotate
    if [[ -f "modules/loggers/mod_log_rotate.c" ]]; then
        sed -i '/forensic+I+/a\
rotate+I+log rotation through server process"' CMakeLists.txt
    fi
    
    HTTPD_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DENABLE_MODULES=i -DINSTALL_PDB=$INSTALL_PDB"
    build_package "${PACKAGES[HTTPD]}" "$HTTPD_CMAKE_OPTS"
    
    # Install additional support scripts
    sed '/^#.*perlbin/d' "$SRC_ROOT/${PACKAGES[HTTPD]}/support/dbmmanage.in" > "$PREFIX/bin/dbmmanage.pl"
    cp "$SRC_ROOT/${PACKAGES[HTTPD]}/docs/cgi-examples/printenv" "$PREFIX/cgi-bin/printenv.pl" 2>/dev/null || true
fi

# MOD_FCGID
if check_package_source "${PACKAGES[MOD_FCGID]}"; then
    MOD_FCGID_CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DINSTALL_PDB=NO"
    build_package "${PACKAGES[MOD_FCGID]}" "$MOD_FCGID_CMAKE_OPTS" "modules/fcgid"
fi

log_info "Build process completed successfully!"