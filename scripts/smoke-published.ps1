param([string]$Executable = (Join-Path $PSScriptRoot '..\artifacts\publish\win-x64\MinuteCapture.exe'))
$ErrorActionPreference = 'Stop'
if (Get-Process MinuteCapture -ErrorAction SilentlyContinue) { throw 'Exit existing MinuteCapture before this isolated check.' }
if (Test-Path "$env:LOCALAPPDATA\MinuteCapture\settings.json") { throw 'This first-run check requires no existing user settings.' }
Add-Type -AssemblyName System.Drawing,UIAutomationClient,UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class SmokeWindow {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr handle);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr handle, IntPtr dc, uint flags);
}
"@
[void][SmokeWindow]::SetThreadDpiAwarenessContext([IntPtr](-4))
$first = $null
$second = $null
try {
    $first = Start-Process -FilePath $Executable -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 3
    $first.Refresh()
    if ($first.HasExited -or !$first.MainWindowHandle) { throw 'First-run settings not visible.' }
    $runtime = $first.Modules | Where-Object ModuleName -eq 'coreclr.dll'
    if (!$runtime -or !(Split-Path $runtime.FileName).Equals((Split-Path ([IO.Path]::GetFullPath($Executable))), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Bundled runtime was not loaded from publish/install folder.'
    }
    Write-Output 'PASS published application loads bundled runtime'
    $preview = Join-Path $PSScriptRoot '..\artifacts\validation\settings-window.png'
    [IO.Directory]::CreateDirectory((Split-Path $preview)) | Out-Null
    $rect = New-Object SmokeWindow+Rect
    [void][SmokeWindow]::GetWindowRect($first.MainWindowHandle, [ref]$rect)
    $bitmap = New-Object Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { [void][SmokeWindow]::PrintWindow($first.MainWindowHandle,$dc,2) }
    finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
    $bitmap.Save($preview,[Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $settingsHandle = $first.MainWindowHandle
    [void]$first.CloseMainWindow()
    Start-Sleep -Milliseconds 800
    $first.Refresh()
    if ($first.HasExited -or [SmokeWindow]::IsWindowVisible($settingsHandle)) { throw 'Closing settings did not hide the running instance.' }
    $second = Start-Process -FilePath $Executable -WindowStyle Hidden -PassThru
    if (!$second.WaitForExit(5000)) { throw 'Second instance did not exit.' }
    Start-Sleep -Seconds 3
    $first.Refresh()
    if (![SmokeWindow]::IsWindowVisible($settingsHandle) -or @(Get-Process MinuteCapture).Count -ne 1) { throw 'Second launch did not reactivate the existing instance.' }
    Write-Output 'PASS separate second process activates original settings window'
    Write-Output "Preview: $preview"
}
finally {
    # This isolated external-process check uses forced cleanup. Graceful Exit is covered by WindowsTests.
    if ($second -and !$second.HasExited) { Stop-Process -Id $second.Id }
    if ($first -and !$first.HasExited) { Stop-Process -Id $first.Id }
}