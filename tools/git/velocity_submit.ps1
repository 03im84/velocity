[CmdletBinding()]
param(
    [string]$Package = "",

    [switch]$Install,

    [switch]$Submit,

    [switch]$ValidatePackage,

    [switch]$Rollback
)

$ErrorActionPreference = "Stop"

$selectedModes = @(
    $Install.IsPresent
    $Submit.IsPresent
    $ValidatePackage.IsPresent
    $Rollback.IsPresent
) | Where-Object { $_ }

if ($selectedModes.Count -gt 1) {
    Write-Error "Install, Submit, ValidatePackage and Rollback are mutually exclusive."
    exit 2
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $scriptDirectory "..\..")
)
$pythonTool = Join-Path $scriptDirectory "velocity_submit.py"

if (-not (Test-Path -LiteralPath $pythonTool -PathType Leaf)) {
    Write-Error "Velocity Submit Python engine was not found: $pythonTool"
    exit 4
}

$arguments = @($pythonTool)

if (-not [string]::IsNullOrWhiteSpace($Package)) {
    $arguments += "--package"
    $arguments += $Package
}

if ($Install) {
    $arguments += "--install"
}
elseif ($Submit) {
    $arguments += "--submit"
}
elseif ($ValidatePackage) {
    $arguments += "--validate-package"
}
elseif ($Rollback) {
    $arguments += "--rollback"
}

$pythonCommand = Get-Command "python.exe" -ErrorAction SilentlyContinue
$usePythonLauncher = $false

if ($null -eq $pythonCommand) {
    $pythonCommand = Get-Command "py.exe" -ErrorAction SilentlyContinue
    $usePythonLauncher = $true
}

if ($null -eq $pythonCommand) {
    Write-Error "Python was not found. Install Python or add it to PATH."
    exit 4
}

$previousLocation = (Get-Location).Path
$exitCode = 4

try {
    Set-Location -LiteralPath $repositoryRoot

    if ($usePythonLauncher) {
        & $pythonCommand.Source -3 @arguments
    }
    else {
        & $pythonCommand.Source @arguments
    }

    $exitCode = $LASTEXITCODE
}
finally {
    Set-Location -LiteralPath $previousLocation
}

exit $exitCode
