# SPDX-License-Identifier: GPL-3.0-or-later
param(
    [switch]$SkipChecks,
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$releaseCertificate = '4f107b17d09f846dff2eba95eb04ad65db059639a0a57fe8690fe4b2f6a8c5f5'
$vcRuntime = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')

function Step([string]$message) {
    Write-Host ''
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Invoke-Checked([string]$command, [string[]]$arguments) {
    & $command @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$command $($arguments -join ' ') terminó con código $LASTEXITCODE"
    }
}

function Find-Tool([string]$name, [string[]]$candidates) {
    $found = Get-Command $name -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    throw "No se encontró $name"
}

$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'pubspec.yaml no tiene una versión con el formato x.y.z+n'
}
$version = $Matches[1]
$build = $Matches[2]
$dist = Join-Path $root "dist\$version"
$symbols = Join-Path $root "build\symbols\$version"

$settings = Get-Content (Join-Path $root 'lib\features\settings\settings_screen.dart') -Raw
if ($settings -notmatch "(?m)^const _appVersion = '([^']+)';") {
    throw 'No se encontró _appVersion en settings_screen.dart'
}
if ($Matches[1] -ne $version) {
    throw "La versión de Ajustes ($($Matches[1])) no coincide con pubspec.yaml ($version)"
}

$pending = git -C $root status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer el estado de git' }
if ($pending -and -not $AllowDirty) {
    throw "Hay cambios sin commit: el release no correspondería a ningún commit. Usa -AllowDirty solo para builds de prueba.`n$($pending -join "`n")"
}

if (-not (Test-Path (Join-Path $root 'android\key.properties'))) {
    throw 'Falta android\key.properties: el APK saldría firmado con la clave de debug'
}

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory |
    Sort-Object { [version]($_.Name -replace '[^\d.].*$', '') } |
    Select-Object -Last 1
if (-not $buildTools) { throw "No hay build-tools en $sdk" }
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$iscc = Find-Tool 'ISCC.exe' @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
)

Write-Host "Lanna $version (build $build)" -ForegroundColor Green
if ($pending) {
    Write-Host 'Build de prueba con cambios sin commit: no publicar' -ForegroundColor Yellow
}

if (-not $SkipChecks) {
    Step 'Análisis estático'
    Invoke-Checked 'flutter' @('analyze')
    Step 'Tests'
    Invoke-Checked 'flutter' @('test')
}

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $symbols) { Remove-Item $symbols -Recurse -Force }

Step 'APK de Android'
Invoke-Checked 'flutter' @(
    'build', 'apk', '--release',
    '--obfuscate', "--split-debug-info=$symbols\android"
)
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'

Step 'Verificando la firma del APK'
$certificates = & $apksigner verify --print-certs $apk
if ($LASTEXITCODE -ne 0) { throw 'apksigner no pudo verificar el APK' }
$digest = $certificates |
    Select-String 'certificate SHA-256 digest: ([0-9a-f]{64})' |
    ForEach-Object { $_.Matches[0].Groups[1].Value } |
    Select-Object -First 1
if ($digest -ne $releaseCertificate) {
    throw "El APK no está firmado con la clave de release (huella: $digest)"
}
Write-Host "Firma correcta: $digest"
$apkName = "lanna-$version-android.apk"
Copy-Item $apk (Join-Path $dist $apkName)

Step 'Build de Windows'
Invoke-Checked 'flutter' @(
    'build', 'windows', '--release',
    '--obfuscate', "--split-debug-info=$symbols\windows"
)
$bundle = Join-Path $root 'build\windows\x64\runner\Release'
foreach ($dll in $vcRuntime) {
    Copy-Item (Join-Path $env:SystemRoot "System32\$dll") $bundle -Force
}

Step 'Zip portable de Windows'
$zipName = "lanna-$version-windows-x64.zip"
$staging = Join-Path $root "build\release-staging\Lanna"
if (Test-Path (Split-Path $staging)) { Remove-Item (Split-Path $staging) -Recurse -Force }
New-Item -ItemType Directory -Force $staging | Out-Null
Copy-Item (Join-Path $bundle '*') $staging -Recurse
Compress-Archive -Path $staging -DestinationPath (Join-Path $dist $zipName) -CompressionLevel Optimal

Step 'Instalador de Windows'
$setupBase = "lanna-$version-windows-x64-setup"
Invoke-Checked $iscc @(
    '/Q',
    "/DAppVersion=$version",
    "/DSourceDir=$bundle",
    "/DOutputDir=$dist",
    "/DOutputName=$setupBase",
    (Join-Path $root 'windows\installer\lanna.iss')
)

Step 'Símbolos de depuración'
$symbolsName = "lanna-$version-symbols.zip"
Compress-Archive -Path (Join-Path $symbols '*') -DestinationPath (Join-Path $dist $symbolsName) -CompressionLevel Optimal

Step 'Checksums'
$published = @($apkName, $zipName, "$setupBase.exe")
$sums = foreach ($file in $published) {
    $hash = (Get-FileHash (Join-Path $dist $file) -Algorithm SHA256).Hash.ToLower()
    "$hash  $file"
}
Set-Content -Path (Join-Path $dist 'SHA256SUMS.txt') -Value $sums -Encoding ascii

Step 'Listo'
Get-ChildItem $dist | ForEach-Object {
    '{0,-45} {1,8:N1} MB' -f $_.Name, ($_.Length / 1MB)
}
Write-Host ''
Write-Host "Archivos en $dist" -ForegroundColor Green
Write-Host "Publicar: $($published -join ', '), SHA256SUMS.txt"
Write-Host "Guardar sin publicar: $symbolsName"
