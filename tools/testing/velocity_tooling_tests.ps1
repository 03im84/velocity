param()

$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "velocity_tooling_tests.py"

$pythonCommand = Get-Command "python.exe" -ErrorAction SilentlyContinue

if ($null -ne $pythonCommand) {
    & $pythonCommand.Source $scriptPath
    exit $LASTEXITCODE
}

$pythonLauncher = Get-Command "py.exe" -ErrorAction SilentlyContinue

if ($null -ne $pythonLauncher) {
    & $pythonLauncher.Source -3 $scriptPath
    exit $LASTEXITCODE
}

Write-Error "Python 3 was not found."
exit 2
