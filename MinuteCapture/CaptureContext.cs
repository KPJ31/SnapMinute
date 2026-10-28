using System.Diagnostics;
using System.Drawing.Imaging;
using Microsoft.Win32;
using MinuteCapture.Core;

namespace MinuteCapture;

internal sealed class CaptureContext : ApplicationContext
{
    private readonly string data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MinuteCapture");
    private readonly SettingsStore store;
    private readonly ErrorLog log;
    private Settings settings;
    private readonly SettingsForm window;
    private readonly NotifyIcon tray;
    private readonly Icon icon;
    private readonly ContextMenuStrip menu = new();
    private readonly ToolStripMenuItem pause;
    private readonly System.Windows.Forms.Timer timer = new() { Interval = 500 };
    private readonly Stopwatch clock = Stopwatch.StartNew();
    private readonly CaptureSchedule schedule = new(TimeSpan.FromSeconds(60));
    private readonly EventWaitHandle show;
    private bool busy, exiting, sessionBlocked, suspended;
    private Task? capture;
    private string? error;
    private DateTime? last;
    private bool configured;

    internal CaptureContext(EventWaitHandle show, bool quiet)
    {
        this.show = show;
        store = new(data);
        log = new(data);
        settings = store.Load(out error);
        configured = !string.IsNullOrWhiteSpace(settings.Folder);
        // Existing installs reflect the actual Run registration; first run visibly defaults to enabled.
        if (configured)
        {
            try
            {
                settings = settings with { StartAtSignIn = Startup.Enabled };
                store.Save(settings);
            }
            catch (Exception ex) { Fail(ex); }
        }
        icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!) ?? (Icon)SystemIcons.Application.Clone();
        window = new SettingsForm(this, icon);
        _ = window.Handle; // Stable UI dispatch handle even when started quietly.
        menu.Items.Add("Open Settings", null, (_, _) => OpenSettings());
        menu.Items.Add("Open Screenshot Folder", null, (_, _) => OpenFolder());
        menu.Items.Add("Capture Now", null, async (_, _) => await CaptureNow());
        pause = new("Pause", null, async (_, _) => await Toggle());
        menu.Items.Add(pause);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Exit", null, async (_, _) => await Exit());
        tray = new NotifyIcon { Icon = icon, Text = "MinuteCapture", ContextMenuStrip = menu, Visible = true };
        tray.DoubleClick += (_, _) => OpenSettings();
        SystemEvents.SessionSwitch += SessionSwitch;
        SystemEvents.PowerModeChanged += PowerChanged;
        schedule.SetEnabled(configured && settings.CaptureEnabled, clock.Elapsed);
        timer.Tick += async (_, _) =>
        {
            if (show.WaitOne(0)) OpenSettings();
            if (schedule.TakeDue(clock.Elapsed)) await BeginCapture();
        };
        timer.Start();
        Refresh();
        if (!quiet || !configured || error is not null) OpenSettings();
    }

    internal Settings Current => settings;
    internal string SuggestedFolder => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), "MinuteCapture");
    internal void OpenSettings()
    {
        if (exiting) return;
        window.LoadSettings(settings, configured);
        window.Show();
        window.WindowState = FormWindowState.Normal;
        window.Activate();
    }
    private void Fail(Exception ex) { error = ex.Message; log.Write(ex); }
    private void Refresh()
    {
        var state = !configured ? "Setup required" : !settings.CaptureEnabled ? "Paused" :
            suspended || sessionBlocked ? "Waiting for active session" : "Running";
        if (error is not null) state += " — error";
        pause.Text = settings.CaptureEnabled ? "Pause" : "Resume";
        window.UpdateStatus(state, last, error, settings.CaptureEnabled, busy);
        tray.Text = ("MinuteCapture — " + state)[..Math.Min(63, ("MinuteCapture — " + state).Length)];
    }
    internal async Task Save(string folder, bool startup)
    {
        if (exiting) return;
        window.SetSaving(true);
        try
        {
            var valid = await Task.Run(() => SettingsStore.ValidateFolder(folder));
            var candidate = settings with { Folder = valid, StartAtSignIn = startup };
            var previous = Startup.Enabled;
            Startup.Set(startup);
            try { store.Save(candidate); }
            catch { Startup.Set(previous); throw; }
            var wasConfigured = configured;
            settings = candidate;
            configured = true;
            error = null;
            window.LoadSettings(settings, true);
            if (!wasConfigured)
            {
                schedule.SetEnabled(settings.CaptureEnabled, clock.Elapsed);
                if (schedule.TakeDue(clock.Elapsed)) await BeginCapture();
            }
        }
        catch (Exception ex) { Fail(ex); }
        finally { window.SetSaving(false); Refresh(); }
    }
    internal async Task Toggle()
    {
        if (!configured) { error = "Choose and save a screenshot folder first."; Refresh(); OpenSettings(); return; }
        try
        {
            var candidate = settings with { CaptureEnabled = !settings.CaptureEnabled };
            store.Save(candidate);
            settings = candidate;
            schedule.SetEnabled(settings.CaptureEnabled, clock.Elapsed);
            error = null;
            Refresh();
            if (schedule.TakeDue(clock.Elapsed)) await BeginCapture();
        }
        catch (Exception ex) { Fail(ex); Refresh(); }
    }
    internal async Task CaptureNow()
    {
        if (!configured || !settings.CaptureEnabled)
        {
            error = "Save a folder and start capture before using Capture Now.";
            Refresh();
            return;
        }
        await BeginCapture();
    }
    private async Task BeginCapture()
    {
        if (busy || exiting || !configured || !settings.CaptureEnabled || sessionBlocked || suspended) return;
        busy = true;
        Refresh();
        var folder = settings.Folder;
        try
        {
            capture = Task.Run(() =>
            {
                if (!Desktop.CanCapture()) return;
                var bounds = Screen.PrimaryScreen?.Bounds ?? throw new IOException("No primary display is available.");
                using var bitmap = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format24bppRgb);
                using (var graphics = Graphics.FromImage(bitmap))
                    graphics.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size, CopyPixelOperation.SourceCopy);
                // Recheck session state before writing an image captured during a lock transition.
                if (!Desktop.CanCapture()) return;
                var final = Path.Combine(folder, CaptureNames.Create(DateTime.Now));
                var temp = final + ".tmp";
                try
                {
                    using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                    {
                        bitmap.Save(stream, ImageFormat.Jpeg);
                        stream.Flush(true);
                    }
                    File.Move(temp, final);
                    last = DateTime.Now;
                }
                finally { if (File.Exists(temp)) File.Delete(temp); }
            });
            await capture;
            error = null;
        }
        catch (Exception ex) { Fail(ex); }
        finally { busy = false; if (!exiting) Refresh(); }
    }
    internal void OpenFolder()
    {
        try
        {
            if (!configured || !Directory.Exists(settings.Folder)) throw new IOException("The saved screenshot folder is unavailable.");
            Process.Start(new ProcessStartInfo(settings.Folder) { UseShellExecute = true });
        }
        catch (Exception ex) { Fail(ex); Refresh(); }
    }
    private void Dispatch(Action action)
    {
        if (!exiting && !window.IsDisposed)
            try { window.BeginInvoke(action); } catch (InvalidOperationException) { }
    }
    private void SessionSwitch(object sender, SessionSwitchEventArgs e) => Dispatch(() =>
    {
        switch (e.Reason)
        {
            case SessionSwitchReason.SessionLock:
            case SessionSwitchReason.RemoteDisconnect:
            case SessionSwitchReason.ConsoleDisconnect: sessionBlocked = true; break;
            case SessionSwitchReason.SessionUnlock:
            case SessionSwitchReason.RemoteConnect:
            case SessionSwitchReason.ConsoleConnect: sessionBlocked = false; schedule.Defer(clock.Elapsed); break;
        }
        Refresh();
    });
    private void PowerChanged(object sender, PowerModeChangedEventArgs e) => Dispatch(() =>
    {
        if (e.Mode == PowerModes.Suspend) suspended = true;
        if (e.Mode == PowerModes.Resume) { suspended = false; schedule.Defer(clock.Elapsed); }
        Refresh();
    });
    private async Task Exit()
    {
        if (exiting) return;
        exiting = true;
        timer.Stop();
        tray.Visible = false;
        window.Enabled = false;
        if (capture is not null) await capture.ContinueWith(_ => { });
        window.AllowClose = true;
        window.Close();
        ExitThread();
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            exiting = true;
            SystemEvents.SessionSwitch -= SessionSwitch;
            SystemEvents.PowerModeChanged -= PowerChanged;
            timer.Dispose();
            tray.Dispose();
            menu.Dispose();
            window.Dispose();
            icon.Dispose();
        }
        base.Dispose(disposing);
    }
}