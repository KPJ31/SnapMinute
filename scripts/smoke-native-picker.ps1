$ErrorActionPreference = 'Stop'
if (Get-Process MinuteCapture -ErrorAction SilentlyContinue) { throw 'Exit existing app before this check.' }
if (Test-Path "$env:LOCALAPPDATA\MinuteCapture\settings.json") { throw 'Existing settings found; use a clean test user.' }
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PickerMessages {
 public delegate bool Callback(IntPtr handle, IntPtr lparam);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, Callback callback, IntPtr lparam);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr handle,System.Text.StringBuilder name,int max);
 [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr handle);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr handle,uint msg,IntPtr wparam,string text);
 public static IntPtr FolderEdit(IntPtr dialog) {
   IntPtr result=IntPtr.Zero;
   EnumChildWindows(dialog,(handle,param)=>{
     var name=new System.Text.StringBuilder(100); GetClassName(handle,name,100);
     if(name.ToString()=="Edit") { Console.WriteLine("Edit control ID: "+GetDlgCtrlID(handle)); if(GetDlgCtrlID(handle)==1001 || GetDlgCtrlID(handle)==1152) result=handle; }
     return true;
   },IntPtr.Zero);
   return result;
 }
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr handle, uint message, IntPtr wparam, IntPtr lparam);
}
"@
$target = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\artifacts\validation\picker-folder'))
[IO.Directory]::CreateDirectory($target) | Out-Null
$app = Start-Process -FilePath (Join-Path $PSScriptRoot '..\artifacts\publish\win-x64\MinuteCapture.exe') -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Seconds 2
    $root = [Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object Windows.Automation.PropertyCondition ([Windows.Automation.AutomationElement]::ProcessIdProperty),$app.Id
    $elements = $root.FindAll([Windows.Automation.TreeScope]::Descendants,$condition)
    $browse = $elements | Where-Object { $_.Current.Name -like 'Browse*' } | Select-Object -First 1
    if (!$browse) { throw 'Browse button not found.' }
    [void][PickerMessages]::PostMessage([IntPtr]$browse.Current.NativeWindowHandle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
    Start-Sleep -Seconds 2
    $elements = $root.FindAll([Windows.Automation.TreeScope]::Descendants,$condition)
    $dialog = $elements | Where-Object { $_.Current.Name -eq 'Choose the screenshot folder' } | Select-Object -First 1
    $field = [PickerMessages]::FolderEdit([IntPtr]$dialog.Current.NativeWindowHandle)
    if ($field -eq [IntPtr]::Zero) { throw 'Native folder edit handle not found.' }
    [void][PickerMessages]::SendMessage($field,0xC,[IntPtr]::Zero,$target)
    $select = $elements | Where-Object { $_.Current.Name -eq 'Select Folder' } | Select-Object -First 1
    if (!$select) { throw 'Select Folder button not found.' }
    [void][PickerMessages]::PostMessage([IntPtr]$select.Current.NativeWindowHandle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
    Start-Sleep -Seconds 2
    $elements = $root.FindAll([Windows.Automation.TreeScope]::Descendants,$condition)
    $edit = $elements | Where-Object { $_.Current.Name -eq 'Screenshot folder' } | Select-Object -First 1
    if (!$edit -or $edit.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).Current.Value -ne $target) { throw 'Selected folder was not returned to settings.' }
    Write-Output 'PASS native folder picker returns selected directory to settings'
    if (Test-Path "$env:LOCALAPPDATA\MinuteCapture\settings.json") { throw 'Picking alone unexpectedly saved settings.' }
}
finally { if (!$app.HasExited) { Stop-Process -Id $app.Id } }