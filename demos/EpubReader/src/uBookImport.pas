{ The books folder on Android: a folder the user chooses once in the
  system's folder picker (Documents/EpubUnum, a memory card's folder),
  read where it is - every EPUB in it and in its folders is in the
  library, nothing is copied (zip 346; owner 2026-11-26: "Is it necessary
  to copy books from e.g. Documents to own storage?" - "don't load single
  files - they should be in folder / subfolders"). Zip 341's copying of
  single files is gone.

  Android gives such a folder's books as content:// addresses, not
  paths. The library keeps a book's address as its name, and the book
  is opened by it: @link(BookOpenPath) has Android open the file (in the
  window's thread - Java), and the book reader reads that open file
  through Epub.Zip's EpubStreamOpener (a stream reading the descriptor by
  position, so two readers of one book in two threads do not disturb
  each other). Zip 346 gave the path /proc/self/fd/<n> instead: Android
  refuses to open that again ("Permission denied" - it checks the real
  path, which an app may not open; the owner's debugger, 15:05). The
  sound player opens an address through Android itself
  (uPlayerAndroid). @link(BookFileName) is a book's file name, for an
  address as for a path: the covers, the indexes and the library match
  books by it.

  The read permission of the chosen folder is kept by Android across
  starts (takePersistableUriPermission). Elsewhere (a desktop, iOS for
  now) BookFolderSupported is False and the addresses never occur. }
unit uBookImport;

interface

uses
  System.SysUtils, System.Classes;

type
  { The folder picker's answer: the folder's address ('' = left without
    a choice). Called in the window's thread. }
  TBookFolderChosen = reference to procedure(const ATree: string);

{ The system's folder picker can be used here (Android).
  @returns(the answer) }
function BookFolderSupported: Boolean;

{ The phone's name as BookManager lists it: its maker and model ('Google
  Pixel 9'); '' when not a phone.
  @returns(the name) }
function PhoneName: string;

{ This is a TV (Android TV, Google TV: the system has the leanback
  feature - a remote, no touch screen, a screen across the room; zip
  381). False elsewhere.
  @returns(the answer) }
function IsTelevision: Boolean;

{ The app's own folders on every storage volume Android has mounted
  (Context.getExternalFilesDirs: the built-in storage first, then a
  memory card or a USB drive set up as portable storage - the app may
  write there without a permission); a volume that is not mounted is
  left out. Empty elsewhere (zip 381: the TV's storage, logged).
  @returns(the folders) }
function StorageFolders: TArray<string>;

{ Keeps the screen on while AOn (Android: the window's
  FLAG_KEEP_SCREEN_ON - while BookManager sends books, a batch is not cut
  short by the screen going off; zip 357). Nothing elsewhere.
  @param(AOn  on or off) }
procedure KeepScreenOn(AOn: Boolean);

{ Holds Android's low-latency Wi-Fi lock while AOn (WIFI_MODE_FULL_LOW_LATENCY:
  the phone's Wi-Fi saves no power while the app is in front with the
  screen on, so BookManager's first connection, and the broadcasts it
  sends, are not dropped - zip 357; the owner's Pixel took 45 - 60 s to
  take a first connection without it). Needs WAKE_LOCK. Nothing
  elsewhere.
  @param(AOn  on or off)
  @returns(what was done, for the log) }
function WifiAwake(AOn: Boolean): string;

{ Shows the system's folder picker; the folder chosen is kept readable
  (across starts too) and given to AOnDone.
  @param(AOnDone  the answer) }
procedure BookFolderChoose(AOnDone: TBookFolderChosen);

{ The EPUB books in folder ATree (a picker's address) and in its folders,
  as addresses.
  @param(ATree  the folder)
  @param(ANote  what went wrong, '' = nothing - the folder gone, its
    permission withdrawn)
  @returns(the books' addresses) }
function BookFolderBooks(const ATree: string; out ANote: string): TArray<string>;

{ The folder ATree as the user knows it ('Documents/EpubUnum'; a memory
  card's: its name, then the path).
  @param(ATree  the folder)
  @returns(its name) }
function BookFolderName(const ATree: string): string;

{ Book AName is in folder ATree (or in one of its folders).
  @param(AName  a book's address)
  @param(ATree  a chosen folder)
  @returns(the answer) }
function BookInFolder(const AName, ATree: string): Boolean;

{ Android forgets the read permission of folder ATree (taken off the
  books folders).
  @param(ATree  the folder) }
procedure BookFolderForget(const ATree: string);

{ AName is a book's address in a chosen folder (content://), not a path.
  @param(AName  a book's name)
  @returns(the answer) }
function IsBookAddress(const AName: string): Boolean;

{ A book's file name ('Night Watch.epub'): of an address, its document's
  last part; of a path, ExtractFileName.
  @param(AName  an address or a path)
  @returns(the file name) }
function BookFileName(const AName: string): string;

{ Makes book AName ready to be read by its name: an address is opened by
  Android (in the window's thread - Java; counted: each call wants a
  BookRelease, or holds it for the run), a path is left as it is.
  @param(AName  an address or a path)
  @returns(AName - the name to give TEpubBook)
  @raises(Exception when the book cannot be opened) }
function BookOpenPath(const AName: string): string;

{ The book reader is done with AName (a cover, the library's details):
  the last of its BookOpenPath calls closes the file; a path: nothing.
  @param(AName  the address (or path) given to BookOpenPath) }
procedure BookRelease(const AName: string);

{ The book's name for the name a book was opened with (since zip 347 the
  same: kept for the reader's calls).
  @param(APath  the name)
  @returns(the name) }
function BookStableName(const APath: string): string;

{ Book AName is there: a path - FileExists; an address - Android still
  has the document.
  @param(AName  an address or a path)
  @returns(the answer) }
function BookExists(const AName: string): Boolean;

{ For Epub.Zip's EpubStreamOpener (uMain sets it on Android): a book of a
  books folder read from the file BookOpenPath had Android open; nil for a
  path (opened as a file) - and elsewhere always nil.
  @param(AFileName  the book's name)
  @returns(the stream, nil = open the file by its name)
  @raises(EStreamError when an address was not opened first) }
function OpenBookStream(const AFileName: string): TStream;

implementation

uses
  // (not Epub.Zip: uMain connects OpenBookStream to its EpubStreamOpener -
  // here the unit was "not found" on the owner's build, zip 349)
  System.Generics.Collections, System.SyncObjs
  {$IFDEF ANDROID},
  System.Messaging, Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.App, Androidapi.JNI.Net,
  Androidapi.JNI.Os, Androidapi.JNI.JavaTypes, Androidapi.JNIBridge, Androidapi.Helpers,
  // CallInUIThread (KeepScreenOn: the window is the Java UI thread's)
  FMX.Helpers.Android,
  // FileClose's inline body expands only with it (H2443)
  Posix.Unistd
  {$ENDIF};

const
  { An address's start. }
  CONTENT_SCHEME = 'content://';
  { Its document part. }
  DOCUMENT_PART = '/document/';

type
  { A file Android opened for a book: its descriptor and how many
    BookOpenPath calls hold it. }
  TOpenedBook = record
    { The descriptor. }
    Fd: Integer;
    { The calls holding it. }
    Count: Integer;
  end;

var
  { The files opened: address -> descriptor (guarded by OpenedLock: the
    book reader asks from the thread that opens a book). }
  Opened: TDictionary<string, TOpenedBook>;
  { Guards Opened. }
  OpenedLock: TCriticalSection;

{ AText with its %XX decoded (as UTF-8). }
function PercentDecode(const AText: string): string;
var
  Bytes: TBytes;
  I, N: Integer;
  H: string;
begin
  SetLength(Bytes, Length(AText));
  N := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    if (AText[I] = '%') and (I + 2 <= Length(AText)) then
    begin
      H := Copy(AText, I + 1, 2);
      Bytes[N] := Byte(StrToIntDef('$' + H, Ord('?')));
      Inc(I, 3);
    end
    else
    begin
      // an address is ASCII; anything else kept as a question mark
      if Ord(AText[I]) < 128 then
        Bytes[N] := Byte(Ord(AText[I]))
      else
        Bytes[N] := Ord('?');
      Inc(I);
    end;
    Inc(N);
  end;
  SetLength(Bytes, N);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

{ The document id of address AName ('primary:Documents/EpubUnum/x.epub'),
  '' when it has none. }
function DocumentId(const AName: string): string;
var
  P: Integer;
begin
  Result := '';
  P := Pos(DOCUMENT_PART, AName);
  if P > 0 then
    Result := PercentDecode(Copy(AName, P + Length(DOCUMENT_PART), MaxInt));
end;

{ The tree id of folder address ATree ('primary:Documents/EpubUnum'). }
function TreeId(const ATree: string): string;
var
  P, Q: Integer;
  Rest: string;
begin
  Result := '';
  P := Pos('/tree/', ATree);
  if P = 0 then
    Exit;
  Rest := Copy(ATree, P + Length('/tree/'), MaxInt);
  Q := Pos('/', Rest);
  if Q > 0 then
    Rest := Copy(Rest, 1, Q - 1);
  Result := PercentDecode(Rest);
end;

function IsBookAddress(const AName: string): Boolean;
begin
  Result := AName.StartsWith(CONTENT_SCHEME, True);
end;

function BookFileName(const AName: string): string;
var
  Id: string;
  P: Integer;
begin
  if not IsBookAddress(AName) then
    Exit(ExtractFileName(AName));
  Id := DocumentId(AName);
  P := Id.LastDelimiter('/:');
  if P >= 0 then
    Result := Id.Substring(P + 1)
  else
    Result := Id;
end;

function BookFolderName(const ATree: string): string;
var
  Id, Volume: string;
  P: Integer;
begin
  Id := TreeId(ATree);
  P := Pos(':', Id);
  if P = 0 then
    Exit(Id);
  Volume := Copy(Id, 1, P - 1);
  Result := Copy(Id, P + 1, MaxInt);
  // the phone's own storage is "primary"; a card goes by its id
  if not SameText(Volume, 'primary') then
    Result := Volume + ': ' + Result;
  if Result = '' then
    Result := Volume;
end;

function BookStableName(const APath: string): string;
begin
  Result := APath;
end;

{$IFDEF ANDROID}

const
  { The folder picker's request code (any number of this program's own). }
  PICK_FOLDER = 7346;
  { A folder among a tree's documents. }
  MIME_DIR = 'vnd.android.document/directory';
  { Folders deep at most (a loop of links is not followed for ever). }
  MAX_DEPTH = 12;

var
  { The picker's callback. }
  FolderChosen: TBookFolderChosen;
  { The subscription to the activity's results (0 = none yet). }
  ResultSubscription: Integer;

{ Java's Uri.encode of AText (what DocumentsContract does to an id). }
function UriEncode(const AText: string): string;
begin
  Result := JStringToString(TJnet_Uri.JavaClass.encode(StringToJString(AText)));
end;

{ The authority of address AName ('com.android.externalstorage.documents'). }
function Authority(const AName: string): string;
var
  Rest: string;
  P: Integer;
begin
  Rest := Copy(AName, Length(CONTENT_SCHEME) + 1, MaxInt);
  P := Pos('/', Rest);
  if P > 0 then
    Result := Copy(Rest, 1, P - 1)
  else
    Result := Rest;
end;

{ Document ADocId of folder ATree, as an address (what
  DocumentsContract.buildDocumentUriUsingTree makes). }
function DocumentAddress(const ATree, ADocId: string): string;
begin
  Result := CONTENT_SCHEME + Authority(ATree) + '/tree/' + UriEncode(TreeId(ATree)) + DOCUMENT_PART +
    UriEncode(ADocId);
end;

function BookFolderSupported: Boolean;
begin
  Result := True;
end;

type
  { android.net.wifi.WifiManager.WifiLock (the RTL has no import). }
  JWifiManager_WifiLockClass = interface(JObjectClass)
    ['{0863E88A-ACB0-4413-AC3E-3A40C14602FB}']
  end;

  { ... its object. }
  [JavaSignature('android/net/wifi/WifiManager$WifiLock')]
  JWifiManager_WifiLock = interface(JObject)
    ['{EFF608B2-122C-43F3-818A-898CB9695C8E}']
    { Takes the lock. }
    procedure acquire; cdecl;
    { Lets it go. }
    procedure release; cdecl;
    { Held now. }
    function isHeld: Boolean; cdecl;
    { Counted or not (not: one release ends it). }
    procedure setReferenceCounted(refCounted: Boolean); cdecl;
  end;

  { ... the import. }
  TJWifiManager_WifiLock = class(TJavaGenericImport<JWifiManager_WifiLockClass, JWifiManager_WifiLock>)
  end;

  { android.net.wifi.WifiManager (only what the lock needs). }
  JWifiManagerClass = interface(JObjectClass)
    ['{D750DC88-C4BA-486E-A10F-620A94AD930B}']
  end;

  { ... its object. }
  [JavaSignature('android/net/wifi/WifiManager')]
  JWifiManager = interface(JObject)
    ['{A19E01E5-CEB3-4028-B545-06E426505F25}']
    { A lock of the kind lockType. }
    function createWifiLock(lockType: Integer; tag: JString): JWifiManager_WifiLock; cdecl; overload;
  end;

  { ... the import. }
  TJWifiManager = class(TJavaGenericImport<JWifiManagerClass, JWifiManager>)
  end;

const
  { WifiManager.WIFI_MODE_FULL_LOW_LATENCY (API 29). }
  WIFI_MODE_FULL_LOW_LATENCY = 4;

var
  { The lock while held (nil = none). }
  GWifiLock: JWifiManager_WifiLock;

function WifiAwake(AOn: Boolean): string;
var
  Service: JObject;
  Manager: JWifiManager;
begin
  try
    if AOn then
    begin
      if GWifiLock = nil then
      begin
        Service := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.WIFI_SERVICE);
        if Service = nil then
          Exit('no Wi-Fi service');
        Manager := TJWifiManager.Wrap((Service as ILocalObject).GetObjectID);
        GWifiLock := Manager.createWifiLock(WIFI_MODE_FULL_LOW_LATENCY, StringToJString('EpubReader link'));
        GWifiLock.setReferenceCounted(False);
      end;
      if not GWifiLock.isHeld then
        GWifiLock.acquire;
      Result := 'low-latency Wi-Fi on';
    end
    else
    begin
      if (GWifiLock <> nil) and GWifiLock.isHeld then
        GWifiLock.release;
      Result := 'low-latency Wi-Fi off';
    end;
  except
    on E: Exception do
      Result := 'low-latency Wi-Fi not set: ' + E.Message;
  end;
end;

procedure KeepScreenOn(AOn: Boolean);
begin
  // the window is the Java UI thread's
  CallInUIThread(
    procedure
    begin
      if AOn then
        TAndroidHelper.Activity.getWindow.addFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON)
      else
        TAndroidHelper.Activity.getWindow.clearFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_KEEP_SCREEN_ON);
    end);
end;

function PhoneName: string;
var
  Maker, Model: string;
begin
  Maker := JStringToString(TJBuild.JavaClass.MANUFACTURER);
  Model := JStringToString(TJBuild.JavaClass.MODEL);
  // 'Google' + 'Pixel 9'; a model that names its maker already, alone
  if (Maker <> '') and not Model.ToLower.StartsWith(Maker.ToLower) then
    Result := Trim(UpperCase(Copy(Maker, 1, 1)) + Copy(Maker, 2, MaxInt) + ' ' + Model)
  else
    Result := Trim(Model);
end;

function IsTelevision: Boolean;
begin
  try
    // PackageManager.FEATURE_LEANBACK: what Google Play itself goes by
    Result := TAndroidHelper.Context.getPackageManager.hasSystemFeature(
      StringToJString('android.software.leanback'));
  except
    Result := False;
  end;
end;

function StorageFolders: TArray<string>;
var
  Dirs: TJavaObjectArray<JFile>;
  I: Integer;
begin
  Result := nil;
  try
    Dirs := TAndroidHelper.Context.getExternalFilesDirs(nil);
    if Dirs = nil then
      Exit;
    try
      // an entry is null for a volume that is not mounted
      for I := 0 to Dirs.Length - 1 do
        if Dirs.Items[I] <> nil then
          Result := Result + [JStringToString(Dirs.Items[I].getAbsolutePath)];
    finally
      Dirs.Free;
    end;
  except
    // none known: the log says so
  end;
end;

procedure BookFolderChoose(AOnDone: TBookFolderChosen);
var
  Intent: JIntent;
begin
  FolderChosen := AOnDone;
  if ResultSubscription = 0 then
    ResultSubscription := TMessageManager.DefaultManager.SubscribeToMessage(TMessageResultNotification,
      procedure(const Sender: TObject; const M: TMessage)
      var
        R: TMessageResultNotification;
        Tree: string;
        Uri: Jnet_Uri;
      begin
        R := TMessageResultNotification(M);
        if R.RequestCode <> PICK_FOLDER then
          Exit;
        Tree := '';
        if (R.ResultCode = TJActivity.JavaClass.RESULT_OK) and (R.Value <> nil) and (R.Value.getData <> nil) then
        begin
          Uri := R.Value.getData;
          // readable after this start too
          try
            TAndroidHelper.Context.getContentResolver.takePersistableUriPermission(Uri,
              TJIntent.JavaClass.FLAG_GRANT_READ_URI_PERMISSION);
          except
            // kept for this start only: chosen again next time
          end;
          Tree := JStringToString(Uri.toString);
        end;
        if Assigned(FolderChosen) then
          FolderChosen(Tree);
      end);
  Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_OPEN_DOCUMENT_TREE);
  Intent.addFlags(TJIntent.JavaClass.FLAG_GRANT_READ_URI_PERMISSION or
    TJIntent.JavaClass.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
  TAndroidHelper.Activity.startActivityForResult(Intent, PICK_FOLDER);
end;

function BookFolderBooks(const ATree: string; out ANote: string): TArray<string>;
var
  Found: TArray<string>;

  { The books of folder ADocId and its folders. }
  procedure Walk(const ADocId: string; ADepth: Integer);
  var
    Children: Jnet_Uri;
    Cursor: JCursor;
    Cols: TJavaObjectArray<JString>;
    Id, Name, Mime: string;
    Dirs: TArray<string>;
    D: string;
  begin
    if ADepth > MAX_DEPTH then
      Exit;
    Children := TJnet_Uri.JavaClass.parse(StringToJString(DocumentAddress(ATree, ADocId) + '/children'));
    Cols := TJavaObjectArray<JString>.Create(3);
    try
      Cols.Items[0] := StringToJString('document_id');
      Cols.Items[1] := StringToJString('_display_name');
      Cols.Items[2] := StringToJString('mime_type');
      Cursor := TAndroidHelper.Context.getContentResolver.query(Children, Cols, nil, nil, nil);
    finally
      Cols.Free;
    end;
    if Cursor = nil then
      Exit;
    Dirs := nil;
    try
      while Cursor.moveToNext do
      begin
        Id := JStringToString(Cursor.getString(0));
        Name := JStringToString(Cursor.getString(1));
        Mime := JStringToString(Cursor.getString(2));
        if Mime = MIME_DIR then
          Dirs := Dirs + [Id]
        else if SameText(ExtractFileExt(Name), '.epub') then
          Found := Found + [DocumentAddress(ATree, Id)];
      end;
    finally
      Cursor.close;
    end;
    for D in Dirs do
      Walk(D, ADepth + 1);
  end;

begin
  ANote := '';
  Found := nil;
  try
    if TreeId(ATree) = '' then
      raise Exception.Create('not a folder''s address');
    Walk(TreeId(ATree), 0);
  except
    on E: Exception do
      ANote := E.Message;
  end;
  Result := Found;
end;

function BookInFolder(const AName, ATree: string): Boolean;
begin
  Result := IsBookAddress(AName) and (TreeId(ATree) <> '') and
    AName.StartsWith(CONTENT_SCHEME + Authority(ATree) + '/tree/' + UriEncode(TreeId(ATree)) + DOCUMENT_PART);
end;

procedure BookFolderForget(const ATree: string);
begin
  try
    TAndroidHelper.Context.getContentResolver.releasePersistableUriPermission(TJnet_Uri.JavaClass.parse(
      StringToJString(ATree)), TJIntent.JavaClass.FLAG_GRANT_READ_URI_PERMISSION);
  except
    // not kept anyway
  end;
end;

{ bionic's pread64: ACount bytes at AOffset of file AFd, its own offset
  untouched (so readers in two threads share a descriptor). }
function pread64(AFd: Integer; ABuf: Pointer; ACount: NativeUInt; AOffset: Int64): NativeInt; cdecl;
  external 'libc.so' name 'pread64';

type
  { A book's open file read by position (TEpubZipReader's stream for an
    address; the descriptor stays BookOpenPath's). }
  TBookFdStream = class(TStream)
  private
    { The descriptor. }
    FFd: Integer;
    { Where the next read starts. }
    FPos: Int64;
    { The file's size. }
    FSize: Int64;
  protected
    { The file's size. }
    function GetSize: Int64; override;
  public
    { Reads descriptor AFd (not closed here). }
    constructor Create(AFd: Integer);
    { Reads ACount bytes at the position. }
    function Read(var Buffer; Count: Longint): Longint; override;
    { Refused: read only. }
    function Write(const Buffer; Count: Longint): Longint; override;
    { Moves the position. }
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TBookFdStream.Create(AFd: Integer);
begin
  inherited Create;
  FFd := AFd;
  // the end (lseek moves the descriptor's own offset, which reads by
  // position do not use)
  FSize := FileSeek(THandle(AFd), Int64(0), 2);
  if FSize < 0 then
    FSize := 0;
end;

function TBookFdStream.GetSize: Int64;
begin
  Result := FSize;
end;

function TBookFdStream.Read(var Buffer; Count: Longint): Longint;
var
  N: NativeInt;
begin
  Result := 0;
  if (Count <= 0) or (FPos >= FSize) then
    Exit;
  N := pread64(FFd, @Buffer, NativeUInt(Count), FPos);
  if N > 0 then
  begin
    Inc(FPos, N);
    Result := Longint(N);
  end;
end;

function TBookFdStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('a book of a books folder is read only');
end;

function TBookFdStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPos := Offset;
    soCurrent:
      FPos := FPos + Offset;
    soEnd:
      FPos := FSize + Offset;
  end;
  if FPos < 0 then
    FPos := 0;
  Result := FPos;
end;

function OpenBookStream(const AFileName: string): TStream;
var
  B: TOpenedBook;
  Found: Boolean;
begin
  Result := nil;
  if not IsBookAddress(AFileName) then
    Exit;
  OpenedLock.Enter;
  try
    Found := (Opened <> nil) and Opened.TryGetValue(AFileName, B);
  finally
    OpenedLock.Leave;
  end;
  if not Found then
    raise EStreamError.Create(BookFileName(AFileName) + ' was not opened first (BookOpenPath)');
  Result := TBookFdStream.Create(B.Fd);
end;

function BookOpenPath(const AName: string): string;
var
  B: TOpenedBook;
  Pfd: JParcelFileDescriptor;
begin
  Result := AName;
  if not IsBookAddress(AName) then
    Exit;
  OpenedLock.Enter;
  try
    if Opened = nil then
      Opened := TDictionary<string, TOpenedBook>.Create;
    if Opened.TryGetValue(AName, B) then
    begin
      Inc(B.Count);
      Opened[AName] := B;
      Exit;
    end;
  finally
    OpenedLock.Leave;
  end;
  Pfd := TAndroidHelper.Context.getContentResolver.openFileDescriptor(TJnet_Uri.JavaClass.parse(
    StringToJString(AName)), StringToJString('r'));
  if Pfd = nil then
    raise Exception.Create('Android did not open ' + BookFileName(AName));
  // ours from now on (the last BookRelease closes it)
  B.Fd := Pfd.detachFd;
  B.Count := 1;
  OpenedLock.Enter;
  try
    Opened.AddOrSetValue(AName, B);
  finally
    OpenedLock.Leave;
  end;
end;

procedure BookRelease(const AName: string);
var
  B: TOpenedBook;
  CloseIt: Boolean;
begin
  CloseIt := False;
  OpenedLock.Enter;
  try
    if (Opened <> nil) and Opened.TryGetValue(AName, B) then
    begin
      Dec(B.Count);
      if B.Count <= 0 then
      begin
        Opened.Remove(AName);
        CloseIt := True;
      end
      else
        Opened[AName] := B;
    end;
  finally
    OpenedLock.Leave;
  end;
  if CloseIt then
    FileClose(THandle(B.Fd));
end;

function BookExists(const AName: string): Boolean;
var
  Cursor: JCursor;
  Cols: TJavaObjectArray<JString>;
begin
  if not IsBookAddress(AName) then
    Exit(FileExists(AName));
  Result := False;
  try
    Cols := TJavaObjectArray<JString>.Create(1);
    try
      Cols.Items[0] := StringToJString('document_id');
      Cursor := TAndroidHelper.Context.getContentResolver.query(TJnet_Uri.JavaClass.parse(StringToJString(AName)),
        Cols, nil, nil, nil);
    finally
      Cols.Free;
    end;
    if Cursor <> nil then
      try
        Result := Cursor.moveToFirst;
      finally
        Cursor.close;
      end;
  except
    // gone (Android says so with an exception), or the folder's
    // permission withdrawn
    Result := False;
  end;
end;

{$ELSE}

function BookFolderSupported: Boolean;
begin
  Result := False;
end;

function PhoneName: string;
begin
  Result := '';
end;

function IsTelevision: Boolean;
begin
  Result := False;
end;

function StorageFolders: TArray<string>;
begin
  Result := nil;
end;

procedure KeepScreenOn(AOn: Boolean);
begin
  // the desktop keeps itself awake (uInhibit)
end;

function WifiAwake(AOn: Boolean): string;
begin
  Result := '';
end;

procedure BookFolderChoose(AOnDone: TBookFolderChosen);
begin
  if Assigned(AOnDone) then
    AOnDone('');
end;

function BookFolderBooks(const ATree: string; out ANote: string): TArray<string>;
begin
  ANote := 'no folder picker here';
  Result := nil;
end;

function BookInFolder(const AName, ATree: string): Boolean;
begin
  Result := False;
end;

procedure BookFolderForget(const ATree: string);
begin
end;

function BookOpenPath(const AName: string): string;
begin
  Result := AName;
end;

procedure BookRelease(const AName: string);
begin
end;

function BookExists(const AName: string): Boolean;
begin
  Result := FileExists(AName);
end;

function OpenBookStream(const AFileName: string): TStream;
begin
  Result := nil;
end;

{$ENDIF}

initialization
  OpenedLock := TCriticalSection.Create;

finalization
  Opened.Free;
  OpenedLock.Free;

end.
