(* @abstract(What machine a program runs on, in one line for its logs: the
  computer's name, the operating system, the processor and the memory.)

  Logs and reports from several machines look alike (owner, 2026-11-17:
  "The output logs give no idea of the machine or backend being used");
  this line tells them apart. Windows reads the processor's name from the
  registry and the memory from GlobalMemoryStatusEx; Linux reads
  /proc/cpuinfo and /proc/meminfo; elsewhere what is not known is left
  out. *)
unit uMachine;

interface

{ The computer's name ('' when it cannot be told).
  @returns(the name) }
function MachineName: string;

{ The processor's name, e.g. 'Intel(R) Core(TM) i9-14900HX' ('' when it
  cannot be told).
  @returns(the name) }
function MachineCpu: string;

{ Physical memory, bytes (0 when it cannot be told).
  @returns(the size) }
function MachineMemory: UInt64;

{ One line: 'name - OS; CPU (N logical processors); 32 GB of memory', the
  parts not known left out.
  @returns(the line) }
function MachineText: string;

implementation

uses
  {$IF Defined(MSWINDOWS)}
  Winapi.Windows, System.Win.Registry,
  {$ELSEIF Defined(POSIX)}
  // System.SysUtils.DeleteFile's inline body expands only with it (H2443)
  Posix.Unistd,
  {$ENDIF}
  System.SysUtils, System.Classes;

{$IF Defined(LINUX) and not Defined(ANDROID)}
{ The whole of a /proc file. Their size is 0 until read, so the file is
  read until nothing more comes ('' when it cannot be read). }
function ReadProcFile(const AFileName: string): string;
var
  S: TFileStream;
  B: TBytes;
  N, Total: Integer;
begin
  Result := '';
  try
    S := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      Total := 0;
      SetLength(B, 65536);
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

{ The value after AKey + ':' on the first line of AText starting with AKey
  (trimmed; '' when there is none). }
function ProcValue(const AText, AKey: string): string;
var
  L: TStringList;
  I, P: Integer;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.Text := AText;
    for I := 0 to L.Count - 1 do
      if L[I].StartsWith(AKey) then
      begin
        P := Pos(':', L[I]);
        if P > 0 then
          Exit(Trim(Copy(L[I], P + 1, MaxInt)));
      end;
  finally
    L.Free;
  end;
end;
{$ENDIF}

function MachineName: string;
{$IF Defined(POSIX)}
var
  Buf: array[0..255] of AnsiChar;
{$ENDIF}
begin
  Result := '';
  {$IF Defined(MSWINDOWS)}
  Result := GetEnvironmentVariable('COMPUTERNAME');
  {$ELSEIF Defined(POSIX)}
  FillChar(Buf, SizeOf(Buf), 0);
  if gethostname(@Buf[0], SizeOf(Buf) - 1) = 0 then
    Result := string(UTF8String(PAnsiChar(@Buf[0])));
  {$ENDIF}
end;

function MachineCpu: string;
{$IF Defined(MSWINDOWS)}
var
  R: TRegistry;
{$ENDIF}
begin
  Result := '';
  try
    {$IF Defined(MSWINDOWS)}
    R := TRegistry.Create(KEY_READ);
    try
      R.RootKey := HKEY_LOCAL_MACHINE;
      if R.OpenKeyReadOnly('HARDWARE\DESCRIPTION\System\CentralProcessor\0') then
        Result := R.ReadString('ProcessorNameString');
    finally
      R.Free;
    end;
    {$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
    Result := ProcValue(ReadProcFile('/proc/cpuinfo'), 'model name');
    {$ENDIF}
  except
    Result := '';
  end;
  // the registry pads some names with spaces
  Result := Trim(Result);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
end;

function MachineMemory: UInt64;
{$IF Defined(MSWINDOWS)}
var
  M: TMemoryStatusEx;
{$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
var
  V: string;
  P: Integer;
{$ENDIF}
begin
  Result := 0;
  {$IF Defined(MSWINDOWS)}
  FillChar(M, SizeOf(M), 0);
  M.dwLength := SizeOf(M);
  if GlobalMemoryStatusEx(M) then
    Result := M.ullTotalPhys;
  {$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
  // 'MemTotal:       65536000 kB'
  V := ProcValue(ReadProcFile('/proc/meminfo'), 'MemTotal');
  P := Pos(' ', V);
  if P > 0 then
    V := Copy(V, 1, P - 1);
  Result := UInt64(StrToInt64Def(V, 0)) * 1024;
  {$ENDIF}
end;

function MachineText: string;
var
  Name, Cpu: string;
  Mem: UInt64;
begin
  Name := MachineName;
  Result := TOSVersion.ToString;
  if Name <> '' then
    Result := Name + ' - ' + Result;
  Cpu := MachineCpu;
  if Cpu <> '' then
    Result := Result + '; ' + Cpu + Format(' (%d logical processors)', [TThread.ProcessorCount])
  else
    Result := Result + Format('; %d logical processors', [TThread.ProcessorCount]);
  Mem := MachineMemory;
  if Mem > 0 then
    Result := Result + Format('; %.0f GB of memory', [Mem / (1024.0 * 1024.0 * 1024.0)]);
end;

end.
