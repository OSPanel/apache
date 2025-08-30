@echo off

rem ---------------------------------------------------------------------------
rem NEW: Ensure base folder structure exists and download all sources unconditionally
rem      (do not check for presence — assume the disk is empty)
rem ---------------------------------------------------------------------------

set "BUILD_BASE=C:\Development\Apache24\build"
set "PREFIX=C:\Apache24"
set "_SRC_ROOT=C:\Development\Apache24\src"

mkdir "C:\Development" 2>nul
mkdir "C:\Development\Apache24" 2>nul
mkdir "C:\Development\Apache24\src" 2>nul
mkdir "C:\Development\Apache24\build" 2>nul
mkdir "%PREFIX%" 2>nul
mkdir "%PREFIX%\bin" 2>nul
mkdir "%PREFIX%\lib" 2>nul
mkdir "%PREFIX%\include" 2>nul
mkdir "%PREFIX%\conf" 2>nul
mkdir "%PREFIX%\cgi-bin" 2>nul

where powershell >nul 2>&1 || (
  echo PowerShell not found. Please ensure PowerShell is installed and in PATH.
  exit /b 1
)

set "ZLIB=zlib-1.3.1"
set "PCRE2=pcre2-10.45"
set "EXPAT=expat-2.7.1"
set "OPENSSL=openssl-3.5.2"
set "LIBXML2=libxml2-2.14.5"
set "JANSSON=jansson-2.14.1"
set "BROTLI=brotli-1.1.0"
set "LUA=lua-5.4.8"
set "APR=apr-1.7.6"
set "APR-UTIL=apr-util-1.6.3"
set "NGHTTP2=nghttp2-1.66.0"
set "CURL=curl-8.15.0"
set "HTTPD=httpd-2.4.65"
set "MOD_FCGID=mod_fcgid-2.3.9"

set "URL_ZLIB=https://zlib.net/zlib-1.3.1.tar.gz"
set "URL_PCRE2=https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.gz"
set "URL_EXPAT=https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz"
set "URL_OPENSSL=https://www.openssl.org/source/openssl-3.5.2.tar.gz"
set "URL_LIBXML2=https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz"
set "URL_JANSSON=https://github.com/akheron/jansson/releases/download/v2.14.1/jansson-2.14.1.tar.gz"
set "URL_BROTLI=https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz"
set "URL_LUA=https://www.lua.org/ftp/lua-5.4.8.tar.gz"
set "URL_APR=https://downloads.apache.org/apr/apr-1.7.6.tar.gz"
set "URL_APR_UTIL=https://downloads.apache.org/apr/apr-util-1.6.3.tar.gz"
set "URL_NGHTTP2=https://github.com/nghttp2/nghttp2/releases/download/v1.66.0/nghttp2-1.66.0.tar.xz"
set "URL_CURL=https://curl.se/download/curl-8.15.0.tar.xz"
set "URL_HTTPD=https://downloads.apache.org/httpd/httpd-2.4.65.tar.bz2"
set "URL_MOD_FCGID=https://downloads.apache.org/httpd/mod_fcgid/mod_fcgid-2.3.9.tar.gz"

where 7z >nul 2>&1 && (set "SEVENZIP_AVAILABLE=1") || (set "SEVENZIP_AVAILABLE=0")

call :_fetch_and_unpack "%ZLIB%"       "%URL_ZLIB%"
call :_fetch_and_unpack "%PCRE2%"      "%URL_PCRE2%"
call :_fetch_and_unpack "%EXPAT%"      "%URL_EXPAT%"
call :_fetch_and_unpack "%OPENSSL%"    "%URL_OPENSSL%"
call :_fetch_and_unpack "%LIBXML2%"    "%URL_LIBXML2%"
call :_fetch_and_unpack "%JANSSON%"    "%URL_JANSSON%"
call :_fetch_and_unpack "%BROTLI%"     "%URL_BROTLI%"  "brotli-1.1.0"  1
call :_fetch_and_unpack "%LUA%"        "%URL_LUA%"
call :_fetch_and_unpack "%APR%"        "%URL_APR%"
call :_fetch_and_unpack "%APR-UTIL%"   "%URL_APR_UTIL%"
call :_fetch_and_unpack "%NGHTTP2%"    "%URL_NGHTTP2%"
call :_fetch_and_unpack "%CURL%"       "%URL_CURL%"
call :_fetch_and_unpack "%HTTPD%"      "%URL_HTTPD%"
call :_fetch_and_unpack "%MOD_FCGID%"  "%URL_MOD_FCGID%"

goto :_after_new_header

:_fetch_and_unpack
rem %1 = expected src folder (eg., zlib-1.3.1)
rem %2 = URL
rem %3 = override extracted dir name (optional)
rem %4 = strip top-level flag (1=yes) (optional)
set "_want_dir=%~1"
set "_url=%~2"
set "_override=%~3"
set "_strip=%~4"
set "_dest_dir=%_SRC_ROOT%\%_want_dir%"

echo Downloading: %_url%
set "_tmp=%TEMP%\dl-%RANDOM%-%RANDOM%"
mkdir "%_tmp%" >nul 2>&1

for %%F in ("%_url%") do set "_fname=%_tmp%\%%~nxF"

powershell -NoLogo -NoProfile -Command ^
  "try {Invoke-WebRequest -Uri '%_url%' -OutFile '%_fname%' -UseBasicParsing; exit 0} catch {Write-Error $_; exit 1}"
if errorlevel 1 (
  echo Download failed: %_url%
  rmdir /s /q "%_tmp%" >nul 2>&1
  exit /b 1
)

mkdir "%_tmp%\x" >nul 2>&1

set "_det="
for %%E in (.tar.gz .tar.xz .tar.bz2 .tgz .txz .tbz2 .zip .gz .xz .bz2) do (
  echo.%_fname% | findstr /i "%%E" >nul && set "_det=%%E"
)
if not defined _det set "_det=.tar.gz"

if "%SEVENZIP_AVAILABLE%"=="1" (
  if /i "%_det%"==".zip" (
    7z x -y -o"%_tmp%\x" "%_fname%" >nul
  ) else (
    7z x -y -o"%_tmp%\x" "%_fname%" >nul
    for /f "delims=" %%A in ('dir /b "%_tmp%\x\*.tar" 2^>nul') do (
      7z x -y -o"%_tmp%\x" "%_tmp%\x\%%A" >nul
    )
  )
) else (
  if /i "%_det%"==".zip" (
    powershell -NoLogo -NoProfile -Command "Expand-Archive -Path '%_fname%' -DestinationPath '%_tmp%\x' -Force"
  ) else (
    tar -xf "%_fname%" -C "%_tmp%\x" 2>nul
    if errorlevel 1 powershell -NoLogo -NoProfile -Command "tar -xf '%_fname%' -C '%_tmp%\x'"
  )
)

set "_top="
for /f "delims=" %%D in ('dir /b /ad "%_tmp%\x"') do if not defined _top set "_top=%%D"

if defined _override (set "_final=%_SRC_ROOT%\%_override%") else (set "_final=%_SRC_ROOT%\%_top%")
mkdir "%_SRC_ROOT%" 2>nul

if "%_strip%"=="1" (
  if not defined _top (
    echo Extraction failed for %_want_dir%
    rmdir /s /q "%_tmp%" >nul 2>&1
    exit /b 1
  )
  if /i "%_top%"=="%_want_dir%" (
    move "%_tmp%\x\%_top%" "%_dest_dir%" >nul
  ) else (
    move "%_tmp%\x\%_top%" "%_final%" >nul
    if /i not "%_final%"=="%_dest_dir%" ren "%_final%" "%_want_dir%" >nul
  )
) else (
  if defined _top (
    move "%_tmp%\x\%_top%" "%_dest_dir%" >nul
  ) else (
    mkdir "%_dest_dir%" >nul 2>&1
    xcopy "%_tmp%\x\*" "%_dest_dir%\*" /e /i /y >nul
  )
)

if not exist "%_dest_dir%" (
  echo Failed to prepare source folder: %_dest_dir%
  rmdir /s /q "%_tmp%" >nul 2>&1
  exit /b 1
)

echo Source ready: %_dest_dir%
rmdir /s /q "%_tmp%" >nul 2>&1
exit /b 0

:_after_new_header

rem @(#)build_all.bat 3.9 - 2025-08-11 tangent
rem
rem 1.0 - Initial release. 2020-12-17
rem 1.1 - Switch CURL to Schannel (WinSSL) rather than OpenSSL, for mod_md.
rem       Accordingly, remove LIBSSH2. Remove YAJL and MOD_SECURITY since not core
rem       ASF/Apache modules. Add LUA_COMPAT_ALL compile option to LUA. 2020-12-18
rem 1.2 - Move CURL build after NGHTTP2 and update options to include HTTP2, BROTLI and UNICODE. 2021-01-03
rem 1.3 - Use OpenSSL (conditionally) with CURL and patch to force use of native CA store on Windows.
rem       Request CURL builds with LDAPS support (Schannel based). 2021-02-16
rem 1.4 - Remove extraneous CMake INSTALL_MSVC_PDB option entries.
rem       Bump releases: PCRE (8.45), EXPAT (2.4.1), OPENSSL (1.1.1l), LIBXML2 (2.9.12),
rem       LUA (5.4.3), NGHTTP2 (1.44.0), CURL (7.78.0), HTTPD (2.4.48). 2021-08-27
rem 1.5 - Bump releases: JANSSON (2.14), NGHTTP2 (1.46.0), CURL (7.80.0), HTTPD (2.4.51). 2021-11-22
rem 1.6 - Bump releases: HTTPD (2.4.52), OpenSSL (1.1.1m). 2021-12-28
rem 1.7 - Bump EXPAT (2.4.2), CURL (7.81.0). Change LUA option LUA_COMPAT_ALL to LUA_COMPAT_5_3.
rem       Patch APR (1.7.0) handle leak (PR 61165 [Ivan Zhakov]). Refine Perl patch edits.
rem       Update VCVARSALL script path for MS Visual Studio 2022 (VS17). 2022-01-14
rem 1.8 - Bump CURL (7.82.0), EXPAT (2.4.7), HTTPD (2.4.53), LUA (5.4.4), NGHTTP2 (1.47.0),
rem       OPENSSL (1.1.1n/3.0.2), PCRE2 (10.39). Provide options to build PCRE2 rather than PCRE,
rem       and similarly build OpenSSL3 rather than OpenSSL. 2022-03-17
rem 1.9 - Bump CURL (7.83.1), EXPAT (2.4.8), HTTPD (2.4.54), LIBXML2 (2.9.14), OPENSSL (1.1.1o/3.0.3),
rem       PCRE2 (10.40), ZLIB (1.2.12). 2022-06-13
rem 2.0 - Bump CURL (7.86.0), EXPAT (2.5.0), LIBXML2 (2.10.3), OPENSSL (1.1.1s/3.0.7), ZLIB (1.2.13).
rem       Add option to set CURL default SSL backend to Schannel rather than OpenSSL. 2022-11-10
rem 2.1 - Bump APR (1.7.2), APR-UTIL (1.6.3), CURL (7.87.0), HTTPD (2.4.55), NGHTTP2 (1.51.0),
rem       PCRE2 (10.42). 2023-02-05
rem 2.2 - Bump CURL (7.88.1), HTTPD (2.4.56), NGHTTP2 (1.52.0), OPENSSL (1.1.1t/3.0.8). 2023-03-08
rem 2.3 - Bump APR (1.7.4), CURL (8.0.1), HTTPD (2.4.57), LIBXML2 (2.11.2), OPENSSL (1.1.1t/3.1.0). 2023-05-12
rem 2.4 - Bump CURL (8.2.1), LIBXML2 (2.11.5), LUA (5.4.6), NGHTTP2 (1.55.1), OPENSSL (1.1.1v/3.1.2). 2023-08-10
rem 2.5 - Bump BROTLI (1.1.0), CURL (8.4.0), HTTPD (2.4.58), NGHTTP2 (1.57.0), OPENSSL (1.1.1w/3.1.3). 2023-10-20
rem 2.6 - Patch HTTPD ApacheMonitor.rc file to comment out MANIFEST file reference, which otherwise
rem       causes a duplicate resource cvtres/link error following recent updates to VS2022.
rem       Bump CURL (8.6.0), LIBXML2 (2.12.5), NGHTTP2 (1.59.0), OPENSSL (3.1.5), ZLIB (1.3.1). 2024-02-04
rem 2.7 - Bump CURL (8.7.1), EXPAT (2.6.2), HTTPD (2.4.59), LIBXML2 (2.12.6), NGHTTP2 (1.61.0), PCRE2 (10.43). 2024-04-04
rem 2.8 - Bump CURL (8.8.0), LIBXML2 (2.12.7), NGHTTP2 (1.62.1), OPENSSL (3.1.6), PCRE2 (10.44). 2024-06-07
rem 2.9 - Bump HTTPD (2.4.62), LIBXML2 (2.13.2), LUA (5.4.7). 2024-07-25
rem 3.0 - Bump APR (1.7.5), CURL (8.9.1), LIBXML2 (2.13.3), NGHTTP2 (1.63.0), OPENSSL (3.1.17).
rem       Add option to CURL build to disable searching for idn2 library. 2024-09-06
rem 3.1 - Bump CURL (8.11.0), EXPAT (2.6.4), LIBXML2 (2.13.5), NGHTTP2 (1.64.0). Patch mod_rewrite.c
rem       to apply Eric Coverner's patch r1919860 as mentioned in the Apache Lounge 2.4.62 Changelog.
rem       Expose result of mklink command when creating APR symbolic links, in case it fails. 2024-11-13
rem 3.2 - Bump CURL (8.11.1), HTTPD (2.4.63), and OPENSSL (3.4.0). 2025-01-24
rem 3.3 - Bump CURL (8.12.1), LIBXML2 (2.13.6), and PCRE (10.45). Regress OPENSSL (3.3.3).
rem       Add options to CURL build to disable using libpsl and libssh2 libraries.
rem       Add BUILD_TYPE option support to OpenSSL. 2025-03-01
rem 3.4 - Bump CURL (8.13.0), EXPAT (2.7.1), JANSSON (2.14.1), LIBXML2 (2.14.1), and NGHTTP2 (1.65.0).
rem       Don't define VCVARSALL variable if already set. Drop support for old PCRE series and revise CMake options.
rem       Switch LIBXML2 build to using CMake. Revise CURL CMake config to prevent possible command line overflow.
rem       Resolve mod_session_crypto issue by updating APR-UTIL build to use OpenSSL with APU_HAVE_CRYPTO.
rem       Refine script logic when BUILD_TYPE is set to DEBUG. 2025-04-08
rem 3.5 - Bump APR (1.7.6), CURL (8.14.1), HTTPD (2.4.64), LIBXML2 (2.14.4), LUA (5.4.8), NGHTTP2 (1.66.0),
rem       and OPENSSL (3.5.1). Drop OpenSSL 1.x series. Build CURL shared and static libs at same time.
rem       Build HTTPD mod_log_rotate (JBlond) module if source file present. 2025-07-10
rem 3.6 - Bump CURL (8.15.0), HTTPD (2.4.65), LIBXML2 (2.14.5). 2025-07-25
rem 3.7 - Patch HTTPD CMakeLists.txt file to build WinTTY console binary. 2025-08-05
rem 3.8 - Rework LUA CMakeLists.txt file patch, and CURL edits to match code updates. 2025-08-09
rem 3.9 - Refine LIBXML2 CMake options, correct APR-UTIL string check logic, plus CURL edit comment. 2025-08-11

rem Apache build command file for Windows.
rem
setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

rem Set required build base folder and target prefix.
rem
set BUILD_BASE=C:\Development\Apache24\build
set PREFIX=C:\Apache24

rem Set required build platform to x86 or x64.
rem
rem set PLATFORM=x86
set PLATFORM=x64

rem Set required build type to Release or Debug.
rem
rem set BUILD_TYPE=Debug
set BUILD_TYPE=Release

rem Request PDB files - ON or OFF.
rem
set INSTALL_PDB=OFF

rem Use OpenSSL with CURL - ON or OFF.
rem
set CURL_USE_OPENSSL=ON
rem
rem Specify CURL default SSL backend. Defaults to OpenSSL if not specified.
rem NB - you can change the SSL backend at run time with environment variable CURL_SSL_BACKEND.
rem
set CURL_DEFAULT_SSL_BACKEND=SCHANNEL

rem ------------------------------------------------------------------------------
rem
rem Define path to MS Visual Studio build environment script.

for /f "usebackq tokens=*" %%i in (`vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    set VSPATH=%%i
)

if not defined VSPATH (
    echo Could not find Visual Studio installation.
    exit /b 1
)

set VCVARSALL=%VSPATH%\VC\Auxiliary\Build\vcvarsall.bat

if exist "%VCVARSALL%" (
    echo Using "%VCVARSALL%"
    call "%VCVARSALL%" %PLATFORM%
) else (
    echo Could not find "%VCVARSALL%"
    exit /b 1
)

rem ------------------------------------------------------------------------------
rem
rem ZLIB

rem Check for package and switch to source folder.
rem
call :check_package_source %ZLIB%

if !STATUS! == 0 (
  set "ZLIB_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DBUILD_SHARED_LIBS=ON -DINSTALL_PKGCONFIG_DIR=%PREFIX%/lib/pkgconfig"
  call :build_package %ZLIB% "!ZLIB_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem PCRE2

rem Check for package and switch to source folder.
rem
call :check_package_source %PCRE2%

if !STATUS! == 0 (
  rem Patch CMakeLists.txt to change man page install path, and that of cmake config files.
  rem
  perl -pi.bak -e ^" ^
    s~(^.+DESTINATION ^)(man^)~${1}share/${2}~; ^
    s~(^install.+DESTINATION ^)(cmake^)~${1}lib/${2}/pcre2-\x24\x7BPCRE2_MAJOR\x7D.\x24\x7BPCRE2_MINOR\x7D~; ^
    ^" CMakeLists.txt

  set "PCRE2_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DBUILD_SHARED_LIBS=ON -DPCRE2_BUILD_TESTS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_SUPPORT_JIT=OFF -DPCRE2_SUPPORT_UNICODE=ON -DPCRE2_NEWLINE=CRLF -DINSTALL_MSVC_PDB=%INSTALL_PDB%"
  call :build_package %PCRE2% "!PCRE2_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem EXPAT

rem Check for package source folder.
rem
call :check_package_source %EXPAT%

if !STATUS! == 0 (
  set "EXPAT_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE%"
  call :build_package %EXPAT% "!EXPAT_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem OPENSSL

rem Check for package and switch to source folder.
rem
call :check_package_source %OPENSSL%

if !STATUS! == 0 (
  echo. & echo Building %OPENSSL%

  if /i "%PLATFORM%" == "x64" (
    set OS_COMPILER=VC-WIN64A
  ) else (
    set OS_COMPILER=VC-WIN32
  )

  if /i "%BUILD_TYPE%" == "Release" (
    set OPENSSL_BUILD_TYPE=--release
  ) else (
    set OPENSSL_BUILD_TYPE=--debug
  )
  set "OPENSSL_CONFIGURE_OPTS=--prefix=%PREFIX% --libdir=lib --openssldir=%PREFIX%\conf --with-zlib-include=%PREFIX%\include shared zlib-dynamic enable-camellia no-idea no-mdc2 %OPENSSL_BUILD_TYPE% -DFD_SETSIZE=32768"

  perl Configure !OS_COMPILER! !OPENSSL_CONFIGURE_OPTS! & call :get_status
  if !STATUS! == 0 (
    if exist makefile (
      if /i "%INSTALL_PDB%"=="OFF" (
        perl -pi.bak -e ^" ^
          s~^(INSTALL_.*PDBS=^).*~${1}nul~; ^
          ^" makefile
      )
      rem Make clean not distclean, else Makefile gets deleted.
      rem
      nmake clean 2>nul
      nmake & call :get_status
      if !STATUS! == 0 (
        nmake install & call :get_status
        if not !STATUS! == 0 (
          echo nmake install for %OPENSSL% failed with status !STATUS!
          exit /b !STATUS!
        )
      ) else (
        echo nmake for %OPENSSL% failed with status !STATUS!
        exit /b !STATUS!
      )
    ) else (
      echo Cannot find Makefile for %OPENSSL% in !SRC_DIR!
      exit /b !STATUS!
    )
  ) else (
    echo perl configure for %OPENSSL% failed with status !STATUS!
    exit /b !STATUS!
  )
)

rem ------------------------------------------------------------------------------
rem
rem LIBXML2

rem Check for package and switch to source folder.
rem
call :check_package_source %LIBXML2%

if !STATUS! == 0 (
  if /i "%BUILD_TYPE%" == "Release" (
    set LIBXML2_DEBUG_MODULE=OFF
  ) else (
    set LIBXML2_DEBUG_MODULE=ON
  )
  set "LIBXML2_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DBUILD_SHARED_LIBS=ON -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_ZLIB=ON -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_DEBUG=!LIBXML2_DEBUG_MODULE!"
  call :build_package %LIBXML2% "!LIBXML2_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem JANSSON

rem Check for package and switch to source folder.
rem
call :check_package_source %JANSSON%

if !STATUS! == 0 (
  set "JANSSON_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DJANSSON_BUILD_SHARED_LIBS=ON -DJANSSON_BUILD_DOCS=OFF -DJANSSON_INSTALL_CMAKE_DIR=lib/cmake/jansson"
  call :build_package %JANSSON% "!JANSSON_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem BROTLI

rem Check for package and switch to source folder.
rem
call :check_package_source %BROTLI%

if !STATUS! == 0 (
  set "BROTLI_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE%"
  call :build_package %BROTLI% "!BROTLI_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem LUA

rem Check for package and switch to source folder.
rem
call :check_package_source %LUA%

if !STATUS! == 0 (
  if exist "%~dp0CMakeLists.txt" (
    copy /y "%~dp0CMakeLists.txt" "!SRC_DIR!\CMakeLists.txt" 1>nul
  ) else (
    echo CMakeLists.txt not found: "%~dp0CMakeLists.txt"
    exit /b 1
  )
  rem Patch CMakeLists.txt to add LUA_COMPAT_5_X compile options.
  rem
  perl -pi.bak -e ^" ^
    s~( LUA_COMPAT_ALL ^)(^\^)^)~${1}LUA_COMPAT_5_1 LUA_COMPAT_5_2 LUA_COMPAT_5_3 ${2}~; ^
    ^" CMakeLists.txt

  set "LUA_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE%"
  call :build_package %LUA% "!LUA_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem APR

rem Check for package and switch to source folder.
rem
call :check_package_source %APR%

if !STATUS! == 0 (
  set "APR_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DMIN_WINDOWS_VER=0x0600 -DAPR_HAVE_IPV6=ON -DAPR_INSTALL_PRIVATE_H=ON -DAPR_BUILD_TESTAPR=OFF -DINSTALL_PDB=%INSTALL_PDB%"
  call :build_package %APR% "!APR_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem APR-UTIL

rem Check for package and switch to source folder.
rem
call :check_package_source %APR-UTIL%

if !STATUS! == 0 (
  rem Check if we're building APR-UTIL 1.6.3
  rem
  if not x%APR-UTIL:1.6.3=% == x%APR-UTIL% (
    rem Patch include\apu.hwc and CMakelists.txt to support OpenSSL, which is needed with APU_HAVE_CRYPTO.
    rem
    if exist "%PREFIX%\lib\libcrypto.lib" (
      perl -pi.bak -e ^" ^
        s~^(APU_HAVE_OPENSSL[\s]+^)0$~${1}\@apu_have_openssl_10\@~; ^
        ^" include\apu.hwc

      perl -pi.bak -e ^" ^
        s~^([\s]+^)(SET.+apu_have_crypto_10 1\^)^)$~${1}${2} \n${1}SET(apu_have_openssl_10 1^)~; ^
        ^" CMakeLists.txt
    )
  )

  set "APR-UTIL_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DOPENSSL_ROOT_DIR=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DAPU_HAVE_CRYPTO=OFF -DAPR_BUILD_TESTAPR=OFF -DINSTALL_PDB=%INSTALL_PDB%" -DAPRUTIL_WITH_ODBC=OFF -DAPRUTIL_WITH_LDAP=OFF
  call :build_package %APR-UTIL% "!APR-UTIL_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem NGHTTP2

rem Check for package and switch to source folder.
rem
call :check_package_source %NGHTTP2%

if !STATUS! == 0 (
  set "NGHTTP2_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DSTATIC_LIB_SUFFIX=_static -DENABLE_LIB_ONLY=ON"
  call :build_package %NGHTTP2% "!NGHTTP2_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem CURL

rem Check for package and switch to source folder.
rem
call :check_package_source %CURL%

if !STATUS! == 0 (
  if /i "%CURL_USE_OPENSSL%" == "ON" (
    rem Patch lib\url.c to force use of native CA store on Windows.
    rem
    perl -pi.bak -0777 -Mopen=OUT,:raw -e ^" ^
    s~(return result;\n#endif\n#endif$^)\n  }~${1} \n#if defined(USE_WIN32_CRYPTO^)\n^
    /* Mandate Windows CA store to be used */\n^
    if(\x21set-\x3Essl.primary.CAfile \x26\x26 \x21set-\x3Essl.primary.CApath^) {\n^
      /* User and environment did not specify any CA file or path.*/\n^
      set-\x3Essl.native_ca_store = TRUE;\n^
    }\n#endif\n  }~smg; ^
    ^" lib\url.c
  ) else (
    rem Remove above lib\url.c patch if present.
    rem
    perl -pi.bak -0777 -Mopen=OUT,:raw -e ^" ^
    s~(return result;\n#endif\n#endif^) \n.+native_ca_store = TRUE;\n    }\n#endif~${1}~smg; ^
    ^" lib\url.c
  )

  if /i "%CURL_USE_OPENSSL%" == "ON" if /i "%CURL_DEFAULT_SSL_BACKEND%" == "SCHANNEL" (
    rem Patch CMakeLists.txt to add a compiler definition for a default SSL backend of Schannel.
    rem
    perl -pi.bak -e ^" ^
      s~(if\(CURL_USE_OPENSSL\^)^)\n~${1} \n  add_definitions(-DCURL_DEFAULT_SSL_BACKEND=\x22schannel\x22^)\n~m; ^
      ^" CMakeLists.txt
  ) else (
    rem Remove above CMakeLists.txt patch if present.
    rem
    perl -pi.bak -e ^" ^
      s~(if\(CURL_USE_OPENSSL\^)^) \n~${1}\n~m; ^
      s~[ ]+add_definitions\(-DCURL_DEFAULT_SSL_BACKEND=\x22schannel\x22\^)\n~~m; ^
      ^" CMakeLists.txt
  )

  rem Patch doc build CMakeLists.txt to reduce number of files processed per batch loop.
  rem This reduces the chance of line length overflow problems with Windows command shell.
  rem
  perl -pi.bak -e ^" ^
    s~(_files_per_batch[\s]+^)200(\^)^)~${1}100${2}~m; ^
    ^" docs\libcurl\CMakeLists.txt

  set "CURL_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DCURL_USE_OPENSSL=%CURL_USE_OPENSSL% -DCURL_USE_SCHANNEL=ON -DCURL_WINDOWS_SSPI=ON -DCURL_BROTLI=ON -DUSE_NGHTTP2=ON -DHAVE_LDAP_SSL=ON -DENABLE_UNICODE=ON -DCURL_STATIC_CRT=OFF -DUSE_WIN32_CRYPTO=ON -DUSE_LIBIDN2=OFF -DCURL_USE_LIBPSL=OFF -DCURL_USE_LIBSSH2=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON"
  call :build_package %CURL% "!CURL_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!
)

rem ------------------------------------------------------------------------------
rem
rem HTTPD

rem Check for package and switch to source folder.
rem
call :check_package_source %HTTPD%

if !STATUS! == 0 (
  rem Patch CMakeLists.txt to build ApacheMonitor.
  rem
  perl -pi.bak -e ^" ^
    s~(^^# ^)(.+ApacheMonitor.+^)~${2}~; ^
    ^" CMakeLists.txt

  rem Patch ApacheMonitor.rc to comment out MANIFEST file reference.
  rem
  perl -pi.bak -e ^" ^
    s~(^^CREATEPROCESS_MANIFEST^)~// ${1}~; ^
    ^" support\win32\ApacheMonitor.rc

  rem Patch CMakeLists.txt to build WinTTY console binary.
  rem
  perl -pi.bak -e ^" ^
    s~(wtsapi32\^)^)\n~${1} \n\n^
    # Build WinTTY console binary\n^
    ADD_EXECUTABLE(WinTTY support/win32/wintty.c^)\n^
    SET(install_targets \x24\x7Binstall_targets\x7D WinTTY^)\n^
    SET_TARGET_PROPERTIES(WinTTY PROPERTIES WIN32_EXECUTABLE TRUE^)\n^
    SET_TARGET_PROPERTIES(WinTTY PROPERTIES COMPILE_FLAGS \x22\x24\x7BEXTRA_COMPILE_FLAGS\x7D\x22^)\n^
    SET_TARGET_PROPERTIES(WinTTY PROPERTIES LINK_FLAGS \x22/subsystem:console\x22^)\n^
    ~m; ^
    ^" CMakeLists.txt

  rem Check if we're building HTTPD 2.4.62 and if so patch mod_rewrite.c
  rem
  if not x%HTTPD:2.4.62=% == x%HTTPD% (
    rem Patch mod_rewrite.c to apply Eric Coverner's patch r1919860 as mentioned
    rem in the Apache Lounge 2.4.62 Changelog
    rem
    rem Note \h denotes horizontal whitespace...
    perl -pi.bak -0777 -Mopen=OUT,:raw -e ^" ^
      s~^([\h]+^)(int is_proxyreq = 0;\n^)(\n[\h]+ctx^)~${1}${2}${1}int prefix_added = 0;\n${3}~smg; ^
      s~^([\h]+^)(newuri = apr_pstrcat[^^;]+;^)\n([\h]+\}^)~${1}${2}\n${1}prefix_added = 1;\n${3}~smg; ^
      ^" modules\mappers\mod_rewrite.c
  )

  rem Patch CMakeLists.txt to build JBlond mod_log_rotate, if source module present.
  rem
  if exist "modules\loggers\mod_log_rotate.c" (
    perl -pi.bak -e ^" ^
      s~(.+^)(forensic\+I\+^)(.+^)(\x22^)\n~${1}${2}${3}${4} \n${1}rotate\+I\+log rotation through server process${4}\n~m; ^
      ^" CMakeLists.txt
  )

  set "HTTPD_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DENABLE_MODULES=i -DINSTALL_PDB=%INSTALL_PDB%"
  call :build_package %HTTPD% "!HTTPD_CMAKE_OPTS!" & if not !STATUS! == 0 exit /b !STATUS!

  rem Install additional support scripts.
  rem
  perl -pe ^" ^
    s~#.+perlbin.+\n~~m; ^
    ^" !src_dir!\support\dbmmanage.in > %PREFIX%\bin\dbmmanage.pl

  copy !src_dir!\docs\cgi-examples\printenv %PREFIX%\cgi-bin\printenv.pl 1>nul 2>&1
)

rem ------------------------------------------------------------------------------
rem
rem MOD_FCGID

rem Check for package and switch to source folder.
rem
call :check_package_source %MOD_FCGID%

if !STATUS! == 0 (
  rem Package provides both NMake makefile and experimental CMake. We use the latter.

  set "MOD_FCGID_CMAKE_OPTS=-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DINSTALL_PDB=NO"
  call :build_package %MOD_FCGID% "!MOD_FCGID_CMAKE_OPTS!" modules\fcgid & if not !STATUS! == 0 exit /b !STATUS!
)
exit /b !STATUS!

rem ------------------------------------------------------------------------------
rem
rem Get current errorlevel value and assign it to the status variable.

:get_status
call doskey /exename=err err=%%errorlevel%%
for /f "usebackq tokens=2 delims== " %%i in (`doskey /m:err`) do (set STATUS=%%i)
exit /b !STATUS!

rem ------------------------------------------------------------------------------
rem
rem Get package and version from release variable passed as first parameter.

:get_package_details
set "RELEASE=%~1"
for /f "delims=-" %%i in ('echo(%RELEASE:-=^&echo(%') do call set "PACKAGE=%%RELEASE:-%%i=%%"
for %%i in (%RELEASE:-= %) do set VERSION=%%i
exit /b

rem ------------------------------------------------------------------------------
rem
rem Check package source folder exists, from release variable passed as first parameter.
rem
:check_package_source

set "SRC_DIR=%BUILD_BASE%\..\src\%~1"
if not exist "!SRC_DIR!" (
  echo Warning for package %~1
  echo Could not find package source folder "!SRC_DIR!"
  set STATUS=1
) else (
  cd /d "!SRC_DIR!"
  set STATUS=0
)
exit /b !STATUS!

rem ------------------------------------------------------------------------------
rem
rem Build subroutine.
rem Parameter one is the package release variable.
rem Parameter two is any required CMake options.
rem Parameter three (optional) is any package sub-folder to the CMakeLists.txt file.

:build_package

call :get_package_details %~1

rem Check source folder exists, else exit (non-fatal).

call :check_package_source %~1
if not !STATUS! == 0 (
  exit /b
) else (
  if not "%~3" == "" (
    set "SRC_DIR=!SRC_DIR!\%~3"
  )
)

rem Clean up any previous build.

if exist "%BUILD_BASE%\!PACKAGE!" rmdir /s /q "%BUILD_BASE%\!PACKAGE!" 1>nul 2>&1
mkdir "%BUILD_BASE%\!PACKAGE!" 1>nul 2>&1

rem Build, make and install.

if exist "%BUILD_BASE%\!PACKAGE!" (
  cd /d "%BUILD_BASE%\!PACKAGE!"
  echo. & echo Building %~1

  rem Patch CMakeLists.txt to remove debug suffix from libraries. Messes up various builds.
  rem Tried setting CMAKE_DEBUG_POSTFIX to an empty string on the CMake command line but
  rem this doesn't work with all packages, e.g. PCRE2, EXPAT, LIBXML2, etc.

  perl -pi -e ^" ^
    s~((DEBUG_POSTFIX^|POSTFIX_DEBUG^)\s+^)([\x22]*^)[-_]*(^|s^)d([\x22]*^)~${1}\x22${4}\x22~; ^
    ^" "!SRC_DIR!\CMakeLists.txt"

  rem Run CMake to create an NMake makefile, which we then process.

  cmake -G "NMake Makefiles" %~2 -DCMAKE_EXE_LINKER_FLAGS="/DYNAMICBASE" -DCMAKE_SHARED_LINKER_FLAGS="/DYNAMICBASE" -DCMAKE_C_FLAGS="/DFD_SETSIZE=32768" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -S "!SRC_DIR!" -B . & call :get_status
  if !STATUS! == 0 (
    nmake & call :get_status
    if !STATUS! == 0 (
      nmake install & call :get_status
      if !STATUS! == 0 (
        exit /b !STATUS!
      ) else (
        echo nmake install for !PACKAGE! failed with exit status !STATUS!
        exit /b !STATUS!
      )
    ) else (
      echo nmake for !PACKAGE! failed with exit status !STATUS!
      exit /b !STATUS!
    )
  ) else (
    echo cmake for !PACKAGE! failed with exit status !STATUS!
    exit /b !STATUS!
  )
) else (
  echo Failed to make folder "%BUILD_BASE%\!PACKAGE!"
  exit /b 1
)
exit /b