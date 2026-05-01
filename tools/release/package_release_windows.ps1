param(
  [string]$Version,
  [switch]$ReuseExistingPackage
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-PackageVersion {
  param(
    [string]$RequestedVersion,
    [string]$PubspecPath
  )

  if (![string]::IsNullOrWhiteSpace($RequestedVersion)) {
    return $RequestedVersion.Trim()
  }

  $versionLine = Select-String -Path $PubspecPath -Pattern "^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+\S+)?" | Select-Object -First 1
  if ($null -eq $versionLine) {
    throw "Cannot resolve version from pubspec.yaml: $PubspecPath"
  }
  return $versionLine.Matches[0].Groups[1].Value
}

function Get-IsccPath {
  $cmd = Get-Command iscc -ErrorAction SilentlyContinue
  if ($null -ne $cmd -and (Test-Path $cmd.Source)) {
    return $cmd.Source
  }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
  )

  foreach ($candidate in $candidates) {
    if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  throw "Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6 first."
}

function Test-DesktopLyricBundle {
  param(
    [string]$BundleDir
  )

  if ([string]::IsNullOrWhiteSpace($BundleDir) -or !(Test-Path $BundleDir)) {
    return $false
  }

  $exePath = Join-Path $BundleDir "desktop_lyric.exe"
  $runtimePath = Join-Path $BundleDir "flutter_windows.dll"
  $dataPath = Join-Path $BundleDir "data"
  return (Test-Path $exePath) -and (Test-Path $runtimePath) -and (Test-Path $dataPath)
}

function Build-DesktopLyricRelease {
  param(
    [string]$ProjectDir
  )

  if (!(Test-Path $ProjectDir)) {
    throw "desktop_lyric project not found: $ProjectDir"
  }

  Push-Location $ProjectDir
  try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
      throw "flutter pub get failed for desktop_lyric with exit code $LASTEXITCODE"
    }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build windows --release failed for desktop_lyric with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Resolve-DesktopLyricSourceDir {
  param(
    [string]$BuildOutputDir,
    [string]$PackagedOutputDir,
    [bool]$PreferPackagedOutput
  )

  $candidates = @()
  if ($PreferPackagedOutput) {
    $candidates += $PackagedOutputDir
    $candidates += $BuildOutputDir
  } else {
    $candidates += $BuildOutputDir
    $candidates += $PackagedOutputDir
  }

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) {
      continue
    }

    if (!(Test-Path $candidate)) {
      continue
    }

    if (Test-DesktopLyricBundle -BundleDir $candidate) {
      return $candidate
    }
  }

  throw "desktop_lyric output not found. Checked: $BuildOutputDir ; $PackagedOutputDir"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$Version = Resolve-PackageVersion -RequestedVersion $Version -PubspecPath $pubspecPath

$buildDir = Join-Path $repoRoot "build"
$distRoot = Join-Path $repoRoot "dist\windows"
$mainReleaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
$desktopLyricProjectDir = Join-Path $repoRoot "third_party\desktop_lyric"
$desktopLyricReleaseDir = Join-Path $repoRoot "third_party\desktop_lyric\build\windows\x64\runner\Release"
$releasePackageDir = Join-Path $distRoot "package"
$existingDesktopLyricPackageDir = Join-Path $releasePackageDir "desktop_lyric"
$artifactsRoot = Join-Path $distRoot "artifacts"
$artifactPackagesDir = Join-Path $artifactsRoot "packages"
$installerWorkDir = Join-Path $distRoot "installer_work"

if (!(Test-Path $mainReleaseDir)) {
  throw "Main release output not found: $mainReleaseDir"
}
if (!(Test-Path (Join-Path $mainReleaseDir "qisheng_player.exe"))) {
  throw "Main release executable missing: $(Join-Path $mainReleaseDir 'qisheng_player.exe')"
}

if (!(Test-DesktopLyricBundle -BundleDir $desktopLyricReleaseDir) -and
    !(Test-DesktopLyricBundle -BundleDir $existingDesktopLyricPackageDir)) {
  Write-Host "desktop_lyric release output not found. Building bundled desktop lyric..."
  Build-DesktopLyricRelease -ProjectDir $desktopLyricProjectDir
}

$desktopLyricSourceDir = Resolve-DesktopLyricSourceDir `
  -BuildOutputDir $desktopLyricReleaseDir `
  -PackagedOutputDir $existingDesktopLyricPackageDir `
  -PreferPackagedOutput $ReuseExistingPackage.IsPresent

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

if (!$ReuseExistingPackage.IsPresent -and (Test-Path $releasePackageDir)) {
  Remove-Item $releasePackageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releasePackageDir -Force | Out-Null

# Main application release files.
Get-ChildItem -Path $releasePackageDir | Where-Object { $_.Name -ne "desktop_lyric" } | Remove-Item -Recurse -Force
Copy-Item -Path (Join-Path $mainReleaseDir "*") -Destination $releasePackageDir -Recurse -Force

# Bundled desktop lyric component.
$desktopLyricTargetDir = Join-Path $releasePackageDir "desktop_lyric"
if (Test-Path $desktopLyricTargetDir) {
  Remove-Item $desktopLyricTargetDir -Recurse -Force
}
New-Item -ItemType Directory -Path $desktopLyricTargetDir -Force | Out-Null
Copy-Item -Path (Join-Path $desktopLyricSourceDir "*") -Destination $desktopLyricTargetDir -Recurse -Force
if (!(Test-DesktopLyricBundle -BundleDir $desktopLyricTargetDir)) {
  throw "Bundled desktop_lyric package is incomplete: $desktopLyricTargetDir"
}

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $artifactPackagesDir -Force | Out-Null
if (Test-Path $installerWorkDir) {
  Remove-Item $installerWorkDir -Recurse -Force
}
New-Item -ItemType Directory -Path $installerWorkDir -Force | Out-Null

$zipName = "Qisheng-Player-v$Version-Windows-x64.zip"
$setupName = "Qisheng-Player-v$Version-Setup-x64.exe"
$zipPath = Join-Path $artifactPackagesDir $zipName
$setupPath = Join-Path $artifactPackagesDir $setupName

$legacyPaths = @(
  (Join-Path $buildDir "release_package"),
  (Join-Path $buildDir "release_artifacts"),
  (Join-Path $buildDir $zipName),
  (Join-Path $buildDir $setupName),
  (Join-Path $buildDir "installer.iss"),
  (Join-Path $buildDir "RELEASE_NOTES.md")
)
foreach ($legacyPath in $legacyPaths) {
  if (Test-Path $legacyPath) {
    Remove-Item $legacyPath -Recurse -Force
  }
}

if (Test-Path $zipPath) {
  Remove-Item $zipPath -Force
}
if (Test-Path $setupPath) {
  Remove-Item $setupPath -Force
}

Compress-Archive -Path (Join-Path $releasePackageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal -Force

$issPath = Join-Path $installerWorkDir "installer.iss"
$escapedReleaseDir = $releasePackageDir.Replace("\", "\\")
$escapedArtifactPackagesDir = $artifactPackagesDir.Replace("\", "\\")
$escapedIconPath = (Join-Path $repoRoot "app_icon.ico").Replace("\", "\\")
$issContent = @"
#define MyAppName "Qisheng Player"
#define MyAppVersion "$Version"
#define MyAppPublisher "reneryi"
#define MyAppURL "https://github.com/reneryi/qisheng_player"
#define MyAppExeName "qisheng_player.exe"
#define ReleaseDir "$escapedReleaseDir"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
UsePreviousAppDir=no
DisableDirPage=no
DefaultGroupName={#MyAppName}
OutputDir=$escapedArtifactPackagesDir
OutputBaseFilename=Qisheng-Player-v{#MyAppVersion}-Setup-x64
SetupIconFile=$escapedIconPath
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional options:"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
"@
Set-Content -Path $issPath -Value $issContent -Encoding UTF8

$isccPath = Get-IsccPath
& $isccPath $issPath
if ($LASTEXITCODE -ne 0) {
  throw "ISCC failed with exit code $LASTEXITCODE"
}

if (!(Test-Path $setupPath)) {
  throw "Installer build failed: $setupPath"
}

# Remove legacy lowercase names to avoid accidental upload of old format.
$legacyZipPath = Join-Path $artifactsRoot "coriander_player-$Version-windows-x64.zip"
$legacySetupPath = Join-Path $artifactsRoot "coriander_player-$Version-windows-x64-installer.exe"
if (Test-Path $legacyZipPath) {
  Remove-Item $legacyZipPath -Force
}
if (Test-Path $legacySetupPath) {
  Remove-Item $legacySetupPath -Force
}

Write-Host "Version: $Version"
Write-Host "Release package: $releasePackageDir"
Write-Host "Desktop lyric source: $desktopLyricSourceDir"
Write-Host "Portable zip: $zipPath"
Write-Host "Installer exe: $setupPath"
Write-Host "Packages dir: $artifactPackagesDir"
