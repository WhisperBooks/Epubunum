# Packs redistributable_bin\Win64 for a release (called by
# tools\redist.bat package [VERSION]): three .zip parts that unpack into
# one folder - core (whisper.cpp, ggml with its CPU and Vulkan backends,
# FFmpeg, the MSVC OpenMP runtime), cuda (ggml-cuda and NVIDIA's runtime),
# rocm (ggml-hip, AMD's HIP SDK runtime and rocBLAS kernels) - each with
# its licences and a read-me, and SHA256SUMS beside them, in
# redistributable_bin\packages. Linux and macOS: tools/redist.sh package.
param([string]$Version = (Get-Date -Format 'yyyyMMdd'))
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root 'redistributable_bin\Win64'
$Pkg = Join-Path $Root 'redistributable_bin\packages'
if (-not (Test-Path (Join-Path $Src 'whisper.dll'))) {
  Write-Host "No ${Src}: run tools\redist.bat collect first"
  exit 1
}
New-Item -ItemType Directory -Force -Path $Pkg | Out-Null

# by name: NVIDIA's and AMD's runtimes, as whisper-dev's Windows build
# copies them next to the backends
$CudaRe = '^(ggml-cuda\.dll|cudart64_.*\.dll|cublas64_.*\.dll|cublasLt64_.*\.dll|nvrtc.*\.dll)$'
$RocmRe = '^(ggml-hip\.dll|amdhip64.*\.dll|amd_comgr.*\.dll|hiprtc.*\.dll|hipblas.*\.dll|hipblaslt.*\.dll|rocblas.*\.dll|rocsolver.*\.dll|libhipblas.*\.dll|rocblas|hipblaslt)$'

$Parts = @{ core = @(); cuda = @(); rocm = @() }
foreach ($e in Get-ChildItem -LiteralPath $Src) {
  if ($e.Name -eq 'README.md' -or $e.Name -eq 'licences') { continue }
  if ($e.Name -match $CudaRe) { $Parts.cuda += $e.FullName }
  elseif ($e.Name -match $RocmRe) { $Parts.rocm += $e.FullName }
  else { $Parts.core += $e.FullName }
}
$Lic = Join-Path $Src 'licences'
$LicFiles = @{ core = @(); cuda = @(); rocm = @() }
if (Test-Path $Lic) {
  foreach ($f in Get-ChildItem -LiteralPath $Lic -File) {
    if ($f.Name -like 'CUDA-*') { $LicFiles.cuda += $f.FullName }
    elseif ($f.Name -like 'ROCm-*') { $LicFiles.rocm += $f.FullName }
    else { $LicFiles.core += $f.FullName }
  }
}

$Readme = @'
EpubUnum libraries - Win64, part "{0}", {1}

Unpack the parts you need into one folder, next to EpubReader.exe /
EpubBuilder.exe.

  core  always: whisper.cpp, ggml (CPU variants, Vulkan), FFmpeg 8
  cuda  NVIDIA GPUs (GTX 16xx / RTX 20xx and newer): ggml-cuda, cudart,
        cuBLAS. Needs NVIDIA's driver 580 or newer.
  rocm  AMD GPUs: ggml-hip, the HIP SDK runtime, rocBLAS and its kernels.
        Needs AMD's Adrenalin driver.

Licences are in licences\: FFmpeg (LGPL; its configure line in
FFmpeg-BUILD-INFO.txt - source: https://ffmpeg.org/releases/ for that
version), whisper.cpp (MIT; source: https://github.com/ggml-org/whisper.cpp),
NVIDIA's CUDA EULA (cudart / cuBLAS are redistributable under its
attachment A) and AMD's HIP SDK licence files.
'@

$Sums = @()
foreach ($part in 'core', 'cuda', 'rocm') {
  if ($Parts[$part].Count -eq 0) { Write-Host "${part}: nothing in ${Src} - left out"; continue }
  if ($part -ne 'core' -and $LicFiles[$part].Count -eq 0) {
    Write-Host "Warning: no licence file for $part in $Lic (tools\redist.bat collect copies them from CUDA_PATH / HIP_PATH)"
  }
  $Stage = Join-Path ([IO.Path]::GetTempPath()) ("epubunum-$part-" + [Guid]::NewGuid())
  New-Item -ItemType Directory -Path $Stage | Out-Null
  try {
    foreach ($p in $Parts[$part]) { Copy-Item -LiteralPath $p -Destination $Stage -Recurse }
    if ($LicFiles[$part].Count -gt 0) {
      $L = New-Item -ItemType Directory -Path (Join-Path $Stage 'licences')
      foreach ($p in $LicFiles[$part]) { Copy-Item -LiteralPath $p -Destination $L.FullName }
    }
    Set-Content -LiteralPath (Join-Path $Stage "EpubUnum-libs-$part.txt") -Value ($Readme -f $part, $Version)
    $Name = "EpubUnum-libs-Win64-$part-$Version.zip"
    $Zip = Join-Path $Pkg $Name
    if (Test-Path $Zip) { Remove-Item -LiteralPath $Zip }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($Stage, $Zip, [IO.Compression.CompressionLevel]::Optimal, $false)
    $Size = (Get-Item -LiteralPath $Zip).Length
    Write-Host ("{0}: {1} MB" -f $Name, [Math]::Round($Size / 1MB))
    if ($Size -gt 2GB) { Write-Host "Warning: $Name is over GitHub's 2 GiB per file" }
    $Hash = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLower()
    $Sums += "$Hash  $Name"
  }
  finally {
    Remove-Item -LiteralPath $Stage -Recurse -Force
  }
}
Set-Content -LiteralPath (Join-Path $Pkg "SHA256SUMS-Win64-$Version.txt") -Value $Sums
Write-Host "In $Pkg, with SHA256SUMS-Win64-$Version.txt"
