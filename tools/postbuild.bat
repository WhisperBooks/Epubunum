@echo off
rem Post-build step of EpubReader and EpubBuilder on Win64 (their .dproj's
rem PostBuildEvent): the libraries the program needs are copied next to
rem it, so its output folder is complete - for a Steam depot as it is.
rem
rem   tools\postbuild.bat PROGRAM CONFIG OUTPUT_FOLDER [PROJECT_FOLDER]
rem
rem   OUTPUT_FOLDER may be relative ($(OUTPUTDIR) is .\Win64\Steam\ when
rem   the project's output path is): it is taken from PROJECT_FOLDER, else
rem   from the current folder.
rem
rem   EpubReader   FFmpeg (av*, sw*, postproc*) and its licence texts
rem   EpubBuilder  whisper.cpp, ggml, FFmpeg and their licences:
rem                Steam / SteamDebug - the CPU and Vulkan backends only
rem                (CUDA and ROCm are to be free DLC; owner 2026-11-17);
rem                Debug / Release - all of redistributable_bin\Win64,
rem                CUDA and ROCm included (for testing every device)
rem   Steam / SteamDebug also get steam_api64.dll
rem   EpubBuilder also gets media\aladdin.m4a (its calibration's recording;
rem   the builder looks in media\ beside the program first) in every
rem   configuration - a Steam folder is complete with it
rem
rem CUDA and ROCm files are told apart by the names tools\redist-package.ps1
rem uses for its cuda and rocm parts. Copies are robocopy's: files already
rem there and unchanged are not copied again.
rem A missing redistributable_bin\Win64 fails the Steam configurations (a
rem depot must be complete) and is a warning only in Debug / Release (the
rem libraries may be on PATH).
setlocal
rem the repository's folder, without "tools\.." in the messages
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "SRC=%ROOT%\redistributable_bin\Win64"
set "PROG=%~1"
set "CFG=%~2"
set "OUT=%~3"
set "PROJ=%~4"
if "%OUT%"=="" goto usage
rem a relative output folder is the project's (not the IDE's current one)
if not "%PROJ%"=="" if not "%OUT:~1,1%"==":" if not "%OUT:~0,2%"=="\\" set "OUT=%PROJ%\%OUT%"
rem the full name, without ".\" and without the trailing backslash robocopy
rem would read as escaping the closing quote
if not "%OUT:~-1%"=="\" set "OUT=%OUT%\"
for %%I in ("%OUT%.") do set "OUT=%%~fI"
if not exist "%OUT%\" (
  echo postbuild: no folder %OUT%
  exit /b 1
)
set STEAM=0
if /i "%CFG:~0,5%"=="Steam" set STEAM=1
set "RC=/njh /njs /nfl /ndl /np"

if not exist "%SRC%\avutil-60.dll" goto nolibs
if /i "%PROG%"=="EpubReader" goto reader
if /i "%PROG%"=="EpubBuilder" goto builder
goto usage

:reader
set "STEP=FFmpeg's DLLs"
robocopy "%SRC%" "%OUT%" av*.dll sw*.dll postproc*.dll %RC% >nul
if errorlevel 8 goto failed
call :licences FFmpeg-*
echo postbuild: FFmpeg copied to %OUT%
goto steam

:builder
if "%STEAM%"=="1" goto buildercore
set "STEP=the libraries"
robocopy "%SRC%" "%OUT%" /e /xf README.md %RC% >nul
if errorlevel 8 goto failed
echo postbuild: whisper.cpp (every backend) and FFmpeg copied to %OUT%
call :media
goto steam

:buildercore
rem CPU + Vulkan: everything but the cuda and rocm parts (their DLLs,
rem rocBLAS / hipBLASLt kernel folders and licence texts)
set "STEP=the libraries (CPU and Vulkan)"
robocopy "%SRC%" "%OUT%" /e /xd rocblas hipblaslt /xf README.md ggml-cuda.dll cudart64_*.dll cublas64_*.dll cublasLt64_*.dll nvrtc*.dll ggml-hip.dll amdhip64*.dll amd_comgr*.dll hiprtc*.dll hipblas*.dll hipblaslt*.dll rocblas*.dll rocsolver*.dll libhipblas*.dll CUDA-* ROCm-* %RC% >nul
if errorlevel 8 goto failed
echo postbuild: whisper.cpp (CPU and Vulkan) and FFmpeg copied to %OUT%
call :media
goto steam

:nolibs
if "%STEAM%"=="1" (
  echo postbuild: no libraries in %SRC% - run tools\redist.bat collect first
  exit /b 1
)
echo postbuild: warning - no libraries in %SRC%, none copied; tools\redist.bat collect fills it
goto steam

:steam
if "%STEAM%"=="0" exit /b 0
if not exist "%ROOT%\redistributable_bin\steam\win64\steam_api64.dll" (
  echo postbuild: no redistributable_bin\steam\win64\steam_api64.dll - copy it from TSteamAPI's redistributable_bin\win64
  exit /b 1
)
set "STEP=steam_api64.dll"
copy /y "%ROOT%\redistributable_bin\steam\win64\steam_api64.dll" "%OUT%\" >nul || goto failed
echo postbuild: steam_api64.dll copied to %OUT%
exit /b 0

:failed
rem robocopy: 8 = some files not copied (in use? the program still
rem running), 16 = a folder missing or not readable
echo postbuild: copying %STEP% from %SRC% to %OUT% failed (code %errorlevel%)
exit /b 1

:media
rem EpubBuilder's calibration recording (media\aladdin.m4a of the
rem repository: git-ignored, the owner's copy) - a warning when missing:
rem the calibration then asks for a recording
if not exist "%ROOT%\media\aladdin.m4a" (
  echo postbuild: warning - no %ROOT%\media\aladdin.m4a: the calibration will ask for a recording
  exit /b 0
)
robocopy "%ROOT%\media" "%OUT%\media" aladdin.m4a %RC% >nul
if errorlevel 8 (
  echo postbuild: warning - media\aladdin.m4a not copied ^(code %errorlevel%^)
  exit /b 0
)
echo postbuild: media\aladdin.m4a copied to %OUT%\media
exit /b 0

:licences
rem the licence texts matching %1, when redistributable_bin\Win64 has a
rem licences folder (tools\redist.bat collect makes it; a folder filled
rem by hand may have none - a warning, not a failure)
if not exist "%SRC%\licences\" (
  echo postbuild: warning - no %SRC%\licences, no licence texts copied ^(tools\redist.bat collect adds them^)
  exit /b 0
)
robocopy "%SRC%\licences" "%OUT%\licences" %1 %RC% >nul
if errorlevel 8 echo postbuild: warning - licence texts not copied ^(code %errorlevel%^)
exit /b 0

:usage
echo tools\postbuild.bat EpubReader^|EpubBuilder CONFIG OUTPUT_FOLDER [PROJECT_FOLDER]
exit /b 1
