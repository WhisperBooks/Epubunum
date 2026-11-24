@echo off
rem Epubunum's redistributables on Windows: the whisper.cpp libraries
rem (whisper-dev) and FFmpeg's (ffmpeg-dev) together in
rem redistributable_bin\Win64, and copied next to a built program.
rem
rem   tools\redist.bat collect WHISPER_DEV [FFMPEG_DEV]
rem     (FFMPEG_DEV not needed when WHISPER_DEV holds FFmpeg's DLLs too)
rem     fills redistributable_bin\Win64 from WHISPER_DEV\dlls (or
rem     WHISPER_DEV itself when it holds the DLLs - TWhisper's
rem     redistributable_bin\Win64 will do) and FFMPEG_DEV\dlls\windows-x64,
rem     with their licence texts
rem   tools\redist.bat package [VERSION]
rem     packs redistributable_bin\Win64 for a release, in
rem     redistributable_bin\packages: core, cuda and rocm .zip parts that
rem     unpack into one folder, with their licences, and SHA256SUMS
rem     (tools\redist-package.ps1; VERSION defaults to today's date)
rem   tools\redist.bat deploy TARGET
rem     copies redistributable_bin\Win64 next to a built program (TARGET:
rem     its folder, e.g. demos\EpubBuilder\Win64\Release)
rem     (every file; the programs' Win64 builds copy what they need
rem     themselves - tools\postbuild.bat, their post-build step)
rem
rem Linux and macOS: tools/redist.sh.
setlocal
rem the repository's folder, without "tools\.." in the messages
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "OUT=%ROOT%\redistributable_bin\Win64"
if /i "%~1"=="collect" goto collect
if /i "%~1"=="deploy" goto deploy
if /i "%~1"=="package" goto package
goto usage

:collect
if "%~2"=="" goto usage
set "WDIR=%~2\dlls"
if not exist "%WDIR%\whisper.dll" set "WDIR=%~2"
set "FDIR=%~3\dlls\windows-x64"
if not exist "%WDIR%\whisper.dll" (
  echo No whisper.dll in %WDIR%: run whisper-dev's build.bat
  exit /b 1
)
rem FFmpeg from ffmpeg-dev, or already beside whisper.cpp's DLLs (TWhisper's
rem redistributable_bin\Win64 holds both) - then FFMPEG_DEV is not needed
if not exist "%FDIR%\avutil-60.dll" if exist "%WDIR%\avutil-60.dll" set "FDIR=%WDIR%"
if not exist "%FDIR%\avutil-60.dll" (
  echo No avutil-60.dll in %FDIR%: run ffmpeg-dev's build.bat
  exit /b 1
)
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%\licences"
rem whisper.cpp's DLLs with their sub-folders (HIP: rocblas\library), not
rem the Debug build; robocopy's exit codes below 8 are success
rem no programs (ffmpeg.exe, ffplay.exe, ffprobe.exe, whisper's tools): the
rem libraries are what the programs use
robocopy "%WDIR%" "%OUT%" /e /xd debug /xf README.md .gitignore *.pdb *.exe /njh /njs /nfl /ndl >nul
if errorlevel 8 goto failed
if /i not "%FDIR%"=="%WDIR%" copy /y "%FDIR%\*.dll" "%OUT%\" >nul || goto failed
for %%f in (COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md BUILD-INFO.txt) do (
  if exist "%FDIR%\%%f" copy /y "%FDIR%\%%f" "%OUT%\licences\FFmpeg-%%f" >nul
)
rem whisper.cpp's MIT licence: whisper-dev's checkout (WHISPER_DEV\whisper.cpp),
rem or a licences folder / LICENSE file beside the DLLs (TWhisper's
rem redistributable_bin\Win64 has none - a warning: it must go with them)
for %%f in ("%~2\whisper.cpp\LICENSE" "%WDIR%\licences\whisper.cpp-LICENSE.txt" "%~2\licences\whisper.cpp-LICENSE.txt" "%WDIR%\whisper.cpp-LICENSE.txt") do (
  if not exist "%OUT%\licences\whisper.cpp-LICENSE.txt" if exist "%%~f" copy /y "%%~f" "%OUT%\licences\whisper.cpp-LICENSE.txt" >nul
)
if not exist "%OUT%\licences\whisper.cpp-LICENSE.txt" (
  echo Warning: no whisper.cpp licence found - copy whisper.cpp's LICENSE to %OUT%\licences\whisper.cpp-LICENSE.txt ^(MIT: it must go with the DLLs^)
)
rem NVIDIA's licence with its runtime (cudart / cuBLAS: attachment A),
rem AMD's HIP SDK licence texts with theirs
if exist "%OUT%\ggml-cuda.dll" if exist "%CUDA_PATH%\EULA.txt" copy /y "%CUDA_PATH%\EULA.txt" "%OUT%\licences\CUDA-EULA.txt" >nul
if exist "%OUT%\ggml-hip.dll" if defined HIP_PATH (
  for %%f in ("%HIP_PATH%\*LICENSE*" "%HIP_PATH%\*NOTICE*") do (
    if exist "%%~f" copy /y "%%~f" "%OUT%\licences\ROCm-%%~nxf" >nul
  )
)
echo Collected in %OUT%
exit /b 0

:deploy
if "%~2"=="" goto usage
if not exist "%OUT%\whisper.dll" (
  echo No %OUT%: run tools\redist.bat collect first
  exit /b 1
)
if not exist "%~2\" (
  echo No folder %~2
  exit /b 1
)
robocopy "%OUT%" "%~2" /e /xf *.exe /njh /njs /nfl /ndl >nul
if errorlevel 8 goto failed
echo Libraries copied next to the program in %~2
exit /b 0

:package
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0redist-package.ps1" %2
exit /b %errorlevel%

:failed
echo Copying failed
exit /b 1

:usage
echo tools\redist.bat collect WHISPER_DEV FFMPEG_DEV
echo tools\redist.bat package [VERSION]
echo tools\redist.bat deploy TARGET
exit /b 1
