(* @abstract(Turns a request from outside to end the program - SIGTERM,
  SIGINT, SIGHUP - into a call on the main thread, so the program can save
  what it has before it goes.)

  Owner, 2026-11-18: "Steam has a "Exit Game" option from it's own control
  panel. This forcibly quits the running app. It would be nice to trap
  that and write anything pending". On Linux Steam's reaper ends a game
  with SIGTERM (then SIGKILL if it is still there a little later); the
  system does the same at shut-down. By default SIGTERM ends a program
  where it stands: settings, the reader's place, the queue file - all as
  they were at the last save.

  A signal handler may do almost nothing safely, so it only writes the
  signal's number to a pipe; a thread waiting on the pipe queues the
  program's handler to the main thread. The handler should be quick: what
  matters first (settings, the place), then end - Steam does not wait
  long.

  POSIX only (Linux, macOS). On Windows nothing is installed:
  QuitSignalInstall returns False. *)
unit uQuitSignal;

interface

uses
  System.SysUtils;

type
  { The program's handler: the signal's number (SIGTERM 15, SIGINT 2,
    SIGHUP 1), on the main thread, once. }
  TQuitSignalProc = reference to procedure(ASignal: Integer);

{ Installs the handlers for SIGTERM, SIGINT and SIGHUP; AProc runs on the
  main thread at the first of them (later ones are ignored - it is already
  ending).
  @param(AProc  the program's handler)
  @returns(False where there is nothing to install (Windows) or it failed) }
function QuitSignalInstall(const AProc: TQuitSignalProc): Boolean;

{ The signal's name for the logs ('SIGTERM' ...).
  @param(ASignal  the number)
  @returns(the name, or 'signal N') }
function QuitSignalName(ASignal: Integer): string;

{ Notes in AFile (beside the settings) that the program was ended by
  ASignal, with the time, so the next start can say so (QuitSignalLast).
  @param(AFile  the note's file)
  @param(ASignal  the signal's number)
  @param(AWhat  what was running, '' for nothing) }
procedure QuitSignalRecord(const AFile: string; ASignal: Integer; const AWhat: string);

{ The note QuitSignalRecord left, deleted once read.
  @param(AFile  the note's file)
  @returns(the line for the log, '' when the last run ended normally) }
function QuitSignalLast(const AFile: string): string;

{ Ends the program at once, without finalization or waiting for threads
  (a transcription on the GPU would make Steam's wait run out): for after
  the handler has saved what matters. Files written are closed by the
  system.
  @param(ACode  the exit code) }
procedure QuitNow(ACode: Integer);

implementation

uses
  {$IFDEF POSIX}
  Posix.Unistd, Posix.Signal,
  {$ENDIF}
  System.Classes, System.IOUtils;

var
  { The handler (nil = not installed). }
  GProc: TQuitSignalProc;
  { The handler has been queued. }
  GDone: Boolean;
  {$IFDEF POSIX}
  { The pipe: the signal handler writes, the thread reads. }
  GPipe: TPipeDescriptors;
  { The pipe was made. }
  GHasPipe: Boolean;
  {$ENDIF}

function QuitSignalName(ASignal: Integer): string;
begin
  case ASignal of
    1: Result := 'SIGHUP';
    2: Result := 'SIGINT';
    15: Result := 'SIGTERM';
  else
    Result := 'signal ' + IntToStr(ASignal);
  end;
end;

{$IFDEF POSIX}
{ The signal handler: the number into the pipe, nothing else (write() is
  safe in a signal handler). }
procedure OnSignal(ASignal: Integer); cdecl;
var
  B: Byte;
begin
  B := Byte(ASignal);
  __write(GPipe.WriteDes, @B, 1);
end;
{$ENDIF}

function QuitSignalInstall(const AProc: TQuitSignalProc): Boolean;
begin
  {$IFDEF POSIX}
  Result := False;
  if GHasPipe then
    Exit;
  if pipe(GPipe) <> 0 then
    Exit;
  GHasPipe := True;
  GProc := AProc;
  TThread.CreateAnonymousThread(
    procedure
    var
      B: Byte;
      N: Integer;
    begin
      repeat
        N := __read(GPipe.ReadDes, @B, 1);
      until (N <> -1) or (GetLastError <> 4);   // EINTR: read again
      // 0: the pipe was closed (the program ends normally)
      if (N <> 1) or GDone then
        Exit;
      GDone := True;
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(GProc) then
            GProc(B);
        end);
    end).Start;
  signal(SIGTERM, OnSignal);
  signal(SIGINT, OnSignal);
  signal(SIGHUP, OnSignal);
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure QuitSignalRecord(const AFile: string; ASignal: Integer; const AWhat: string);
var
  Text: string;
begin
  Text := Format('The last run was ended from outside at %s (%s - Steam''s Exit Game, or the system shutting ' +
    'down)', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), QuitSignalName(ASignal)]);
  if AWhat <> '' then
    Text := Text + ' while ' + AWhat;
  try
    TFile.WriteAllText(AFile, Text + '.', TEncoding.UTF8);
  except
    // a note that cannot be written must not stop the saving
  end;
end;

function QuitSignalLast(const AFile: string): string;
begin
  Result := '';
  try
    if not TFile.Exists(AFile) then
      Exit;
    Result := Trim(TFile.ReadAllText(AFile, TEncoding.UTF8));
    TFile.Delete(AFile);
  except
    // unreadable: as if there were none
  end;
end;

procedure QuitNow(ACode: Integer);
begin
  {$IFDEF POSIX}
  _exit(ACode);
  {$ELSE}
  Halt(ACode);
  {$ENDIF}
end;

initialization

finalization
  {$IFDEF POSIX}
  // a normal end: the thread's read returns 0 and it ends without a call
  if GHasPipe then
    __close(GPipe.WriteDes);
  {$ENDIF}
end.
