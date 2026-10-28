using MinuteCapture.Core;
var count = 0;
void Check(bool ok, string message) { if (!ok) throw new Exception(message); count++; Console.WriteLine("PASS " + message); }
var root = Path.Combine(Path.GetTempPath(), "MinuteCapture-tests-" + Guid.NewGuid().ToString("N"));
try
{
    var store = new SettingsStore(root);
    Check(store.Load(out var warning) == new Settings() && warning is null, "missing settings use safe setup defaults");
    var folder = SettingsStore.ValidateFolder(Path.Combine(root, "captures"));
    Check(Directory.Exists(folder) && !Directory.EnumerateFiles(folder).Any(), "validation creates folder and removes probe");
    var settings = new Settings(folder, false, false);
    store.Save(settings);
    Check(store.Load(out warning) == settings && warning is null, "settings round trip");
    store.Save(settings with { CaptureEnabled = true });
    Check(store.Load(out _) .CaptureEnabled, "atomic replacement");
    Check(!Directory.EnumerateFiles(root, "*.tmp").Any(), "no temporary config remains");
    File.WriteAllText(store.FilePath, "{broken");
    Check(store.Load(out warning) == new Settings() && warning is not null, "invalid configuration recovers");
    var rejected = false;
    try { SettingsStore.ValidateFolder("relative"); } catch (IOException) { rejected = true; }
    Check(rejected, "relative path rejected");
    var before = new DateTime(2026, 10, 29, 12, 34, 56, 789);
    var names = Enumerable.Range(0, 2000).Select(_ => CaptureNames.Create(before)).ToArray();
    Check(names.Distinct().Count() == names.Length, "same-millisecond filenames unique");
    Check(names[0].StartsWith("MinuteCapture_2026-10-29_12-34-56-789_") && names[0].EndsWith(".jpg"), "filename has local millisecond timestamp");
    Check(string.CompareOrdinal(names[0], CaptureNames.Create(before.AddSeconds(1))) < 0, "timestamps sort chronologically");
    var schedule = new CaptureSchedule(TimeSpan.FromSeconds(60));
    Check(!schedule.TakeDue(TimeSpan.Zero), "initially disabled");
    schedule.SetEnabled(true, TimeSpan.Zero);
    Check(schedule.TakeDue(TimeSpan.Zero) && !schedule.TakeDue(TimeSpan.Zero), "start due once immediately");
    Check(!schedule.TakeDue(TimeSpan.FromSeconds(59)) && schedule.TakeDue(TimeSpan.FromSeconds(60)), "60 second interval");
    Check(schedule.TakeDue(TimeSpan.FromHours(2)) && !schedule.TakeDue(TimeSpan.FromHours(2)), "no catch-up after long delay");
    schedule.SetEnabled(false, TimeSpan.FromHours(2));
    Check(!schedule.TakeDue(TimeSpan.FromHours(3)), "paused never due");
    schedule.SetEnabled(true, TimeSpan.FromHours(3));
    Check(schedule.TakeDue(TimeSpan.FromHours(3)), "resume immediately due");
    schedule.Defer(TimeSpan.FromHours(4));
    Check(!schedule.TakeDue(TimeSpan.FromHours(4)) && schedule.TakeDue(TimeSpan.FromHours(4) + TimeSpan.FromSeconds(60)), "wake defers normal interval");
    Console.WriteLine($"{count} checks passed.");
}
finally { if (Directory.Exists(root)) Directory.Delete(root, true); }