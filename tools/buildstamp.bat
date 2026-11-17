@echo off
rem Pre-build step of EpubReader and EpubBuilder (their .dproj's
rem PreBuildEvent, every platform - Delphi compiles on Windows for Linux
rem and macOS too): writes demos\common\BuildStamp.inc with when and from
rem which commit the program is built, so its debug log says which build
rem it is (owner, 2026-11-17: "can't tell if this is new update or not").
rem
rem   tools\buildstamp.bat
rem
rem The file is not tracked (.gitignore). The time comes from PowerShell
rem (locale-independent; else %DATE% %TIME%), the commit from git when it
rem is on PATH ('+' = changes not yet committed; "no git" otherwise).
rem Always succeeds: a build never fails for want of a stamp.
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "OUT=%ROOT%\demos\common\BuildStamp.inc"
set "WHEN="
for /f "usebackq delims=" %%d in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'" 2^>nul`) do set "WHEN=%%d"
if "%WHEN%"=="" set "WHEN=%DATE% %TIME:~0,5%"
set "REV=no git"
for /f "usebackq delims=" %%r in (`git -C "%ROOT%" rev-parse --short HEAD 2^>nul`) do set "REV=%%r"
set "DIRTY="
for /f "usebackq delims=" %%s in (`git -C "%ROOT%" status --porcelain --untracked-files=no 2^>nul`) do set "DIRTY=+"
> "%OUT%" (
  echo { Written by tools\buildstamp.bat before every build of EpubReader and
  echo   EpubBuilder ^(their pre-build step^) - not tracked. }
  echo const
  echo   { When and from which commit the program was built ^('+': with
  echo     changes not committed yet^). }
  echo   BUILD_STAMP = '%WHEN%, %REV%%DIRTY%';
)
echo buildstamp: %WHEN%, %REV%%DIRTY%
exit /b 0
