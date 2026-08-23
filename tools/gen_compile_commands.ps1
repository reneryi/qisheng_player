# Generates build/clangd/compile_commands.json for clangd / IDE C++ indexing.
#
# The Visual Studio CMake generator used by Flutter does not support exporting
# compile_commands.json, so we configure a separate configure-only Ninja build
# tree that produces it. Run this script after `flutter clean` or whenever the
# C++ sources / include paths change.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\gen_compile_commands.ps1

$ErrorActionPreference = "Stop"

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) {
    Write-Error "vswhere.exe not found; install Visual Studio 2022 Build Tools."
    exit 1
}

$vsJson = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.CMake.Project -format json
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vsJson)) {
    Write-Error "No Visual Studio installation with CMake and MSVC tools was found."
    exit 1
}

$vsInstallPath = (($vsJson | ConvertFrom-Json) | Select-Object -First 1).installationPath
if ([string]::IsNullOrWhiteSpace($vsInstallPath)) {
    Write-Error "Visual Studio installation path could not be determined."
    exit 1
}

$BuildTools = $vsInstallPath

$Cmake = Join-Path $BuildTools "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$Ninja = Join-Path $BuildTools "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe"
$Vcvars = Join-Path $BuildTools "VC\Auxiliary\Build\vcvars64.bat"

if (-not (Test-Path $Cmake)) { Write-Error "cmake.exe not found"; exit 1 }
if (-not (Test-Path $Ninja)) { Write-Error "ninja.exe not found"; exit 1 }
if (-not (Test-Path $Vcvars)) { Write-Error "vcvars64.bat not found"; exit 1 }

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# vcvars64.bat sets INCLUDE/LIB/PATH required by the MSVC toolchain; the
# configure step itself must run inside that environment.
$cmd = @"
call "$Vcvars" >nul 2>&1
if errorlevel 1 exit /b 1
"$Cmake" -S "$ProjectRoot\windows" -B "$ProjectRoot\build\clangd" -G Ninja `
  -DCMAKE_MAKE_PROGRAM="$Ninja" -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
"@

cmd /c $cmd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ccJson = Join-Path $ProjectRoot "build\clangd\compile_commands.json"
if (Test-Path $ccJson) {
    Write-Host "OK: $ccJson"
} else {
    Write-Error "compile_commands.json was not generated"
    exit 1
}
