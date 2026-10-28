$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$setup = Join-Path $workspace 'artifacts\installer\win-x64\MinuteCapture-Setup.exe'
$target = Join-Path $workspace 'artifacts\validation\installed'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{40C412F1-04E2-47F7-82A4-EF7A80ED73BD}_is1'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (Test-Path $uninstallKey) { throw 'Existing MinuteCapture install found; use a clean test user.' }
if (Get-ItemProperty -Path $runKey -Name MinuteCapture -ErrorAction SilentlyContinue) { throw 'Existing startup setting found; use a clean test user.' }
if (Get-Process MinuteCapture -ErrorAction SilentlyContinue) { throw 'Exit existing application before testing.' }
$installed = $false
function Run-Setup {
    $process = Start-Process -FilePath $setup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOICONS',('/DIR="' + $target + '"')) -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Setup exited $($process.ExitCode)" }
}
try {
    Run-Setup
    $installed = $true
    if (!(Test-Path "$target\MinuteCapture.exe") -or !(Test-Path "$target\coreclr.dll")) { throw 'Installed executable or runtime missing.' }
    Write-Output 'PASS installer installs application and runtime without elevation'
    Run-Setup
    if (!(Test-Path $uninstallKey)) { throw 'Upgrade registration missing.' }
    Write-Output 'PASS same-version upgrade uses existing install registration'
    & (Join-Path $PSScriptRoot 'smoke-published.ps1') -Executable "$target\MinuteCapture.exe"
    # Exercise uninstall cleanup of the exact Run entry used by the app.
    New-ItemProperty -Path $runKey -Name MinuteCapture -Value ('"' + $target + '\MinuteCapture.exe" --startup') -PropertyType String -Force | Out-Null
    $preserved = Join-Path $workspace 'artifacts\validation\screenshot-folder'
    [IO.Directory]::CreateDirectory($preserved) | Out-Null
    [IO.File]::WriteAllText((Join-Path $preserved 'preservation-sentinel.txt'),'Installer must leave user capture directories alone.')
    $uninstaller = Start-Process -FilePath "$target\unins000.exe" -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -WindowStyle Hidden -Wait -PassThru
    if ($uninstaller.ExitCode -ne 0) { throw "Uninstall exited $($uninstaller.ExitCode)" }
    $installed = $false
    if (Test-Path "$target\MinuteCapture.exe") { throw 'Application was not removed.' }
    if (Get-ItemProperty -Path $runKey -Name MinuteCapture -ErrorAction SilentlyContinue) { throw 'Startup registration was not removed.' }
    if (!(Test-Path "$preserved\preservation-sentinel.txt")) { throw 'Capture directory sentinel removed.' }
    Write-Output 'PASS uninstall removes application/startup entry and preserves external capture-folder sentinel'
}
finally {
    if ($installed -and (Test-Path "$target\unins000.exe")) {
        $cleanup = Start-Process -FilePath "$target\unins000.exe" -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -WindowStyle Hidden -Wait -PassThru
        if ($cleanup.ExitCode -ne 0) { Write-Warning 'Test installation cleanup failed.' }
    }
    # The precondition guarantees this value was absent before this test.
    Remove-ItemProperty -Path $runKey -Name MinuteCapture -ErrorAction SilentlyContinue
}