(* @abstract(Books streamed from BookManager: a TV reads them by blocks
  over the link instead of keeping them.)

  Owner, 2026-11-27 15:47: "Next we need to stream to the tv"; 15:5x:
  the TV sees ALL of BookManager's books (its fetch folder) while it runs
  and is paired, and streams them by default (zip 392; BookManager's half,
  its server, is zip 391).

  A streamed book is named by an address of its own,
  bookmanager://ID/PATH - ID the BookManager's id on the link (it stays
  when its address changes), PATH the book's path on that computer, URL-
  encoded - and goes through the reader as a book of a books folder does
  (uBookImport): the BookManager is a "books folder"
  (bookmanager://ID/), its books are listed from the list it gave last
  (StreamBooks - never a call in the window's thread), and a book is read
  through @link(OpenStreamBook): a TStream whose reads are /book calls
  for blocks of STREAM_BLOCK bytes, the last STREAM_BLOCKS_KEPT kept. The
  audio stored in a book is played by the player straight from
  BookManager (@link(StreamAudioUrl): its /slice, with HTTP ranges).

  The BookManagers are told by the reader (@link(StreamServerHeard): its
  announcement, with the token this reader gave it when they paired - the
  same token is the key to its server); their lists are asked for in a
  thread (@link(StreamRefresh)). *)

unit uStreamBook;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections;

const
  { A streamed book's address begins so. }
  STREAM_SCHEME = 'bookmanager://';
  { A streamed book is read by blocks of this many bytes (one /book call
    each). }
  STREAM_BLOCK = 512 * 1024;
  { Blocks a streamed book keeps (the newest; 16 MB). }
  STREAM_BLOCKS_KEPT = 32;

{ AName is a streamed book's address (or a BookManager's "folder").
  @param(AName  a book's name)
  @returns(the answer) }
function IsStreamName(const AName: string): Boolean;

{ The "books folder" of the BookManager AId: bookmanager://ID/.
  @param(AId  its id on the link)
  @returns(the folder's name) }
function StreamTree(const AId: string): string;

{ A streamed book's address.
  @param(AId  the BookManager's id)
  @param(APath  the book's path on its computer)
  @returns(bookmanager://ID/PATH) }
function StreamBookName(const AId, APath: string): string;

{ A streamed book's file name ('Night Watch.epub').
  @param(AName  its address)
  @returns(the file name) }
function StreamBookFileName(const AName: string): string;

{ A BookManager "folder"'s name for the library: "BookManager on
  MONSTER" (its id when it was not heard this run).
  @param(ATree  bookmanager://ID/ - or one of its books)
  @returns(the name) }
function StreamFolderName(const ATree: string): string;

{ A streamed book is the BookManager ATree's.
  @param(AName  the book)
  @param(ATree  bookmanager://ID/)
  @returns(the answer) }
function StreamBookIn(const AName, ATree: string): Boolean;

{ A BookManager was heard (the window's thread): where it is now, and the
  token to call it with (the one this reader gave it; '' = not paired -
  it is not called).
  @param(AId  its id)
  @param(AName  "BookManager on MONSTER")
  @param(AHost  its address)
  @param(APort  its server's port)
  @param(AToken  the token) }
procedure StreamServerHeard(const AId, AName, AHost: string; APort: Integer; const AToken: string);

{ A BookManager not heard for a while (or that said goodbye): its books
  are not read until it is heard again (the window's thread).
  @param(AId  its id) }
procedure StreamServerLost(const AId: string);

{ The BookManager of a streamed book (or of a "folder") is on the network
  now, paired: the book can be read.
  @param(AName  the book, or bookmanager://ID/)
  @returns(the answer) }
function StreamReachable(const AName: string): Boolean;

{ The books of the BookManager ATree, as it gave them last (no call).
  @param(ATree  bookmanager://ID/)
  @param(ANote  '' when a list is known; else why not (not heard, not
    answered) - the books are then not taken for gone)
  @returns(the books' addresses) }
function StreamBooks(const ATree: string; out ANote: string): TArray<string>;

{ Asks the BookManager ATree for its books, in a thread (one at a time);
  AOnDone in the window's thread after, when the list changed.
  @param(ATree  bookmanager://ID/)
  @param(AOnDone  told when the list changed (nil: not told)) }
procedure StreamRefresh(const ATree: string; const AOnDone: TProc);

{ A streamed book, read by blocks from its BookManager (any thread; the
  caller frees it).
  @param(AName  its address)
  @returns(the stream)
  @raises(EStreamError when its BookManager is not known or does not
    answer) }
function OpenStreamBook(const AName: string): TStream;

{ The address a player streams ASize bytes at AOffset of a streamed book
  from (its BookManager's /slice; the token in it).
  @param(AName  the book)
  @param(AOffset  the first byte (the audio stored in the book))
  @param(ASize  its length)
  @returns(an http:// address; '' when its BookManager is not known) }
function StreamAudioUrl(const AName: string; AOffset, ASize: Int64): string;

implementation

uses
  System.NetEncoding, System.JSON, System.Math, IdHTTP, IdIOHandlerStack, uLink, uDebugLog;

type
  { A book a BookManager listed. }
  TStreamListed = record
    { Its path there. }
    Path: string;
    { Its size. }
    Size: Int64;
  end;

  { A BookManager heard. }
  TStreamServer = record
    { Its id. }
    Id: string;
    { "BookManager on MONSTER". }
    Name: string;
    { Its address. }
    Host: string;
    { Its server's port. }
    Port: Integer;
    { The token to call it with. }
    Token: string;
    { Its books, as listed last. }
    Books: TArray<TStreamListed>;
    { A list was given. }
    Listed: Boolean;
    { A list is being asked for. }
    Refreshing: Boolean;
    { Why the last ask failed ('' = it did not). }
    Note: string;
  end;

  { A block of a streamed book kept. }
  TStreamBlock = record
    { Its number (offset div STREAM_BLOCK). }
    Index: Int64;
    { Its bytes. }
    Data: TBytes;
  end;

  { A streamed book read by blocks (/book?path&offset&length). }
  TStreamBookStream = class(TStream)
  private
    { The BookManager's address. }
    FHost: string;
    { Its port. }
    FPort: Integer;
    { The token. }
    FToken: string;
    { The book's path there. }
    FPath: string;
    { Its size. }
    FSize: Int64;
    { Where the next read starts. }
    FPos: Int64;
    { The blocks kept, the newest last. }
    FBlocks: TList<TStreamBlock>;
    { The connection's client. }
    FHttp: TIdHTTP;
    { Block AIndex: kept, else asked for.
      @param(AIndex  its number)
      @returns(its bytes) }
    function Block(AIndex: Int64): TBytes;
    { The bytes from AOffset (at most ALength) asked for.
      @param(AOffset  the first byte)
      @param(ALength  how many)
      @param(ASize  the book's size, as the answer says)
      @returns(the bytes) }
    function Fetch(AOffset, ALength: Int64; out ASize: Int64): TBytes;
  protected
    { The book's size. }
    function GetSize: Int64; override;
  public
    { For the book APath of the BookManager at AHost:APort; ASize its
      size when known (-1: asked for).
      @param(AHost  its address)
      @param(APort  its port)
      @param(AToken  the token)
      @param(APath  the book's path there)
      @param(ASize  its size, or -1) }
    constructor Create(const AHost: string; APort: Integer; const AToken, APath: string; ASize: Int64);
    { Frees the blocks and the client. }
    destructor Destroy; override;
    { Reads from the blocks. }
    function Read(var Buffer; Count: Longint): Longint; override;
    { Refused: read only. }
    function Write(const Buffer; Count: Longint): Longint; override;
    { Moves the position. }
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

var
  { Guards Servers. }
  ServersLock: TCriticalSection;
  { The BookManagers heard, by id. }
  Servers: TDictionary<string, TStreamServer>;

function IsStreamName(const AName: string): Boolean;
begin
  Result := AName.StartsWith(STREAM_SCHEME, True);
end;

function StreamTree(const AId: string): string;
begin
  Result := STREAM_SCHEME + AId + '/';
end;

function StreamBookName(const AId, APath: string): string;
begin
  Result := StreamTree(AId) + TNetEncoding.URL.Encode(APath);
end;

{ A streamed address taken apart: the BookManager's id and the path (''
  for a "folder").
  @param(AName  the address)
  @param(AId  the id)
  @param(APath  the path)
  @returns(it is a streamed address) }
function SplitName(const AName: string; out AId, APath: string): Boolean;
var
  Rest: string;
  P: Integer;
begin
  AId := '';
  APath := '';
  Result := IsStreamName(AName);
  if not Result then
    Exit;
  Rest := Copy(AName, Length(STREAM_SCHEME) + 1, MaxInt);
  P := Pos('/', Rest);
  if P = 0 then
  begin
    AId := Rest;
    Exit;
  end;
  AId := Copy(Rest, 1, P - 1);
  APath := TNetEncoding.URL.Decode(Copy(Rest, P + 1, MaxInt));
end;

function StreamBookFileName(const AName: string): string;
var
  Id, Path: string;
  P: Integer;
begin
  SplitName(AName, Id, Path);
  // the path is the computer's: Windows' \ or a Mac's /
  P := Path.LastDelimiter('\/');
  if P >= 0 then
    Result := Path.Substring(P + 1)
  else
    Result := Path;
end;

function StreamFolderName(const ATree: string): string;
var
  Id, Path: string;
  S: TStreamServer;
begin
  SplitName(ATree, Id, Path);
  Result := 'BookManager ' + Id;
  ServersLock.Enter;
  try
    if (Servers <> nil) and Servers.TryGetValue(Id, S) and (S.Name <> '') then
      Result := S.Name;
  finally
    ServersLock.Leave;
  end;
end;

function StreamBookIn(const AName, ATree: string): Boolean;
begin
  Result := IsStreamName(AName) and AName.StartsWith(ATree, True);
end;

procedure StreamServerHeard(const AId, AName, AHost: string; APort: Integer; const AToken: string);
var
  S: TStreamServer;
begin
  if AId = '' then
    Exit;
  ServersLock.Enter;
  try
    if Servers = nil then
      Servers := TDictionary<string, TStreamServer>.Create;
    if not Servers.TryGetValue(AId, S) then
    begin
      S := Default(TStreamServer);
      S.Id := AId;
    end;
    S.Name := AName;
    S.Host := AHost;
    S.Port := APort;
    S.Token := AToken;
    Servers.AddOrSetValue(AId, S);
  finally
    ServersLock.Leave;
  end;
end;

procedure StreamServerLost(const AId: string);
var
  S: TStreamServer;
begin
  ServersLock.Enter;
  try
    if (Servers <> nil) and Servers.TryGetValue(AId, S) then
    begin
      S.Port := 0;
      Servers[AId] := S;
    end;
  finally
    ServersLock.Leave;
  end;
end;

function StreamReachable(const AName: string): Boolean;
var
  Id, Path: string;
  S: TStreamServer;
begin
  Result := False;
  if not SplitName(AName, Id, Path) then
    Exit;
  ServersLock.Enter;
  try
    Result := (Servers <> nil) and Servers.TryGetValue(Id, S) and (S.Token <> '') and (S.Port > 0);
  finally
    ServersLock.Leave;
  end;
end;

function StreamBooks(const ATree: string; out ANote: string): TArray<string>;
var
  Id, Path: string;
  S: TStreamServer;
  I: Integer;
begin
  Result := nil;
  SplitName(ATree, Id, Path);
  ServersLock.Enter;
  try
    if (Servers = nil) or not Servers.TryGetValue(Id, S) then
    begin
      ANote := 'not heard on the network yet';
      Exit;
    end;
    if not S.Listed then
    begin
      ANote := S.Note;
      if ANote = '' then
        ANote := 'its books not listed yet';
      Exit;
    end;
    ANote := '';
    SetLength(Result, Length(S.Books));
    for I := 0 to High(S.Books) do
      Result[I] := StreamBookName(Id, S.Books[I].Path);
  finally
    ServersLock.Leave;
  end;
end;

procedure StreamRefresh(const ATree: string; const AOnDone: TProc);
var
  Id, Path: string;
  S: TStreamServer;
  Done: TProc;
begin
  // (a parameter is not captured: a copy)
  Done := AOnDone;
  SplitName(ATree, Id, Path);
  ServersLock.Enter;
  try
    if (Servers = nil) or not Servers.TryGetValue(Id, S) or S.Refreshing or (S.Token = '') or (S.Port <= 0) then
      Exit;
    S.Refreshing := True;
    Servers[Id] := S;
  finally
    ServersLock.Leave;
  end;
  TThread.CreateAnonymousThread(
    procedure
    var
      Client: TLinkClient;
      O, E: TJSONObject;
      A: TJSONArray;
      V: TJSONValue;
      Books: TArray<TStreamListed>;
      L: TStreamListed;
      Why: string;
      Changed: Boolean;
      Cur: TStreamServer;
      I: Integer;
    begin
      Books := nil;
      Why := '';
      try
        Client := TLinkClient.Create(S.Host, S.Port, 'EpubReader', S.Token);
        try
          O := Client.Books;
          try
            if O.TryGetValue<TJSONArray>('books', A) then
              for V in A do
                if V is TJSONObject then
                begin
                  E := TJSONObject(V);
                  L.Path := E.GetValue<string>('path', '');
                  L.Size := E.GetValue<Int64>('size', -1);
                  if L.Path <> '' then
                    Books := Books + [L];
                end;
          finally
            O.Free;
          end;
        finally
          Client.Free;
        end;
      except
        on Ex: Exception do
          Why := Ex.Message;
      end;
      Changed := False;
      ServersLock.Enter;
      try
        if Servers.TryGetValue(S.Id, Cur) then
        begin
          Cur.Refreshing := False;
          Cur.Note := Why;
          if Why = '' then
          begin
            Changed := not Cur.Listed or (Length(Cur.Books) <> Length(Books));
            if not Changed then
              for I := 0 to High(Books) do
                if not SameText(Books[I].Path, Cur.Books[I].Path) or (Books[I].Size <> Cur.Books[I].Size) then
                begin
                  Changed := True;
                  Break;
                end;
            Cur.Books := Books;
            Cur.Listed := True;
          end;
          Servers[S.Id] := Cur;
        end;
      finally
        ServersLock.Leave;
      end;
      if Why <> '' then
        DebugLog(Format('stream: %s gave no list - %s', [S.Name, Why]))
      else if Changed then
        DebugLog(Format('stream: %s has %d book(s)', [S.Name, Length(Books)]));
      if Changed and Assigned(Done) then
        TThread.Queue(nil,
          procedure
          begin
            Done();
          end);
    end).Start;
end;

{ The BookManager of a streamed book, and the book's path and size there.
  @param(AName  the book)
  @param(AServer  its BookManager)
  @param(APath  the path)
  @param(ASize  the size (-1: not listed))
  @returns(its BookManager is known and may be called) }
function FindServer(const AName: string; out AServer: TStreamServer; out APath: string; out ASize: Int64): Boolean;
var
  Id: string;
  L: TStreamListed;
begin
  ASize := -1;
  Result := False;
  if not SplitName(AName, Id, APath) or (APath = '') then
    Exit;
  ServersLock.Enter;
  try
    Result := (Servers <> nil) and Servers.TryGetValue(Id, AServer) and (AServer.Token <> '') and
      (AServer.Port > 0);
    if Result then
      for L in AServer.Books do
        if SameText(L.Path, APath) then
        begin
          ASize := L.Size;
          Break;
        end;
  finally
    ServersLock.Leave;
  end;
end;

function OpenStreamBook(const AName: string): TStream;
var
  S: TStreamServer;
  Path: string;
  Size: Int64;
begin
  if not FindServer(AName, S, Path, Size) then
    raise EStreamError.Create(StreamBookFileName(AName) + ': its BookManager is not on the network now');
  Result := TStreamBookStream.Create(S.Host, S.Port, S.Token, Path, Size);
end;

function StreamAudioUrl(const AName: string; AOffset, ASize: Int64): string;
var
  S: TStreamServer;
  Path: string;
  Size: Int64;
begin
  Result := '';
  if not FindServer(AName, S, Path, Size) then
    Exit;
  Result := Format('http://%s:%d/slice?path=%s&offset=%d&length=%d&type=audio/mp4&token=%s', [S.Host, S.Port,
    TNetEncoding.URL.Encode(Path), AOffset, ASize, TNetEncoding.URL.Encode(S.Token)]);
end;

{ TStreamBookStream }

constructor TStreamBookStream.Create(const AHost: string; APort: Integer; const AToken, APath: string;
  ASize: Int64);
var
  Size: Int64;
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FToken := AToken;
  FPath := APath;
  FBlocks := TList<TStreamBlock>.Create;
  FHttp := TIdHTTP.Create(nil);
  FHttp.IOHandler := TIdIOHandlerStack.Create(FHttp);
  FHttp.ConnectTimeout := LINK_CONNECT_MS;
  FHttp.ReadTimeout := 30000;
  FHttp.Request.CustomHeaders.Values['X-Link-Token'] := FToken;
  FSize := ASize;
  // not listed: the answer to a first byte says it
  if FSize < 0 then
  begin
    Fetch(0, 1, Size);
    FSize := Size;
  end;
end;

destructor TStreamBookStream.Destroy;
begin
  FHttp.Free;
  FBlocks.Free;
  inherited;
end;

function TStreamBookStream.GetSize: Int64;
begin
  Result := FSize;
end;

function TStreamBookStream.Fetch(AOffset, ALength: Int64; out ASize: Int64): TBytes;
var
  Mem: TMemoryStream;
begin
  Mem := TMemoryStream.Create;
  try
    try
      FHttp.Get(Format('http://%s:%d/book?path=%s&offset=%d&length=%d', [FHost, FPort,
        TNetEncoding.URL.Encode(FPath), AOffset, ALength]), Mem);
    except
      on E: Exception do
        raise EStreamError.CreateFmt('BookManager did not give the book''s bytes at %d: %s', [AOffset, E.Message]);
    end;
    ASize := StrToInt64Def(FHttp.Response.RawHeaders.Values['X-Link-Size'], -1);
    SetLength(Result, Mem.Size);
    if Mem.Size > 0 then
      Move(Mem.Memory^, Result[0], Mem.Size);
  finally
    Mem.Free;
  end;
end;

function TStreamBookStream.Block(AIndex: Int64): TBytes;
var
  I: Integer;
  B: TStreamBlock;
  Size: Int64;
begin
  for I := FBlocks.Count - 1 downto 0 do
    if FBlocks[I].Index = AIndex then
    begin
      B := FBlocks[I];
      // the newest last
      if I < FBlocks.Count - 1 then
      begin
        FBlocks.Delete(I);
        FBlocks.Add(B);
      end;
      Exit(B.Data);
    end;
  B.Index := AIndex;
  B.Data := Fetch(AIndex * STREAM_BLOCK, Min(Int64(STREAM_BLOCK), FSize - AIndex * STREAM_BLOCK), Size);
  if FBlocks.Count >= STREAM_BLOCKS_KEPT then
    FBlocks.Delete(0);
  FBlocks.Add(B);
  Result := B.Data;
end;

function TStreamBookStream.Read(var Buffer; Count: Longint): Longint;
var
  Data: TBytes;
  Index: Int64;
  Within, Take: Integer;
  Dest: PByte;
begin
  Result := 0;
  Dest := @Buffer;
  while (Count > 0) and (FPos < FSize) do
  begin
    Index := FPos div STREAM_BLOCK;
    // less than a block: an Integer
    Within := Integer(FPos mod STREAM_BLOCK);
    Data := Block(Index);
    Take := Min(Count, Length(Data) - Within);
    if Take <= 0 then
      Break;
    Move(Data[Within], Dest^, Take);
    Inc(Dest, Take);
    Inc(FPos, Take);
    Inc(Result, Take);
    Dec(Count, Take);
  end;
end;

function TStreamBookStream.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('a streamed book is read only');
end;

function TStreamBookStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
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

initialization
  ServersLock := TCriticalSection.Create;

finalization
  Servers.Free;
  ServersLock.Free;

end.
