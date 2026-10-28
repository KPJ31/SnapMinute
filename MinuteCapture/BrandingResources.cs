namespace MinuteCapture;

/// <summary>Owns the shared branding for one application lifetime. Controls borrow these resources.</summary>
internal sealed class BrandingResources : IDisposable
{
    private readonly Dictionary<int, Icon> icons = new();
    private readonly MemoryStream iconStream;
    private bool disposed;
    internal Bitmap Logo { get; }

    internal BrandingResources()
    {
        var assembly = typeof(BrandingResources).Assembly;
        using var logoStream = assembly.GetManifestResourceStream("MinuteCapture.Branding.Logo.png")
            ?? throw new InvalidOperationException("Embedded logo is missing.");
        using var decoded = Image.FromStream(logoStream);
        Logo = new Bitmap(decoded); // Detach from the resource stream, retaining alpha.
        using var source = assembly.GetManifestResourceStream("MinuteCapture.Branding.App.ico")
            ?? throw new InvalidOperationException("Embedded application icon is missing.");
        iconStream = new MemoryStream();
        source.CopyTo(iconStream);
    }

    internal Icon GetIcon(int pixels)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        if (!icons.TryGetValue(pixels, out var icon))
        {
            iconStream.Position = 0;
            icon = new Icon(iconStream, pixels, pixels);
            icons.Add(pixels, icon);
        }
        return icon;
    }

    internal Icon GetIconForDpi(int dpi, int logicalPixels) =>
        GetIcon(Math.Max(16, (int)Math.Round(logicalPixels * dpi / 96d)));

    public void Dispose()
    {
        if (disposed) return;
        disposed = true;
        foreach (var icon in icons.Values) icon.Dispose();
        icons.Clear();
        Logo.Dispose();
        iconStream.Dispose();
    }
}