$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if (-not (Test-Path -LiteralPath sourcemap.json)) {
        & rojo sourcemap default.project.json --output sourcemap.json
        if ($LASTEXITCODE -ne 0) { throw 'Rojo sourcemap failed' }
    }
    & lune run tests/run @args
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
} finally {
    Pop-Location
}
