# Deterministic conversion of the supplied PNG. Requires Windows PowerShell/System.Drawing.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class BrandingIconBuilder
{
    public static void Build(string source, string destination, string preview)
    {
        int[] sizes = { 16, 20, 24, 32, 48, 64, 128, 256 };
        var frames = new List<byte[]>();
        using (var original = new Bitmap(source))
        using (var sheet = new Bitmap(860, 600, PixelFormat.Format32bppArgb))
        using (var sheetGraphics = Graphics.FromImage(sheet))
        using (var labelFont = new Font("Segoe UI", 10))
        {
            sheetGraphics.Clear(Color.White);
            using (var dark = new SolidBrush(Color.FromArgb(32, 32, 32)))
                sheetGraphics.FillRectangle(dark, 0, 300, sheet.Width, 300);
            int x = 14;
            foreach (int size in sizes)
            {
                using (var scaled = new Bitmap(size, size, PixelFormat.Format32bppArgb))
                using (var frame = new Bitmap(size, size, PixelFormat.Format32bppArgb))
                {
                    using (var graphics = Graphics.FromImage(scaled))
                    using (var attributes = new ImageAttributes())
                    {
                        graphics.Clear(Color.Transparent);
                        graphics.CompositingMode = CompositingMode.SourceCopy;
                        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        attributes.SetWrapMode(WrapMode.TileFlipXY);
                        float scale = Math.Min((float)size / original.Width, (float)size / original.Height);
                        int width = Math.Max(1, (int)Math.Round(original.Width * scale));
                        int height = Math.Max(1, (int)Math.Round(original.Height * scale));
                        graphics.DrawImage(original, new Rectangle((size-width)/2, (size-height)/2, width, height),
                            0, 0, original.Width, original.Height, GraphicsUnit.Pixel, attributes);
                    }
                    // A narrow translucent light keyline behind the artwork keeps navy strokes
                    // distinguishable on dark taskbars. All other transparent space stays transparent.
                    int radius = size >= 128 ? 2 : 1;
                    for (int y = 0; y < size; y++)
                    for (int px = 0; px < size; px++)
                    {
                        int alpha = 0;
                        for (int dy = -radius; dy <= radius; dy++)
                        for (int dx = -radius; dx <= radius; dx++)
                        {
                            if (dx*dx + dy*dy > radius*radius) continue;
                            int sx = px + dx, sy = y + dy;
                            if (sx >= 0 && sx < size && sy >= 0 && sy < size)
                                alpha = Math.Max(alpha, scaled.GetPixel(sx, sy).A);
                        }
                        frame.SetPixel(px, y, Color.FromArgb((int)(alpha * 0.72), 255, 255, 255));
                    }
                    using (var graphics = Graphics.FromImage(frame))
                        graphics.DrawImageUnscaled(scaled, 0, 0);
                    using (var memory = new MemoryStream())
                    {
                        frame.Save(memory, ImageFormat.Png);
                        frames.Add(memory.ToArray());
                    }
                    sheetGraphics.DrawImageUnscaled(frame, x, 25);
                    sheetGraphics.DrawImageUnscaled(frame, x, 325);
                    sheetGraphics.DrawString(size.ToString(), labelFont, Brushes.Black, x, 5);
                    sheetGraphics.DrawString(size.ToString(), labelFont, Brushes.White, x, 305);
                    x += size + 14;
                }
            }
            // ICO directory + eight separately encoded RGBA PNG frames; never a renamed PNG.
            using (var writer = new BinaryWriter(File.Create(destination)))
            {
                writer.Write((ushort)0); writer.Write((ushort)1); writer.Write((ushort)sizes.Length);
                int offset = 6 + sizes.Length * 16;
                for (int i = 0; i < sizes.Length; i++)
                {
                    writer.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                    writer.Write((byte)(sizes[i] == 256 ? 0 : sizes[i]));
                    writer.Write((byte)0); writer.Write((byte)0);
                    writer.Write((ushort)1); writer.Write((ushort)32);
                    writer.Write(frames[i].Length); writer.Write(offset);
                    offset += frames[i].Length;
                }
                foreach (byte[] bytes in frames) writer.Write(bytes);
            }
            Directory.CreateDirectory(Path.GetDirectoryName(preview));
            sheet.Save(preview, ImageFormat.Png);
        }
    }
}
"@
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$assets = Join-Path $workspace 'MinuteCapture\Assets\Branding'
[BrandingIconBuilder]::Build(
    (Join-Path $assets 'taskbar-log.png'),
    (Join-Path $assets 'SnapMinute.ico'),
    (Join-Path $workspace 'artifacts\validation\branding-icon-sizes.png'))
Write-Output 'Generated SnapMinute.ico: 16, 20, 24, 32, 48, 64, 128, 256 pixels.'