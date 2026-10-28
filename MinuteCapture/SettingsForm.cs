namespace MinuteCapture;

internal sealed class SettingsForm : Form
{
    private readonly TextBox folder = new() { Dock = DockStyle.Fill, AccessibleName = "Screenshot folder" };
    private readonly CheckBox startup = new() { Text = "Start automatically when I sign in", AutoSize = true };
    private readonly Label status = new() { AutoSize = true };
    private readonly Label last = new() { AutoSize = true };
    private readonly Label error = new() { AutoSize = true, ForeColor = Color.Firebrick, MaximumSize = new Size(540, 0) };
    private readonly Button save = new() { Text = "Save Settings", AutoSize = true };
    private readonly Button toggle = new() { AutoSize = true };
    private readonly Button now = new() { Text = "Capture Now", AutoSize = true };
    internal bool AllowClose;
    internal SettingsForm(CaptureContext app, Icon icon)
    {
        Text = "MinuteCapture";
        Icon = icon;
        Font = new Font("Segoe UI", 10);
        AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(610, 350);
        MinimumSize = new Size(570, 390);
        StartPosition = FormStartPosition.CenterScreen;
        var root = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(20), ColumnCount = 1, RowCount = 8 };
        root.Controls.Add(new Label { Text = "Capture your primary screen every 60 seconds", AutoSize = true, Font = new Font(Font, FontStyle.Bold) });
        root.Controls.Add(new Label { Text = "Choose a folder, then save to begin. Screenshots stay on this computer.", AutoSize = true });
        var row = new TableLayoutPanel { Dock = DockStyle.Top, ColumnCount = 2, AutoSize = true };
        row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        row.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        var browse = new Button { Text = "Browse…", AutoSize = true };
        browse.Click += (_, _) =>
        {
            using var dialog = new FolderBrowserDialog { Description = "Choose the screenshot folder", UseDescriptionForTitle = true, InitialDirectory = folder.Text, ShowNewFolderButton = true };
            if (dialog.ShowDialog(this) == DialogResult.OK) folder.Text = dialog.SelectedPath;
        };
        row.Controls.Add(folder, 0, 0); row.Controls.Add(browse, 1, 0);
        root.Controls.Add(row);
        root.Controls.Add(startup);
        var actions = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Top };
        var open = new Button { Text = "Open Screenshot Folder", AutoSize = true };
        save.Click += async (_, _) => await app.Save(folder.Text, startup.Checked);
        open.Click += (_, _) => app.OpenFolder();
        now.Click += async (_, _) => await app.CaptureNow();
        toggle.Click += async (_, _) => await app.Toggle();
        actions.Controls.AddRange([save, open, now, toggle]);
        root.Controls.Add(actions);
        var info = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, Dock = DockStyle.Top };
        info.Controls.AddRange([status, last, error]);
        root.Controls.Add(info);
        root.Controls.Add(new Label { Text = "Closing this window keeps MinuteCapture in the system tray.\nUse the tray menu → Exit to stop the application.", AutoSize = true });
        Controls.Add(root);
        FormClosing += (_, e) => { if (!AllowClose && e.CloseReason is CloseReason.UserClosing or CloseReason.TaskManagerClosing) { e.Cancel = true; Hide(); } };
    }
    internal void LoadSettings(Core.Settings settings, bool configured)
    {
        folder.Text = configured ? settings.Folder : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), "MinuteCapture");
        startup.Checked = settings.StartAtSignIn;
    }
    internal void SetSaving(bool saving) => save.Enabled = !saving;
    internal void UpdateStatus(string state, DateTime? time, string? message, bool enabled, bool busy)
    {
        status.Text = "Status: " + state + (busy ? " (capturing…)" : "");
        last.Text = "Last successful capture: " + (time?.ToString("G") ?? "none this session");
        error.Text = message ?? "";
        toggle.Text = enabled ? "Pause" : "Start";
        now.Enabled = enabled && !busy;
    }
}