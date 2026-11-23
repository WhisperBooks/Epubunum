(* @abstract(The power a graphics card draws while a benchmark runs, read
  about once a second: NVIDIA's cards through NVML, the library their
  driver installs (Windows and Linux); AMD's on Linux from the files the
  kernel's driver keeps.)

  Owner, 2026-11-23: a laptop's own power profile made the same
  benchmark half as fast again ("you know those are actually valid
  different tests"), and the program cannot ask a maker's profile what
  it is; "It would be nice if there was an easy, consistant way to read
  GPU power" - there is none across makers; "Most consumer PCs use
  nvidia if they have a GPU" - so NVIDIA's cards were read first (asked:
  in the log only, or on the website too? "website too"); 19:30: "AMD
  have 18.72% market - possibly worth trying?" - AMD's on Linux, where
  it is a file to read (his three AMD machines run SteamOS; on Windows
  it needs AMD's own library and none of his machines could try it).

  GpuPowerStart begins the reading in a thread of its own; GpuPowerStop
  ends it and gives, for every card found: the median and the highest
  draw, and the limit the card is held to (which is what a maker's low
  profile usually lowers; NVML's limit, an AMD card's power1_cap). The
  median, not the mean (owner, 18:31: "median then"): the readings cover
  the whole run, and the card idles while the model loads and the book
  is written - the median is what it drew while it worked. GpuPowerFind
  picks the card a benchmark ran on by its description.

  AMD on Linux: /sys/class/drm/cardN/device (vendor 0x1002) has a hwmon
  folder with power1_average (a card of its own) or power1_input (a
  processor's graphics: the WHOLE chip's power, processor included), in
  microwatts.

  Nothing is shipped and nothing is needed: with no NVIDIA driver (no
  nvml.dll / libnvidia-ml.so.1) and no such file, on a Mac, or with a
  card that does not report its power, GpuPowerStop gives nothing and
  nothing else changes. *)
unit uGpuPower;

interface

type
  { What a card drew between GpuPowerStart and GpuPowerStop. }
  TGpuPower = record
    { 'nvidia' or 'amd'. }
    Vendor: string;
    { The card as NVML names it ('NVIDIA GeForce RTX 5090 Laptop GPU');
      an AMD card: 'AMD graphics' and its PCI device number. }
    Name: string;
    { Readings taken (0 = the card does not report its power). }
    Readings: Integer;
    { Their median, W. }
    MedianW: Integer;
    { The highest, W. }
    PeakW: Integer;
    { The limit the card is held to, W (0 = not told). }
    LimitW: Integer;
  end;

{ Starts reading (a reading still under way is ended first). }
procedure GpuPowerStart;

{ Ends the reading.
  @returns(a record for each card found - none when nothing was started
    or no card can be read) }
function GpuPowerStop: TArray<TGpuPower>;

{ The card among ACards that ADescription names (a device's description
  as the benchmark has it). An NVIDIA card by its name ('NVIDIA' at the
  names' start is not needed to agree); an AMD card when the description
  is an AMD one ('AMD', 'Radeon' or 'RADV' in it) and the machine has
  exactly one AMD card - the kernel's files do not carry the name.
  @returns(its index, -1 when none is it or it gave no reading) }
function GpuPowerFind(const ACards: TArray<TGpuPower>; const ADescription: string): Integer;

implementation

uses
  {$IF Defined(MSWINDOWS)}
  Winapi.Windows,
  {$ENDIF}
  System.SysUtils, System.Classes, System.SyncObjs, System.IOUtils, System.Generics.Collections;

{$IF Defined(MSWINDOWS) or (Defined(LINUX) and not Defined(ANDROID))}
  {$DEFINE GPUPOWER_READS}
{$ENDIF}
{$IF Defined(LINUX) and not Defined(ANDROID)}
  {$DEFINE GPUPOWER_SYSFS}
{$ENDIF}

{$IFDEF GPUPOWER_READS}
const
  { NVML, as the driver installs it. }
  {$IF Defined(MSWINDOWS)}
  NVML_LIBRARY = 'nvml.dll';
  {$ELSE}
  NVML_LIBRARY = 'libnvidia-ml.so.1';
  {$ENDIF}
  { NVML's "it worked". }
  NVML_SUCCESS = 0;
  { Between two readings, ms. }
  READ_EVERY_MS = 1000;
  { The cards read at most. }
  CARDS_MAX = 8;

type
  { nvmlInit_v2 and nvmlShutdown. }
  TNvmlPlain = function: Integer; cdecl;
  { nvmlDeviceGetCount_v2. }
  TNvmlCount = function(out ACount: Cardinal): Integer; cdecl;
  { nvmlDeviceGetHandleByIndex_v2. }
  TNvmlHandle = function(AIndex: Cardinal; out ADevice: Pointer): Integer; cdecl;
  { nvmlDeviceGetName. }
  TNvmlName = function(ADevice: Pointer; AName: PAnsiChar; ALength: Cardinal): Integer; cdecl;
  { nvmlDeviceGetPowerUsage and nvmlDeviceGetEnforcedPowerLimit: mW. }
  TNvmlMilliwatts = function(ADevice: Pointer; out AMilliwatts: Cardinal): Integer; cdecl;

  { The reading. }
  TGpuPowerReader = class(TThread)
  private
    { Set by Stop: the thread ends. }
    FStop: TEvent;
    { What was read. }
    FCards: TArray<TGpuPower>;
    { Each card's readings, mW. }
    FValues: array[0..CARDS_MAX - 1] of TArray<Cardinal>;
    { An NVIDIA card's NVML handle (nil = not one of NVML's). }
    FDevices: array[0..CARDS_MAX - 1] of Pointer;
    { An AMD card's power file ('' = not one). }
    FFiles: array[0..CARDS_MAX - 1] of string;
    { NVML (0 = not loaded). }
    FLib: HMODULE;
    { NVML was started (nvmlInit_v2) and is to be shut down. }
    FNvmlUp: Boolean;
    { nvmlShutdown. }
    FShutdown: TNvmlPlain;
    { nvmlDeviceGetPowerUsage. }
    FGetPower: TNvmlMilliwatts;
    { A card more, its vendor and name set.
      @returns(its index, -1 when CARDS_MAX are there) }
    function AddCard(const AVendor, AName: string): Integer;
    { NVML loaded and its cards added (nothing when it is not there). }
    procedure FindNvidia;
    { NVML shut down and unloaded. }
    procedure LeaveNvidia;
    {$IFDEF GPUPOWER_SYSFS}
    { The AMD cards the kernel's driver reports power for, added. }
    procedure FindAmd;
    {$ENDIF}
    { A reading of AMw for card AIndex. }
    procedure Keep(AIndex: Integer; AMw: Cardinal);
    { Every card read once. }
    procedure ReadAll;
    { Each card's median from its readings. }
    procedure Medians;
  protected
    { Finds the cards and reads them until Stop. }
    procedure Execute; override;
  public
    { A reader, started at once. }
    constructor Create;
    { Frees the event. }
    destructor Destroy; override;
    { Ends the reading and waits for the thread. }
    procedure Stop;
    { What was read (after Stop). }
    property Cards: TArray<TGpuPower> read FCards;
  end;

var
  { The reading under way (nil = none). }
  GReader: TGpuPowerReader = nil;

{$IFDEF GPUPOWER_SYSFS}
{ The first line of a file of the kernel's, trimmed ('' when it cannot
  be read). Their size is not what can be read: read until nothing
  comes. }
function ReadSysFile(const AFileName: string): string;
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
      SetLength(B, 256);
      repeat
        N := S.Read(B[Total], Length(B) - Total);
        if N > 0 then
          Inc(Total, N);
      until (N <= 0) or (Total >= Length(B));
      Result := TEncoding.ASCII.GetString(B, 0, Total);
    finally
      S.Free;
    end;
    N := Pos(#10, Result);
    if N > 0 then
      Result := Copy(Result, 1, N - 1);
    Result := Trim(Result);
  except
    Result := '';
  end;
end;
{$ENDIF}

constructor TGpuPowerReader.Create;
begin
  FStop := TEvent.Create(nil, True, False, '');
  inherited Create(False);
end;

destructor TGpuPowerReader.Destroy;
begin
  inherited;
  FStop.Free;
end;

procedure TGpuPowerReader.Stop;
begin
  FStop.SetEvent;
  WaitFor;
end;

function TGpuPowerReader.AddCard(const AVendor, AName: string): Integer;
begin
  Result := Length(FCards);
  if Result >= CARDS_MAX then
    Exit(-1);
  SetLength(FCards, Result + 1);
  FCards[Result] := Default(TGpuPower);
  FCards[Result].Vendor := AVendor;
  FCards[Result].Name := AName;
  FValues[Result] := nil;
  FDevices[Result] := nil;
  FFiles[Result] := '';
end;

procedure TGpuPowerReader.FindNvidia;
var
  Init: TNvmlPlain;
  GetCount: TNvmlCount;
  GetHandle: TNvmlHandle;
  GetName: TNvmlName;
  GetLimit: TNvmlMilliwatts;
  Name: array[0..95] of AnsiChar;
  Device: Pointer;
  Count, Mw: Cardinal;
  I, At: Integer;
begin
  {$IF Defined(MSWINDOWS)}
  // no "the library was not found" box of the system's
  FLib := SafeLoadLibrary(NVML_LIBRARY, SEM_FAILCRITICALERRORS or SEM_NOOPENFILEERRORBOX);
  {$ELSE}
  FLib := LoadLibrary(PChar(NVML_LIBRARY));
  {$ENDIF}
  if FLib = 0 then
    Exit;
  @Init := GetProcAddress(FLib, 'nvmlInit_v2');
  @FShutdown := GetProcAddress(FLib, 'nvmlShutdown');
  @GetCount := GetProcAddress(FLib, 'nvmlDeviceGetCount_v2');
  @GetHandle := GetProcAddress(FLib, 'nvmlDeviceGetHandleByIndex_v2');
  @GetName := GetProcAddress(FLib, 'nvmlDeviceGetName');
  @FGetPower := GetProcAddress(FLib, 'nvmlDeviceGetPowerUsage');
  @GetLimit := GetProcAddress(FLib, 'nvmlDeviceGetEnforcedPowerLimit');
  if not (Assigned(Init) and Assigned(FShutdown) and Assigned(GetCount) and Assigned(GetHandle) and
    Assigned(GetName) and Assigned(FGetPower)) then
    Exit;
  if Init() <> NVML_SUCCESS then
    Exit;
  FNvmlUp := True;
  Count := 0;
  if GetCount(Count) <> NVML_SUCCESS then
    Exit;
  for I := 0 to Integer(Count) - 1 do
  begin
    Device := nil;
    if (GetHandle(Cardinal(I), Device) <> NVML_SUCCESS) or (Device = nil) then
      Continue;
    FillChar(Name, SizeOf(Name), 0);
    if GetName(Device, @Name[0], SizeOf(Name) - 1) <> NVML_SUCCESS then
      Name[0] := #0;
    At := AddCard('nvidia', Trim(string(AnsiString(PAnsiChar(@Name[0])))));
    if At < 0 then
      Break;
    FDevices[At] := Device;
    Mw := 0;
    if Assigned(GetLimit) and (GetLimit(Device, Mw) = NVML_SUCCESS) then
      FCards[At].LimitW := Integer((Mw + 500) div 1000);
  end;
end;

procedure TGpuPowerReader.LeaveNvidia;
begin
  if FNvmlUp then
    FShutdown();
  FNvmlUp := False;
  if FLib <> 0 then
    FreeLibrary(FLib);
  FLib := 0;
end;

{$IFDEF GPUPOWER_SYSFS}
procedure TGpuPowerReader.FindAmd;
var
  N, At: Integer;
  Device, Mon, PowerFile: string;
  Microwatts: Int64;
begin
  for N := 0 to 15 do
  begin
    Device := Format('/sys/class/drm/card%d/device', [N]);
    if not SameText(ReadSysFile(Device + '/vendor'), '0x1002') then
      Continue;
    if not TDirectory.Exists(Device + '/hwmon') then
      Continue;
    PowerFile := '';
    for Mon in TDirectory.GetDirectories(Device + '/hwmon') do
    begin
      // a card of its own reports an average, a processor's graphics
      // the chip's power now
      if FileExists(Mon + '/power1_average') then
        PowerFile := Mon + '/power1_average'
      else if FileExists(Mon + '/power1_input') then
        PowerFile := Mon + '/power1_input';
      if PowerFile = '' then
        Continue;
      At := AddCard('amd', Trim('AMD graphics ' + ReadSysFile(Device + '/device')));
      if At < 0 then
        Exit;
      FFiles[At] := PowerFile;
      Microwatts := StrToInt64Def(ReadSysFile(Mon + '/power1_cap'), 0);
      if Microwatts > 0 then
        FCards[At].LimitW := Integer((Microwatts + 500000) div 1000000);
      Break;
    end;
  end;
end;
{$ENDIF}

procedure TGpuPowerReader.Keep(AIndex: Integer; AMw: Cardinal);
begin
  if AMw = 0 then
    Exit;
  // room for a quarter of an hour more at a time
  if FCards[AIndex].Readings >= Length(FValues[AIndex]) then
    SetLength(FValues[AIndex], Length(FValues[AIndex]) + 900);
  FValues[AIndex][FCards[AIndex].Readings] := AMw;
  Inc(FCards[AIndex].Readings);
  if Integer((AMw + 500) div 1000) > FCards[AIndex].PeakW then
    FCards[AIndex].PeakW := Integer((AMw + 500) div 1000);
end;

procedure TGpuPowerReader.ReadAll;
var
  I: Integer;
  Mw: Cardinal;
  {$IFDEF GPUPOWER_SYSFS}
  Microwatts: Int64;
  {$ENDIF}
begin
  for I := 0 to High(FCards) do
    if FDevices[I] <> nil then
    begin
      Mw := 0;
      if FGetPower(FDevices[I], Mw) = NVML_SUCCESS then
        Keep(I, Mw);
    end
    {$IFDEF GPUPOWER_SYSFS}
    else if FFiles[I] <> '' then
    begin
      Microwatts := StrToInt64Def(ReadSysFile(FFiles[I]), 0);
      // more than 2 kW is not a reading
      if (Microwatts > 0) and (Microwatts < 2000000000) then
        Keep(I, Cardinal(Microwatts div 1000));
    end
    {$ENDIF}
    ;
end;

procedure TGpuPowerReader.Medians;
var
  I, Half: Integer;
  Mid: Int64;
begin
  for I := 0 to High(FCards) do
    if FCards[I].Readings > 0 then
    begin
      // the middle reading (of an even number, the two middle ones'
      // mean)
      SetLength(FValues[I], FCards[I].Readings);
      TArray.Sort<Cardinal>(FValues[I]);
      Half := FCards[I].Readings div 2;
      if Odd(FCards[I].Readings) then
        Mid := FValues[I][Half]
      else
        Mid := (Int64(FValues[I][Half - 1]) + FValues[I][Half]) div 2;
      FCards[I].MedianW := Integer((Mid + 500) div 1000);
    end;
end;

procedure TGpuPowerReader.Execute;
begin
  try
    try
      try
        FindNvidia;
      except
        // a driver's fault: its cards are not read
      end;
      {$IFDEF GPUPOWER_SYSFS}
      try
        FindAmd;
      except
        // files not as expected: those cards are not read
      end;
      {$ENDIF}
      if Length(FCards) = 0 then
        Exit;
      // the first reading at once, then one every READ_EVERY_MS
      repeat
        ReadAll;
      until FStop.WaitFor(READ_EVERY_MS) <> wrTimeout;
      Medians;
    finally
      LeaveNvidia;
    end;
  except
    // nothing of this is the benchmark's fault: nothing was read
    FCards := nil;
  end;
end;
{$ENDIF}

procedure GpuPowerStart;
begin
  GpuPowerStop;
  {$IFDEF GPUPOWER_READS}
  GReader := TGpuPowerReader.Create;
  {$ENDIF}
end;

function GpuPowerStop: TArray<TGpuPower>;
begin
  Result := nil;
  {$IFDEF GPUPOWER_READS}
  if GReader = nil then
    Exit;
  try
    GReader.Stop;
    Result := GReader.Cards;
  finally
    FreeAndNil(GReader);
  end;
  {$ENDIF}
end;

{ A card's name for comparing: lower case, without 'NVIDIA' before it. }
function PlainName(const AName: string): string;
begin
  Result := LowerCase(Trim(AName));
  if Copy(Result, 1, 7) = 'nvidia ' then
    Result := Trim(Copy(Result, 8, MaxInt));
end;

function GpuPowerFind(const ACards: TArray<TGpuPower>; const ADescription: string): Integer;
var
  I, Amd: Integer;
  Want, Have: string;
begin
  Result := -1;
  Want := PlainName(ADescription);
  if Want = '' then
    Exit;
  for I := 0 to High(ACards) do
  begin
    Have := PlainName(ACards[I].Name);
    if (ACards[I].Vendor = 'nvidia') and (ACards[I].Readings > 0) and (Have <> '') and ((Have = Want) or
      (Pos(Have, Want) > 0) or (Pos(Want, Have) > 0)) then
      Exit(I);
  end;
  // an AMD description, and one AMD card: that one
  if (Pos('amd', Want) = 0) and (Pos('radeon', Want) = 0) and (Pos('radv', Want) = 0) then
    Exit;
  Amd := 0;
  for I := 0 to High(ACards) do
    if ACards[I].Vendor = 'amd' then
    begin
      Inc(Amd);
      Result := I;
    end;
  if (Amd <> 1) or (ACards[Result].Readings = 0) then
    Result := -1;
end;

initialization

finalization
  GpuPowerStop;

end.
