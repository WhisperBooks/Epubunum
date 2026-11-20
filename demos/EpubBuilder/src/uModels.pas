{ @abstract(EpubBuilder's Whisper models: the ones it offers by name, the
  folder they are kept in, and downloading one the first time it is
  chosen.)

  Owner, 2026-11-18: "rather than deploy we let the app download models and
  store them in some known location. For Steam this would be in the steam
  app directory while on desktop you can elect a folder for model storage.
  This then means we can refer to the models by their short names allowing
  selection from a drop-down." (Deploying large-v3-turbo - 1.5 GB - would
  also put a Linux deploy over PAServer's 2 GiB, Later tests 4.)

  Names are whisper.cpp's (base.en, large-v3-turbo, ...): the file is
  ggml-<name>.bin, downloaded from whisper.cpp's own model repository on
  Hugging Face (as its models/download-ggml-model.sh does) into the
  models folder, as <file>.part first and renamed when complete and
  checked: its size against what Hugging Face gives for the file, and its
  SHA-256 when Hugging Face gives one (the X-Linked-Size / X-Linked-ETag of
  the redirect to the file; without them the size against the download's
  own length).

  The models folder (ModelsDefaultFolder):
  - Steam builds: 'models' in the program's folder in Steam's library (on
    macOS beside the .app - never inside it, its signature covers the
    bundle); the folder goes when the program is uninstalled;
  - otherwise the folder the user chose (Model > Folder...; kept in the
    settings), by default 'models' beside the settings;
  - a folder that cannot be written: 'models' beside the settings.

  Core ML (macOS, whisper-dev zip 22: whisper built with Core ML and its
  fallback to Metal): a model's encoder runs through Core ML when its
  ggml-<name>-encoder.mlmodelc folder is beside the .bin (ModelEncoderPath,
  as whisper.cpp names it). whisper.cpp's model repository has them as
  ggml-<name>-encoder.mlmodelc.zip; a download on a Core ML build fetches
  it with the model (or alone, for a model already there), unpacks it
  beside the model and deletes the zip. }
unit uModels;

interface

uses
  System.SysUtils, System.Classes;

type
  { A model EpubBuilder offers by name. }
  TWhisperModelInfo = record
    { whisper.cpp's name (the file is ggml-<Name>.bin). }
    Name: string;
    { About how large the file is, MB. }
    SizeMB: Integer;
    { What it is for, in a few words. }
    Note: string;
    { About how large its Core ML encoder's zip is, MB (0 = not known). }
    EncoderMB: Integer;
  end;

const
  { The models offered by name, smallest first (sizes as whisper.cpp's
    README gives them; large-v3-turbo as measured, 2026-11-18; the Core ML
    encoders' as Hugging Face lists them, tiny's not known). }
  MODEL_CATALOGUE: array[0..9] of TWhisperModelInfo = (
    (Name: 'tiny.en'; SizeMB: 75; Note: 'English only, fastest, least accurate'; EncoderMB: 0),
    (Name: 'tiny'; SizeMB: 75; Note: 'every language, fastest'; EncoderMB: 0),
    (Name: 'base.en'; SizeMB: 142; Note: 'English only, fast'; EncoderMB: 38),
    (Name: 'base'; SizeMB: 142; Note: 'every language, fast'; EncoderMB: 38),
    (Name: 'small.en'; SizeMB: 466; Note: 'English only'; EncoderMB: 163),
    (Name: 'small'; SizeMB: 466; Note: 'every language'; EncoderMB: 163),
    (Name: 'medium.en'; SizeMB: 1500; Note: 'English only, slow'; EncoderMB: 568),
    (Name: 'medium'; SizeMB: 1500; Note: 'every language, slow'; EncoderMB: 568),
    (Name: 'large-v3-turbo'; SizeMB: 1549; Note: 'every language, accurate and much faster than large-v3';
      EncoderMB: 1170),
    (Name: 'large-v3'; SizeMB: 2950; Note: 'every language, most accurate, slowest'; EncoderMB: 1180));
  { Where the files are downloaded from (whisper.cpp's model repository). }
  MODEL_DOWNLOAD_BASE = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/';
  { The models folder's name. }
  MODELS_FOLDER_NAME = 'models';

type
  { Downloads one model into the models folder on its own thread.
    Progress and messages reach the caller through TThread.Queue. }
  TModelDownload = class(TThread)
  private
    { The model's name. }
    FName: string;
    { The file to make. }
    FTarget: string;
    { Download the model (False: it is there - only its encoder). }
    FWithModel: Boolean;
    { Download and unpack the model's Core ML encoder too. }
    FWithEncoder: Boolean;
    { Bytes received so far. }
    FReceived: Int64;
    { Bytes expected (-1 = not known). }
    FTotal: Int64;
    { When progress was last sent. }
    FLastSent: TDateTime;
    { Why it failed ('' = it did not). }
    FError: string;
    { Backing field of @link(Succeeded). }
    FSucceeded: Boolean;
    { Receives the bytes received and expected (on the main thread). }
    FOnProgress: TProc<Int64, Int64>;
    { Receives the messages (on the main thread). }
    FOnLog: TProc<string>;
    { Sends AText to OnLog. }
    procedure Log(const AText: string);
    { Sends the progress to OnProgress. }
    procedure Progress;
    { THTTPClient's OnReceiveData: progress, at most every half second;
      Cancel stops the transfer here. }
    procedure ReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64; var AAbort: Boolean);
    { Downloads AUrl to AFile: through AFile + '.part', its size and its
      SHA-256 checked when Hugging Face gives them, renamed when right.
      Raises on a failure; returns False when cancelled (nothing left).
      @returns(True when AFile is complete) }
    function Fetch(const AUrl, AFile, AWhat: string): Boolean;
  protected
    { Downloads, checks and renames. }
    procedure Execute; override;
  public
    { A download into AFolder (started with Start): model AName when
      AWithModel, its Core ML encoder when AWithEncoder (unpacked beside
      it). }
    constructor Create(const AName, AFolder: string; AWithModel, AWithEncoder: Boolean);
    { Stops it: the part downloaded is deleted. }
    procedure Cancel;
    { The model's name. }
    property ModelName: string read FName;
    { The model's file once downloaded. }
    property Target: string read FTarget;
    { Why it failed ('' when it did not or was cancelled). }
    property Error: string read FError;
    { True when everything asked for is there, complete and checked. }
    property Succeeded: Boolean read FSucceeded;
    { The model was downloaded (not only its encoder). }
    property WithModel: Boolean read FWithModel;
    { The encoder was asked for. }
    property WithEncoder: Boolean read FWithEncoder;
    { Receives the bytes received and the bytes expected (-1 = not known). }
    property OnProgress: TProc<Int64, Int64> read FOnProgress write FOnProgress;
    { Receives the messages. }
    property OnLog: TProc<string> read FOnLog write FOnLog;
  end;

{ The file of model AName: ggml-<AName>.bin.
  @returns(the file name, without a folder) }
function ModelFileName(const AName: string): string;

{ The model's name in a file name: ggml-base.en.bin -> base.en.
  @returns(the name; AFile's name without '.bin' when it does not start
    with 'ggml-') }
function ModelShortName(const AFile: string): string;

{ Where model AName is downloaded from.
  @returns(the URL) }
function ModelUrl(const AName: string): string;

{ The Core ML encoder of model file AModelFile as whisper.cpp looks for it:
  '.bin' and a quantisation suffix ('-q5_0') dropped, '-encoder.mlmodelc'
  added (a folder).
  @returns(the folder's path) }
function ModelEncoderPath(const AModelFile: string): string;

{ Where model AName's Core ML encoder is downloaded from (a zip of the
  .mlmodelc folder).
  @returns(the URL) }
function ModelEncoderUrl(const AName: string): string;

{ AName's place in MODEL_CATALOGUE.
  @returns(-1 when it is not offered by name) }
function ModelCatalogueIndex(const AName: string): Integer;

{ About AMB megabytes for people: '142 MB', '1.5 GB'; 'a few MB' for 0 (not
  known).
  @returns(the text) }
function ModelSizeText(AMB: Integer): string;

{ The models folder when the user has not chosen one: in a Steam build the
  program's folder in Steam's library + 'models' (macOS: beside the .app),
  else ASettingsFolder + 'models'.
  @returns(the folder, without a trailing delimiter) }
function ModelsDefaultFolder(ASteam: Boolean; const ASettingsFolder: string): string;

{ True when files can be made in AFolder (made when missing; a test file
  is written and deleted).
  @returns(the answer) }
function FolderWritable(const AFolder: string): Boolean;

implementation

uses
  {$IFDEF POSIX}
  // System.SysUtils.DeleteFile / RenameFile's inline bodies expand only
  // with them (H2443)
  Posix.Unistd, Posix.Stdio,
  {$ENDIF}
  System.DateUtils, System.IOUtils, System.Hash, System.Zip, System.Net.URLClient, System.Net.HttpClient;

const
  { Progress is sent at most this often, ms. }
  PROGRESS_EVERY_MS = 500;

function ModelFileName(const AName: string): string;
begin
  Result := 'ggml-' + AName + '.bin';
end;

function ModelShortName(const AFile: string): string;
begin
  Result := ExtractFileName(AFile);
  if SameText(ExtractFileExt(Result), '.bin') then
    Result := ChangeFileExt(Result, '');
  if SameText(Copy(Result, 1, 5), 'ggml-') then
    Delete(Result, 1, 5);
end;

function ModelUrl(const AName: string): string;
begin
  Result := MODEL_DOWNLOAD_BASE + ModelFileName(AName);
end;

function ModelEncoderPath(const AModelFile: string): string;
var
  P: Integer;
  Tail: string;
begin
  Result := AModelFile;
  if SameText(ExtractFileExt(Result), '.bin') then
    Result := ChangeFileExt(Result, '');
  // '-qX_Y' (5 characters with the dash), as whisper_get_coreml_path_encoder
  P := LastDelimiter('-', Result);
  if P > Length(ExtractFilePath(Result)) then
  begin
    Tail := Copy(Result, P, MaxInt);
    if (Length(Tail) = 5) and (Tail[2] = 'q') and (Tail[4] = '_') then
      Result := Copy(Result, 1, P - 1);
  end;
  Result := Result + '-encoder.mlmodelc';
end;

function ModelEncoderUrl(const AName: string): string;
begin
  Result := MODEL_DOWNLOAD_BASE + 'ggml-' + AName + '-encoder.mlmodelc.zip';
end;

function ModelCatalogueIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := Low(MODEL_CATALOGUE) to High(MODEL_CATALOGUE) do
    if SameText(MODEL_CATALOGUE[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function ModelSizeText(AMB: Integer): string;
begin
  if AMB <= 0 then
    Result := 'a few MB'   // not known (tiny's Core ML encoder)
  else if AMB >= 1000 then
    Result := FloatToStrF(AMB / 1000, ffFixed, 15, 1) + ' GB'
  else
    Result := IntToStr(AMB) + ' MB';
end;

function ModelsDefaultFolder(ASteam: Boolean; const ASettingsFolder: string): string;
var
  Dir: string;
begin
  if ASteam then
  begin
    Dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    {$IFDEF MACOS}
    // <Steam library>/EpubBuilder/EpubBuilder.app/Contents/MacOS: three up
    // is the folder holding the .app
    Dir := ExtractFileDir(ExtractFileDir(ExtractFileDir(Dir)));
    {$ENDIF}
    Result := TPath.Combine(Dir, MODELS_FOLDER_NAME);
  end
  else
    Result := TPath.Combine(ExcludeTrailingPathDelimiter(ASettingsFolder), MODELS_FOLDER_NAME);
end;

function FolderWritable(const AFolder: string): Boolean;
var
  Test: string;
  F: TFileStream;
begin
  Result := False;
  try
    if not ForceDirectories(AFolder) then
      Exit;
    Test := TPath.Combine(AFolder, '.epubbuilder-write-test');
    F := TFileStream.Create(Test, fmCreate);
    F.Free;
    DeleteFile(Test);
    Result := True;
  except
    Result := False;
  end;
end;

{ TModelDownload }

constructor TModelDownload.Create(const AName, AFolder: string; AWithModel, AWithEncoder: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FName := AName;
  FTarget := TPath.Combine(AFolder, ModelFileName(AName));
  FWithModel := AWithModel;
  FWithEncoder := AWithEncoder;
  FTotal := -1;
end;

procedure TModelDownload.Cancel;
begin
  Terminate;
end;

procedure TModelDownload.Log(const AText: string);
var
  P: TProc<string>;
begin
  P := FOnLog;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(AText);
      end);
end;

procedure TModelDownload.Progress;
var
  P: TProc<Int64, Int64>;
  Received, Total: Int64;
begin
  P := FOnProgress;
  Received := FReceived;
  Total := FTotal;
  if Assigned(P) then
    TThread.Queue(nil,
      procedure
      begin
        P(Received, Total);
      end);
end;

procedure TModelDownload.ReceiveData(const Sender: TObject; AContentLength: Int64; AReadCount: Int64;
  var AAbort: Boolean);
begin
  AAbort := Terminated;
  FReceived := AReadCount;
  if (FTotal < 0) and (AContentLength > 0) then
    FTotal := AContentLength;
  if MilliSecondsBetween(Now, FLastSent) >= PROGRESS_EVERY_MS then
  begin
    FLastSent := Now;
    Progress;
  end;
end;

function TModelDownload.Fetch(const AUrl, AFile, AWhat: string): Boolean;
var
  Client: THTTPClient;
  Resp: IHTTPResponse;
  F: TFileStream;
  Part, Sha, Got: string;
  Size: Int64;
  I: Integer;
begin
  Result := False;
  Part := AFile + '.part';
  FReceived := 0;
  FTotal := -1;
  try
    ForceDirectories(ExtractFilePath(AFile));
    Client := THTTPClient.Create;
    try
      Client.UserAgent := 'EpubBuilder';
      // the size and SHA-256 Hugging Face gives for the file: on its
      // redirect to the file, so asked without following it
      Sha := '';
      try
        Client.HandleRedirects := False;
        Resp := Client.Head(AUrl);
        FTotal := StrToInt64Def(Trim(Resp.HeaderValue['X-Linked-Size']), -1);
        Sha := LowerCase(StringReplace(Trim(Resp.HeaderValue['X-Linked-ETag']), '"', '', [rfReplaceAll]));
        if Length(Sha) <> 64 then
          Sha := '';
        for I := 1 to Length(Sha) do
          if not CharInSet(Sha[I], ['0'..'9', 'a'..'f']) then
          begin
            Sha := '';
            Break;
          end;
      except
        on E: Exception do
          Log('  (the file''s size and checksum were not given: ' + E.Message + ')');
      end;
      if FTotal > 0 then
        Log(Format('Downloading %s (%s) from %s', [AWhat, ModelSizeText(Integer(FTotal div 1000000)), AUrl]))
      else
        Log(Format('Downloading %s from %s', [AWhat, AUrl]));
      Client.HandleRedirects := True;
      Client.OnReceiveData := ReceiveData;
      FLastSent := Now;
      F := TFileStream.Create(Part, fmCreate);
      try
        Resp := Client.Get(AUrl, F);
      finally
        F.Free;
      end;
    finally
      Client.Free;
    end;
    if Terminated then
    begin
      DeleteFile(Part);
      Exit;
    end;
    if Resp.StatusCode <> 200 then
      raise Exception.CreateFmt('the server answered %d %s', [Resp.StatusCode, Resp.StatusText]);
    Size := TFile.GetSize(Part);
    FReceived := Size;
    Progress;
    if (FTotal > 0) and (Size <> FTotal) then
      raise Exception.CreateFmt('%d bytes received, %d expected', [Size, FTotal]);
    if Sha <> '' then
    begin
      Log('Checking the download (SHA-256) ...');
      Got := LowerCase(THashSHA2.GetHashStringFromFile(Part));
      if Got <> Sha then
        raise Exception.Create('the file''s checksum (SHA-256) is not the one Hugging Face gives');
      Log('  checksum right');
    end
    else
      Log('  (no checksum given: the size was checked only)');
    if FileExists(AFile) and not DeleteFile(AFile) then
      raise Exception.CreateFmt('%s cannot be replaced', [AFile]);
    if not RenameFile(Part, AFile) then
      raise Exception.CreateFmt('%s cannot be renamed to %s', [Part, AFile]);
    Result := True;
  except
    if FileExists(Part) then
      DeleteFile(Part);
    raise;
  end;
end;

procedure TModelDownload.Execute;
var
  Zip, Encoder: string;
begin
  try
    if FWithModel then
    begin
      if not Fetch(ModelUrl(FName), FTarget, ModelFileName(FName)) then
      begin
        Log('Download cancelled: ' + ModelFileName(FName));
        Exit;
      end;
      Log(Format('Downloaded: %s', [FTarget]));
    end;
    if FWithEncoder then
    begin
      Encoder := ModelEncoderPath(FTarget);
      Zip := Encoder + '.zip';
      if not Fetch(ModelEncoderUrl(FName), Zip, ExtractFileName(Zip) + ' (Core ML encoder)') then
      begin
        Log('Download cancelled: ' + ExtractFileName(Zip));
        Exit;
      end;
      Log('Unpacking the Core ML encoder ...');
      // the zip holds the .mlmodelc folder itself: unpacked beside the model
      if TDirectory.Exists(Encoder) then
        TDirectory.Delete(Encoder, True);
      try
        TZipFile.ExtractZipFile(Zip, ExtractFilePath(FTarget));
      finally
        DeleteFile(Zip);
      end;
      if not TDirectory.Exists(Encoder) then
        raise Exception.CreateFmt('the zip did not hold %s', [ExtractFileName(Encoder)]);
      Log(Format('Core ML encoder: %s (its first use is slow - macOS compiles it for this Mac)', [Encoder]));
    end;
    FSucceeded := True;
  except
    on E: Exception do
      if Terminated then
        Log('Download cancelled: ' + FName)
      else
      begin
        FError := E.Message;
        Log(Format('The download of %s failed: %s', [FName, E.Message]));
      end;
  end;
end;

end.
