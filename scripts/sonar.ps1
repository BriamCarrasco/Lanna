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

if (-not $SkipTests) {
    Write-Host '==> flutter test --coverage' -ForegroundColor Cyan
    flutter test --coverage
    if ($LASTEXITCODE -ne 0) {
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
