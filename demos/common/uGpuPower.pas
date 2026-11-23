(* @abstract(The power an NVIDIA card draws while a benchmark runs: read
  about once a second through NVML, the library NVIDIA's driver installs.)

  Owner, 2026-11-23: a laptop's own power profile made the same
  benchmark half as fast again ("you know those are actually valid
  different tests"), and the program cannot ask a maker's profile what
  it is; "It would be nice if there was an easy, consistant way to read
  GPU power" - there is none across makers; "Most consumer PCs use
  nvidia if they have a GPU" - so NVIDIA's cards are read, and the
  others are not (asked: in the log only, or on the website too?
  "website too").

  GpuPowerStart begins the reading in a thread of its own; GpuPowerStop
  ends it and gives, for every card NVML knows: the average and the
  highest draw, and the limit the card is held to (which is what a
  maker's low profile usually lowers). GpuPowerFind picks the card a
  benchmark ran on by its description.

  Nothing is shipped and nothing is needed: with no NVIDIA driver (no
  nvml.dll / libnvidia-ml.so.1), on a Mac, or with a card that does not
  report its power, GpuPowerStop gives nothing and nothing else
  changes. *)
unit uGpuPower;

interface

type
  { What a card drew between GpuPowerStart and GpuPowerStop. }
  TGpuPower = record
    { The card as NVML names it ('NVIDIA GeForce RTX 5090 Laptop GPU'). }
    Name: string;
    { Readings taken (0 = the card does not report its power). }
    Readings: Integer;
    { Their average, W. }
    AverageW: Integer;
    { The highest, W. }
    PeakW: Integer;
    { The limit the card is held to, W (0 = not told). }
    LimitW: Integer;
  end;

{ Starts reading (a reading still under way is ended first). }
procedure GpuPowerStart;

{ Ends the reading.
  @returns(a record for each card of NVML's - none when nothing was
    started or NVML is not there) }
function GpuPowerStop: TArray<TGpuPower>;

{ The card among ACards that ADescription names (a device's description
  as the benchmark has it; 'NVIDIA' at the names' start is not needed to
  agree).
  @returns(its index, -1 when none is it or it gave no reading) }
function GpuPowerFind(const ACards: TArray<TGpuPower>; const ADescription: string): Integer;

implementation

uses
  {$IF Defined(MSWINDOWS)}
  Winapi.Windows,
  {$ENDIF}
  System.SysUtils, System.Classes, System.SyncObjs;

{$IF Defined(MSWINDOWS) or (Defined(LINUX) and not Defined(ANDROID))}
  {$DEFINE GPUPOWER_NVML}
{$ENDIF}

{$IFDEF GPUPOWER_NVML}
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
  protected
    { Loads NVML and reads every card until Stop. }
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

procedure TGpuPowerReader.Execute;
var
  Lib: HMODULE;
  Init, Shutdown: TNvmlPlain;
  GetCount: TNvmlCount;
  GetHandle: TNvmlHandle;
  GetName: TNvmlName;
  GetPower, GetLimit: TNvmlMilliwatts;
  Devices: array[0..CARDS_MAX - 1] of Pointer;
  Sums: array[0..CARDS_MAX - 1] of Int64;
  Name: array[0..95] of AnsiChar;
  Count, Mw: Cardinal;
  I, N: Integer;
begin
  try
    {$IF Defined(MSWINDOWS)}
    // no "the library was not found" box of the system's
    Lib := SafeLoadLibrary(NVML_LIBRARY, SEM_FAILCRITICALERRORS or SEM_NOOPENFILEERRORBOX);
    {$ELSE}
    Lib := LoadLibrary(PChar(NVML_LIBRARY));
    {$ENDIF}
    if Lib = 0 then
      Exit;
    try
      @Init := GetProcAddress(Lib, 'nvmlInit_v2');
      @Shutdown := GetProcAddress(Lib, 'nvmlShutdown');
      @GetCount := GetProcAddress(Lib, 'nvmlDeviceGetCount_v2');
      @GetHandle := GetProcAddress(Lib, 'nvmlDeviceGetHandleByIndex_v2');
      @GetName := GetProcAddress(Lib, 'nvmlDeviceGetName');
      @GetPower := GetProcAddress(Lib, 'nvmlDeviceGetPowerUsage');
      @GetLimit := GetProcAddress(Lib, 'nvmlDeviceGetEnforcedPowerLimit');
      if not (Assigned(Init) and Assigned(Shutdown) and Assigned(GetCount) and Assigned(GetHandle) and
        Assigned(GetName) and Assigned(GetPower)) then
        Exit;
      if Init() <> NVML_SUCCESS then
        Exit;
      try
        Count := 0;
        if (GetCount(Count) <> NVML_SUCCESS) or (Count = 0) then
          Exit;
        N := 0;
        for I := 0 to Integer(Count) - 1 do
        begin
          if N >= CARDS_MAX then
            Break;
          Devices[N] := nil;
          if (GetHandle(Cardinal(I), Devices[N]) <> NVML_SUCCESS) or (Devices[N] = nil) then
            Continue;
          SetLength(FCards, N + 1);
          FCards[N] := Default(TGpuPower);
          FillChar(Name, SizeOf(Name), 0);
          if GetName(Devices[N], @Name[0], SizeOf(Name) - 1) = NVML_SUCCESS then
            FCards[N].Name := Trim(string(AnsiString(PAnsiChar(@Name[0]))));
          Mw := 0;
          if Assigned(GetLimit) and (GetLimit(Devices[N], Mw) = NVML_SUCCESS) then
            FCards[N].LimitW := Integer((Mw + 500) div 1000);
          Sums[N] := 0;
          Inc(N);
        end;
        // the first reading at once, then one every READ_EVERY_MS
        repeat
          for I := 0 to N - 1 do
          begin
            Mw := 0;
            if (GetPower(Devices[I], Mw) = NVML_SUCCESS) and (Mw > 0) then
            begin
              Inc(FCards[I].Readings);
              Inc(Sums[I], Mw);
              if Integer((Mw + 500) div 1000) > FCards[I].PeakW then
                FCards[I].PeakW := Integer((Mw + 500) div 1000);
            end;
          end;
        until FStop.WaitFor(READ_EVERY_MS) <> wrTimeout;
        for I := 0 to N - 1 do
          if FCards[I].Readings > 0 then
            FCards[I].AverageW := Integer((Sums[I] div FCards[I].Readings + 500) div 1000);
      finally
        Shutdown();
      end;
    finally
      FreeLibrary(Lib);
    end;
  except
    // a driver's fault is not the benchmark's: nothing was read
    FCards := nil;
  end;
end;
{$ENDIF}

procedure GpuPowerStart;
begin
  GpuPowerStop;
  {$IFDEF GPUPOWER_NVML}
  GReader := TGpuPowerReader.Create;
  {$ENDIF}
end;

function GpuPowerStop: TArray<TGpuPower>;
begin
  Result := nil;
  {$IFDEF GPUPOWER_NVML}
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
  I: Integer;
  Want, Have: string;
begin
  Result := -1;
  Want := PlainName(ADescription);
  if Want = '' then
    Exit;
  for I := 0 to High(ACards) do
  begin
    Have := PlainName(ACards[I].Name);
    if (ACards[I].Readings > 0) and (Have <> '') and ((Have = Want) or (Pos(Have, Want) > 0) or
      (Pos(Want, Have) > 0)) then
      Exit(I);
  end;
end;

initialization

finalization
  GpuPowerStop;

end.
