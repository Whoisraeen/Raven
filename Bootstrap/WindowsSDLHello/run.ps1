$repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$swiftToolBin = Join-Path $env:LOCALAPPDATA 'Programs\Swift\Toolchains\6.2.4+Asserts\usr\bin'
$swiftRuntimeBin = Join-Path $env:LOCALAPPDATA 'Programs\Swift\Runtimes\6.2.4\usr\bin'
$sdkRoot = Join-Path $env:LOCALAPPDATA 'Programs\Swift\Platforms\6.2.4\Windows.platform\Developer\SDKs\Windows.sdk'
$sdlBin = Join-Path $repoRoot 'vendor\SDL3\SDL3-3.4.2\lib\x64'

$env:Path = "$swiftToolBin;$swiftRuntimeBin;$sdlBin;$env:Path"
$env:SDKROOT = $sdkRoot

& (Join-Path $swiftToolBin 'swift.exe') run RavenWindowsBootstrap

