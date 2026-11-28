(* @abstract(A plain-text debug log for the demo programs: one file per
  program, started afresh at each run, every line written straight to the
  file with the time and the thread.)

  A crash in a library (whisper.cpp, ggml, a GPU runtime, FFmpeg) ends the
  program without a word on screen; the last lines here say what it was
  doing. The previous run's log is kept as .old.

  The file is next to the program's settings (Linux: ~/.config/<program>/,
  Windows: %APPDATA%\<program>\, macOS: ~/Library/Application Support/
  <program>/). Lines can come from any thread. *)
unit uDebugLog;

interface

uses
  System.SysUtils;

{ Starts the log in AFileName: the previous file (if any) becomes
  AFileName + '.old', and the new one begins with the program, the
  platform and the time. Safe to call once; later calls are ignored.
  @param(AFileName  the log file, with its folder (made when missing)) }
procedure DebugLogOpen(const AFileName: string);

{ Adds a line (or several, split at line breaks) to the log, with the time
  and the thread's id. Does nothing before DebugLogOpen or when the file
  cannot be written. Thread safe.
  @param(AText  the text) }
procedure DebugLog(const AText: string);

{ The log file DebugLogOpen started; '' before that.
  @returns(the file name) }
function DebugLogFile: string;

{ When and from which commit the program was built: 'yyyy-mm-dd hh:nn,
  <commit>' ('+' after the commit: with changes not committed yet), from
  BuildStamp.inc, which tools\buildstamp.bat writes before every build.
  The log's first lines show it.
  @returns(the stamp) }
function BuildStamp: string;

{ Where an address is: on Linux the library (or program) it falls in and
  the offset in that file, from /proc/self/maps - 'libsk4d.so +0x1a2b3c'
  - so a crash in a library can be placed without a debugger (Steam Deck,
  2026-11-17); '' elsewhere or when it cannot be told.
  @param(AAddress  the address)
  @returns(the place) }
function DebugLogWhere(AAddress: Pointer): string;

{ Logs an exception the application did not handle: its class, message,
  address and, on Linux, the library it happened in (DebugLogWhere) - also
  for the address an access violation's message names. For
  Application.OnException (then show it as before).
  @param(E  the exception)
  @param(AAddress  where it was raised (System.ExceptAddr)) }
procedure DebugLogException(E: Exception; AAddress: Pointer);

implementation

uses
  {$IFDEF POSIX}
  // System.SysUtils.DeleteFile's and RenameFile's inline bodies expand
  // only with them (H2443)
  Posix.Unistd, Posix.Stdio,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  // System.SysUtils.RenameFile's inline body expands only with it (H2443)
  Winapi.Windows,
  {$ENDIF}
  // the version (major.minor.build) on the log's first lines
  uVersion,
  // System.SysUtils: in the interface's uses
  System.Classes, System.SyncObjs;

{$I BuildStamp.inc}

var
  { Guards the file: lines come from several threads. Made at start-up
    and never freed (see the end of the unit). }
  Lock: TCriticalSection;
  { The log file, '' when not started. }
  LogName: string;

const
  { A log grows to this, then goes to .old and a new one starts (zip 397:
    a TV left playing all day wrote without end - never the device's last
    space): the log takes at most twice this. }
  LOG_MAX = Int64(8) * 1024 * 1024;

procedure WriteRaw(const AText: string);
var
  S: TFileStream;
  B: TBytes;
  Size: Int64;
begin
  // open, append, close for every line: what is written is in the file
  // even when the next instruction kills the process
  B := TEncoding.UTF8.GetBytes(AText);
  if FileExists(LogName) then
    S := TFileStream.Create(LogName, fmOpenReadWrite or fmShareDenyNone)
  else
    S := TFileStream.Create(LogName, fmCreate);
  try
    S.Seek(0, soEnd);
    if Length(B) > 0 then
      S.WriteBuffer(B[0], Length(B));
    Size := S.Size;
  finally
    S.Free;
  end;
  // full: the lines so far become .old (the last run's .old goes), and a
  // new log starts saying so
  if Size > LOG_MAX then
  begin
    System.SysUtils.DeleteFile(LogName + '.old');
    if System.SysUtils.RenameFile(LogName, LogName + '.old') then
    begin
      B := TEncoding.UTF8.GetBytes(FormatDateTime('hh:nn:ss.zzz', Now) + ' (the log went on from ' +
        ExtractFileName(LogName) + '.old: it had reached ' + IntToStr(LOG_MAX div (1024 * 1024)) + ' MB)' +
        sLineBreak);
      S := TFileStream.Create(LogName, fmCreate);
      try
        S.WriteBuffer(B[0], Length(B));
      finally
        S.Free;
      end;
    end;
  end;
end;

procedure DebugLogOpen(const AFileName: string);
var
  Plat: string;
begin
  if (Lock = nil) or (LogName <> '') or (AFileName = '') then
    Exit;
  Lock.Acquire;
  try
    try
      ForceDirectories(ExtractFilePath(AFileName));
      if FileExists(AFileName) then
      begin
        // qualified: Winapi.Windows (later in the uses) has its own
        System.SysUtils.DeleteFile(AFileName + '.old');
        System.SysUtils.RenameFile(AFileName, AFileName + '.old');
      end;
      LogName := AFileName;
      {$IF Defined(MSWINDOWS)}
      Plat := 'Windows';
      {$ELSEIF Defined(ANDROID)}
      // (was "unknown" there)
      Plat := 'Android';
      {$ELSEIF Defined(IOS)}
      Plat := 'iOS';
      {$ELSEIF Defined(MACOS)}
      Plat := 'macOS';
      {$ELSEIF Defined(LINUX)}
      Plat := 'Linux';
      {$ELSE}
      Plat := 'unknown';
      {$ENDIF}
      {$IFDEF CPU64BITS}
      Plat := Plat + ' 64-bit';
      {$ENDIF}
      WriteRaw(Format('%s - debug log, %s, started %s' + sLineBreak + 'Version: %s' + sLineBreak +
        'Build: %s' + sLineBreak + 'Program: %s' + sLineBreak + 'OS: %s' + sLineBreak,
        [ChangeFileExt(ExtractFileName(ParamStr(0)), ''), Plat, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
        VersionText, BUILD_STAMP, ParamStr(0), TOSVersion.ToString]));
    except
      LogName := '';
    end;
  finally
    Lock.Release;
  end;
end;

procedure DebugLog(const AText: string);
var
  Lines: TStringList;
  Head, Text: string;
  I: Integer;
begin
  if (Lock = nil) or (LogName = '') then
    Exit;
  Head := FormatDateTime('hh:nn:ss.zzz', Now) + Format(' [%d] ', [TThread.CurrentThread.ThreadID]);
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Text := '';
    for I := 0 to Lines.Count - 1 do
      Text := Text + Head + Lines[I] + sLineBreak;
    if Lines.Count = 0 then
      Text := Head + sLineBreak;
  finally
    Lines.Free;
  end;
  Lock.Acquire;
  try
    try
      WriteRaw(Text);
    except
      // a log that cannot be written must not stop the program
    end;
  finally
    Lock.Release;
  end;
end;

function DebugLogFile: string;
begin
  Result := LogName;
end;

function BuildStamp: string;
begin
  Result := BUILD_STAMP;
end;

{$IF Defined(LINUX) and not Defined(ANDROID)}
{ The whole of /proc/self/maps (its size is 0 until read: read until
  nothing more comes). }
function ReadMaps: string;
var
  S: TFileStream;
  B: TBytes;
  N, Total: Integer;
begin
  Result := '';
  try
    S := TFileStream.Create('/proc/self/maps', fmOpenRead or fmShareDenyNone);
    try
      Total := 0;
      SetLength(B, 262144);
      repeat
        if Total = Length(B) then
          SetLength(B, Length(B) * 2);
        N := S.Read(B[Total], Length(B) - Total);
        Inc(Total, N);
      until N <= 0;
      Result := TEncoding.UTF8.GetString(B, 0, Total);
    finally
      S.Free;
    end;
  except
    Result := '';
  end;
end;
{$ENDIF}

function DebugLogWhere(AAddress: Pointer): string;
{$IF Defined(LINUX) and not Defined(ANDROID)}
var
  L: TStringList;
  I, P: Integer;
  Line, Range, Path: string;
  Parts: TArray<string>;
  A, First, Last, Ofs: UInt64;
{$ENDIF}
begin
  Result := '';
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  if AAddress = nil then
    Exit;
  A := UInt64(NativeUInt(AAddress));
  L := TStringList.Create;
  try
    L.Text := ReadMaps;
    // '7fbf53600000-7fbf53a00000 r-xp 00012000 08:01 1234   /path/lib.so'
    for I := 0 to L.Count - 1 do
    begin
      Line := L[I];
      Parts := Line.Split([' '], TStringSplitOptions.ExcludeEmpty);
      if Length(Parts) < 5 then
        Continue;
      Range := Parts[0];
      P := Pos('-', Range);
      if P = 0 then
        Continue;
      First := UInt64(StrToInt64Def('$' + Copy(Range, 1, P - 1), 0));
      Last := UInt64(StrToInt64Def('$' + Copy(Range, P + 1, MaxInt), 0));
      if (A < First) or (A >= Last) then
        Continue;
      Ofs := UInt64(StrToInt64Def('$' + Parts[2], 0));
      if Length(Parts) >= 6 then
        Path := Parts[5]
      else
        Path := '(anonymous memory)';
      Exit(Format('%s +0x%x (%s)', [ExtractFileName(Path), A - First + Ofs, Path]));
    end;
  finally
    L.Free;
  end;
  {$ENDIF}
end;

procedure DebugLogException(E: Exception; AAddress: Pointer);
var
  Where, Msg, Hex: string;
  P, K: Integer;
  V: Int64;
begin
  Msg := Format('UNHANDLED %s: %s - raised at %p', [E.ClassName, E.Message, AAddress]);
  Where := DebugLogWhere(AAddress);
  if Where <> '' then
    Msg := Msg + ' in ' + Where;
  // an access violation names the faulting instruction itself:
  // 'Access violation at address 00007FBF5378F2B7, accessing ...'
  P := Pos('at address ', E.Message);
  if P > 0 then
  begin
    K := P + Length('at address ');
    Hex := '';
    while (K <= Length(E.Message)) and CharInSet(E.Message[K], ['0'..'9', 'A'..'F', 'a'..'f']) do
    begin
      Hex := Hex + E.Message[K];
      Inc(K);
    end;
    if (Hex <> '') and TryStrToInt64('$' + Hex, V) then
    begin
      Where := DebugLogWhere(Pointer(NativeUInt(V)));
      if Where <> '' then
        Msg := Msg + '; the faulting address is in ' + Where;
    end;
  end;
  DebugLog(Msg);
end;

initialization
  Lock := TCriticalSection.Create;
  // meant to stay (below): not a leak for ReportMemoryLeaksOnShutdown.
  // Windows only: the call exists only there (E2003 on Linux / macOS),
  // and is marked platform (W1002) - as is the leak report itself
  {$IFDEF MSWINDOWS}
  {$WARN SYMBOL_PLATFORM OFF}
  RegisterExpectedMemoryLeak(Lock);
  {$WARN SYMBOL_PLATFORM ON}
  {$ENDIF}

// No finalization: the lock is never freed. A worker thread (whisper.cpp's
// and ggml's lines come from theirs) can be inside DebugLog while the
// program shuts down - between its "Lock = nil" test and Acquire - and a
// freed lock there is an access violation on the way out. The process
// ends anyway; the system takes the lock back.

end.
