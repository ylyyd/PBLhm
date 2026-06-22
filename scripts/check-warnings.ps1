param(
    [int]$WarningBaseline = 209,
    [string]$ProjectDir = "E:\ollma\pp"
)

Write-Host "=== Build Quality Check ===" -ForegroundColor Cyan
$exitCode = 0

# --- Check 1: AppButton + layoutWeight not allowed ---
Write-Host ""
Write-Host "[检查 1/2] 禁止 AppButton + .layoutWeight() 组合..." -ForegroundColor Yellow
$files = Select-String -Path "$ProjectDir\entry\src\main\ets\**\*.ets" -Pattern "AppButton.*\n.*layoutWeight|AppButton.*layoutWeight" -List
if ($files) {
    Write-Host "FAIL: 以下文件存在 AppButton + layoutWeight 组合:" -ForegroundColor Red
    foreach ($f in $files) {
        Write-Host "  - $($f.Path)" -ForegroundColor Red
    }
    $exitCode = 1
} else {
    Write-Host "PASS: 无 AppButton + layoutWeight 组合。" -ForegroundColor Green
}

# --- Check 2: Warning count ---
Write-Host ""
Write-Host "[检查 2/2] Build warning 数量..." -ForegroundColor Yellow
$buildLog = "$ProjectDir\build\output\build.log"
if (Test-Path -LiteralPath $buildLog) {
    $warningLines = Select-String -Path $buildLog -Pattern "WARNING|warning" | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "当前 warnings: $warningLines (基线: $WarningBaseline)" -ForegroundColor $(
        if ($warningLines -le $WarningBaseline) { "Green" } else { "Red" }
    )
    if ($warningLines -gt $WarningBaseline) {
        Write-Host "FAIL: warning 数量超过基线 ($warningLines > $WarningBaseline)" -ForegroundColor Red
        $exitCode = 1
    } else {
        Write-Host "PASS: warning 数量在基线范围内。" -ForegroundColor Green
    }
} else {
    Write-Host "SKIP: Build log not found at $buildLog (build may not have been run yet)" -ForegroundColor Yellow
    Write-Host "Run build first, then this check script."
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "=== ALL CHECKS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== SOME CHECKS FAILED ===" -ForegroundColor Red
}
exit $exitCode
