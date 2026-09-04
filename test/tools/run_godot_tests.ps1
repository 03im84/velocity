[CmdletBinding()]
param(
    [string]$Scene = "",

    [switch]$All,

    [string]$GodotPath = $env:GODOT_CONSOLE,

    [ValidateRange(1, 100)]
    [int]$Repeat = 1,

    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 15
)


$ErrorActionPreference = "Stop"

$MetricsPrefix = "VELOCITY_TEST_METRICS_JSON:"
$MetricsProtocolVersion = 1


function Resolve-GodotExecutable {
    param(
        [string]$RequestedPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath) {
            $resolvedPath = Resolve-Path -LiteralPath $RequestedPath

            return $resolvedPath.Path
        }

        $requestedCommand = Get-Command $RequestedPath -ErrorAction SilentlyContinue

        if ($null -ne $requestedCommand) {
            if ($requestedCommand.CommandType -eq "Application") {
                return $requestedCommand.Source
            }

            return $requestedCommand.Definition
        }

        throw "Godot executable not found: $RequestedPath"
    }

    $commandNames = @(
        "godot_console",
        "godot"
    )

    foreach ($commandName in $commandNames) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue

        if ($null -ne $command) {
            if ($command.CommandType -eq "Application") {
                return $command.Source
            }

            return $command.Definition
        }
    }

    throw "Godot Console was not found. Use -GodotPath or define GODOT_CONSOLE."
}


function Convert-ToResourcePath {
    param(
        [string]$PathValue
    )

    $normalizedPath = $PathValue.Replace("\", "/")

    if ($normalizedPath.StartsWith("res://")) {
        return $normalizedPath
    }

    while ($normalizedPath.StartsWith("./")) {
        $normalizedPath = $normalizedPath.Substring(2)
    }

    $normalizedPath = $normalizedPath.TrimStart("/")

    return "res://" + $normalizedPath
}


function Convert-ToFileSystemPath {
    param(
        [string]$ResourcePath,

        [string]$ProjectRoot
    )

    $relativePath = $ResourcePath.Substring("res://".Length)

    $separator = [System.IO.Path]::DirectorySeparatorChar.ToString()

    $relativePath = $relativePath.Replace("/", $separator)

    return Join-Path $ProjectRoot $relativePath
}


function Get-ProjectTestScenes {
    param(
        [string]$ProjectRoot
    )

    $testRoot = Join-Path $ProjectRoot "test"

    if (-not (Test-Path -LiteralPath $testRoot)) {
        throw "Test directory not found: $testRoot"
    }

    $sceneFiles = Get-ChildItem -LiteralPath $testRoot -Recurse -File -Filter "*.tscn" |
        Where-Object {
            $isTestScene = $_.Name -match "(?i)test\.tscn$"
            $isFailureIsolation = $_.Name -match "(?i)failure_isolation"
            $isInfrastructure = $_.FullName -match "[\\/]infrastructure[\\/]"

            return $isTestScene -and (-not $isFailureIsolation) -and (-not $isInfrastructure)
        } |
        Sort-Object FullName

    $resourcePaths = @()

    foreach ($sceneFile in $sceneFiles) {
        $relativePath = $sceneFile.FullName.Substring($ProjectRoot.Length)

        $relativePath = $relativePath -replace "^[\\/]+", ""

        $relativePath = $relativePath.Replace("\", "/")

        $resourcePaths += "res://" + $relativePath
    }

    return $resourcePaths
}


function Get-TestMetrics {
    param(
        [string[]]$OutputLines
    )

    $checks = $null
    $checkFailures = $null

    foreach ($outputLine in $OutputLines) {
        $lineText = [string]$outputLine

        if ($lineText -match "^\s*Checks:\s*(\d+)\s*$") {
            $checks = [int]$Matches[1]
        }

        if ($lineText -match "^\s*Failures:\s*(\d+)\s*$") {
            $checkFailures = [int]$Matches[1]
        }
    }

    $available = (
        $null -ne $checks -and
        $null -ne $checkFailures
    )

    if (-not $available) {
        $checks = $null
        $checkFailures = $null
    }

    return [PSCustomObject]@{
        Available = $available
        Checks = $checks
        CheckFailures = $checkFailures
    }
}


function Write-TestMetricsMarker {
    param(
        [string]$ScenePath,

        [int]$Attempt,

        [PSCustomObject]$Metrics
    )

    $payload = [ordered]@{
        version = $MetricsProtocolVersion
        scene = $ScenePath
        attempt = $Attempt
        available = [bool]$Metrics.Available
        checks = $Metrics.Checks
        check_failures = $Metrics.CheckFailures
    }

    $payloadJson = $payload | ConvertTo-Json -Compress

    Write-Host ($MetricsPrefix + $payloadJson)
}


function Invoke-GodotTest {
    param(
        [string]$GodotExecutable,

        [string]$ProjectRoot,

        [string]$ScenePath,

        [int]$Attempt,

        [int]$TimeoutSeconds
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host "TEST: $ScenePath" -ForegroundColor Cyan
    Write-Host "ATTEMPT: $Attempt" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray

    $standardOutputFile = [System.IO.Path]::GetTempFileName()
    $standardErrorFile = [System.IO.Path]::GetTempFileName()

    $processArguments = '--headless --path "{0}" "{1}"' -f $ProjectRoot, $ScenePath

    $testExitCode = 125
    $timedOut = $false
    $engineErrorDetected = $false

    $standardOutput = @()
    $standardError = @()

    $engineErrorPattern = "(?i)(SCRIPT ERROR:|^ERROR:|Parse Error:|Invalid call\.)"

    try {
        $startProcessParameters = @{
            FilePath = $GodotExecutable
            ArgumentList = $processArguments
            PassThru = $true
            NoNewWindow = $true
            RedirectStandardOutput = $standardOutputFile
            RedirectStandardError = $standardErrorFile
        }

        $godotProcess = Start-Process @startProcessParameters

        $completed = $godotProcess.WaitForExit($TimeoutSeconds * 1000)

        if (-not $completed) {
            $timedOut = $true

            Write-Host "TIMEOUT after $TimeoutSeconds seconds." -ForegroundColor Yellow

            Stop-Process -Id $godotProcess.Id -Force -ErrorAction SilentlyContinue

            $godotProcess.WaitForExit()
        }
        else {
            $godotProcess.WaitForExit()
        }

        if ($timedOut) {
            $testExitCode = 124
        }
        else {
            $godotProcess.Refresh()

            if ($godotProcess.HasExited) {
                $testExitCode = [int]$godotProcess.ExitCode
            }
            else {
                $testExitCode = 125
            }
        }
    }
    catch {
        Write-Host "RUNNER PROCESS ERROR: $($_.Exception.Message)" -ForegroundColor Red

        $testExitCode = 125
    }
    finally {
        $standardOutput = @(
            Get-Content -LiteralPath $standardOutputFile -ErrorAction SilentlyContinue
        )

        $standardError = @(
            Get-Content -LiteralPath $standardErrorFile -ErrorAction SilentlyContinue
        )

        Remove-Item -LiteralPath $standardOutputFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $standardErrorFile -Force -ErrorAction SilentlyContinue
    }

    foreach ($outputLine in $standardOutput) {
        Write-Host $outputLine

        if ([string]$outputLine -match $engineErrorPattern) {
            $engineErrorDetected = $true
        }
    }

    foreach ($errorLine in $standardError) {
        Write-Host $errorLine -ForegroundColor Red

        if ([string]$errorLine -match $engineErrorPattern) {
            $engineErrorDetected = $true
        }
    }

    $metrics = Get-TestMetrics -OutputLines $standardOutput

    if ($testExitCode -eq 0 -and $engineErrorDetected) {
        $testExitCode = 126
    }

    if (
        $testExitCode -eq 0 -and
        $metrics.Available -and
        $metrics.CheckFailures -gt 0
    ) {
        Write-Host "TEST CONTRACT ERROR: Check failures were reported with ExitCode 0." -ForegroundColor Red

        $testExitCode = 1
    }

    $status = "PASS"

    if ($testExitCode -eq 124) {
        $status = "TIMEOUT"
    }
    elseif ($testExitCode -eq 126) {
        $status = "ENGINE_ERROR"
    }
    elseif ($testExitCode -ne 0) {
        $status = "FAIL"
    }

    Write-TestMetricsMarker -ScenePath $ScenePath -Attempt $Attempt -Metrics $metrics

    return [PSCustomObject]@{
        Scene = $ScenePath
        Attempt = $Attempt
        ExitCode = $testExitCode
        Status = $status
        EngineError = $engineErrorDetected
        Checks = $metrics.Checks
        CheckFailures = $metrics.CheckFailures
        MetricsAvailable = $metrics.Available
    }
}


# =====================================================================
# MAIN
# =====================================================================

if ($All -and (-not [string]::IsNullOrWhiteSpace($Scene))) {
    throw "Use -All or -Scene, not both."
}

if ((-not $All) -and [string]::IsNullOrWhiteSpace($Scene)) {
    throw "No test was selected. Use -Scene or -All."
}


$projectRootPath = Join-Path $PSScriptRoot "..\.."

$projectRoot = (Resolve-Path $projectRootPath).Path

$projectFile = Join-Path $projectRoot "project.godot"


if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "project.godot was not found at: $projectFile"
}


$godotExecutable = Resolve-GodotExecutable -RequestedPath $GodotPath


Write-Host ""
Write-Host "Velocity Test Runner" -ForegroundColor Green
Write-Host "Metrics Protocol: $MetricsProtocolVersion"
Write-Host "Project: $projectRoot"
Write-Host "Godot:  $godotExecutable"
Write-Host "Repeat: $Repeat"
Write-Host "Timeout: $TimeoutSeconds seconds"


$testScenes = @()


if ($All) {
    $testScenes = @(
        Get-ProjectTestScenes -ProjectRoot $projectRoot
    )
}
else {
    $resourcePath = Convert-ToResourcePath -PathValue $Scene

    $fileSystemPath = Convert-ToFileSystemPath -ResourcePath $resourcePath -ProjectRoot $projectRoot

    if (-not (Test-Path -LiteralPath $fileSystemPath)) {
        throw "Test scene not found: $fileSystemPath"
    }

    $testScenes = @(
        $resourcePath
    )
}


if ($testScenes.Count -eq 0) {
    throw "No test scenes were found."
}


Write-Host "Tests:  $($testScenes.Count)"


$results = @()


foreach ($testScene in $testScenes) {
    for ($attempt = 1; $attempt -le $Repeat; $attempt++) {
        $invokeParameters = @{
            GodotExecutable = $godotExecutable
            ProjectRoot = $projectRoot
            ScenePath = $testScene
            Attempt = $attempt
            TimeoutSeconds = $TimeoutSeconds
        }

        $result = Invoke-GodotTest @invokeParameters

        $results += $result
    }
}


Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host "TEST SUMMARY" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor DarkGray


$results |
    Format-Table Scene, Attempt, ExitCode, Status, EngineError, Checks, CheckFailures, MetricsAvailable -AutoSize |
    Out-Host


$failedResults = @(
    $results |
        Where-Object {
            $_.ExitCode -ne 0
        }
)


$metricsResults = @(
    $results |
        Where-Object {
            $_.MetricsAvailable
        }
)


$passedCount = $results.Count - $failedResults.Count

$missingMetricsCount = $results.Count - $metricsResults.Count

$totalChecks = 0
$totalCheckFailures = 0

if ($metricsResults.Count -gt 0) {
    $checksMeasure = $metricsResults |
        Measure-Object -Property Checks -Sum

    $checkFailuresMeasure = $metricsResults |
        Measure-Object -Property CheckFailures -Sum

    if ($null -ne $checksMeasure.Sum) {
        $totalChecks = [int]$checksMeasure.Sum
    }

    if ($null -ne $checkFailuresMeasure.Sum) {
        $totalCheckFailures = [int]$checkFailuresMeasure.Sum
    }
}


Write-Host "Total runs:      $($results.Count)"
Write-Host "Passed:          $passedCount"
Write-Host "Failed:          $($failedResults.Count)"
Write-Host "Total checks:    $totalChecks"
Write-Host "Check failures:  $totalCheckFailures"
Write-Host "Missing metrics: $missingMetricsCount"


if ($failedResults.Count -gt 0) {
    Write-Host ""
    Write-Host "RESULT: FAIL" -ForegroundColor Red

    exit 1
}


Write-Host ""
Write-Host "RESULT: PASS" -ForegroundColor Green

exit 0