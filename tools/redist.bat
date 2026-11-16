@echo off
rem Epubunum's redistributables on Windows: the whisper.cpp libraries
rem (whisper-dev) and FFmpeg's (ffmpeg-dev) together in
rem redistributable_bin\Win64, and copied next to a built program.
rem
rem   tools\redist.bat collect WHISPER_DEV FFMPEG_DEV
rem     fills redistributable_bin\Win64 from WHISPER_DEV\dlls (or
rem     WHISPER_DEV itself when it holds the DLLs - TWhisper's
rem     redistributable_bin\Win64 will do) and FFMPEG_DEV\dlls\windows-x64,
rem     with their licence texts
rem   tools\redist.bat deploy TARGET
rem     copies redistributable_bin\Win64 next to a built program (TARGET:
rem     its folder, e.g. demos\EpubBuilder\Win64\Release)
rem
rem Linux and macOS: tools/redist.sh.
setlocal
set "ROOT=%~dp0.."
set "OUT=%ROOT%\redistributable_bin\Win64"
if /i "%~1"=="collect" goto collect
if /i "%~1"=="deploy" goto deploy
goto usage

:collect
if "%~3"=="" goto usage
set "WDIR=%~2\dlls"
if not exist "%WDIR%\whisper.dll" set "WDIR=%~2"
set "FDIR=%~3\dlls\windows-x64"
if not exist "%WDIR%\whisper.dll" (
  echo No whisper.dll in %WDIR%: run whisper-dev's build.bat
  exit /b 1
)
if not exist "%FDIR%\avutil-60.dll" (
  echo No avutil-60.dll in %FDIR%: run ffmpeg-dev's build.bat
  exit /b 1
)
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%\licences"
rem whisper.cpp's DLLs with their sub-folders (HIP: rocblas\library), not
rem the Debug build; robocopy's exit codes below 8 are success
robocopy "%WDIR%" "%OUT%" /e /xd debug /xf README.md .gitignore *.pdb /njh /njs /nfl /ndl >nul
if errorlevel 8 goto failed
copy /y "%FDIR%\*.dll" "%OUT%\" >nul || goto failed
for %%f in (COPYING.LGPLv2.1 COPYING.LGPLv3 LICENSE.md BUILD-INFO.txt) do (
  if exist "%FDIR%\%%f" copy /y "%FDIR%\%%f" "%OUT%\licences\FFmpeg-%%f" >nul
)
if exist "%~2\whisper.cpp\LICENSE" copy /y "%~2\whisper.cpp\LICENSE" "%OUT%\licences\whisper.cpp-LICENSE.txt" >nul
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
robocopy "%OUT%" "%~2" /e /njh /njs /nfl /ndl >nul
if errorlevel 8 goto failed
echo Libraries copied next to the program in %~2
exit /b 0

:failed
echo Copying failed
exit /b 1

:usage
echo tools\redist.bat collect WHISPER_DEV FFMPEG_DEV
echo tools\redist.bat deploy TARGET
exit /b 1
