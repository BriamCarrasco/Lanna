# Analiza Lanna con el SonarQube local (http://localhost:9000).
#
# Uso:
#   .\scripts\sonar.ps1               # pruebas con cobertura + analisis
#   .\scripts\sonar.ps1 -SkipTests    # solo analisis
#
# Token: genera uno en SonarQube (Mi cuenta > Seguridad) y definelo en
# $env:SONAR_TOKEN, o guardalo en .sonar-token en la raiz del proyecto.

param(
    [switch]$SkipTests,
    [string]$HostUrl = 'http://host.docker.internal:9000'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$token = $env:SONAR_TOKEN
$tokenFile = Join-Path $root '.sonar-token'
if (-not $token -and (Test-Path $tokenFile)) {
    $token = (Get-Content $tokenFile -Raw).Trim()
}
if (-not $token) {
    throw 'Falta el token: define $env:SONAR_TOKEN o crea el archivo .sonar-token.'
}

try {
    $status = Invoke-RestMethod 'http://localhost:9000/api/system/status'
} catch {
    throw 'SonarQube no responde en http://localhost:9000. Inicia el contenedor con: docker start sonarqube'
}
if ($status.status -ne 'UP') {
    throw "SonarQube no esta listo (estado: $($status.status))."
}

$out = Join-Path $root 'build/sonar'
New-Item -ItemType Directory -Force $out | Out-Null
$prefix = $root.Replace('\', '/').TrimEnd('/') + '/'

function ConvertTo-ScannerPath([string]$path) {
    $path = $path.Replace('\', '/')
    if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        $path = '/usr/src/' + $path.Substring($prefix.Length)
    }
    $path
}

function Write-Report([string]$name, [string[]]$lines) {
    $text = ($lines -join "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $out $name), $text, (New-Object Text.UTF8Encoding $false))
}

Write-Host '==> dart analyze' -ForegroundColor Cyan
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$issues = dart analyze --format=machine 2>&1 | ForEach-Object { "$_" } |
    Where-Object { $_ -match '^[A-Z]+\|[A-Z_]+\|[A-Z_]+\|' } |
    ForEach-Object {
        $parts = $_ -split '\|', 5
        $parts[3] = ConvertTo-ScannerPath $parts[3].Replace('\\', '\')
        $parts -join '|'
    }
$ErrorActionPreference = $previous
Write-Report 'analysis.txt' @($issues)
Write-Host "    $(@($issues).Count) avisos del analizador"

if (-not $SkipTests) {
    Write-Host '==> flutter test --coverage' -ForegroundColor Cyan
    $events = flutter test --coverage --machine
    $failed = $LASTEXITCODE -ne 0
    $events = $events | ForEach-Object {
        [regex]::Replace($_, '"path":"((?:[^"\\]|\\.)*)"', {
            param($m)
            $path = $m.Groups[1].Value.Replace('\\', '\')
            '"path":"' + (ConvertTo-ScannerPath $path) + '"'
        })
    }
    Write-Report 'tests.output' @($events)
    $lcov = Join-Path $root 'coverage/lcov.info'
    if (Test-Path $lcov) {
        Write-Report 'lcov.info' @(Get-Content $lcov | ForEach-Object {
            if ($_.StartsWith('SF:')) { 'SF:' + (ConvertTo-ScannerPath $_.Substring(3)) } else { $_ }
        })
    }
    if ($failed) {
        Write-Warning 'Hay pruebas fallidas; el analisis sigue con la cobertura generada.'
    }
}

Write-Host '==> sonar-scanner' -ForegroundColor Cyan
docker run --rm `
    -e SONAR_HOST_URL=$HostUrl `
    -e SONAR_TOKEN=$token `
    -v "${root}:/usr/src" `
    sonarsource/sonar-scanner-cli:latest
if ($LASTEXITCODE -ne 0) { throw 'El analisis de SonarQube fallo.' }

Write-Host '==> Resultado: http://localhost:9000/dashboard?id=lanna' -ForegroundColor Green
