# MinuteCapture

A small Windows Forms tray application that captures the primary monitor locally every 60 seconds. No uploads, telemetry, database, or service.

## Build and install

Requires Windows and the .NET 10 SDK for development, plus Inno Setup 6 for installer creation. [.NET 10 is LTS](https://dotnet.microsoft.com/en-us/platform/support/policy). The destination computer needs neither SDK nor a separately installed runtime.

~~~powershell
dotnet build MinuteCapture.slnx -c Release
dotnet run --project MinuteCapture.Tests -c Release
.\build.ps1
# Publish only:
.\build.ps1 -SkipInstaller
# ARM64, separately:
.\build.ps1 -Runtime win-arm64
# Explicit compiler or runtime patch:
.\build.ps1 -IsccPath 'C:\path\ISCC.exe' -RuntimeFrameworkVersion 10.0.12
~~~

Use a current serviced .NET 10 SDK/runtime pack when distributing. The optional patch argument makes the runtime selection explicit; toolchain updates can change binary output. The script is repeatable, fails on build/check/compiler failures, and clears only its selected publish output. It uses a folder-based self-contained build, without trimming, single-file extraction, or executable packers.

Outputs:
- artifacts/publish/win-x64/MinuteCapture.exe and its runtime files: copy the **entire folder** for portable use.
- artifacts/installer/win-x64/MinuteCapture-Setup.exe: installer, when Inno Setup is available.
- ARM64 outputs use win-arm64 instead.

Install per-user into %LOCALAPPDATA%\Programs\MinuteCapture. No administrator elevation is requested. Start-menu and uninstall shortcuts are created. Upgrades use the same AppId and one named startup value; close the running app through its tray menu before upgrading if Setup cannot close it. Keep the installation path stable across upgrades.

The application and installer are unsigned. Windows SmartScreen may show an unrecognized-app warning because there is no established publisher reputation; it is not proof of either safety or malware. Verify source and artifact provenance. Do not disable Windows security. For broad distribution, sign both application and installer with a trusted certificate.

## First use and settings

Launch MinuteCapture, choose a screenshot directory with Browse, and click Save Settings. Pictures\MinuteCapture is suggested. No automatic captures happen until a folder is saved. Startup is visibly checked by default and is registered when you save first-run settings. Closing the settings window leaves the visible tray icon running; Exit on the tray stops the app.

The window and tray provide Open Screenshot Folder, Capture Now, and Pause/Start (Pause/Resume in the tray). Capture Now is unavailable while paused. Starting/resuming captures immediately, followed by attempts about every 60 seconds. Completed screenshots remain when you pause; in-progress work is cancelled before final publication where possible. Resume does not make up missed screenshots.

Change the folder at any time and save. The app creates it if needed and tests write permission before saving settings. Existing screenshots stay where they are. A capture already in progress can finish in the old folder; later captures use the new folder. Invalid changes leave the previous setting intact.

Capture uses the primary monitor at native pixels with per-monitor DPI awareness. Each JPEG name contains local date, time, milliseconds, and a unique suffix. Clock corrections and daylight-saving changes can affect chronological filename sorting. Images are never automatically deleted. Monitor disk space yourself.

## Startup and configuration

Settings are JSON at %LOCALAPPDATA%\MinuteCapture\settings.json, for example:

~~~json
{
  "Folder": "C:\\Users\\YourName\\Pictures\\MinuteCapture",
  "StartAtSignIn": true,
  "CaptureEnabled": true
}
~~~

Use the UI to change them. Writes use a flushed temporary file and same-directory atomic replacement. Missing/invalid settings require setup again; unreadable settings show an error. A loaded folder that later becomes unavailable stays configured so scheduled attempts can recover.

Startup uses HKCU\Software\Microsoft\Windows\CurrentVersion\Run, value MinuteCapture, containing the quoted executable path and --startup. No Windows service or elevation. Saved installations reconcile the preference with that actual value on launch. Uncheck and save to remove it. An operating-system startup-app override (Task Manager/Settings) can separately prevent Run entries from launching; enable it there if necessary. Moving a portable build requires saving the startup checkbox again to register the new executable path.

A sign-in launch is quiet after setup and respects the saved running/paused preference. A second launch in the same user session activates the existing settings window. Different interactive sessions are independent. Last-success time is for the current process session.

## Reliability, privacy, and troubleshooting

Lock/disconnect/secure desktop: captures are skipped. Active-session and input-desktop checks run before capture and before writing; session events also suspend work. Protected content may be black or unavailable; the app does not bypass protection. Sleep/unlock resumes the normal interval without replaying missed work. Remote desktop and display changes may cause a transient failure; the next interval retries.

Unavailable drives, permission failures, full disks, and drawing failures appear inline and are retried at the next interval. No recurring modal error boxes. Reconnect the drive or choose a writable folder. A small rotating log lives beside settings: errors.log plus errors.log.1 (roughly 128 KiB each plus one bounded entry). Logging failure does not stop the app. An OS crash/power loss can leave a .tmp image; it is not a completed screenshot.

JPEGs may contain private information visible on screen. Files remain local to the selected path; selecting a cloud-synced folder allows that folder's separate sync application to upload them. The app itself performs no networking.

Uninstall via Windows Installed Apps or the Start-menu shortcut. Exit the tray app first. Uninstall removes the application and its startup registration, preserving screenshots **and settings**. Delete %LOCALAPPDATA%\MinuteCapture yourself if you also want settings/logs removed. Keep screenshots outside the application installation folder.

## Checks and memory measurement

Run the test project for isolated core checks: defaults, JSON roundtrip/replacement/recovery, folder probe cleanup, path rejection, filename uniqueness/order, immediate start, 60-second scheduling, pause/resume, and no catch-up after delays.

See VALIDATION.md for checks actually performed and manual acceptance steps. On Windows test at native display scaling and at 150%/200%; verify the JPEG dimensions match primary display pixels.

For memory measurement, run the **published Release executable** for 30–60 minutes with automatic capture, minimize settings, and use Task Manager Details or Process Explorer to record private bytes/commit size, working set, handles, and GDI objects at start, after warmup, and every 5 minutes. PowerShell sampling:

~~~powershell
1..12 | ForEach-Object {
  Get-Process MinuteCapture | Select-Object Id, WorkingSet64, PrivateMemorySize64, HandleCount
  Start-Sleep -Seconds 300
}
~~~

Repeat with folder changes, pauses, resolution changes, and temporary failures. A warmed-up fluctuating working set is normal; persistent growth in private bytes or GDI objects needs investigation. Bitmaps, graphics, file streams, registry handles, input desktops, icons, and timers have explicit disposal; only one capture is in flight and screenshots are not retained. No forced GC or working-set trimming. No fixed RAM claim is made; short smoke tests do not replace this soak.
## Additional verification commands

~~~powershell
dotnet run --project MinuteCapture.WindowsTests -c Release
.\scripts\smoke-published.ps1
.\scripts\smoke-native-picker.ps1
.\scripts\smoke-installer.ps1
~~~

WindowsTests uses isolated temporary settings and screenshots. The external smoke scripts require a clean test user with no existing MinuteCapture settings, installation, startup entry, or running app; they fail rather than overwrite an existing setup. They require an unlocked interactive desktop and English dialog labels. The build script runs core checks automatically; GUI checks are explicit so builds do not unexpectedly capture the screen.

If saving settings fails when you click Pause, capture still pauses for the current process. The error remains visible and the prior on-disk preference may still be enabled; fix the storage issue and save before restarting.

Built artifacts and the actual/manual test distinction are recorded in [VALIDATION.md](VALIDATION.md). SHA-256 checksums are in artifacts/SHA256SUMS.txt. Inno Setup is a separate build-time tool; use it under its applicable license.
## Branding assets

The supplied SnapMinute logo and application icon are embedded in the application. The settings header uses a proportional Zoom image; the executable, title bar, taskbar, tray, installer, and shortcuts use the multi-resolution icon. Existing MinuteCapture application/settings/installer identities are retained. See [BRANDING.md](BRANDING.md) for files, regeneration commands, visual verification, and remaining DPI/theme checks.