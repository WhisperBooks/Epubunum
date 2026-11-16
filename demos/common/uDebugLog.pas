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

implementation

uses
  {$IFDEF POSIX}
  // System.SysUtils.DeleteFile's inline body expands only with it (H2443)
  Posix.Unistd,
  {$ENDIF}
  System.SysUtils, System.Classes, System.SyncObjs;

var
  { Guards the file: lines come from several threads. }
  Lock: TCriticalSection;
  { The log file, '' when not started. }
  LogName: string;

procedure WriteRaw(const AText: string);
var
  S: TFileStream;
  B: TBytes;
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
  finally
    S.Free;
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
        DeleteFile(AFileName + '.old');
        RenameFile(AFileName, AFileName + '.old');
      end;
      LogName := AFileName;
      {$IF Defined(MSWINDOWS)}
      Plat := 'Windows';
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
      WriteRaw(Format('%s - debug log, %s, started %s' + sLineBreak + 'Program: %s' + sLineBreak +
        'OS: %s' + sLineBreak, [ChangeFileExt(ExtractFileName(ParamStr(0)), ''), Plat,
        FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), ParamStr(0), TOSVersion.ToString]));
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

initialization
  Lock := TCriticalSection.Create;

finalization
  FreeAndNil(Lock);

end.
