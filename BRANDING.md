# SnapMinute branding update

The existing solution and executable remain named MinuteCapture. This update applies the supplied SnapMinute artwork without changing application identity, settings paths, Run registration, screenshot behavior, installer AppId, install directory, or upgrade behavior.

## Files

- Root logo.png and taskbar-log.png: originals, unchanged.
- MinuteCapture/Assets/Branding/logo.png and taskbar-log.png: byte-identical source copies.
- MinuteCapture/Assets/Branding/SnapMinute.ico: genuine ICO directory containing eight 32-bit RGBA images at 16, 20, 24, 32, 48, 64, 128, and 256 pixels. Frames are PNG-encoded inside the ICO, supported by the target Windows version. The full original artwork is fitted proportionally; a narrow translucent light keyline helps navy strokes remain distinguishable on dark shell backgrounds. Surrounding transparency is retained.
- MinuteCapture/BrandingResources.cs: shared application-lifetime resource owner. The embedded logo is decoded once into a detached bitmap. Embedded ICO bytes are loaded once; requested icon sizes are cached. Controls borrow the images. The context disposes controls/tray before disposing shared images, icons, and their stream.
- MinuteCapture/SettingsForm.cs: white, padded header with a Zoom PictureBox, larger DPI-aware layout, explicit ShowIcon/ShowInTaskbar, and DPI-sensitive icon selection.
- MinuteCapture/CaptureContext.cs: the form and NotifyIcon share embedded branding; the tray icon size follows the settings window's DPI changes.
- MinuteCapture/MinuteCapture.csproj: ApplicationIcon and named embedded PNG/ICO resources.
- installer/MinuteCapture.iss: installer icon and explicit installed shortcut icon references. Other installer settings are preserved.
- scripts/build-branding.ps1: repeatable icon conversion and light/dark contact sheet. No original PNG is modified.
- scripts/verify-branding.ps1: source-copy equality, all ICO dimensions/alpha, and byte-for-byte matching of all eight native executable icon resources.
- scripts/smoke-shell-branding.ps1: taskbar-window-style check and shell previews with settings open/closed.

There are no other custom application windows. The native folder picker remains owned by the settings form. No absolute development paths are used for runtime assets. Loose PNG files are not needed beside the published executable.

## Reproduce

~~~powershell
# Only needed to regenerate the committed ICO from its project PNG:
.\scripts\build-branding.ps1
.\build.ps1
.\scripts\verify-branding.ps1
dotnet run --project MinuteCapture.WindowsTests -c Release --no-build
.\scripts\smoke-published.ps1
.\scripts\smoke-shell-branding.ps1
.\scripts\smoke-installer.ps1
~~~

GUI smoke scripts require an unlocked, clean test user without existing app settings or a running instance. External-process tests force-stop only their own test processes; Windows can briefly retain stale notification icons until the pointer passes over them. They do not enable capture or startup for the real user.

## Verified on Windows, 2026-10-29

- Release build: zero warnings and errors.
- All 17 core checks and 15 Windows integration checks passed.
- Both original PNG SHA-256 hashes unchanged; project copies match.
- Eight genuine ICO frames decoded at exact required dimensions with transparent corners and visible content.
- Published executable contains eight native icon resources identical to the generated ICO frames.
- Published app loads its bundled runtime and embedded logo, with no loose branding files in the publish directory.
- Settings preview visually inspected: Zoom logo, intact proportions, white background, spacing, title-bar icon, and controls.
- Taskbar preview visually inspected while settings were open: branded taskbar icon visible.
- Notification-overflow preview visually inspected after closing settings: branded tray icon available.
- Every generated icon size inspected on white and dark backgrounds.
- Close-to-tray and separate-process reactivation still pass.
- Inno Setup 6.7.4 compiled a real x64 installer. Installation, same-version upgrade, installed-app launch, second-process activation, and uninstall/startup cleanup smoke checks passed.

Evidence under artifacts/validation:
- settings-window.png
- branding-icon-sizes.png
- branding-taskbar.png
- branding-tray.png
- branding-tray-overflow.png

Build log: artifacts/branding-build.log.
Deliverables retain existing paths:
- artifacts/publish/win-x64/MinuteCapture.exe (distribute the entire folder).
- artifacts/installer/win-x64/MinuteCapture-Setup.exe.
- artifacts/SHA256SUMS.txt records current executable, assembly, and installer hashes.

## Remaining manual checks

Move the window between monitors at 125%, 150%, and 200% scaling and inspect logo/control layout and shell icon selection. Switch actual Windows light/dark themes; both-color contact sheets and the current desktop were inspected, but system theme switching was not performed. Check Explorer/Start/pinned-shortcut icon caching after upgrading an existing installation; Windows may keep a previous cached icon until Explorer refreshes. Long-duration, sign-in, lock/sleep, and ARM64 checks listed in VALIDATION.md remain unchanged.

Original hashes:
- logo.png: C7BFA5413767963D52F1A42EDEFED603D3A88232DF3EB81EB576C1C4AFBD6328
- taskbar-log.png: 8E95252A710E4356A221BD731BAF7DF2BAA9634F7B46AB878DE156A1B041B34D