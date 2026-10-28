param([string]$Executable = (Join-Path $PSScriptRoot '..\artifacts\publish\win-x64\MinuteCapture.exe'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
public static class BrandingValidation {
    delegate bool ResourceCallback(IntPtr module, IntPtr type, IntPtr name, IntPtr param);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr module);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    static extern bool EnumResourceNames(IntPtr module, IntPtr type, ResourceCallback callback, IntPtr param);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    static extern IntPtr FindResource(IntPtr module, IntPtr name, IntPtr type);
    [DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr module, IntPtr info);
    [DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr resource);
    [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr module, IntPtr info);
    static byte[] ReadResource(IntPtr module, IntPtr name, int type) {
        IntPtr info=FindResource(module,name,(IntPtr)type);
        if(info==IntPtr.Zero) throw new Exception("Missing Win32 icon resource.");
        byte[] result=new byte[SizeofResource(module,info)];
        Marshal.Copy(LockResource(LoadResource(module,info)),result,0,result.Length);
        return result;
    }
    public static void Verify(string ico, string executable) {
        int[] expected={16,20,24,32,48,64,128,256};
        byte[] data=File.ReadAllBytes(ico);
        byte[][] frames=new byte[8][];
        using(var reader=new BinaryReader(new MemoryStream(data))) {
            if(reader.ReadUInt16()!=0 || reader.ReadUInt16()!=1 || reader.ReadUInt16()!=8)
                throw new Exception("Not an eight-frame ICO.");
            for(int i=0;i<8;i++) {
                reader.BaseStream.Position=6+i*16;
                int w=reader.ReadByte(),h=reader.ReadByte(); w=w==0?256:w; h=h==0?256:h;
                reader.ReadUInt16();
                if(reader.ReadUInt16()!=1 || reader.ReadUInt16()!=32 || w!=expected[i] || h!=expected[i])
                    throw new Exception("Incorrect ICO directory entry.");
                int length=reader.ReadInt32(),offset=reader.ReadInt32();
                frames[i]=new byte[length]; Array.Copy(data,offset,frames[i],0,length);
                using(var stream=new MemoryStream(frames[i]))
                using(var image=new Bitmap(stream)) {
                    if(image.Width!=w || image.Height!=h || image.GetPixel(0,0).A!=0)
                        throw new Exception("Frame size/transparency incorrect.");
                    bool visible=false;
                    for(int y=0;y<h && !visible;y++) for(int x=0;x<w;x++)
                        if(image.GetPixel(x,y).A>200) {visible=true;break;}
                    if(!visible) throw new Exception("Empty icon frame.");
                }
            }
        }
        Console.WriteLine("PASS genuine ICO: eight decoded 32-bit frames, correct dimensions and transparent corners");
        IntPtr module=LoadLibraryEx(Path.GetFullPath(executable),IntPtr.Zero,0x22);
        if(module==IntPtr.Zero) throw new Exception("Cannot read executable resources.");
        try {
            byte[] group=null;
            ResourceCallback callback=(m,t,n,p)=>{ if(group==null) group=ReadResource(m,n,14); return true; };
            EnumResourceNames(module,(IntPtr)14,callback,IntPtr.Zero);
            GC.KeepAlive(callback);
            if(group==null) throw new Exception("Executable has no icon group.");
            using(var reader=new BinaryReader(new MemoryStream(group))) {
                reader.ReadUInt16();reader.ReadUInt16();
                if(reader.ReadUInt16()!=8) throw new Exception("Executable lost ICO sizes.");
                for(int i=0;i<8;i++) {
                    reader.BaseStream.Position=6+i*14+12;
                    int id=reader.ReadUInt16();
                    if(!ReadResource(module,(IntPtr)id,3).SequenceEqual(frames[i]))
                        throw new Exception("Executable icon differs from supplied branding conversion.");
                }
            }
        } finally { FreeLibrary(module); }
        Console.WriteLine("PASS published executable contains all eight matching native icon resources");
    }
}
"@
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$assets = Join-Path $workspace 'MinuteCapture\Assets\Branding'
foreach ($file in @('logo.png','taskbar-log.png')) {
    $source = Get-FileHash -LiteralPath (Join-Path $workspace $file)
    $packaged = Get-FileHash -LiteralPath (Join-Path $assets $file)
    if ($source.Hash -ne $packaged.Hash) { throw "$file copy differs from original." }
}
[BrandingValidation]::Verify((Join-Path $assets 'SnapMinute.ico'),$Executable)
Write-Output 'PASS packaged PNG copies match the original assets'