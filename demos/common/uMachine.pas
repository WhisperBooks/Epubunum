(* @abstract(What machine a program runs on, in one line for its logs: the
  computer's name, the operating system, the processor and the memory.)

  Logs and reports from several machines look alike (owner, 2026-11-17:
  "The output logs give no idea of the machine or backend being used");
  this line tells them apart. Windows reads the processor's name from the
  registry and the memory from GlobalMemoryStatusEx; Linux reads
  /proc/cpuinfo and /proc/meminfo; a Mac is asked by sysctl; elsewhere
  what is not known is left out.

  MachineFacts is what a leaderboard tells machines apart by: the model,
  the processor, its cores (on Apple's chips the performance and the
  efficiency cores, and the graphics' cores) and the memory - never the
  computer's or the user's name. *)
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

{ The operating system in a few words, for the website's leaderboard:
  'Windows 11 (Version ...)' as the run-time library has it; on Linux
  the HOST's name and version from its os-release ('SteamOS 3.8.2',
  'Ubuntu 24.04'). Steam runs a Linux program in a container whose own
  os-release says 'Steam Runtime 3' (owner, 2026-11-23: "Doesn't
  actually say SteamOS" - three machines all showed that); the host's
  is at /run/host there, and is looked for first.
  @returns(the text) }
function MachineOs: string;

type
  { What kind of machine this is, for telling machines apart on a
    leaderboard (owner, 2026-11-24: "It would be good to differentiate
    Macs more. Memory and CPU/GPU cores are the big things that tend to
    make a difference"; and for every machine, "with fallback to
    Unknown"). Nothing here names the computer or its user: a model's
    name is the maker's ('Mac mini', 'ROG Ally RC71L'). What cannot be
    told is '' or 0. }
  TMachineFacts = record
    { The model: 'Mac mini', 'MacBook Pro', 'Steam Deck', 'ROG Ally
      RC71L' ('' = not told, or a maker's placeholder). }
    Model: string;
    { The processor or chip: 'Apple M4 Pro', 'AMD Ryzen Z1 Extreme'. }
    Cpu: string;
    { Processor cores (0 = not told). }
    Cores: Integer;
    { Of them the performance cores and the efficiency cores (0, 0 = not
      told, or the processor has one kind). }
    PerfCores: Integer;
    { The efficiency cores (see PerfCores). }
    EffCores: Integer;
    { Logical processors. }
    Threads: Integer;
    { The cores of an Apple chip's graphics (0 = not told / not Apple). }
    GpuCores: Integer;
    { Memory, whole GB (0 = not told). }
    MemoryGb: Integer;
  end;

{ The machine's facts, read once and kept (the first call may take a
  moment: a Mac is asked through its system report). Safe from any
  thread; a program that shows them in its window asks first from a
  thread of its own.
  @returns(the facts) }
function MachineFacts: TMachineFacts;

implementation

uses
  {$IF Defined(MSWINDOWS)}
  Winapi.Windows, System.Win.Registry,
  {$ELSEIF Defined(POSIX)}
  // System.SysUtils.DeleteFile's inline body expands only with it (H2443)
  Posix.Unistd,
  {$ENDIF}
  {$IF Defined(MACOS) and not Defined(IOS)}
  // libc and the names' underscore, for the system's own calls below
  Posix.Base,
  {$ENDIF}
  System.SysUtils, System.Classes;

var
  { MachineFacts' answer, once read (under GFactsGate). }
  GFacts: TMachineFacts;
  { GFacts is read. }
  GFactsDone: Boolean = False;
  { Guards the two. }
  GFactsGate: TObject = nil;

{$IF Defined(MSWINDOWS)}
{ GetLogicalProcessorInformationEx: the system's list of processors,
  with each core's efficiency class (the plain call has none). }
function WinProcessorInfoEx(ARelation: DWORD; ABuffer: Pointer; var ALength: DWORD): BOOL; stdcall;
  external kernel32 name 'GetLogicalProcessorInformationEx';

{ The cores by kind, on a chip that has two (Intel's P and E cores,
  Arm's big and little): the cores of the highest efficiency class are
  the performance cores, all others the efficiency cores. Both 0 on a
  chip with one kind, or when the system does not say.
  @param(ACores every core counted (0 = not said))
  @param(APerf the performance cores)
  @param(AEff the efficiency cores) }
procedure WinCoreKinds(out ACores, APerf, AEff: Integer);
var
  Len, At, Size: DWORD;
  Buf: TBytes;
  Counts: array[Byte] of Integer;
  I, Top, Kinds: Integer;
begin
  ACores := 0;
  APerf := 0;
  AEff := 0;
  Len := 0;
  // 0 = RelationProcessorCore
  WinProcessorInfoEx(0, nil, Len);
  if Len < 12 then
    Exit;
  SetLength(Buf, Len);
  if not WinProcessorInfoEx(0, @Buf[0], Len) then
    Exit;
  FillChar(Counts, SizeOf(Counts), 0);
  // each entry: Relationship (4 bytes), Size (4), Flags (1),
  // EfficiencyClass (1), ...
  At := 0;
  while At + 12 <= Len do
  begin
    Size := PCardinal(@Buf[At + 4])^;
    if (Size < 12) or (At + Size > Len) then
      Break;
    if PCardinal(@Buf[At])^ = 0 then
    begin
      Inc(Counts[Buf[At + 9]]);
      Inc(ACores);
    end;
    Inc(At, Size);
  end;
  Top := -1;
  Kinds := 0;
  for I := 0 to High(Counts) do
    if Counts[I] > 0 then
    begin
      Inc(Kinds);
      Top := I;
    end;
  if Kinds < 2 then
    Exit;
  APerf := Counts[Top];
  AEff := ACores - APerf;
end;
{$ENDIF}

{$IF Defined(MACOS) and not Defined(IOS)}
{ sysctlbyname(3): a value of the system by its name. }
function MacSysctlByName(AName: MarshaledAString; AOld: Pointer; AOldLen: PNativeUInt; ANew: Pointer;
  ANewLen: NativeUInt): Integer; cdecl; external libc name _PU + 'sysctlbyname';
{ popen(3): a command's output as a stream. }
function MacPOpen(ACommand, AMode: MarshaledAString): Pointer; cdecl; external libc name _PU + 'popen';
{ pclose(3). }
function MacPClose(AStream: Pointer): Integer; cdecl; external libc name _PU + 'pclose';
{ fgets(3): a line of a stream. }
function MacFGets(ABuffer: MarshaledAString; ASize: Integer; AStream: Pointer): MarshaledAString; cdecl;
  external libc name _PU + 'fgets';

{ A whole number of the system by its sysctl name (0 when there is none:
  an Intel Mac has no hw.perflevel1). }
function MacSysNumber(const AName: string): Int64;
var
  V: Int64;
  Len: NativeUInt;
begin
  Result := 0;
  V := 0;
  Len := SizeOf(V);
  // a 4-byte answer fills the low half (little-endian), a 8-byte one all
  if MacSysctlByName(MarshaledAString(UTF8String(AName)), @V, @Len, nil, 0) = 0 then
    if Len = 4 then
      Result := Integer(V and $FFFFFFFF)
    else if Len = 8 then
      Result := V;
end;

{ A text of the system by its sysctl name ('' when there is none). }
function MacSysText(const AName: string): string;
var
  Buf: array[0..255] of AnsiChar;
  Len: NativeUInt;
begin
  Result := '';
  FillChar(Buf, SizeOf(Buf), 0);
  Len := SizeOf(Buf) - 1;
  if MacSysctlByName(MarshaledAString(UTF8String(AName)), @Buf[0], @Len, nil, 0) = 0 then
    Result := Trim(string(UTF8String(PAnsiChar(@Buf[0]))));
end;

{ What ACommand prints, line by line (nothing when it cannot be run). }
function MacCommandLines(const ACommand: string): TArray<string>;
var
  Stream: Pointer;
  Buf: array[0..1023] of AnsiChar;
begin
  Result := nil;
  Stream := MacPOpen(MarshaledAString(UTF8String(ACommand)), 'r');
  if Stream = nil then
    Exit;
  try
    while (Length(Result) < 400) and (MacFGets(@Buf[0], SizeOf(Buf), Stream) <> nil) do
      Result := Result + [TrimRight(string(UTF8String(PAnsiChar(@Buf[0]))))];
  finally
    MacPClose(Stream);
  end;
end;
{$ENDIF}

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
    {$ELSEIF Defined(MACOS) and not Defined(IOS)}
    // 'Apple M4 Pro'
    Result := MacSysText('machdep.cpu.brand_string');
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
  {$IF Defined(MSWINDOWS)}
  Result := 0;
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
  {$ELSEIF Defined(MACOS) and not Defined(IOS)}
  Result := UInt64(MacSysNumber('hw.memsize'));
  {$ELSE}
  // (Linux sets it on every path: a first 0 there was H2077)
  Result := 0;
  {$ENDIF}
end;

{ A model's name as a maker left it, or '' when it is a placeholder a
  board's maker never filled in. Valve's code names are the machines'. }
function CleanModel(const AVendor, AProduct: string): string;
const
  NOTHING: array[0..8] of string = ('System Product Name', 'To Be Filled By O.E.M.', 'Default string',
    'System Version', 'Not Applicable', 'None', 'Unknown', 'Not Specified', 'OEM');
var
  I: Integer;
begin
  Result := Trim(AProduct);
  for I := Low(NOTHING) to High(NOTHING) do
    if SameText(Result, NOTHING[I]) then
      Exit('');
  if Pos('valve', LowerCase(AVendor)) > 0 then
  begin
    if SameText(Result, 'Jupiter') then
      Result := 'Steam Deck'
    else if SameText(Result, 'Galileo') then
      Result := 'Steam Deck OLED';
  end;
  // one line, not too long for a board
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Copy(Result, 1, 60);
end;

{ The facts, read from the system (MachineFacts keeps them). }
function ReadMachineFacts: TMachineFacts;
{$IF Defined(MSWINDOWS)}
var
  R: TRegistry;
  Vendor, Product: string;
  Len: DWORD;
  Buf: TBytes;
  P: PSystemLogicalProcessorInformation;
  I: Integer;
  AllCores: Integer;
{$ELSEIF Defined(MACOS) and not Defined(IOS)}
var
  Lines: TArray<string>;
  I, P: Integer;
  Line, Value: string;
  Graphics: Boolean;
{$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
var
  L, Seen: TStringList;
  I, P: Integer;
  Phys, Core, Name, Value: string;
{$ENDIF}
begin
  Result := Default(TMachineFacts);
  Result.Cpu := MachineCpu;
  Result.Threads := TThread.ProcessorCount;
  Result.MemoryGb := Integer(Round(MachineMemory / (1024.0 * 1024.0 * 1024.0)));
  try
    {$IF Defined(MSWINDOWS)}
    Vendor := '';
    Product := '';
    R := TRegistry.Create(KEY_READ);
    try
      R.RootKey := HKEY_LOCAL_MACHINE;
      if R.OpenKeyReadOnly('HARDWARE\DESCRIPTION\System\BIOS') then
      begin
        Vendor := R.ReadString('SystemManufacturer');
        Product := R.ReadString('SystemProductName');
        // Lenovo's product name is a type's code ('83EY' - the owner's
        // Legion, 2026-11-24); the name people know is its version
        if (Pos('lenovo', LowerCase(Vendor)) > 0) and (CleanModel(Vendor, R.ReadString('SystemVersion')) <> '') then
          Product := R.ReadString('SystemVersion');
        // a maker's placeholder there: the family, then the main board (a
        // PC built from parts has no model, its board has a name)
        if CleanModel(Vendor, Product) = '' then
          Product := R.ReadString('SystemFamily');
        if CleanModel(Vendor, Product) = '' then
          Product := R.ReadString('BaseBoardProduct');
      end;
    finally
      R.Free;
    end;
    Result.Model := CleanModel(Vendor, Product);
    // the cores: one entry of the system's list each
    Len := 0;
    GetLogicalProcessorInformation(nil, Len);
    if Len >= SizeOf(TSystemLogicalProcessorInformation) then
    begin
      SetLength(Buf, Len);
      if GetLogicalProcessorInformation(PSystemLogicalProcessorInformation(@Buf[0]), Len) then
      begin
        P := PSystemLogicalProcessorInformation(@Buf[0]);
        for I := 1 to Integer(Len div SizeOf(TSystemLogicalProcessorInformation)) do
        begin
          if P^.Relationship = RelationProcessorCore then
            Inc(Result.Cores);
          Inc(P);
        end;
      end;
    end;
    // the kinds of core (and the count again: the plain list stops at
    // 64 processors)
    try
      WinCoreKinds(AllCores, Result.PerfCores, Result.EffCores);
      if AllCores > 0 then
        Result.Cores := AllCores;
    except
      // an older Windows without the call: the plain count stays
    end;
    {$ELSEIF Defined(MACOS) and not Defined(IOS)}
    Result.Cores := Integer(MacSysNumber('hw.physicalcpu'));
    // Apple's chips: performance cores, then efficiency cores
    Result.PerfCores := Integer(MacSysNumber('hw.perflevel0.physicalcpu'));
    Result.EffCores := Integer(MacSysNumber('hw.perflevel1.physicalcpu'));
    if Result.EffCores = 0 then
      Result.PerfCores := 0;
    // the model's name and the graphics' cores: only the system's report
    // has them in words ('Model Name: Mac mini'; under 'Graphics/Displays:'
    // 'Total Number of Cores: 10')
    Lines := MacCommandLines('/usr/sbin/system_profiler SPHardwareDataType SPDisplaysDataType 2>/dev/null');
    Graphics := False;
    for I := 0 to High(Lines) do
    begin
      Line := Trim(Lines[I]);
      if SameText(Line, 'Graphics/Displays:') then
        Graphics := True;
      P := Pos(':', Line);
      if P < 2 then
        Continue;
      Value := Trim(Copy(Line, P + 1, MaxInt));
      Line := Trim(Copy(Line, 1, P - 1));
      if SameText(Line, 'Model Name') and (Result.Model = '') then
        Result.Model := CleanModel('Apple', Value)
      else if Graphics and SameText(Line, 'Total Number of Cores') and (Result.GpuCores = 0) then
        Result.GpuCores := StrToIntDef(Value, 0);
    end;
    // the report did not say (it could not be run, or words it differently):
    // the model's identifier at least ('Mac16,10')
    if Result.Model = '' then
      Result.Model := CleanModel('Apple', MacSysText('hw.model'));
    {$ELSEIF Defined(LINUX) and not Defined(ANDROID)}
    Result.Model := CleanModel(Trim(ReadProcFile('/sys/class/dmi/id/sys_vendor')),
      Trim(ReadProcFile('/sys/class/dmi/id/product_name')));
    // Lenovo's product name is a type's code: the name is its version
    if (Pos('lenovo', LowerCase(ReadProcFile('/sys/class/dmi/id/sys_vendor'))) > 0) and
      (CleanModel('Lenovo', Trim(ReadProcFile('/sys/class/dmi/id/product_version'))) <> '') then
      Result.Model := CleanModel('Lenovo', Trim(ReadProcFile('/sys/class/dmi/id/product_version')));
    // a maker's placeholder there: the family, then the main board
    if Result.Model = '' then
      Result.Model := CleanModel('', Trim(ReadProcFile('/sys/class/dmi/id/product_family')));
    if Result.Model = '' then
      Result.Model := CleanModel('', Trim(ReadProcFile('/sys/class/dmi/id/board_name')));
    // the cores: the pairs of 'physical id' and 'core id' in /proc/cpuinfo
    L := TStringList.Create;
    Seen := TStringList.Create;
    try
      Seen.Sorted := True;
      Seen.Duplicates := dupIgnore;
      L.Text := ReadProcFile('/proc/cpuinfo');
      Phys := '';
      Core := '';
      for I := 0 to L.Count do
      begin
        // a blank line (and the end) closes a processor's block
        if (I = L.Count) or (Trim(L[I]) = '') then
        begin
          if Core <> '' then
            Seen.Add(Phys + ':' + Core);
          Phys := '';
          Core := '';
          Continue;
        end;
        P := Pos(':', L[I]);
        if P < 2 then
          Continue;
        Name := Trim(Copy(L[I], 1, P - 1));
        Value := Trim(Copy(L[I], P + 1, MaxInt));
        if Name = 'physical id' then
          Phys := Value
        else if Name = 'core id' then
          Core := Value;
      end;
      Result.Cores := Seen.Count;
    finally
      Seen.Free;
      L.Free;
    end;
    {$ENDIF}
  except
    // what was read so far stands
  end;
  if Result.MemoryGb < 0 then
    Result.MemoryGb := 0;
end;

function MachineFacts: TMachineFacts;
begin
  TMonitor.Enter(GFactsGate);
  try
    if not GFactsDone then
    begin
      GFacts := ReadMachineFacts;
      GFactsDone := True;
    end;
    Result := GFacts;
  finally
    TMonitor.Exit(GFactsGate);
  end;
end;

function MachineOs: string;
{$IF Defined(LINUX) and not Defined(ANDROID)}
const
  // the host's seen from inside Steam's container, then the system's own
  FILES: array[0..3] of string = ('/run/host/etc/os-release', '/run/host/usr/lib/os-release',
    '/etc/os-release', '/usr/lib/os-release');
var
  L: TStringList;
  I: Integer;
  Name, Version, Pretty: string;

  { KEY's value in the file loaded, without its quotes. }
  function Value(const AKey: string): string;
  begin
    Result := Trim(L.Values[AKey]);
    if (Length(Result) >= 2) and CharInSet(Result[1], ['"', '''']) and (Result[Length(Result)] = Result[1]) then
      Result := Copy(Result, 2, Length(Result) - 2);
  end;
{$ENDIF}
begin
  Result := TOSVersion.ToString;
  {$IF Defined(MACOS) and not Defined(IOS)}
  // TOSVersion's text has the version only in a bracket ('macOS (Version
  // 26.1.0)'), and a board shows what stands before it: 'macOS 26.1'
  // (owner, 2026-11-24: "Mac only says MacOS, no version")
  Result := Format('macOS %d.%d', [TOSVersion.Major, TOSVersion.Minor]);
  if TOSVersion.Build > 0 then
    Result := Result + Format(' (build %d)', [TOSVersion.Build]);
  {$ENDIF}
  {$IF Defined(LINUX) and not Defined(ANDROID)}
  L := TStringList.Create;
  try
    L.NameValueSeparator := '=';
    for I := Low(FILES) to High(FILES) do
    begin
      L.Text := ReadProcFile(FILES[I]);
      Name := Value('NAME');
      Version := Value('VERSION_ID');
      Pretty := Value('PRETTY_NAME');
      if (Name <> '') and (Version <> '') then
        Exit(Name + ' ' + Version);
      if Pretty <> '' then
        Exit(Pretty);
      if Name <> '' then
        Exit(Name);
    end;
  finally
    L.Free;
  end;
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

initialization
  // not freed at the end: a thread still reading the facts when the
  // program closes would be left holding a gate that is gone
  GFactsGate := TObject.Create;

end.
