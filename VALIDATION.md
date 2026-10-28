# Validation record

Performed on Windows 10 x64 (10.0.19045) on 2026-10-29, using .NET SDK 10.0.401 and Inno Setup 6.7.4.

## Automated checks performed

- Release solution build: successful, zero warnings and errors.
- Core test executable: **17 checks passed**, covering defaults, atomic settings replacement, malformed JSON recovery, folder validation/probe cleanup, relative-path rejection, unique millisecond filenames, ordering, immediate start, 60-second deadlines, pause/resume, delayed ticks, and wake deferral.
- Windows integration executable: **15 checks passed**. Real primary-monitor JPEG creation and native pixel dimensions; changing folders preserves old images; invalid folder retains prior setting; pause blocks Capture Now; resume captures immediately; missing-folder error and recovery; overlapping requests produce one capture; Pause works when JSON persistence fails; closing settings hides it; activation event reopens settings; no partial image/config files remain. Tests use temporary directories and a fake startup provider, and remove only their own temporary images.
- Native folder picker: the real Browse dialog was opened and a workspace test directory selected. Its path was returned to the settings field; choosing alone did not save configuration.
- Published-app process check: loaded coreclr.dll from its self-contained output directory, closed settings to tray, launched a separate second process, verified that process exited and the original instance reopened settings.
- Installer smoke test: per-user silent installation into a workspace test directory, bundled runtime presence, same-version upgrade, installed-app launch, second-process activation, uninstall, startup Run-entry removal, and preservation of an external capture-folder sentinel. The uninstall test uses a deliberately created startup entry; it does not claim to verify a real sign-in.
- A first-run settings-window preview was inspected at artifacts/validation/settings-window.png.
- Resource review: bitmap, graphics, streams, desktop/WTS handles, registry keys, current-process wrappers, Windows identity, tray icon, menu, timer, and window have explicit disposal. Capture runs on a background task with a single-flight guard and cancellation on pause/exit/session suspend. Images are not retained in history.
- Self-contained Windows x64 Release folder and real Inno Setup installer were built. Build log: artifacts/build.log. Checksums: artifacts/SHA256SUMS.txt.

The external close/second-launch test originally exposed a disposed settings-window bug. The close handler was corrected, then the test passed. A separate assertion verifies that settings-write failure cannot prevent Pause.

## Reproduce

~~~powershell
.\build.ps1
dotnet run --project MinuteCapture.WindowsTests -c Release
.\scripts\smoke-published.ps1
.\scripts\smoke-native-picker.ps1
.\scripts\smoke-installer.ps1
~~~

The GUI scripts require an active, unlocked desktop, English Windows dialog labels, no running MinuteCapture, and no existing user settings. The installer script also refuses an existing install/startup entry. Use a clean Windows test user. External-process scripts force-stop only the processes they launched during cleanup; graceful application Exit is exercised by the integration suite. A physical click on the tray Exit item remains on the manual checklist.

## Manual acceptance still required

These checks were **not** performed and are not implied by the automated results:

1. Save startup enabled, sign out/in, verify quiet tray launch and automatic capture. Pause, sign out/in, verify it remains paused. Disable startup and verify it no longer launches. Check Task Manager startup-app overrides independently.
2. Lock/unlock, disconnect/reconnect RDP, sleep/wake; verify no locked/disconnected capture and no burst of missed captures on recovery. Test UAC secure desktop and protected content without bypassing protection.
3. Keep the app running across primary-monitor changes and 150%/200% scaling; inspect JPEG dimensions for each configuration.
4. Test denied permissions and a genuinely full test volume, then restore access/free space and wait for the next automatic interval. The automated error check covers a missing folder, not every Windows/storage error.
5. Physically double-click the tray icon and use every tray menu item, including Exit during active work. Confirm no remaining process/icon after Exit.
6. Observe actual 60-second cadence over several minutes. Scheduling deadlines are covered by deterministic tests; no long-duration real-time cadence test was run.
7. Run the documented 30–60 minute Release-build memory/GDI/handle soak. No steady-state RAM figure or leak-free soak claim is made.
8. Test on another clean Windows machine without .NET installed and on native ARM64 hardware. Local module inspection proved use of the bundled runtime, but this is not a clean-machine or ARM64 run.
9. Test upgrade from a genuinely older released version while running. Only a same-version upgrade was exercised here.
10. Test an installer launched interactively under a standard user and check Windows SmartScreen behavior. Both deliverables remain unsigned.

Screenshots, settings, and startup were not left enabled for the user by these tests. Inno Setup's compiler was installed in tools/InnoSetup to build the installer; it is a build-time tool and is not needed on the destination computer.

Branding update: see [BRANDING.md](BRANDING.md) for the current embedded-artwork, shell-icon, build, and installer checks. The earlier behavioral/manual-check record above remains applicable.