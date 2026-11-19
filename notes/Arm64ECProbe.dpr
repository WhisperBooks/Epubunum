program Arm64ECProbe;

{ Windows on Arm probe (notes/Windows-on-Arm.md, test 1). Build it for
  Win64 and for Windows Arm64EC (Delphi 13.1+, 64-bit IDE), run each in a
  console on the machine to test, and keep the output. It reports:

  1. the compiler's conditional symbols - TWhisper's Whisper.inc and
     TSteamAPI's Steamworks.inc choose the C calling convention by them;
  2. the process and the machine (IsWow64Process2);
  3. Vulkan: vulkan-1.dll loaded or not (and the file's machine type), the
     devices it lists - the GPU ggml-vulkan would use;
  4. CUDA: nvcuda.dll loaded or not (and its machine type), the driver
     version and the devices - for ggml-cuda;
  5. each DLL named on the command line, or found next to the program
     (whisper.dll, ggml-base.dll, avutil-60.dll, steam_api64.dll): loads
     or not, and its machine type.

  An Arm64EC process loads x64 and Arm64EC DLLs, not pure ARM64 ones
  (error 193). Nothing here needs a GPU: a missing one is reported. }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes;

const
  { PE machine types. }
  IMAGE_FILE_MACHINE_I386 = $014C;
  IMAGE_FILE_MACHINE_AMD64 = $8664;
  IMAGE_FILE_MACHINE_ARM64 = $AA64;
  IMAGE_FILE_MACHINE_ARM64EC = $A641;
  IMAGE_FILE_MACHINE_ARM64X = $A64E;

type
  { Vulkan handles. }
  VkInstance = Pointer;
  VkPhysicalDevice = Pointer;
  PVkPhysicalDevice = ^VkPhysicalDevice;

  { VkInstanceCreateInfo (64-bit layout: Delphi's default alignment pads
    as C does). }
  TVkInstanceCreateInfo = record
    sType: Cardinal;
    pNext: Pointer;
    flags: Cardinal;
    pApplicationInfo: Pointer;
    enabledLayerCount: Cardinal;
    ppEnabledLayerNames: Pointer;
    enabledExtensionCount: Cardinal;
    ppEnabledExtensionNames: Pointer;
  end;

  TvkCreateInstance = function(const ACreateInfo: TVkInstanceCreateInfo; AAllocator: Pointer;
    out AInstance: VkInstance): Integer; stdcall;
  TvkDestroyInstance = procedure(AInstance: VkInstance; AAllocator: Pointer); stdcall;
  TvkEnumeratePhysicalDevices = function(AInstance: VkInstance; var ACount: Cardinal;
    ADevices: PVkPhysicalDevice): Integer; stdcall;
  { The properties are read from a large buffer: apiVersion (0),
    driverVersion (4), vendorID (8), deviceID (12), deviceType (16),
    deviceName (20, 256 chars) - the rest is not needed. }
  TvkGetPhysicalDeviceProperties = procedure(ADevice: VkPhysicalDevice; AProps: Pointer); stdcall;

  TcuInit = function(AFlags: Cardinal): Integer; stdcall;
  TcuDriverGetVersion = function(out AVersion: Integer): Integer; stdcall;
  TcuDeviceGetCount = function(out ACount: Integer): Integer; stdcall;
  TcuDeviceGet = function(out ADevice: Integer; AOrdinal: Integer): Integer; stdcall;
  TcuDeviceGetName = function(AName: PAnsiChar; ALen: Integer; ADevice: Integer): Integer; stdcall;
  TcuDeviceTotalMem = function(out ABytes: UInt64; ADevice: Integer): Integer; stdcall;

  TIsWow64Process2 = function(AProcess: THandle; out AProcessMachine, ANativeMachine: Word): BOOL; stdcall;

function MachineName(AMachine: Word): string;
begin
  case AMachine of
    0: Result := 'none';
    IMAGE_FILE_MACHINE_I386: Result := 'x86';
    IMAGE_FILE_MACHINE_AMD64: Result := 'x64 (or Arm64EC)';
    IMAGE_FILE_MACHINE_ARM64: Result := 'ARM64';
    IMAGE_FILE_MACHINE_ARM64EC: Result := 'Arm64EC';
    IMAGE_FILE_MACHINE_ARM64X: Result := 'ARM64X';
  else
    Result := Format('$%.4x', [AMachine]);
  end;
end;

{ The machine type in a PE file's header ('' when it cannot be read). }
function FileMachine(const AFile: string): string;
var
  S: TFileStream;
  Lfanew: Integer;
  Sig: Cardinal;
  M: Word;
begin
  Result := '';
  try
    S := TFileStream.Create(AFile, fmOpenRead or fmShareDenyNone);
    try
      S.Position := $3C;
      S.ReadBuffer(Lfanew, 4);
      S.Position := Lfanew;
      S.ReadBuffer(Sig, 4);
      S.ReadBuffer(M, 2);
      if Sig = $00004550 then
        Result := MachineName(M);
    except
      Result := '';
    end;
    S.Free;
  except
    Result := '';
  end;
end;

function ModulePath(AModule: HMODULE): string;
var
  Buf: array[0..MAX_PATH] of Char;
begin
  SetString(Result, Buf, GetModuleFileName(AModule, Buf, Length(Buf)));
end;

{ Loads ANameOrPath and says how it went. @returns(the module, 0 if not) }
function TryLoad(const ANameOrPath: string): HMODULE;
var
  E: Cardinal;
  P: string;
begin
  Result := LoadLibrary(PChar(ANameOrPath));
  if Result = 0 then
  begin
    E := GetLastError;
    Write(Format('  %s: NOT loaded, error %d (%s)', [ANameOrPath, E, SysErrorMessage(E)]));
    if E = 193 then
      Write(' - wrong machine type for this process');
    if FileExists(ANameOrPath) then
      Write(' - the file is ', FileMachine(ANameOrPath));
    Writeln;
  end
  else
  begin
    P := ModulePath(Result);
    Writeln(Format('  %s: loaded from %s (%s)', [ANameOrPath, P, FileMachine(P)]));
  end;
end;

procedure Symbols;

  procedure Show(const AName: string; ADefined: Boolean);
  begin
    Writeln(Format('  %-14s %s', [AName, BoolToStr(ADefined, True)]));
  end;

begin
  Writeln('== 1. Compiler symbols');
  Writeln('  CompilerVersion ', CompilerVersion:0:1, ', pointer ', SizeOf(Pointer) * 8, ' bit');
  Show('MSWINDOWS', {$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF});
  Show('WIN32', {$IFDEF WIN32}True{$ELSE}False{$ENDIF});
  Show('WIN64', {$IFDEF WIN64}True{$ELSE}False{$ENDIF});
  Show('CPU64BITS', {$IFDEF CPU64BITS}True{$ELSE}False{$ENDIF});
  Show('CPUX64', {$IFDEF CPUX64}True{$ELSE}False{$ENDIF});
  Show('CPUX86', {$IFDEF CPUX86}True{$ELSE}False{$ENDIF});
  Show('CPUARM', {$IFDEF CPUARM}True{$ELSE}False{$ENDIF});
  Show('CPUARM64', {$IFDEF CPUARM64}True{$ELSE}False{$ENDIF});
  Show('ARM64EC', {$IFDEF ARM64EC}True{$ELSE}False{$ENDIF});
  Show('CPUARM64EC', {$IFDEF CPUARM64EC}True{$ELSE}False{$ENDIF});
  Show('WINARM64EC', {$IFDEF WINARM64EC}True{$ELSE}False{$ENDIF});
  Show('WINARM64', {$IFDEF WINARM64}True{$ELSE}False{$ENDIF});
  Show('LLVM', {$IFDEF LLVM}True{$ELSE}False{$ENDIF});
  Show('ASSEMBLER', {$IFDEF ASSEMBLER}True{$ELSE}False{$ENDIF});
  Show('PUREPASCAL', {$IFDEF PUREPASCAL}True{$ELSE}False{$ENDIF});
  Show('EXTERNALLINKER', {$IFDEF EXTERNALLINKER}True{$ELSE}False{$ENDIF});
  Show('POSIX', {$IFDEF POSIX}True{$ELSE}False{$ENDIF});
end;

procedure Machine;
var
  K: HMODULE;
  F: TIsWow64Process2;
  PM, NM: Word;
begin
  Writeln('== 2. Process and machine');
  Writeln('  ', TOSVersion.ToString);
  Writeln('  TOSVersion.Architecture ', Ord(TOSVersion.Architecture), ' (0 x86, 1 x64, 2 ARM32, 3 ARM64)');
  Writeln('  this program''s file: ', FileMachine(ParamStr(0)));
  K := GetModuleHandle(kernel32);
  @F := GetProcAddress(K, 'IsWow64Process2');
  if Assigned(F) and F(GetCurrentProcess, PM, NM) then
    Writeln('  IsWow64Process2: process ', MachineName(PM), ' (none = not WOW64), machine ', MachineName(NM))
  else
    Writeln('  IsWow64Process2 not available');
end;

procedure Vulkan;
var
  L: HMODULE;
  VkCreate: TvkCreateInstance;
  VkDestroy: TvkDestroyInstance;
  Enum: TvkEnumeratePhysicalDevices;
  Props: TvkGetPhysicalDeviceProperties;
  CI: TVkInstanceCreateInfo;
  Inst: VkInstance;
  N, I: Cardinal;
  Devs: array of VkPhysicalDevice;
  Buf: array[0..4095] of Byte;
  R: Integer;
  Api: Cardinal;
const
  TYPES: array[0..4] of string = ('other', 'integrated GPU', 'discrete GPU', 'virtual GPU', 'CPU');
begin
  Writeln('== 3. Vulkan');
  L := TryLoad('vulkan-1.dll');
  if L = 0 then
    Exit;
  @VkCreate := GetProcAddress(L, 'vkCreateInstance');
  @VkDestroy := GetProcAddress(L, 'vkDestroyInstance');
  @Enum := GetProcAddress(L, 'vkEnumeratePhysicalDevices');
  @Props := GetProcAddress(L, 'vkGetPhysicalDeviceProperties');
  if not (Assigned(VkCreate) and Assigned(VkDestroy) and Assigned(Enum) and Assigned(Props)) then
  begin
    Writeln('  the loader lacks vkCreateInstance & co.');
    Exit;
  end;
  FillChar(CI, SizeOf(CI), 0);
  CI.sType := 1;   // VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
  R := VkCreate(CI, nil, Inst);
  if R <> 0 then
  begin
    Writeln('  vkCreateInstance failed: ', R, ' (-9 = no driver)');
    Exit;
  end;
  try
    N := 0;
    R := Enum(Inst, N, nil);
    Writeln('  devices: ', N, ' (result ', R, ')');
    if N = 0 then
      Exit;
    SetLength(Devs, N);
    Enum(Inst, N, @Devs[0]);
    for I := 0 to N - 1 do
    begin
      FillChar(Buf, SizeOf(Buf), 0);
      Props(Devs[I], @Buf[0]);
      Api := PCardinal(@Buf[0])^;
      Writeln(Format('  Vulkan%d: %s - %s, vendor $%.4x, Vulkan %d.%d.%d', [I, PAnsiChar(@Buf[20]),
        TYPES[PCardinal(@Buf[16])^ mod 5], PCardinal(@Buf[8])^, (Api shr 22) and $7F, (Api shr 12) and $3FF,
        Api and $FFF]));
    end;
  finally
    VkDestroy(Inst, nil);
  end;
end;

procedure Cuda;
var
  L: HMODULE;
  Init: TcuInit;
  DrvVer: TcuDriverGetVersion;
  Count: TcuDeviceGetCount;
  Get: TcuDeviceGet;
  Name: TcuDeviceGetName;
  Mem: TcuDeviceTotalMem;
  R, V, N, I, D: Integer;
  B: array[0..255] of AnsiChar;
  Bytes: UInt64;
begin
  Writeln('== 4. CUDA');
  L := TryLoad('nvcuda.dll');
  if L = 0 then
    Exit;
  @Init := GetProcAddress(L, 'cuInit');
  @DrvVer := GetProcAddress(L, 'cuDriverGetVersion');
  @Count := GetProcAddress(L, 'cuDeviceGetCount');
  @Get := GetProcAddress(L, 'cuDeviceGet');
  @Name := GetProcAddress(L, 'cuDeviceGetName');
  @Mem := GetProcAddress(L, 'cuDeviceTotalMem_v2');
  if not (Assigned(Init) and Assigned(DrvVer) and Assigned(Count) and Assigned(Get) and Assigned(Name)) then
  begin
    Writeln('  nvcuda.dll lacks cuInit & co.');
    Exit;
  end;
  R := Init(0);
  if R <> 0 then
  begin
    Writeln('  cuInit failed: ', R, ' (100 = no device)');
    Exit;
  end;
  V := 0;
  DrvVer(V);
  N := 0;
  Count(N);
  Writeln(Format('  driver CUDA %d.%d, devices: %d', [V div 1000, (V mod 1000) div 10, N]));
  for I := 0 to N - 1 do
    if Get(D, I) = 0 then
    begin
      FillChar(B, SizeOf(B), 0);
      Name(@B[0], Length(B) - 1, D);
      Bytes := 0;
      if Assigned(Mem) then
        Mem(Bytes, D);
      Writeln(Format('  CUDA%d: %s, %.1f GB', [I, string(AnsiString(PAnsiChar(@B[0]))), Bytes / 1073741824]));
    end;
end;

procedure Libraries;
const
  BESIDE: array[0..4] of string = ('whisper.dll', 'ggml-base.dll', 'ggml.dll', 'avutil-60.dll', 'steam_api64.dll');
var
  I: Integer;
  Dir: string;
  Any: Boolean;
begin
  Writeln('== 5. Libraries');
  Any := False;
  // the folder's DLLs find each other there
  Dir := ExtractFilePath(ParamStr(0));
  for I := 1 to ParamCount do
  begin
    TryLoad(ParamStr(I));
    Any := True;
  end;
  for I := 0 to High(BESIDE) do
    if FileExists(Dir + BESIDE[I]) then
    begin
      TryLoad(Dir + BESIDE[I]);
      Any := True;
    end;
  if not Any then
    Writeln('  none next to the program and none named (copy redistributable_bin\Win64 next to it to test them)');
end;

begin
  try
    Symbols;
    Machine;
    Vulkan;
    Cuda;
    Libraries;
  except
    on E: Exception do
      Writeln('Stopped: ', E.ClassName, ': ', E.Message);
  end;
  Writeln('Done.');
end.
