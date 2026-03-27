# compile_shaders.ps1 — Compiles GLSL shaders to SPIR-V using glslangValidator from the Vulkan SDK
$scriptDir = $PSScriptRoot

# Find the latest Vulkan SDK
$vulkanBase = "C:\VulkanSDK"
$sdkDir = Get-ChildItem -Path $vulkanBase -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1
if (-not $sdkDir) {
    Write-Error "No Vulkan SDK found under $vulkanBase"
    exit 1
}

$glslang = Join-Path $sdkDir.FullName "Bin\glslangValidator.exe"
if (-not (Test-Path $glslang)) {
    # Try glslc as a fallback
    $glslang = Join-Path $sdkDir.FullName "Bin\glslc.exe"
    if (-not (Test-Path $glslang)) {
        Write-Error "Neither glslangValidator.exe nor glslc.exe found in $($sdkDir.FullName)\Bin"
        exit 1
    }
    # glslc mode
    Write-Host "Using glslc: $glslang"
    & $glslang -o "$scriptDir\quad_vert.spv" "$scriptDir\quad.vert"
    & $glslang -o "$scriptDir\quad_frag.spv" "$scriptDir\quad.frag"
}
else {
    Write-Host "Using glslangValidator: $glslang"
    & $glslang -V -o "$scriptDir\quad_vert.spv" "$scriptDir\quad.vert"
    & $glslang -V -o "$scriptDir\quad_frag.spv" "$scriptDir\quad.frag"
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Shaders compiled successfully."
} else {
    Write-Error "Shader compilation failed."
    exit 1
}
