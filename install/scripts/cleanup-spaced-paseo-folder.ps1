$target = "\\?\C:\Users\rmicua\.paseo "

# Kill any daemon using it
$pidFile = "$($target)paseo.pid"
if (Test-Path -LiteralPath $pidFile) {
    $daemonPid = (Get-Content -LiteralPath $pidFile | ConvertFrom-Json).pid
    Stop-Process -Id $daemonPid -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
}

# Delete all files recursively then the directory
Get-ChildItem -LiteralPath $target -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $target -Force -Recurse -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $target) {
    Write-Host "Still exists. Trying cmd..." -ForegroundColor Yellow
    cmd /c "rmdir /s /q `"\\?\C:\Users\rmicua\.paseo `""
} else {
    Write-Host "Deleted." -ForegroundColor Green
}
