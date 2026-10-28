$ErrorActionPreference = 'Stop'
if (Get-Process MinuteCapture -ErrorAction SilentlyContinue) { throw 'Exit the existing application before this test.' }
if (Test-Path "$env:LOCALAPPDATA\MinuteCapture\settings.json") { throw 'Use a clean test user for first-run shell verification.' }
Add-Type -AssemblyName System.Drawing,UIAutomationClient,UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class ShellBranding {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string title);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent,IntPtr after,string cls,string title);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr handle,uint msg,IntPtr wparam,IntPtr lparam);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr handle,out Rect rect);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr handle);
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr handle,int index);
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
}
"@
[void][ShellBranding]::SetThreadDpiAwarenessContext([IntPtr](-4))
$output = Join-Path $PSScriptRoot '..\artifacts\validation'
function Save-WindowArea([IntPtr]$handle,[string]$name) {
    $rect=New-Object ShellBranding+Rect
    [void][ShellBranding]::GetWindowRect($handle,[ref]$rect)
    $image=New-Object Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
    $graphics=[Drawing.Graphics]::FromImage($image)
    try {
        $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$image.Size)
        $image.Save((Join-Path $output $name),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $image.Dispose() }
}
$app=$null
$chevron=[IntPtr]::Zero
$opened=$false
try {
    $app=Start-Process (Join-Path $PSScriptRoot '..\artifacts\publish\win-x64\MinuteCapture.exe') -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 4
    $app.Refresh()
    $settings=$app.MainWindowHandle
    $taskbar=[ShellBranding]::FindWindow('Shell_TrayWnd',$null)
    if (([ShellBranding]::GetWindowLongPtr($settings,-20).ToInt64() -band 0x40000) -eq 0) {
        throw 'Settings window does not have taskbar application-window style.'
    }
    Save-WindowArea $taskbar 'branding-taskbar.png'
    Write-Output 'PASS settings window has taskbar application-window style; inspect branding-taskbar.png'
    [void]$app.CloseMainWindow()
    Start-Sleep -Milliseconds 700
    if ([ShellBranding]::IsWindowVisible($settings)) { throw 'Settings window did not hide.' }
    $notify=[ShellBranding]::FindWindowEx($taskbar,[IntPtr]::Zero,'TrayNotifyWnd',$null)
    $chevron=[ShellBranding]::FindWindowEx($notify,[IntPtr]::Zero,'Button',$null)
    $overflow=[ShellBranding]::FindWindow('NotifyIconOverflowWindow',$null)
    if ($chevron -ne [IntPtr]::Zero -and ![ShellBranding]::IsWindowVisible($overflow)) {
        [void][ShellBranding]::PostMessage($chevron,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
        $opened=$true
        Start-Sleep -Milliseconds 700
        $overflow=[ShellBranding]::FindWindow('NotifyIconOverflowWindow',$null)
    }
    Save-WindowArea $taskbar 'branding-tray.png'
    if ([ShellBranding]::IsWindowVisible($overflow)) { Save-WindowArea $overflow 'branding-tray-overflow.png' }
    Write-Output 'PASS settings window hidden; inspect branding-tray.png / branding-tray-overflow.png for notification icon'
}
finally {
    if ($opened -and [ShellBranding]::IsWindowVisible([ShellBranding]::FindWindow('NotifyIconOverflowWindow',$null))) {
        [void][ShellBranding]::PostMessage($chevron,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
    }
    if ($app -and !$app.HasExited) { Stop-Process -Id $app.Id }
}