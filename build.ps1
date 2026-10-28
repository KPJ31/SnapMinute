[CmdletBinding()]
param(
    [ValidateSet('win-x64','win-arm64')][string]$Runtime = 'win-x64',
    [switch]$SkipInstaller,
    [string]$IsccPath,
    [string]$RuntimeFrameworkVersion
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Push-Location $PSScriptRoot
try {
    dotnet build MinuteCapture.slnx -c Release
    if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
    dotnet run --project MinuteCapture.Tests -c Release --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Core checks failed.' }
    $publish = Join-Path $PSScriptRoot "artifacts/publish/$Runtime"
    $expected = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'artifacts/publish')) + [IO.Path]::DirectorySeparatorChar
    if (![IO.Path]::GetFullPath($publish).StartsWith($expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe output path.' }
    if (Test-Path -LiteralPath $publish) { Remove-Item -LiteralPath $publish -Recurse -Force }
    $arguments = @('publish','MinuteCapture/MinuteCapture.csproj','-c','Release','-r',$Runtime,
        '--self-contained','true','-p:PublishSingleFile=false','-p:PublishTrimmed=false',
        '-p:DebugType=None','-p:DebugSymbols=false','-o',$publish)
    if ($RuntimeFrameworkVersion) { $arguments += "-p:RuntimeFrameworkVersion=$RuntimeFrameworkVersion" }
    dotnet @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
    Write-Host "Published application: $publish\MinuteCapture.exe"
    if (!$SkipInstaller) {
        if (!$IsccPath) {
            $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
            if ($command) { $IsccPath = $command.Source }
            else {
                foreach ($candidate in @(
                    (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Inno Setup 6\ISCC.exe'),
                    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
                    "$PSScriptRoot\tools\InnoSetup\ISCC.exe")) {
                    if (Test-Path -LiteralPath $candidate) { $IsccPath = $candidate; break }
                }
            }
        }
        if (!$IsccPath) { throw 'Inno Setup 6 is missing. Install it from https://jrsoftware.org/isinfo.php or use -IsccPath. Publish output is ready.' }
        & $IsccPath "/DMyRuntime=$Runtime" "/DPublishDir=$publish" (Join-Path $PSScriptRoot 'installer/MinuteCapture.iss')
        if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
    }
}
finally { Pop-Location }