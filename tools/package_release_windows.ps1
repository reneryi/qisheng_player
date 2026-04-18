param(
  [string]$Version
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"

if ([string]::IsNullOrWhiteSpace($Version)) {
  $versionLine = Select-String -Path $pubspecPath -Pattern "^version:\s*([0-9]+\.[0-9]+\.[0-9]+)" | Select-Object -First 1
  if ($null -eq $versionLine) {
    throw "Cannot resolve version from pubspec.yaml"
  }
  $Version = $versionLine.Matches[0].Groups[1].Value
}

$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
if (!(Test-Path $releaseDir)) {
  throw "Release build output not found: $releaseDir"
}

$artifactsRoot = Join-Path $repoRoot "build\release_artifacts"
New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null

$portableZipName = "coriander_player-$Version-windows-x64.zip"
$portableZipPath = Join-Path $artifactsRoot $portableZipName
if (Test-Path $portableZipPath) {
  Remove-Item $portableZipPath -Force
}
Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $portableZipPath -CompressionLevel Optimal -Force

$installerWorkDir = Join-Path $artifactsRoot "installer_work"
if (Test-Path $installerWorkDir) {
  Remove-Item $installerWorkDir -Recurse -Force
}
New-Item -ItemType Directory -Path $installerWorkDir -Force | Out-Null

$payloadZipPath = Join-Path $installerWorkDir "payload.zip"
Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $payloadZipPath -CompressionLevel Optimal -Force

$installCmdPath = Join-Path $installerWorkDir "install.cmd"
$installCmd = @'
@echo off
setlocal
set "TARGET=%LOCALAPPDATA%\Coriander Player"
set "PAYLOAD=%~dp0payload.zip"

taskkill /IM coriander_player.exe /F >nul 2>&1
taskkill /IM desktop_lyric.exe /F >nul 2>&1

if not exist "%TARGET%" mkdir "%TARGET%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%PAYLOAD%' -DestinationPath '%TARGET%' -Force"
if errorlevel 1 exit /b 1

if exist "%TARGET%\coriander_player.exe" (
  start "" "%TARGET%\coriander_player.exe"
)

exit /b 0
'@
Set-Content -Path $installCmdPath -Value $installCmd -Encoding Ascii

$installerExeName = "coriander_player-$Version-windows-x64-installer.exe"
$installerExePath = Join-Path $artifactsRoot $installerExeName
if (Test-Path $installerExePath) {
  Remove-Item $installerExePath -Force
}

$sedPath = Join-Path $installerWorkDir "installer.sed"
$sedContent = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=Coriander Player $Version install finished.
TargetName=$installerExePath
FriendlyName=Coriander Player $Version Installer
AppLaunched=install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=install.cmd
UserQuietInstCmd=install.cmd
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$installerWorkDir
[SourceFiles0]
%FILE0%=
%FILE1%=
[Strings]
FILE0=install.cmd
FILE1=payload.zip
"@
Set-Content -Path $sedPath -Value $sedContent -Encoding Ascii

$iexpressPath = Join-Path $env:WINDIR "System32\iexpress.exe"
if (!(Test-Path $iexpressPath)) {
  throw "IExpress not found: $iexpressPath"
}

& $iexpressPath /N /Q $sedPath
for ($i = 0; $i -lt 600 -and !(Test-Path $installerExePath); $i++) {
  Start-Sleep -Milliseconds 200
}
if (!(Test-Path $installerExePath)) {
  throw "Installer build failed: $installerExePath"
}

Write-Host "Portable zip: $portableZipPath"
Write-Host "Installer exe: $installerExePath"
