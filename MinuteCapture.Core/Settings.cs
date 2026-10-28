using System.Text.Json;

namespace MinuteCapture.Core;

public sealed record Settings(string Folder = "", bool StartAtSignIn = true, bool CaptureEnabled = true);

public sealed class SettingsStore(string directory)
{
    public string FilePath => Path.Combine(directory, "settings.json");
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };
    public Settings Load(out string? warning)
    {
        warning = null;
        if (!File.Exists(FilePath)) return new();
        try
        {
            var value = JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath));
            if (value is null || value.Folder is null) throw new InvalidDataException("Empty settings.");
            return value;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException or InvalidDataException)
        {
            warning = "Settings could not be read. Choose and save a folder again. " + ex.Message;
            return new();
        }
    }
    public void Save(Settings settings)
    {
        Directory.CreateDirectory(directory);
        var temp = FilePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var stream = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                JsonSerializer.Serialize(stream, settings, Options);
                stream.Flush(true);
            }
            File.Move(temp, FilePath, true);
        }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    public static string ValidateFolder(string folder)
    {
        if (string.IsNullOrWhiteSpace(folder) || !Path.IsPathFullyQualified(folder))
            throw new IOException("Choose an absolute folder path.");
        var full = Path.GetFullPath(folder.Trim());
        Directory.CreateDirectory(full);
        var probe = Path.Combine(full, ".MinuteCapture-" + Guid.NewGuid().ToString("N") + ".tmp");
        using (var stream = new FileStream(probe, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1, FileOptions.DeleteOnClose))
        {
            stream.WriteByte(0);
            stream.Flush(true);
        }
        return full;
    }
}

public static class CaptureNames
{
    public static string Create(DateTime localTime) =>
        $"MinuteCapture_{localTime:yyyy-MM-dd_HH-mm-ss-fff}_{Guid.NewGuid():N}.jpg";
}

// Monotonic deadlines avoid wall-clock changes. A delayed tick produces one attempt, never catch-up work.
public sealed class CaptureSchedule(TimeSpan interval)
{
    private TimeSpan next;
    public bool Enabled { get; private set; }
    public void SetEnabled(bool enabled, TimeSpan now)
    {
        Enabled = enabled;
        next = now;
    }
    public void Defer(TimeSpan now) => next = now + interval;
    public bool TakeDue(TimeSpan now)
    {
        if (!Enabled || now < next) return false;
        Defer(now);
        return true;
    }
}