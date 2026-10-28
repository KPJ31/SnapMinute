using System.Diagnostics;
using System.Security.Principal;

namespace MinuteCapture;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        using var windowsIdentity = WindowsIdentity.GetCurrent();
        using var process = Process.GetCurrentProcess();
        var identity = windowsIdentity.User!.Value;
        var name = $@"Local\MinuteCapture-{identity}-{process.SessionId}";
        using var mutex = new Mutex(true, name, out var first);
        using var show = new EventWaitHandle(false, EventResetMode.AutoReset, name + "-Show");
        if (!first) { show.Set(); return; }
        try
        {
            using var context = new CaptureContext(show, args.Contains("--startup"));
            Application.Run(context);
        }
        finally { mutex.ReleaseMutex(); }
    }
}