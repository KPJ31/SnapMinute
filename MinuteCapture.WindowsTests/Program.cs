using MinuteCapture;
using MinuteCapture.Core;

internal static class Program
{
    [STAThread]
    private static int Main()
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        var root = Path.Combine(Path.GetTempPath(), "MinuteCapture-windows-" + Guid.NewGuid().ToString("N"));
        using var show = new EventWaitHandle(false, EventResetMode.AutoReset);
        using var context = new CaptureContext(show, false, Path.Combine(root, "settings"), new FakeStartup());
        var failed = false;
        var checks = 0;
        void Check(bool condition, string message)
        {
            if (!condition) throw new Exception(message + ": " + context.LastError);
            checks++;
            Console.WriteLine("PASS " + message);
        }
        context.Window.BeginInvoke(async () =>
        {
            try
            {
                Check(context.Current.Folder == "" && context.Current.StartAtSignIn, "first run needs setup, startup visibly defaults on");
                Check(Desktop.CanCapture(), "interactive desktop is available");
                var first = Path.Combine(root, "first");
                await context.Save(first, false);
                Check(Directory.GetFiles(first, "*.jpg").Length == 1, "first saved folder captures immediately");
                using (var image = Image.FromFile(Directory.GetFiles(first, "*.jpg")[0]))
                    Check(image.Size == Screen.PrimaryScreen!.Bounds.Size, "JPEG uses native primary display dimensions");
                var second = Path.Combine(root, "second");
                await context.Save(second, false);
                await context.CaptureNow();
                Check(Directory.GetFiles(second, "*.jpg").Length == 1 && Directory.GetFiles(first, "*.jpg").Length == 1, "folder change directs later captures and preserves old images");
                await context.Save("relative-invalid-folder", false);
                Check(context.Current.Folder == second && context.LastError is not null, "invalid folder retains working setting");
                await context.Toggle();
                var count = Directory.GetFiles(second, "*.jpg").Length;
                await context.CaptureNow();
                Check(!context.Current.CaptureEnabled && Directory.GetFiles(second, "*.jpg").Length == count, "pause blocks manual captures");
                await context.Toggle();
                Check(context.Current.CaptureEnabled && Directory.GetFiles(second, "*.jpg").Length == count + 1, "resume captures immediately");
                var moved = second + "-offline";
                Directory.Move(second, moved);
                await context.CaptureNow();
                Check(context.LastError is not null, "missing folder produces recoverable status error");
                Directory.Move(moved, second);
                await context.CaptureNow();
                Check(context.LastError is null && Directory.GetFiles(second, "*.jpg").Length == count + 2, "capture recovers when folder returns");
                count = Directory.GetFiles(second, "*.jpg").Length;
                await Task.WhenAll(context.CaptureNow(), context.CaptureNow(), context.CaptureNow());
                Check(Directory.GetFiles(second, "*.jpg").Length == count + 1, "concurrent requests do not overlap");
                var configPath = Path.Combine(root, "settings", "settings.json");
                File.Delete(configPath);
                Directory.CreateDirectory(configPath);
                await context.Toggle();
                Check(!context.Current.CaptureEnabled && context.LastError is not null, "Pause remains effective when settings persistence fails");
                Directory.Delete(configPath);
                await context.Save(second, false);
                context.Window.Close();
                Check(!context.Window.IsDisposed && !context.Window.Visible, "closing settings hides to tray");
                show.Set();
                await Task.Delay(800);
                Check(context.Window.Visible, "activation event reopens settings");
                Check(!Directory.EnumerateFiles(root, "*.tmp", SearchOption.AllDirectories).Any(), "no partial image or settings files remain");
                Console.WriteLine($"{checks} Windows checks passed.");
            }
            catch (Exception ex) { Console.Error.WriteLine(ex); failed = true; }
            finally { await context.Exit(); }
        });
        Application.Run(context);
        if (Directory.Exists(root)) Directory.Delete(root, true);
        return failed ? 1 : 0;
    }
    private sealed class FakeStartup : IStartupRegistration
    {
        public bool Enabled { get; private set; }
        public void Set(bool enabled) => Enabled = enabled;
    }
}