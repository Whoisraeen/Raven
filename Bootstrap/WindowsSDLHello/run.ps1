$repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

# Auto-detect Swift toolchain version from installed directory
$swiftBase = Join-Path $env:LOCALAPPDATA 'Programs\Swift\Toolchains'
$swiftVersion = if (Test-Path $swiftBase) {
    (Get-ChildItem -Path $swiftBase -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
} else { '6.1+Asserts' }

$runtimeBase = Join-Path $env:LOCALAPPDATA 'Programs\Swift\Runtimes'
$runtimeVersion = if (Test-Path $runtimeBase) {
    (Get-ChildItem -Path $runtimeBase -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
} else { '6.1' }

$platformBase = Join-Path $env:LOCALAPPDATA 'Programs\Swift\Platforms'
$platformVersion = if (Test-Path $platformBase) {
    (Get-ChildItem -Path $platformBase -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
} else { '6.1' }

$swiftToolBin = Join-Path $env:LOCALAPPDATA "Programs\Swift\Toolchains\$swiftVersion\usr\bin"
$swiftRuntimeBin = Join-Path $env:LOCALAPPDATA "Programs\Swift\Runtimes\$runtimeVersion\usr\bin"
$sdkRoot = Join-Path $env:LOCALAPPDATA "Programs\Swift\Platforms\$platformVersion\Windows.platform\Developer\SDKs\Windows.sdk"

# Auto-detect SDL3 version from vendor directory
$sdlBase = Join-Path $repoRoot 'vendor\SDL3'
$sdlDir = if (Test-Path $sdlBase) {
    (Get-ChildItem -Path $sdlBase -Directory -Filter 'SDL3-*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
} else { Join-Path $sdlBase 'SDL3-3.4.2' }
$sdlBin = Join-Path $sdlDir 'lib\x64'

$env:Path = "$swiftToolBin;$swiftRuntimeBin;$sdlBin;$env:Path"
$env:SDKROOT = $sdkRoot

& (Join-Path $swiftToolBin 'swift.exe') run RavenWindowsBootstrap
