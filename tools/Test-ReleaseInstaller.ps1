param([string]$SetupPath,[string]$Target)
$ErrorActionPreference = 'Stop'
$targetPath = [IO.Path]::GetFullPath($Target)
$desktopLink = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Amos影音下載.lnk'
$menuLink = Join-Path ([Environment]::GetFolderPath('Programs')) 'Amos影音下載\Amos影音下載.lnk'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{3AC22966-A3BE-48BB-B24A-0244212A6D36}_is1'
foreach ($path in @($targetPath,$desktopLink,$key)) {
    if (Test-Path -LiteralPath $path) { throw "Requires clean test machine: $path" }
}
$uninstaller = Join-Path $targetPath 'unins000.exe'
try {
    $process = Start-Process -FilePath (Resolve-Path -LiteralPath $SetupPath).Path -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/DIR="'+$targetPath+'"')) -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "Setup failed: $($process.ExitCode)" }
    $exe = Join-Path $targetPath 'Aureate.exe'
    foreach ($path in @($exe,$desktopLink,$menuLink,$key,$uninstaller)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing installed item: $path" }
    }
    $shell = New-Object -ComObject WScript.Shell
    foreach ($path in @($desktopLink,$menuLink)) {
        $inspectionLink = Join-Path $env:RUNNER_TEMP 'Amos-shortcut-inspection.lnk'
        Copy-Item -LiteralPath $path -Destination $inspectionLink -Force
        try { $shortcut = $shell.CreateShortcut($inspectionLink) }
        finally { Remove-Item -LiteralPath $inspectionLink -Force }
        if ($shortcut.TargetPath -ne $exe) { throw "Wrong shortcut target: actual='$($shortcut.TargetPath)'; expected='$exe'" }
        if ($shortcut.IconLocation -notlike ($exe + '*')) { throw 'Wrong shortcut icon' }
    }
    $registration = Get-ItemProperty -LiteralPath $key
    if ($registration.DisplayName -notlike 'Amos影音下載*' -or $registration.DisplayVersion -ne '1.0.2') { throw 'Wrong uninstall display metadata' }
    Write-Output 'PASS: setup, version, desktop shortcut, Start menu shortcut and icon target'
    $report = Join-Path $env:RUNNER_TEMP 'engine-report.json'
    $appProcess = Start-Process -FilePath $exe -ArgumentList @('--self-check','--report',('"'+$report+'"')) -Wait -PassThru -WindowStyle Hidden
    if ($appProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $report) -or -not ((Get-Content -LiteralPath $report -Raw | ConvertFrom-Json).ok)) { throw 'Installed engine check failed' }
    Write-Output 'PASS: installed bundled engine hashes and versions'
} finally {
    if (Test-Path -LiteralPath $uninstaller) {
        $process = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) { throw 'Uninstall failed' }
    }
}
foreach ($path in @($desktopLink,$menuLink,$key,(Join-Path $targetPath 'Aureate.exe'))) {
    if (Test-Path -LiteralPath $path) { throw "Uninstall left installed item: $path" }
}
Write-Output 'PASS: uninstall removes program, shortcuts and registration'
