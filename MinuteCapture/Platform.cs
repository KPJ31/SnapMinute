using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace MinuteCapture;

internal interface IStartupRegistration { bool Enabled { get; } void Set(bool enabled); }
internal sealed class Startup : IStartupRegistration
{
    private const string Key = @"Software\Microsoft\Windows\CurrentVersion\Run";
    public bool Enabled => string.Equals(Read(), Command, StringComparison.OrdinalIgnoreCase);
    private static string Command => $"\"{Environment.ProcessPath}\" --startup";
    private static string? Read()
    {
        using var key = Registry.CurrentUser.OpenSubKey(Key);
        return key?.GetValue("MinuteCapture") as string;
    }
    public void Set(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(Key);
        if (enabled) key.SetValue("MinuteCapture", Command);
        else key.DeleteValue("MinuteCapture", false);
    }
}

internal static class Desktop
{
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] private static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll")] private static extern bool SwitchDesktop(IntPtr desktop);
    [DllImport("wtsapi32.dll", SetLastError = true)] private static extern bool WTSQuerySessionInformation(IntPtr server, int session, int info, out IntPtr buffer, out int bytes);
    [DllImport("wtsapi32.dll")] private static extern void WTSFreeMemory(IntPtr buffer);
    internal static bool CanCapture()
    {
        using var process = Process.GetCurrentProcess();
        if (!WTSQuerySessionInformation(IntPtr.Zero, process.SessionId, 8, out var buffer, out var bytes)) return false;
        try { if (bytes < 4 || Marshal.ReadInt32(buffer) != 0) return false; }
        finally { WTSFreeMemory(buffer); }
        var desktop = OpenInputDesktop(0, false, 0x0100);
        if (desktop == IntPtr.Zero) return false;
        try { return SwitchDesktop(desktop); }
        finally { CloseDesktop(desktop); }
    }
}

internal sealed class ErrorLog(string directory)
{
    private readonly object gate = new();
    internal void Write(Exception ex)
    {
        lock (gate)
        {
            try
            {
                Directory.CreateDirectory(directory);
                var path = Path.Combine(directory, "errors.log");
                if (File.Exists(path) && new FileInfo(path).Length > 128 * 1024)
                    File.Move(path, path + ".1", true);
                File.AppendAllText(path, $"{DateTimeOffset.Now:O} {ex.ToString()[..Math.Min(ex.ToString().Length, 8192)]}{Environment.NewLine}");
            }
            catch { /* Logging must never take down capture. */ }
        }
    }
}