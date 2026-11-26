(* @abstract(The link between EpubBuilder and the programs that talk to it -
  BookManager (sends books and audio, receives the books made, shows the
  progress and the log) and EpubReader (copies the books made).)

  Owner, 2026-11-20: "Builder should be connectable to by Reader so Reader
  can get local copies of Transcribed epubs", a BookManager drop target
  ("drag a book to it and builder sticks it in books, drag audio -> audio,
  drag folder - send right bits to right locations"), "space-aware ... so
  we don't fill up the users build drive", and TSteamAPI's remote logger
  was "hard to connect to" - so nothing is typed:

  @unorderedList(
    @item(@bold(Found by itself): a builder says where it is every two
      seconds (UDP broadcast, port LINK_DISCOVERY_PORT, a line of JSON);
      @link(TLinkFinder) lists the builders heard.)
    @item(@bold(HTTP) (Indy - works on Linux and in Steam's runtime): the
      builder's @link(TLinkServer) on LINK_HTTP_PORT or the next free
      port; @link(TLinkClient) calls it.)
    @item(@bold(Paired once): a program asks (/pair), the builder shows a
      6-digit code, the program sends it back (/pair/confirm) and gets a
      token, kept on both sides. Every other call but /info needs it
      (header X-Link-Token).)
    @item(@bold(Space): an upload is checked first (/upload/check) and again
      when it starts: it never leaves less than LINK_RESERVE free on the
      drive it goes to.))

  Calls (JSON unless a file):
  @unorderedList(
    @item(GET /info - who it is (no token needed);)
    @item(POST /pair?client=NAME, POST /pair/confirm?client=NAME&code=N;)
    @item(POST /pair/ticket?client=NAME&ticket=T - pairing without the
      code, for two installations of one account of the link site
      (uLinkSite): the token at once, when @link(TLinkServer.TicketCheck)
      says the ticket is good; 404 when the builder takes none
      (@link(TLinkServer.TakesTickets));)
    @item(GET /space - the books and audio folders and their free space;)
    @item(GET /books - the books made (the output folders);)
    @item(GET /book?path=P&offset=N - one of them, from byte N;)
    @item(POST /upload/check and POST /upload - a file into Books, Audio
      or Covers (headers X-Link-Kind book / audio / cover, X-Link-Name,
      X-Link-Dir,
      X-Link-Size); written as .part, put in place when whole;)
    @item(GET /status - the progress (what the builder last set);)
    @item(GET /log?from=N - the log lines from N on.)) *)
unit uLink;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON, System.Generics.Collections, IdGlobal,
  IdContext, IdCustomHTTPServer, IdHTTPServer, IdHeaderList, IdUDPServer, IdUDPClient, IdSocketHandle,
  IdHTTP, IdComponent;

const
  { The builders say where they are on this UDP port. }
  LINK_DISCOVERY_PORT = 47820;
  { The builder's HTTP port (or one of the next nine, when taken). }
  LINK_HTTP_PORT = 47821;
  { The link's version (in /info and the announcements). }
  LINK_VERSION = 1;
  { Space an upload never takes: building needs room too (2 GiB). }
  LINK_RESERVE = Int64(2) * 1024 * 1024 * 1024;
  { A builder not heard for this long (s) leaves the finder's list. }
  LINK_GONE_SECONDS = 10;
  { A pairing code works this long (minutes). }
  LINK_PAIR_MINUTES = 5;
  { The app name EpubBuilder announces (TLinkPeer.App). }
  LINK_APP_BUILDER = 'EpubBuilder';
  { The app name EpubReader announces on a phone, to be sent books
    (zip 354: BookManager's Send to phone; only books, into the reader's
    own Books folder). }
  LINK_APP_READER = 'EpubReader';
  { The app name BookManager says itself under (zip 357: a TLinkBeacon, so
    a phone that links can answer it directly - port 0, no server). }
  LINK_APP_MANAGER = 'BookManager';
  { Space an upload to a phone never takes (500 MiB): the phone needs room
    for itself. }
  LINK_RESERVE_PHONE = Int64(500) * 1024 * 1024;
  { How long a call waits for the connection, ms (a builder on a
    computer answers at once). }
  LINK_CONNECT_MS = 5000;
  { ... to a phone (zip 356): the owner's Pixel took 45 - 60 s to take a
    first connection from the computer (its Wi-Fi or the router drop the
    first tries; TCP tries again after 1, 3, 7, 15 s ...). }
  LINK_CONNECT_PHONE_MS = 30000;
  { The buffers of a transfer, bytes (zip 369: 1 MiB - Indy's default 32 KiB
    and the phone's 32-KiB writes held a phone to ~10 - 15 MB/s on Wi-Fi). }
  LINK_BUFFER = 1024 * 1024;
  { Tickets refused in a minute before no more are looked at for the
    rest of it (each one looked at is a call to the link site). }
  LINK_TICKET_TRIES = 5;

type
  { A builder heard (TLinkFinder). }
  TLinkPeer = record
    { The builder's own id (it stays when its address changes). }
    Id: string;
    { LINK_APP_BUILDER or LINK_APP_READER ('' from an old builder:
      a builder). }
    App: string;
    { The machine's name. }
    Name: string;
    { Its address. }
    Host: string;
    { Its HTTP port. }
    Port: Integer;
    { When it was last heard. }
    Seen: TDateTime;
  end;

  { The builders heard. }
  TLinkPeerArray = array of TLinkPeer;

  { The builder shows a pairing code: AClient asked, ACode is the code. }
  TLinkPairCodeEvent = procedure(const AClient, ACode: string) of object;
  { A program was paired: its name and token (to keep). }
  TLinkPairedEvent = procedure(const AClient, AToken: string) of object;
  { The code offered to AClient no longer works, without a pairing:
    AWhy (five wrong codes). }
  TLinkPairEndedEvent = procedure(const AClient, AWhy: string) of object;
  { A file was received: 'book' or 'audio', and where it is now. }
  TLinkReceivedEvent = procedure(const AKind, AFileName: string) of object;
  { Asks whether ATicket, handed over by a program that wants to pair
    without the code, is good (the link site says - uLinkSite's
    TLinkSite.Check). Called in one of the server's threads; it may take
    as long as the site does.
    @param(AClient what the site calls the program, when it is good)
    @param(AWhy why not, when it is not)
    @returns(True when the program may be paired) }
  TLinkTicketCheck = reference to function(const ATicket: string; out AClient, AWhy: string): Boolean;
  { A call came: what and from where (for the debug log). }
  TLinkRequestEvent = procedure(const AText: string) of object;
  { An upload's progress: the file's name, its place in the sender's batch
    ('2/3'; '' = not said), bytes done of ATotal. }
  TLinkUploadProgressEvent = procedure(const AName, ABatch: string; ADone, ATotal: Int64) of object;

  { The builder's side: says where it is, answers the calls. Its events
    come on the main thread. }
  TLinkServer = class
  private
    { The HTTP server. }
    FHttp: TIdHTTPServer;
    { Says where the builder is every two seconds. }
    FAnnouncer: TThread;
    { Guards the fields below (the server's threads read them). }
    FLock: TCriticalSection;
    { The builder's id (kept in its settings by the caller). }
    FId: string;
    { LINK_APP_BUILDER or LINK_APP_READER. }
    FApp: string;
    { Backing field of Reserve. }
    FReserve: Int64;
    { The machine's name. }
    FName: string;
    { The HTTP port in use (0 = not started). }
    FPort: Integer;
    { The books folder. }
    FBooks: string;
    { The audio folder. }
    FAudio: string;
    { The covers folder (pictures named as a book: its cover). }
    FCovers: string;
    { The folders the books made are in. }
    FOutputs: TArray<string>;
    { The progress, as JSON. }
    FStatus: string;
    { The last log lines. }
    FLog: TStringList;
    { The number of the first line in FLog. }
    FLogBase: Integer;
    { The paired programs: token=name. }
    FTokens: TStringList;
    { The pairing code offered now ('' = none). }
    FPairCode: string;
    { The program it was offered to. }
    FPairClient: string;
    { Until when the code is good. }
    FPairUntil: TDateTime;
    { Wrong codes sent for FPairCode. }
    FPairWrong: Integer;
    { The last code was refused on the builder (RefusePair): its program is
      told so. }
    FPairRefused: Boolean;
    { Backing field of TicketCheck. }
    FTicketCheck: TLinkTicketCheck;
    { Backing field of TakesTickets (under FLock). }
    FTakesTickets: Boolean;
    { Tickets refused since FTicketSince. }
    FTicketWrong: Integer;
    { When the minute FTicketWrong counts in began. }
    FTicketSince: TDateTime;
    { Backing field of OnPairEnded. }
    FOnPairEnded: TLinkPairEndedEvent;
    { Backing field of OnPairCode. }
    FOnPairCode: TLinkPairCodeEvent;
    { Backing field of OnPaired. }
    FOnPaired: TLinkPairedEvent;
    { Backing field of OnReceived. }
    FOnReceived: TLinkReceivedEvent;
    { Backing field of OnRequest. }
    FOnRequest: TLinkRequestEvent;
    { Backing field of Announcing. }
    FAnnouncing: Boolean;
    { Backing field of OnUploadProgress. }
    FOnUploadProgress: TLinkUploadProgressEvent;
    { Backing field of OnBye. }
    FOnBye: TLinkRequestEvent;
    { Addresses the announcement also goes to directly (SetDirect; under
      FLock). }
    FDirect: TArray<string>;
    { TakesTickets' getter. }
    function GetTakesTickets: Boolean;
    { TakesTickets' setter. }
    procedure SetTakesTickets(AValue: Boolean);
    { Answers a call. }
    procedure CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    { An upload's body goes straight into its .part file. }
    procedure CreatePostStream(AContext: TIdContext; AHeaders: TIdHeaderList; var VPostStream: TStream);
    { A connection came: its buffers LINK_BUFFER. }
    procedure Connected(AContext: TIdContext);
    { The token sent is a paired program's. }
    function TokenOk(const AToken: string): Boolean;
    { Checks an upload's headers: the file it goes to ('' and AWhy when it
      may not), its folder and size. }
    function UploadTarget(AHeaders: TIdHeaderList; out AFolder: string; out ASize: Int64;
      out AWhy: string): string;
    { The JSON of /books. }
    function BooksJson: string;
    { The file APath may be sent: an EPUB in an output folder. }
    function MayGet(const APath: string): Boolean;
    { The announcement (a line of JSON). }
    function Announcement: string;
  public
    { Not started yet (Start).
      @param(AApp  LINK_APP_BUILDER or LINK_APP_READER)
      @param(AName  the machine's name)
      @param(AId  the builder's id, kept between runs) }
    constructor Create(const AApp, AName, AId: string);
    { Stops and frees. }
    destructor Destroy; override;
    { Listens (LINK_HTTP_PORT or the next free one) and says where it is.
      @returns(what was done, for the log) }
    function Start: string;
    { Stops listening and saying. }
    procedure Stop;
    { The announcement also goes straight to these addresses (a phone: the
      BookManagers it hears) - a unicast packet makes the computer learn
      the phone's address, so its first connection is not lost (zip 357;
      the owner's Pixel took 45 - 60 s to take one otherwise). }
    procedure SetDirect(const AHosts: TArray<string>);
    { The addresses of SetDirect (any thread). }
    function Direct: TArray<string>;
    { The folders: books, audio, covers and those the books made are in. }
    procedure SetFolders(const ABooks, AAudio, ACovers: string; const AOutputs: TArray<string>);
    { The progress, as JSON (sent by /status). }
    procedure SetStatus(const AJson: string);
    { A log line (sent by /log). }
    procedure AddLog(const ALine: string);
    { The paired programs, token=name a line (from the settings). }
    procedure SetTokens(const AText: string);
    { The paired programs, token=name a line (to keep). }
    function TokensText: string;
    { The code offered is refused (the builder's Refuse connection): the
      program asking is told so; it may ask again. }
    procedure RefusePair;
    { The HTTP port in use (0 = not listening). }
    property Port: Integer read FPort;
    { Space an upload never takes, bytes (LINK_RESERVE at first; a phone:
      LINK_RESERVE_PHONE). Set before Start. }
    property Reserve: Int64 read FReserve write FReserve;
    { Says whether a ticket is good (/pair/ticket). Not set: the builder
      takes no tickets, and pairing is by the code only. Set it before
      Start (it is not changed while the server runs: TakesTickets is). }
    property TicketCheck: TLinkTicketCheck read FTicketCheck write FTicketCheck;
    { Tickets are taken now (False at first): the builder is in an account
      of the link site. /info says so; /pair/ticket answers 404 while it
      is False. May be changed at any time, from any thread. }
    property TakesTickets: Boolean read GetTakesTickets write SetTakesTickets;
    { A program asks to pair: show the code. }
    property OnPairCode: TLinkPairCodeEvent read FOnPairCode write FOnPairCode;
    { A program was paired: keep the tokens (TokensText). }
    property OnPaired: TLinkPairedEvent read FOnPaired write FOnPaired;
    { The code offered stopped working without a pairing (five wrong
      codes): take the code away. }
    property OnPairEnded: TLinkPairEndedEvent read FOnPairEnded write FOnPairEnded;
    { A file was received. }
    property OnReceived: TLinkReceivedEvent read FOnReceived write FOnReceived;
    { Every call that comes: 'GET /info from 192.168.1.10' (on the main
      thread; set before Start). }
    property OnRequest: TLinkRequestEvent read FOnRequest write FOnRequest;
    { Says where it is every two seconds (True at first). A phone sets it
      False while the app is not in front: Android takes the network away
      then (the announcement fails with Socket Error # 1), and the phone
      shows as not heard. Read by the announcer's thread. }
    property Announcing: Boolean read FAnnouncing write FAnnouncing;
    { An upload's progress, at most twice a second and at its end (on the
      main thread; set before Start). }
    property OnUploadProgress: TLinkUploadProgressEvent read FOnUploadProgress write FOnUploadProgress;
    { A paired program says it is closing (POST /bye): its name (on the
      main thread; zip 371 - the phone's link panel closes when
      BookManager does). }
    property OnBye: TLinkRequestEvent read FOnBye write FOnBye;
  end;

  { Says that a program with no server is here (BookManager: its name and
    id, port 0), every two seconds, so a phone that links can answer it
    directly (TLinkServer.SetDirect). }
  TLinkBeacon = class(TThread)
  private
    { The announcement. }
    FText: string;
  protected
    { Broadcasts until terminated. }
    procedure Execute; override;
  public
    { Starts at once.
      @param(AApp  LINK_APP_MANAGER)
      @param(AName  the machine's name)
      @param(AId  the program's id, kept between runs) }
    constructor Create(const AApp, AName, AId: string);
  end;

  { Lists the builders heard on the network (their announcements). Its
    event comes on the main thread. }
  TLinkFinder = class
  private
    { Hears the announcements. }
    FUdp: TIdUDPServer;
    { Guards FPeers. }
    FLock: TCriticalSection;
    { The builders heard. }
    FPeers: TLinkPeerArray;
    { Backing field of OnChange. }
    FOnChange: TNotifyEvent;
    { Backing field of State. }
    FState: string;
    { Backing field of OnFirstHeard. }
    FOnFirstHeard: TLinkRequestEvent;
    { Backing field of OnBye. }
    FOnBye: TLinkRequestEvent;
    { An announcement came. }
    procedure UdpRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
  public
    { Listens at once. }
    constructor Create;
    { Stops and frees. }
    destructor Destroy; override;
    { The builders heard in the last LINK_GONE_SECONDS. }
    function Peers: TLinkPeerArray;
    { A builder came, went or moved (called on the main thread; also call
      Peers now and then: one that stops saying goes quietly). }
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    { Whether it listens, for the log ('listening on UDP 47820', or why
      not). }
    property State: string read FState;
    { The first announcement of a program not in the list: 'BookManager
      "BookManager on PC" from 192.168.1.91, first heard' (on the main
      thread; for the log - zip 364, the ~60 s before BookManager and a
      phone hear each other). }
    property OnFirstHeard: TLinkRequestEvent read FOnFirstHeard write FOnFirstHeard;
    { A program said goodbye (an announcement with "bye": LinkSayBye): its
      app and name, 'BookManager "BookManager on PC"' (on the main thread);
      it leaves the list at once. }
    property OnBye: TLinkRequestEvent read FOnBye write FOnBye;
  end;

  { Called with the bytes done and the whole (0 = not known). }
  TLinkProgress = reference to procedure(ADone, ATotal: Int64);

  { The other programs' side: calls a builder. Blocking - use it from a
    thread for files. Raises ELinkError with the builder's message (or
    with what went wrong on the way), ELinkCancelled after Cancel. }
  TLinkClient = class
  private
    { The builder's address. }
    FHost: string;
    { Its port. }
    FPort: Integer;
    { The token from pairing ('' = not paired). }
    FToken: string;
    { This program's name, sent when pairing. }
    FClient: string;
    { The progress callback of the transfer running. }
    FProgress: TLinkProgress;
    { The size of the transfer running. }
    FTotal: Int64;
    { The bytes of a download already there (resumed). }
    FOffset: Int64;
    { The direction FProgress counts (wmRead: a download, wmWrite: an
      upload's body). }
    FWorkMode: TWorkMode;
    { Cancel was called: the call running stops, the next ones do not
      start. }
    FCancel: Boolean;
    { Guards FHttp (Cancel comes from another thread). }
    FLock: TCriticalSection;
    { The HTTP client of the call running (nil = none): Cancel disconnects
      it, which also ends a call stuck on a silent network. }
    FHttp: TIdHTTP;
    { Backing field of Skipped. }
    FSkipped: Boolean;
    { Backing field of ConnectTimeout. }
    FConnectTimeout: Integer;
    { Backing field of Batch. }
    FBatch: string;
    { Backing field of ReadTimeout. }
    FReadTimeout: Integer;
    { A new HTTP client with the token. }
    function NewHttp: TIdHTTP;
    { The call running is AHttp's (nil: none now) - for Cancel. }
    procedure Running(AHttp: TIdHTTP);
    { Raises ELinkCancelled when Cancel was called. }
    procedure CheckCancel;
    { Indy's work event: FProgress (and Cancel). }
    procedure Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
    { Indy's work-begin event: a download's size, as soon as it is known. }
    procedure WorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
    { The exception to raise for E, raised in an HTTP call: the builder's
      message, ELinkCancelled after Cancel, else what went wrong and
      where. }
    function Failure(E: Exception): Exception;
    { GET APath: the answer's JSON (raises with the builder's message). }
    function GetJson(const APath: string): TJSONObject;
    { POST APath with no body: the answer's JSON. }
    function PostJson(const APath: string): TJSONObject;
  public
    { A client for the builder at AHost:APort.
      @param(AClient  this program's name, e.g. 'BookManager on PC') }
    constructor Create(const AHost: string; APort: Integer; const AClient, AToken: string);
    { Frees. }
    destructor Destroy; override;
    { Stops the call running (from any thread): it raises ELinkCancelled.
      A download's .part file stays (the next try goes on from it). }
    procedure Cancel;
    { /info: the builder's JSON (the caller frees it). }
    function Info: TJSONObject;
    { Says this program is closing (POST /bye; paired only) - a phone's link
      panel closes. }
    procedure Bye;
    { Asks to pair: the builder shows a code. }
    procedure PairAsk;
    { Sends the code shown: the token (also kept in Token). }
    function PairConfirm(const ACode: string): string;
    { Pairs without a code: hands over ATicket, which the link site gave
      this program for that builder (uLinkSite's TLinkSite.Ticket, asked
      with the id of the builder's /info).
      @returns(the token, also kept in Token) }
    function PairTicket(const ATicket: string): string;
    { /space (the caller frees it). }
    function Space: TJSONObject;
    { /books (the caller frees it). }
    function Books: TJSONObject;
    { /status (the caller frees it). }
    function Status: TJSONObject;
    { /log from line AFrom (the caller frees it). }
    function Log(AFrom: Integer): TJSONObject;
    { Downloads the book APath (as /books gives it) to AFileName - going on
      from a .part file of an earlier try. }
    procedure Download(const APath, AFileName: string; const AProgress: TLinkProgress);
    { Sends AFileName as AKind ('book' / 'audio' / 'cover') into the folder
      ADir of its kind ('' = the folder itself; '/' between names).
      Checked first (/upload/check): refused there, nothing is sent; the
      same file (name and size) there already is not sent again unless
      AReplace (Skipped says so).
      @returns(where the builder put it, or has it) }
    function Upload(const AKind, AFileName, ADir: string; AReplace: Boolean; const AProgress: TLinkProgress): string;
    { The token from pairing. }
    property Token: string read FToken;
    { The last Upload sent nothing: the builder has that file already. }
    property Skipped: Boolean read FSkipped;
    { How long a call waits for the connection, ms (LINK_CONNECT_MS at
      first; a phone: LINK_CONNECT_PHONE_MS). }
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout;
    { The next Upload's place in its batch, '2/3' ('' = not said): the
      phone shows it with its progress. }
    property Batch: string read FBatch write FBatch;
    { How long a call waits for an answer, ms (60000 at first; a goodbye
      on closing: a few seconds). }
    property ReadTimeout: Integer read FReadTimeout write FReadTimeout;
  end;

  { A link call that did not work, with the builder's reason. }
  ELinkError = class(Exception);

  { A link call stopped by TLinkClient.Cancel. }
  ELinkCancelled = class(ELinkError);

{ The free space of the drive AFolder is on, bytes (-1 = not known). }
function LinkFreeSpace(const AFolder: string): Int64;

{ This machine's network's broadcast address, taken as a /24 ('192.168.1.255'
  for 192.168.1.118; '' when not known): the announcements go there as well
  as to 255.255.255.255, which some routers and phones pass unreliably
  (zip 357 - the Pixel was heard after 1.8 s once, 55 s the next time). On
  a larger network the address is an ordinary one and the copy is lost -
  harmless. Found by "connecting" a UDP socket (nothing is sent). }
function LinkNetworkBroadcast: string;

{ Says goodbye on the network: an announcement with "bye" (AApp, AName,
  AId, port 0) to 255.255.255.255, LinkBroadcastTargets and AHosts directly
  - a program that hears it drops this one at once (TLinkFinder.OnBye).
  Sent twice; returns at once. }
procedure LinkSayBye(const AApp, AName, AId: string; const AHosts: TArray<string>);

{ This machine's IPv4 addresses, space-separated (for the log: a computer
  with virtual adapters - Hyper-V, WSL, a VPN - may send its broadcasts out
  of one of those). }
function LinkLocalAddresses: string;

{ The broadcast addresses the announcements go to besides 255.255.255.255:
  LinkNetworkBroadcast and each local IPv4 address's x.y.z.255 (a /24
  taken), without loopback and link-local ones. A computer with virtual
  adapters sends 255.255.255.255 out of one of them (the owner's PC:
  BookManager heard its own beacon "from 192.168.239.1", a VMware
  adapter - zip 366); a copy to each network's own address reaches the
  real one too. }
function LinkBroadcastTargets: TArray<string>;

{ 'book', 'audio', 'cover' (a picture) or '' for a file name (by its
  extension). }
function LinkKindOf(const AFileName: string): string;

implementation

uses
  {$IFDEF MSWINDOWS} Winapi.Windows, {$ENDIF}
  // Android's RTL has no statvfs (declared below, from its libc: Posix.Base's
  // libc names the library)
  {$IF Defined(POSIX) and not Defined(ANDROID)} Posix.SysStatvfs, {$ENDIF}
  {$IFDEF ANDROID} Posix.Base, {$ENDIF}
  System.IOUtils, System.StrUtils, System.DateUtils, System.NetEncoding, System.Diagnostics,
  // the machine's addresses (LinkLocalAddresses)
  IdStack,
  // the transfers' buffers
  IdIOHandler, IdIOHandlerStack, IdTCPConnection;

const
  { Book files. }
  BOOK_EXTS: array[0..4] of string = ('.epub', '.mobi', '.prc', '.azw', '.azw3');
  { Audio files. }
  AUDIO_EXTS: array[0..8] of string = ('.m4b', '.m4a', '.aax', '.mp3', '.wav', '.flac', '.ogg', '.opus', '.aac');
  { Pictures (covers). }
  COVER_EXTS: array[0..4] of string = ('.jpg', '.jpeg', '.png', '.webp', '.gif');
  { Log lines kept for /log. }
  LOG_KEEP = 5000;

type
  { An upload's .part file: where it goes when whole, and how big. }
  TLinkPartStream = class(TBufferedFileStream)
  public
    { The .part file. }
    PartName: string;
    { The file it becomes. }
    FinalName: string;
    { 'book' or 'audio'. }
    Kind: string;
    { The size it must reach. }
    Size: Int64;
    { Whose upload (its OnUploadProgress). }
    Server: TLinkServer;
    { Its place in the sender's batch ('2/3'). }
    Batch: string;
    { Bytes written. }
    Done: Int64;
    { When the progress was last told (TThread.GetTickCount64). }
    LastTick: UInt64;
    { When the first bytes came (0 = none yet). }
    FirstTick: UInt64;
    { Time spent writing them to storage, ms (zip 370: the network or the
      storage - which holds a phone's uploads to ~12 MB/s?). }
    WriteMs: Double;
    { Writes, and tells the progress now and then. }
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

  { An upload refused: its body is read and dropped. }
  TLinkRefusedStream = class(TStream)
  public
    { Why. }
    Why: string;
    { Drops the bytes. }
    function Write(const Buffer; Count: Longint): Longint; override;
    { Nothing to read. }
    function Read(var Buffer; Count: Longint): Longint; override;
    { Always 0. }
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  { Says where the builder is every two seconds. }
  TLinkAnnouncer = class(TThread)
  private
    { Whose announcement. }
    FServer: TLinkServer;
  protected
    { Broadcasts until terminated. }
    procedure Execute; override;
  public
    { For AServer. }
    constructor Create(AServer: TLinkServer);
  end;

function TLinkRefusedStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := Count;
end;

function TLinkRefusedStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := 0;
end;

function TLinkRefusedStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := 0;
end;

{$IFDEF ANDROID}
type
  { bionic's struct statvfs (64-bit: every field 8 bytes, then
    __f_reserved[6]; the spare room is more than that, to be safe). }
  TAndroidStatVfs = record
    { Block size. }
    f_bsize: NativeUInt;
    { Fragment size (the unit of the counts). }
    f_frsize: NativeUInt;
    { Blocks in all. }
    f_blocks: NativeUInt;
    { Free blocks. }
    f_bfree: NativeUInt;
    { Free blocks an app may use. }
    f_bavail: NativeUInt;
    { Files in all. }
    f_files: NativeUInt;
    { Free file slots. }
    f_ffree: NativeUInt;
    { ... an app may use. }
    f_favail: NativeUInt;
    { The file system's id. }
    f_fsid: NativeUInt;
    { Mount flags. }
    f_flag: NativeUInt;
    { Longest name. }
    f_namemax: NativeUInt;
    { Reserved (and room to spare). }
    f_spare: array[0..15] of UInt32;
  end;

{ libc's statvfs (Android's RTL declares none, zip 355). }
function android_statvfs(APath: MarshaledAString; var ABuf: TAndroidStatVfs): Integer; cdecl;
  external libc name 'statvfs';
{$ENDIF}

function LinkFreeSpace(const AFolder: string): Int64;
{$IF Defined(MSWINDOWS)}
var
  Free, Total: Int64;
begin
  Result := -1;
  if GetDiskFreeSpaceEx(PChar(IncludeTrailingPathDelimiter(AFolder)), Free, Total, nil) then
    Result := Free;
end;
{$ELSEIF Defined(ANDROID)}
var
  S: TAndroidStatVfs;
  M: TMarshaller;
begin
  Result := -1;
  FillChar(S, SizeOf(S), 0);
  if android_statvfs(MarshaledAString(M.AsAnsi(AFolder, CP_UTF8).ToPointer), S) = 0 then
    Result := Int64(S.f_bavail) * Int64(S.f_frsize);
end;
{$ELSE}
{$IFDEF POSIX}
var
  S: _statvfs;
  M: TMarshaller;
begin
  Result := -1;
  if statvfs(MarshaledAString(M.AsAnsi(AFolder, CP_UTF8).ToPointer), S) = 0 then
    Result := Int64(S.f_bavail) * Int64(S.f_frsize);
end;
{$ELSE}
begin
  Result := -1;
end;
{$ENDIF}
{$ENDIF}

function LinkNetworkBroadcast: string;
var
  Udp: TIdUDPClient;
  IP: string;
  Parts: TArray<string>;
begin
  Result := '';
  Udp := TIdUDPClient.Create(nil);
  try
    try
      // TEST-NET-1: never reached - the route to it says which address
      // the network is on
      Udp.Host := '192.0.2.1';
      Udp.Port := 9;
      Udp.IPVersion := Id_IPv4;
      Udp.Connect;
      IP := Udp.Binding.IP;
      Parts := IP.Split(['.']);
      if (Length(Parts) = 4) and (IP <> '0.0.0.0') and not IP.StartsWith('127.') then
        Result := Format('%s.%s.%s.255', [Parts[0], Parts[1], Parts[2]]);
    except
      // no network now
    end;
  finally
    Udp.Free;
  end;
end;

function LinkLocalAddresses: string;
var
  L: TIdStackLocalAddressList;
  I: Integer;
begin
  Result := '';
  TIdStack.IncUsage;
  try
    try
      L := TIdStackLocalAddressList.Create;
      try
        GStack.GetLocalAddressList(L);
        for I := 0 to L.Count - 1 do
          if L[I].IPVersion = Id_IPv4 then
            Result := Trim(Result + ' ' + L[I].IPAddress);
      finally
        L.Free;
      end;
    except
      on E: Exception do
        Result := '(not known: ' + E.Message + ')';
    end;
  finally
    TIdStack.DecUsage;
  end;
end;

procedure LinkSayBye(const AApp, AName, AId: string; const AHosts: TArray<string>);
var
  O: TJSONObject;
  Text, Host: string;
  Udp: TIdUDPClient;
  I: Integer;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('link', TJSONNumber.Create(LINK_VERSION));
    O.AddPair('app', AApp);
    O.AddPair('name', AName);
    O.AddPair('id', AId);
    O.AddPair('port', TJSONNumber.Create(0));
    O.AddPair('bye', TJSONBool.Create(True));
    Text := O.ToJSON;
  finally
    O.Free;
  end;
  Udp := TIdUDPClient.Create(nil);
  try
    Udp.BroadcastEnabled := True;
    // twice: a datagram may be lost
    for I := 1 to 2 do
    begin
      try
        Udp.Broadcast(Text, LINK_DISCOVERY_PORT, '255.255.255.255', IndyTextEncoding_UTF8);
      except
        // no network
      end;
      for Host in LinkBroadcastTargets + AHosts do
      try
        Udp.Send(Host, LINK_DISCOVERY_PORT, Text, IndyTextEncoding_UTF8);
      except
        // next
      end;
    end;
  finally
    Udp.Free;
  end;
end;

function LinkBroadcastTargets: TArray<string>;
var
  A, Net: string;
  Parts: TArray<string>;
begin
  Result := nil;
  Net := LinkNetworkBroadcast;
  if Net <> '' then
    Result := [Net];
  for A in LinkLocalAddresses.Split([' ']) do
  begin
    Parts := A.Split(['.']);
    if (Length(Parts) <> 4) or (Parts[0] = '127') or ((Parts[0] = '169') and (Parts[1] = '254')) then
      Continue;
    Net := Format('%s.%s.%s.255', [Parts[0], Parts[1], Parts[2]]);
    if IndexStr(Net, Result) < 0 then
      Result := Result + [Net];
  end;
end;

function LinkKindOf(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if IndexText(Ext, BOOK_EXTS) >= 0 then
    Result := 'book'
  else if IndexText(Ext, AUDIO_EXTS) >= 0 then
    Result := 'audio'
  else if IndexText(Ext, COVER_EXTS) >= 0 then
    Result := 'cover'
  else
    Result := '';
end;

{ A file or folder name made safe: no folders, no '..', no characters
  file systems refuse ('' when nothing is left). }
function SafeName(const AName: string): string;
var
  C: Char;
begin
  Result := '';
  for C in AName do
    if CharInSet(C, ['/', '\', ':', '*', '?', '"', '<', '>', '|']) or (C < ' ') then
      Result := Result + '_'
    else
      Result := Result + C;
  Result := Trim(Result);
  if (Result = '.') or (Result = '..') then
    Result := '';
end;

{ A sub folder path made safe ('a/b' -> 'a' + delimiter + 'b'). }
function SafeDir(const ADir: string): string;
var
  Part, P: string;
begin
  Result := '';
  for Part in ADir.Replace('\', '/').Split(['/']) do
  begin
    P := SafeName(Part);
    if P <> '' then
      Result := IncludeTrailingPathDelimiter(Result) + P;
  end;
  if (Result <> '') and (Result[1] = PathDelim) then
    Delete(Result, 1, 1);
end;

{ The query value AName of a call: Indy's Params, else read from the query
  itself (a POST with no form body may leave Params empty). }
function QueryValue(ARequestInfo: TIdHTTPRequestInfo; const AName: string): string;
var
  Pair: string;
  P: Integer;
begin
  Result := ARequestInfo.Params.Values[AName];
  if Result <> '' then
    Exit;
  for Pair in ARequestInfo.QueryParams.Split(['&']) do
  begin
    P := Pos('=', Pair);
    if (P > 0) and SameText(Copy(Pair, 1, P - 1), AName) then
      Exit(TNetEncoding.URL.Decode(Copy(Pair, P + 1, MaxInt)));
  end;
end;

{ A JSON error. }
procedure SendError(AResponseInfo: TIdHTTPResponseInfo; ACode: Integer; const AText: string);
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('ok', TJSONBool.Create(False));
    O.AddPair('error', AText);
    AResponseInfo.ResponseNo := ACode;
    AResponseInfo.ContentType := 'application/json; charset=utf-8';
    AResponseInfo.ContentText := O.ToJSON;
  finally
    O.Free;
  end;
end;

{ A JSON answer (AJson freed). }
procedure SendJson(AResponseInfo: TIdHTTPResponseInfo; AJson: TJSONObject);
begin
  try
    AResponseInfo.ResponseNo := 200;
    AResponseInfo.ContentType := 'application/json; charset=utf-8';
    AResponseInfo.ContentText := AJson.ToJSON;
  finally
    AJson.Free;
  end;
end;

function TLinkPartStream.Write(const Buffer; Count: Longint): Longint;
const
  { At most this often, ms. }
  EVERY_MS = 500;
var
  Tick: UInt64;
  Name, B: string;
  D, T: Int64;
  Event: TLinkUploadProgressEvent;
  W: TStopwatch;
begin
  if FirstTick = 0 then
    FirstTick := TThread.GetTickCount64;
  W := TStopwatch.StartNew;
  Result := inherited Write(Buffer, Count);
  WriteMs := WriteMs + W.Elapsed.TotalMilliseconds;
  Inc(Done, Result);
  if (Server = nil) or not Assigned(Server.FOnUploadProgress) then
    Exit;
  Tick := TThread.GetTickCount64;
  if (Tick - LastTick < EVERY_MS) and (Done < Size) then
    Exit;
  LastTick := Tick;
  Name := ExtractFileName(FinalName);
  B := Batch;
  D := Done;
  T := Size;
  Event := Server.FOnUploadProgress;
  TThread.Queue(nil,
    procedure
    begin
      Event(Name, B, D, T);
    end);
end;

{ TLinkBeacon }

constructor TLinkBeacon.Create(const AApp, AName, AId: string);
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('link', TJSONNumber.Create(LINK_VERSION));
    O.AddPair('app', AApp);
    O.AddPair('name', AName);
    O.AddPair('id', AId);
    O.AddPair('port', TJSONNumber.Create(0));
    FText := O.ToJSON;
  finally
    O.Free;
  end;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TLinkBeacon.Execute;
var
  Udp: TIdUDPClient;
  I, Round_: Integer;
  Net: string;
  Nets: TArray<string>;
begin
  Udp := TIdUDPClient.Create(nil);
  try
    Udp.BroadcastEnabled := True;
    Round_ := 0;
    Nets := nil;
    while not Terminated do
    begin
      // the networks' own broadcast addresses, looked at every 30 s
      // (Wi-Fi changed)
      if Round_ mod 15 = 0 then
        Nets := LinkBroadcastTargets;
      Inc(Round_);
      try
        Udp.Broadcast(FText, LINK_DISCOVERY_PORT, '255.255.255.255', IndyTextEncoding_UTF8);
      except
        // no network now: next time
      end;
      for Net in Nets do
      try
        Udp.Broadcast(FText, LINK_DISCOVERY_PORT, Net, IndyTextEncoding_UTF8);
      except
        // next time
      end;
      for I := 1 to 20 do
        if not Terminated then
          Sleep(100);
    end;
  finally
    Udp.Free;
  end;
end;

{ TLinkAnnouncer }

constructor TLinkAnnouncer.Create(AServer: TLinkServer);
begin
  FServer := AServer;
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TLinkAnnouncer.Execute;
var
  Udp: TIdUDPClient;
  I, Round_: Integer;
  Host, Net: string;
  Nets: TArray<string>;
begin
  Udp := TIdUDPClient.Create(nil);
  try
    Udp.BroadcastEnabled := True;
    Round_ := 0;
    Nets := nil;
    while not Terminated do
    begin
      // the networks' own broadcast addresses, looked at every 30 s
      // (Wi-Fi changed)
      if Round_ mod 15 = 0 then
        Nets := LinkBroadcastTargets;
      Inc(Round_);
      if FServer.Announcing then
      begin
        try
          Udp.Broadcast(FServer.Announcement, LINK_DISCOVERY_PORT, '255.255.255.255', IndyTextEncoding_UTF8);
        except
          // no network now (asleep, cable out): next time
        end;
        for Net in Nets do
        try
          Udp.Broadcast(FServer.Announcement, LINK_DISCOVERY_PORT, Net, IndyTextEncoding_UTF8);
        except
          // next time
        end;
        // and straight to each BookManager heard (SetDirect)
        for Host in FServer.Direct do
        try
          Udp.Send(Host, LINK_DISCOVERY_PORT, FServer.Announcement, IndyTextEncoding_UTF8);
        except
          // gone: next time
        end;
      end;
      for I := 1 to 20 do
        if not Terminated then
          Sleep(100);
    end;
  finally
    Udp.Free;
  end;
end;

{ TLinkServer }

constructor TLinkServer.Create(const AApp, AName, AId: string);
begin
  inherited Create;
  FApp := AApp;
  FName := AName;
  FId := AId;
  FReserve := LINK_RESERVE;
  FAnnouncing := True;
  FLock := TCriticalSection.Create;
  FLog := TStringList.Create;
  FTokens := TStringList.Create;
  FStatus := '{"busy":false}';
end;

destructor TLinkServer.Destroy;
begin
  Stop;
  FTokens.Free;
  FLog.Free;
  FLock.Free;
  inherited;
end;

function TLinkServer.Start: string;
var
  P: Integer;
  B: TIdSocketHandle;
begin
  Stop;
  FHttp := TIdHTTPServer.Create(nil);
  FHttp.OnCommandGet := CommandGet;
  FHttp.OnCreatePostStream := CreatePostStream;
  FHttp.OnConnect := Connected;
  FHttp.ParseParams := True;
  FHttp.KeepAlive := False;
  for P := LINK_HTTP_PORT to LINK_HTTP_PORT + 9 do
  begin
    try
      FHttp.Bindings.Clear;
      B := FHttp.Bindings.Add;
      B.IP := '0.0.0.0';
      B.Port := P;
      B.IPVersion := Id_IPv4;
      FHttp.Active := True;
      FPort := P;
      Break;
    except
      FHttp.Active := False;
    end;
  end;
  if FPort = 0 then
  begin
    FreeAndNil(FHttp);
    Exit(Format('link: no free port from %d to %d - BookManager and EpubReader cannot connect',
      [LINK_HTTP_PORT, LINK_HTTP_PORT + 9]));
  end;
  FAnnouncer := TLinkAnnouncer.Create(Self);
  Result := Format('link: BookManager and EpubReader can connect (port %d; found by itself on the network, ' +
    'UDP %d)', [FPort, LINK_DISCOVERY_PORT]);
end;

procedure TLinkServer.Stop;
begin
  if FAnnouncer <> nil then
  begin
    FAnnouncer.Terminate;
    FAnnouncer.WaitFor;
    FreeAndNil(FAnnouncer);
  end;
  if FHttp <> nil then
  begin
    try
      FHttp.Active := False;
    except
      // stopping anyway
    end;
    FreeAndNil(FHttp);
  end;
  FPort := 0;
end;

procedure TLinkServer.Connected(AContext: TIdContext);
begin
  try
    AContext.Connection.IOHandler.RecvBufferSize := LINK_BUFFER;
    AContext.Connection.IOHandler.SendBufferSize := LINK_BUFFER;
  except
    // Indy's defaults
  end;
end;

procedure TLinkServer.SetDirect(const AHosts: TArray<string>);
begin
  FLock.Enter;
  try
    FDirect := Copy(AHosts);
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.Direct: TArray<string>;
begin
  FLock.Enter;
  try
    Result := Copy(FDirect);
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.Announcement: string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.AddPair('link', TJSONNumber.Create(LINK_VERSION));
    O.AddPair('app', FApp);
    O.AddPair('name', FName);
    O.AddPair('id', FId);
    O.AddPair('port', TJSONNumber.Create(FPort));
    Result := O.ToJSON;
  finally
    O.Free;
  end;
end;

procedure TLinkServer.SetFolders(const ABooks, AAudio, ACovers: string; const AOutputs: TArray<string>);
begin
  FLock.Enter;
  try
    FBooks := ABooks;
    FAudio := AAudio;
    FCovers := ACovers;
    FOutputs := Copy(AOutputs);
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.SetStatus(const AJson: string);
begin
  FLock.Enter;
  try
    FStatus := AJson;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.AddLog(const ALine: string);
begin
  FLock.Enter;
  try
    FLog.Add(ALine);
    while FLog.Count > LOG_KEEP do
    begin
      FLog.Delete(0);
      Inc(FLogBase);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.SetTokens(const AText: string);
begin
  FLock.Enter;
  try
    FTokens.Text := AText;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.TokensText: string;
begin
  FLock.Enter;
  try
    Result := FTokens.Text;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.GetTakesTickets: Boolean;
begin
  FLock.Enter;
  try
    Result := FTakesTickets;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.SetTakesTickets(AValue: Boolean);
begin
  FLock.Enter;
  try
    FTakesTickets := AValue;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkServer.RefusePair;
begin
  FLock.Enter;
  try
    FPairCode := '';
    FPairRefused := True;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.TokenOk(const AToken: string): Boolean;
begin
  if Length(AToken) < 16 then
    Exit(False);
  FLock.Enter;
  try
    Result := FTokens.IndexOfName(AToken) >= 0;
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.UploadTarget(AHeaders: TIdHeaderList; out AFolder: string; out ASize: Int64;
  out AWhy: string): string;
var
  Kind, Name, Dir, Base, Folder: string;
  Free: Int64;
  N: Integer;
begin
  Result := '';
  AFolder := '';
  ASize := StrToInt64Def(AHeaders.Values['X-Link-Size'], -1);
  AWhy := '';
  if not TokenOk(AHeaders.Values['X-Link-Token']) then
  begin
    AWhy := 'not paired';
    Exit;
  end;
  Kind := LowerCase(AHeaders.Values['X-Link-Kind']);
  Name := SafeName(TNetEncoding.URL.Decode(AHeaders.Values['X-Link-Name']));
  Dir := SafeDir(TNetEncoding.URL.Decode(AHeaders.Values['X-Link-Dir']));
  if Name = '' then
  begin
    AWhy := 'no file name';
    Exit;
  end;
  if ASize < 0 then
  begin
    AWhy := 'no size given';
    Exit;
  end;
  FLock.Enter;
  try
    if Kind = 'book' then
      Base := FBooks
    else if Kind = 'audio' then
      Base := FAudio
    else if Kind = 'cover' then
      Base := FCovers
    else
      Base := '';
  finally
    FLock.Leave;
  end;
  if Base = '' then
  begin
    // a phone takes books only (no folder for audio or pictures)
    if (Kind = 'book') or (Kind = 'audio') or (Kind = 'cover') then
      AWhy := Format('%s takes no %s files', [FApp, Kind])
    else
      AWhy := 'not a book, audio or picture file';
    Exit;
  end;
  if LinkKindOf(Name) <> Kind then
  begin
    AWhy := Format('%s is not a %s file', [Name, Kind]);
    Exit;
  end;
  Folder := Base;
  if Dir <> '' then
    Folder := TPath.Combine(Base, Dir);
  ForceDirectories(Folder);
  // never fills the drive the builder works on
  Free := LinkFreeSpace(Folder);
  if (Free >= 0) and (ASize + FReserve > Free) then
  begin
    AWhy := Format('not enough space: %s needs %.1f GB, %.1f GB free and %.1f GB kept free on %s',
      [Name, ASize / 1E9, Free / 1E9, FReserve / 1E9, FApp]);
    Exit;
  end;
  // the same file there already: kept; another of that name: numbered
  Result := TPath.Combine(Folder, Name);
  N := 1;
  while FileExists(Result) and (TFile.GetSize(Result) <> ASize) do
  begin
    Inc(N);
    Result := TPath.Combine(Folder, Format('%s (%d)%s', [ChangeFileExt(Name, ''), N, ExtractFileExt(Name)]));
  end;
  AFolder := Folder;
end;

procedure TLinkServer.CreatePostStream(AContext: TIdContext; AHeaders: TIdHeaderList; var VPostStream: TStream);
var
  Target, Folder, Why: string;
  Size: Int64;
  S: TLinkPartStream;
  R: TLinkRefusedStream;
begin
  // only an upload's body goes to a file (X-Link-Upload: /upload/check
  // sends the same headers with no body); other calls are small
  if AHeaders.Values['X-Link-Upload'] <> '1' then
    Exit;
  Target := UploadTarget(AHeaders, Folder, Size, Why);
  if Target = '' then
  begin
    R := TLinkRefusedStream.Create;
    R.Why := Why;
    VPostStream := R;
    Exit;
  end;
  try
    // written a megabyte at a time (a phone's storage is slow with small
    // writes)
    S := TLinkPartStream.Create(Target + '.part', fmCreate, LINK_BUFFER);
    S.PartName := Target + '.part';
    S.FinalName := Target;
    S.Kind := LowerCase(AHeaders.Values['X-Link-Kind']);
    S.Size := Size;
    S.Server := Self;
    S.Batch := AHeaders.Values['X-Link-Batch'];
    VPostStream := S;
  except
    on E: Exception do
    begin
      R := TLinkRefusedStream.Create;
      R.Why := 'cannot write ' + Target + ': ' + E.Message;
      VPostStream := R;
    end;
  end;
end;

function TLinkServer.MayGet(const APath: string): Boolean;
var
  F, Full: string;
begin
  Result := False;
  if not SameText(ExtractFileExt(APath), '.epub') or not FileExists(APath) then
    Exit;
  Full := ExpandFileName(APath);
  FLock.Enter;
  try
    for F in FOutputs do
      if (F <> '') and StartsText(IncludeTrailingPathDelimiter(ExpandFileName(F)), Full) then
        Exit(True);
  finally
    FLock.Leave;
  end;
end;

function TLinkServer.BooksJson: string;
var
  Root: TJSONObject;
  A: TJSONArray;
  O: TJSONObject;
  F, Folder: string;
  Folders: TArray<string>;
  Seen: TStringList;
begin
  FLock.Enter;
  try
    Folders := Copy(FOutputs);
  finally
    FLock.Leave;
  end;
  Root := TJSONObject.Create;
  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    A := TJSONArray.Create;
    Root.AddPair('books', A);
    for Folder in Folders do
      if (Folder <> '') and TDirectory.Exists(Folder) then
        for F in TDirectory.GetFiles(Folder, '*', TSearchOption.soAllDirectories) do
        begin
          if not SameText(ExtractFileExt(F), '.epub') or (Seen.IndexOf(ExpandFileName(F)) >= 0) then
            Continue;
          Seen.Add(ExpandFileName(F));
          O := TJSONObject.Create;
          O.AddPair('path', F);
          O.AddPair('name', ExtractFileName(F));
          O.AddPair('folder', Folder);
          O.AddPair('size', TJSONNumber.Create(TFile.GetSize(F)));
          O.AddPair('modified', DateToISO8601(TFile.GetLastWriteTime(F), False));
          A.AddElement(O);
        end;
    Result := Root.ToJSON;
  finally
    Seen.Free;
    Root.Free;
  end;
end;

procedure TLinkServer.CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  Doc, Token, Client, Code, Path, Kind, Final: string;
  O, B: TJSONObject;
  A: TJSONArray;
  From, I, Last: Integer;
  Offset, Size: Int64;
  F: TFileStream;
  Part: TLinkPartStream;
  Folder, Why, BooksDir, AudioDir: string;
  Ended: Boolean;
  Ticket, Named: string;
  TicketOk: TLinkTicketCheck;
  Good: Boolean;
  Said: string;
  RequestEvent: TLinkRequestEvent;
  Took, WriteSecs: Double;
  Stats: string;
  ByeEvent: TLinkRequestEvent;
  ByeName: string;
  FlushWatch: TStopwatch;
  CodeEvent: TLinkPairCodeEvent;
  EndedEvent: TLinkPairEndedEvent;
  PairedEvent: TLinkPairedEvent;
  ReceivedEvent: TLinkReceivedEvent;
begin
  Doc := LowerCase(ARequestInfo.Document);
  Token := ARequestInfo.RawHeaders.Values['X-Link-Token'];
  // every call, for the debug log (a phone: did it reach us at all?)
  // (the events below are copied before they are queued: the server may
  // be freed before the queue runs - a phone's link ends with Done while
  // BookManager's calls are on their way; reading the freed server's
  // fields was an access violation, zip 360)
  if Assigned(FOnRequest) then
  begin
    Said := Format('%s %s from %s', [ARequestInfo.Command, ARequestInfo.Document, ARequestInfo.RemoteIP]);
    RequestEvent := FOnRequest;
    TThread.Queue(nil,
      procedure
      begin
        RequestEvent(Said);
      end);
  end;
  try
    // who it is: no token needed
    if Doc = '/info' then
    begin
      O := TJSONObject.Create;
      O.AddPair('link', TJSONNumber.Create(LINK_VERSION));
      O.AddPair('app', FApp);
      O.AddPair('name', FName);
      O.AddPair('id', FId);
      O.AddPair('paired', TJSONBool.Create(TokenOk(Token)));
      // it takes a ticket of the link site in place of the code
      O.AddPair('ticket', TJSONBool.Create(Assigned(FTicketCheck) and TakesTickets));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    // pairing: the builder shows a code, the program sends it back
    if Doc = '/pair' then
    begin
      Client := Trim(QueryValue(ARequestInfo, 'client'));
      if Client = '' then
        Client := ARequestInfo.RemoteIP;
      FLock.Enter;
      try
        FPairCode := Format('%.6d', [Random(1000000)]);
        FPairClient := Client;
        FPairUntil := IncMinute(Now, LINK_PAIR_MINUTES);
        FPairWrong := 0;
        FPairRefused := False;
        Code := FPairCode;
      finally
        FLock.Leave;
      end;
      if Assigned(FOnPairCode) then
      begin
        CodeEvent := FOnPairCode;
        TThread.Queue(nil,
          procedure
          begin
            CodeEvent(Client, Code);
          end);
      end;
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('message', 'Type the code ' + FApp + ' shows');
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/pair/confirm' then
    begin
      Client := Trim(QueryValue(ARequestInfo, 'client'));
      Code := Trim(QueryValue(ARequestInfo, 'code'));
      Ended := False;
      FLock.Enter;
      try
        if FPairRefused then
          Why := 'the connection was refused on ' + FApp
        else if (FPairCode = '') or (Now > FPairUntil) then
        begin
          FPairCode := '';
          Why := 'no code is offered now: ask again';
        end
        else if Code <> FPairCode then
        begin
          Inc(FPairWrong);
          Why := 'wrong code';
          if FPairWrong >= 5 then
          begin
            FPairCode := '';
            Ended := True;
            Why := 'wrong code five times: ask again';
            if Client = '' then
              Client := FPairClient;
          end;
        end
        else
        begin
          Why := '';
          FPairCode := '';
          Token := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '').ToLower;
          if Client = '' then
            Client := FPairClient;
          FTokens.Add(Token + '=' + Client);
        end;
      finally
        FLock.Leave;
      end;
      if Ended and Assigned(FOnPairEnded) then
      begin
        EndedEvent := FOnPairEnded;
        if Assigned(EndedEvent) then
          TThread.Queue(nil,
            procedure
            begin
              EndedEvent(Client, 'wrong code five times');
            end);
      end;
      if Why <> '' then
      begin
        SendError(AResponseInfo, 403, Why);
        Exit;
      end;
      if Assigned(FOnPaired) then
      begin
        PairedEvent := FOnPaired;
        if Assigned(PairedEvent) then
          TThread.Queue(nil,
            procedure
            begin
              PairedEvent(Client, Token);
            end);
      end;
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('token', Token);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    // pairing without the code: a ticket of the link site, which says
    // whether the program is one of the same account's
    if Doc = '/pair/ticket' then
    begin
      TicketOk := FTicketCheck;
      if not Assigned(TicketOk) or not TakesTickets then
      begin
        SendError(AResponseInfo, 404, FApp + ' takes no tickets: pair with the code');
        Exit;
      end;
      Client := Trim(QueryValue(ARequestInfo, 'client'));
      Ticket := Trim(QueryValue(ARequestInfo, 'ticket'));
      // each ticket looked at is a call to the site: not without end
      FLock.Enter;
      try
        if SecondsBetween(Now, FTicketSince) >= 60 then
        begin
          FTicketSince := Now;
          FTicketWrong := 0;
        end;
        Ended := FTicketWrong >= LINK_TICKET_TRIES;
      finally
        FLock.Leave;
      end;
      if Ended then
      begin
        SendError(AResponseInfo, 429, 'too many tickets refused: wait a minute');
        Exit;
      end;
      Why := '';
      Named := '';
      Good := False;
      if Ticket <> '' then
        try
          Good := TicketOk(Ticket, Named, Why);
        except
          on E: Exception do
          begin
            Good := False;
            Why := E.Message;
          end;
        end;
      if not Good then
      begin
        FLock.Enter;
        try
          Inc(FTicketWrong);
        finally
          FLock.Leave;
        end;
        if Why = '' then
          Why := 'the ticket is not good';
        SendError(AResponseInfo, 403, Why);
        Exit;
      end;
      if Client = '' then
        Client := Named;
      if Client = '' then
        Client := ARequestInfo.RemoteIP;
      Token := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '').ToLower;
      FLock.Enter;
      try
        FTokens.Add(Token + '=' + Client);
      finally
        FLock.Leave;
      end;
      if Assigned(FOnPaired) then
      begin
        PairedEvent := FOnPaired;
        if Assigned(PairedEvent) then
          TThread.Queue(nil,
            procedure
            begin
              PairedEvent(Client, Token);
            end);
      end;
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('token', Token);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    // everything else: paired programs only
    if not TokenOk(Token) then
    begin
      SendError(AResponseInfo, 401, 'not paired - pair with this ' + FApp + ' first');
      Exit;
    end;
    if Doc = '/space' then
    begin
      FLock.Enter;
      try
        BooksDir := FBooks;
        AudioDir := FAudio;
      finally
        FLock.Leave;
      end;
      O := TJSONObject.Create;
      B := TJSONObject.Create;
      B.AddPair('folder', BooksDir);
      B.AddPair('free', TJSONNumber.Create(LinkFreeSpace(BooksDir)));
      O.AddPair('books', B);
      B := TJSONObject.Create;
      B.AddPair('folder', AudioDir);
      B.AddPair('free', TJSONNumber.Create(LinkFreeSpace(AudioDir)));
      O.AddPair('audio', B);
      O.AddPair('reserve', TJSONNumber.Create(FReserve));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/books' then
    begin
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := BooksJson;
      Exit;
    end;
    if Doc = '/book' then
    begin
      Path := QueryValue(ARequestInfo, 'path');
      Offset := StrToInt64Def(QueryValue(ARequestInfo, 'offset'), 0);
      if not MayGet(Path) then
      begin
        SendError(AResponseInfo, 404, 'no such book');
        Exit;
      end;
      F := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
      Size := F.Size;
      if (Offset < 0) or (Offset > Size) then
        Offset := 0;
      F.Position := Offset;
      AResponseInfo.ResponseNo := 200;
      AResponseInfo.ContentType := 'application/epub+zip';
      AResponseInfo.CustomHeaders.Values['X-Link-Size'] := IntToStr(Size);
      AResponseInfo.CustomHeaders.Values['X-Link-Offset'] := IntToStr(Offset);
      AResponseInfo.ContentStream := F;
      AResponseInfo.ContentLength := Size - Offset;
      AResponseInfo.FreeContentStream := True;
      Exit;
    end;
    if Doc = '/upload/check' then
    begin
      Final := UploadTarget(ARequestInfo.RawHeaders, Folder, Size, Why);
      if Final = '' then
      begin
        SendError(AResponseInfo, 507, Why);
        Exit;
      end;
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('file', Final);
      O.AddPair('there', TJSONBool.Create(FileExists(Final)));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/upload' then
    begin
      if ARequestInfo.PostStream is TLinkRefusedStream then
      begin
        SendError(AResponseInfo, 507, TLinkRefusedStream(ARequestInfo.PostStream).Why);
        Exit;
      end;
      if not (ARequestInfo.PostStream is TLinkPartStream) then
      begin
        SendError(AResponseInfo, 400, 'no file sent');
        Exit;
      end;
      Part := TLinkPartStream(ARequestInfo.PostStream);
      Size := Part.Size;
      Final := Part.FinalName;
      Path := Part.PartName;
      Kind := Part.Kind;
      if Part.Seek(0, soEnd) <> Size then
      begin
        ARequestInfo.PostStream := nil;
        Part.Free;
        TFile.Delete(Path);
        SendError(AResponseInfo, 400, 'the file did not arrive whole');
        Exit;
      end;
      // for the log: how long the body took to come, and how much of that
      // was writing it (the rest is the network)
      Took := (TThread.GetTickCount64 - Part.FirstTick) / 1000;
      WriteSecs := Part.WriteMs / 1000;
      ARequestInfo.PostStream := nil;
      FlushWatch := TStopwatch.StartNew;
      Part.Free;
      WriteSecs := WriteSecs + FlushWatch.Elapsed.TotalSeconds;
      if Assigned(FOnRequest) and (Took > 0) then
      begin
        // (its own variable: Said is captured by the call's first line,
        // which may not have run yet)
        Stats := Format('upload of %s: %.1f MB in %.1f s (%.1f MB/s); writing it took %.1f s of that (%.0f %%)',
          [ExtractFileName(Final), Size / 1E6, Took, Size / 1E6 / Took, WriteSecs, WriteSecs * 100 / Took]);
        RequestEvent := FOnRequest;
        TThread.Queue(nil,
          procedure
          begin
            RequestEvent(Stats);
          end);
      end;
      if FileExists(Final) then
        // the same file (same name and size): the new copy replaces it
        TFile.Delete(Final);
      TFile.Move(Path, Final);
      if Assigned(FOnReceived) then
      begin
        ReceivedEvent := FOnReceived;
        if Assigned(ReceivedEvent) then
          TThread.Queue(nil,
            procedure
            begin
              ReceivedEvent(Kind, Final);
            end);
      end;
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      O.AddPair('file', Final);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/bye' then
    begin
      // a paired program is closing: its name, for the event
      FLock.Enter;
      try
        Named := FTokens.Values[Token];
      finally
        FLock.Leave;
      end;
      // its own variables: RequestEvent and Said are captured by the
      // call's first queued line (a captured variable is shared)
      ByeEvent := FOnBye;
      ByeName := Named;
      if Assigned(ByeEvent) then
        TThread.Queue(nil,
          procedure
          begin
            ByeEvent(ByeName);
          end);
      O := TJSONObject.Create;
      O.AddPair('ok', TJSONBool.Create(True));
      SendJson(AResponseInfo, O);
      Exit;
    end;
    if Doc = '/status' then
    begin
      FLock.Enter;
      try
        AResponseInfo.ContentText := FStatus;
      finally
        FLock.Leave;
      end;
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      Exit;
    end;
    if Doc = '/log' then
    begin
      From := StrToIntDef(QueryValue(ARequestInfo, 'from'), 0);
      O := TJSONObject.Create;
      A := TJSONArray.Create;
      FLock.Enter;
      try
        if From < FLogBase then
          From := FLogBase;
        Last := FLogBase + FLog.Count;
        for I := From to Last - 1 do
          A.Add(FLog[I - FLogBase]);
      finally
        FLock.Leave;
      end;
      O.AddPair('from', TJSONNumber.Create(From));
      O.AddPair('next', TJSONNumber.Create(Last));
      O.AddPair('lines', A);
      SendJson(AResponseInfo, O);
      Exit;
    end;
    SendError(AResponseInfo, 404, 'no such call: ' + ARequestInfo.Document);
  except
    on E: Exception do
      SendError(AResponseInfo, 500, E.Message);
  end;
end;

{ TLinkFinder }

constructor TLinkFinder.Create;
var
  B: TIdSocketHandle;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FUdp := TIdUDPServer.Create(nil);
  FUdp.ThreadedEvent := True;
  FUdp.OnUDPRead := UdpRead;
  FUdp.BroadcastEnabled := True;
  B := FUdp.Bindings.Add;
  B.IP := '0.0.0.0';
  B.Port := LINK_DISCOVERY_PORT;
  B.IPVersion := Id_IPv4;
  // the reader and BookManager on one machine both listen
  B.ReuseSocket := rsTrue;
  try
    FUdp.Active := True;
    FState := Format('listening on UDP %d', [LINK_DISCOVERY_PORT]);
  except
    // the port taken without sharing: nothing is heard (a typed address
    // still works)
    on E: Exception do
      FState := Format('NOT listening on UDP %d: %s', [LINK_DISCOVERY_PORT, E.Message]);
  end;
end;

destructor TLinkFinder.Destroy;
begin
  try
    FUdp.Active := False;
  except
    // ending anyway
  end;
  FUdp.Free;
  FLock.Free;
  inherited;
end;

procedure TLinkFinder.UdpRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
var
  V: TJSONValue;
  P: TLinkPeer;
  ChangeEvent: TNotifyEvent;
  HeardEvent: TLinkRequestEvent;
  ByeEvent: TLinkRequestEvent;
  Said: string;
  I: Integer;
  Changed, Bye: Boolean;
begin
  V := TJSONObject.ParseJSONValue(BytesToString(AData, IndyTextEncoding_UTF8));
  try
    if not (V is TJSONObject) then
      Exit;
    P := Default(TLinkPeer);
    if not TJSONObject(V).TryGetValue<string>('id', P.Id) or (P.Id = '') then
      Exit;
    TJSONObject(V).TryGetValue<string>('app', P.App);
    TJSONObject(V).TryGetValue<string>('name', P.Name);
    TJSONObject(V).TryGetValue<Integer>('port', P.Port);
    Bye := False;
    TJSONObject(V).TryGetValue<Boolean>('bye', Bye);
    P.Host := ABinding.PeerIP;
    P.Seen := Now;
    // a BookManager has no server (port 0): heard all the same (a phone
    // answers it directly)
    if (P.Port = 0) and (P.App <> LINK_APP_MANAGER) then
      Exit;
  finally
    V.Free;
  end;
  // goodbye: out of the list at once, and said
  if Bye then
  begin
    FLock.Enter;
    try
      for I := High(FPeers) downto 0 do
        if FPeers[I].Id = P.Id then
          Delete(FPeers, I, 1);
    finally
      FLock.Leave;
    end;
    ByeEvent := FOnBye;
    if Assigned(ByeEvent) then
    begin
      Said := Format('%s "%s"', [P.App, P.Name]);
      TThread.Queue(nil,
        procedure
        begin
          ByeEvent(Said);
        end);
    end;
    ChangeEvent := FOnChange;
    if Assigned(ChangeEvent) then
      TThread.Queue(nil,
        procedure
        begin
          ChangeEvent(nil);
        end);
    Exit;
  end;
  Changed := True;
  FLock.Enter;
  try
    I := 0;
    while (I <= High(FPeers)) and (FPeers[I].Id <> P.Id) do
      Inc(I);
    if I <= High(FPeers) then
    begin
      // heard before: a change only when it moved
      Changed := (FPeers[I].Host <> P.Host) or (FPeers[I].Port <> P.Port);
      FPeers[I] := P;
    end
    else
    begin
      FPeers := FPeers + [P];
      // the first time: for the log (copied - see ChangeEvent)
      HeardEvent := FOnFirstHeard;
      if Assigned(HeardEvent) then
      begin
        Said := Format('%s "%s" from %s, first heard', [P.App, P.Name, P.Host]);
        TThread.Queue(nil,
          procedure
          begin
            HeardEvent(Said);
          end);
      end;
    end;
  finally
    FLock.Leave;
  end;
  if Changed and Assigned(FOnChange) then
  begin
    // copied: the finder may be freed before the queue runs (a phone's
    // link ends with Done; zip 360)
    ChangeEvent := FOnChange;
    if Assigned(ChangeEvent) then
      TThread.Queue(nil,
        procedure
        begin
          ChangeEvent(nil);
        end);
  end;
end;

function TLinkFinder.Peers: TLinkPeerArray;
var
  P: TLinkPeer;
begin
  Result := nil;
  FLock.Enter;
  try
    for P in FPeers do
      if SecondsBetween(Now, P.Seen) <= LINK_GONE_SECONDS then
        Result := Result + [P];
    FPeers := Copy(Result);
  finally
    FLock.Leave;
  end;
end;

{ TLinkClient }

constructor TLinkClient.Create(const AHost: string; APort: Integer; const AClient, AToken: string);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FClient := AClient;
  FToken := AToken;
  FConnectTimeout := LINK_CONNECT_MS;
  FReadTimeout := 60000;
  FLock := TCriticalSection.Create;
end;

destructor TLinkClient.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLinkClient.NewHttp: TIdHTTP;
begin
  Result := TIdHTTP.Create(nil);
  // a megabyte at a time both ways (books are hundreds of megabytes)
  Result.IOHandler := TIdIOHandlerStack.Create(Result);
  Result.IOHandler.RecvBufferSize := LINK_BUFFER;
  Result.IOHandler.SendBufferSize := LINK_BUFFER;
  Result.ConnectTimeout := FConnectTimeout;
  Result.ReadTimeout := FReadTimeout;
  Result.Request.CustomHeaders.Values['X-Link-Token'] := FToken;
  Result.OnWork := Work;
  Result.OnWorkBegin := WorkBegin;
end;

procedure TLinkClient.Running(AHttp: TIdHTTP);
begin
  FLock.Enter;
  try
    FHttp := AHttp;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkClient.Cancel;
begin
  FCancel := True;
  FLock.Enter;
  try
    // a blocked read or write ends when its socket is closed (also when
    // the builder went to sleep mid-transfer and nothing comes any more)
    if FHttp <> nil then
      try
        FHttp.Disconnect;
      except
        // closing anyway
      end;
  finally
    FLock.Leave;
  end;
end;

procedure TLinkClient.CheckCancel;
begin
  if FCancel then
    raise ELinkCancelled.Create('cancelled');
end;

procedure TLinkClient.Work(ASender: TObject; AWorkMode: TWorkMode; AWorkCount: Int64);
begin
  CheckCancel;
  if Assigned(FProgress) and (AWorkMode = FWorkMode) then
    FProgress(FOffset + AWorkCount, FTotal);
end;

procedure TLinkClient.WorkBegin(ASender: TObject; AWorkMode: TWorkMode; AWorkCountMax: Int64);
begin
  CheckCancel;
  // a download: the answer's length is what is left of the book
  if (FWorkMode = wmRead) and (AWorkMode = wmRead) and (AWorkCountMax > 0) then
    FTotal := FOffset + AWorkCountMax;
end;

{ The builder's message from an HTTP error's body. }
function ErrorText(E: EIdHTTPProtocolException): string;
var
  V: TJSONValue;
begin
  Result := E.Message;
  V := TJSONObject.ParseJSONValue(E.ErrorMessage);
  try
    if V is TJSONObject then
      TJSONObject(V).TryGetValue<string>('error', Result);
  finally
    V.Free;
  end;
end;

function TLinkClient.Failure(E: Exception): Exception;
begin
  if FCancel then
    Result := ELinkCancelled.Create('cancelled')
  else if E is EIdHTTPProtocolException then
    Result := ELinkError.Create(ErrorText(EIdHTTPProtocolException(E)))
  else if E is ELinkError then
    Result := ELinkError.Create(E.Message)
  else
    // no answer, connection lost, ...: where, and Indy's words
    Result := ELinkError.CreateFmt('%s:%d: %s', [FHost, FPort, E.Message]);
end;

function TLinkClient.GetJson(const APath: string): TJSONObject;
var
  H: TIdHTTP;
  S: string;
  V: TJSONValue;
  Answer: TStringStream;
begin
  CheckCancel;
  H := NewHttp;
  Answer := TStringStream.Create('', TEncoding.UTF8);
  try
    Running(H);
    try
      // into a stream: UTF-8 whatever the answer's header says
      H.Get(Format('http://%s:%d%s', [FHost, FPort, APath]), Answer);
      S := Answer.DataString;
    except
      on E: Exception do
        raise Failure(E);
    end;
  finally
    Running(nil);
    Answer.Free;
    H.Free;
  end;
  V := TJSONObject.ParseJSONValue(S);
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise ELinkError.Create('the builder''s answer is not JSON');
  end;
  Result := TJSONObject(V);
end;

function TLinkClient.PostJson(const APath: string): TJSONObject;
var
  H: TIdHTTP;
  Body, Answer: TStringStream;
  V: TJSONValue;
begin
  CheckCancel;
  H := NewHttp;
  Body := TStringStream.Create('');
  Answer := TStringStream.Create('', TEncoding.UTF8);
  try
    Running(H);
    try
      H.Post(Format('http://%s:%d%s', [FHost, FPort, APath]), Body, Answer);
    except
      on E: Exception do
        raise Failure(E);
    end;
    V := TJSONObject.ParseJSONValue(Answer.DataString);
  finally
    Running(nil);
    Answer.Free;
    Body.Free;
    H.Free;
  end;
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise ELinkError.Create('the builder''s answer is not JSON');
  end;
  Result := TJSONObject(V);
end;

function TLinkClient.Info: TJSONObject;
begin
  Result := GetJson('/info');
end;

procedure TLinkClient.Bye;
begin
  PostJson('/bye').Free;
end;

procedure TLinkClient.PairAsk;
begin
  PostJson('/pair?client=' + TNetEncoding.URL.Encode(FClient)).Free;
end;

function TLinkClient.PairConfirm(const ACode: string): string;
var
  O: TJSONObject;
begin
  O := PostJson('/pair/confirm?client=' + TNetEncoding.URL.Encode(FClient) + '&code=' +
    TNetEncoding.URL.Encode(Trim(ACode)));
  try
    Result := '';
    O.TryGetValue<string>('token', Result);
  finally
    O.Free;
  end;
  if Result = '' then
    raise ELinkError.Create('no token in the builder''s answer');
  FToken := Result;
end;

function TLinkClient.PairTicket(const ATicket: string): string;
var
  O: TJSONObject;
begin
  O := PostJson('/pair/ticket?client=' + TNetEncoding.URL.Encode(FClient) + '&ticket=' +
    TNetEncoding.URL.Encode(Trim(ATicket)));
  try
    Result := '';
    O.TryGetValue<string>('token', Result);
  finally
    O.Free;
  end;
  if Result = '' then
    raise ELinkError.Create('no token in the builder''s answer');
  FToken := Result;
end;

function TLinkClient.Space: TJSONObject;
begin
  Result := GetJson('/space');
end;

function TLinkClient.Books: TJSONObject;
begin
  Result := GetJson('/books');
end;

function TLinkClient.Status: TJSONObject;
begin
  Result := GetJson('/status');
end;

function TLinkClient.Log(AFrom: Integer): TJSONObject;
begin
  Result := GetJson('/log?from=' + IntToStr(AFrom));
end;

procedure TLinkClient.Download(const APath, AFileName: string; const AProgress: TLinkProgress);
var
  H: TIdHTTP;
  F: TFileStream;
  Part: string;
begin
  CheckCancel;
  Part := AFileName + '.part';
  if FileExists(Part) then
    F := TFileStream.Create(Part, fmOpenReadWrite or fmShareDenyWrite)
  else
    F := TFileStream.Create(Part, fmCreate);
  try
    F.Seek(0, soEnd);
    FOffset := F.Size;
    FTotal := 0;
    FWorkMode := wmRead;
    FProgress := AProgress;
    H := NewHttp;
    try
      Running(H);
      try
        H.Get(Format('http://%s:%d/book?path=%s&offset=%d', [FHost, FPort, TNetEncoding.URL.Encode(APath),
          FOffset]), F);
        FTotal := StrToInt64Def(H.Response.RawHeaders.Values['X-Link-Size'], F.Size);
      except
        on E: Exception do
          raise Failure(E);
      end;
    finally
      Running(nil);
      H.Free;
      FProgress := nil;
    end;
    if F.Size <> FTotal then
      raise ELinkError.CreateFmt('%s did not arrive whole (%d of %d bytes) - try again to go on', [APath,
        F.Size, FTotal]);
  finally
    F.Free;
  end;
  if FileExists(AFileName) then
    TFile.Delete(AFileName);
  TFile.Move(Part, AFileName);
end;

function TLinkClient.Upload(const AKind, AFileName, ADir: string; AReplace: Boolean;
  const AProgress: TLinkProgress): string;
var
  H: TIdHTTP;
  F: TFileStream;
  Answer, Empty: TStringStream;
  V: TJSONValue;
  Base: string;
  There: Boolean;

  procedure Headers(AH: TIdHTTP);
  begin
    AH.Request.CustomHeaders.Values['X-Link-Kind'] := AKind;
    AH.Request.CustomHeaders.Values['X-Link-Name'] := TNetEncoding.URL.Encode(ExtractFileName(AFileName));
    AH.Request.CustomHeaders.Values['X-Link-Dir'] := TNetEncoding.URL.Encode(ADir);
    AH.Request.CustomHeaders.Values['X-Link-Size'] := IntToStr(F.Size);
    if FBatch <> '' then
      AH.Request.CustomHeaders.Values['X-Link-Batch'] := FBatch;
    AH.Request.ContentType := 'application/octet-stream';
  end;

begin
  CheckCancel;
  FSkipped := False;
  Result := '';
  Base := Format('http://%s:%d', [FHost, FPort]);
  F := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  Answer := TStringStream.Create('', TEncoding.UTF8);
  Empty := TStringStream.Create('');
  H := nil;
  try
    // asked first: no gigabyte sent to be refused
    H := NewHttp;
    Running(H);
    Headers(H);
    try
      H.Post(Base + '/upload/check', Empty, Answer);
    except
      on E: Exception do
        raise Failure(E);
    end;
    There := False;
    V := TJSONObject.ParseJSONValue(Answer.DataString);
    try
      if V is TJSONObject then
      begin
        TJSONObject(V).TryGetValue<string>('file', Result);
        TJSONObject(V).TryGetValue<Boolean>('there', There);
      end;
    finally
      V.Free;
    end;
    // the same file (name and size) there already
    if There and not AReplace then
    begin
      FSkipped := True;
      Exit;
    end;
    Running(nil);
    FreeAndNil(H);
    H := NewHttp;
    Running(H);
    Headers(H);
    H.Request.CustomHeaders.Values['X-Link-Upload'] := '1';
    Answer.Clear;
    FOffset := 0;
    FTotal := F.Size;
    FWorkMode := wmWrite;
    FProgress := AProgress;
    try
      H.Post(Base + '/upload', F, Answer);
    except
      on E: Exception do
        raise Failure(E);
    end;
    V := TJSONObject.ParseJSONValue(Answer.DataString);
    try
      if V is TJSONObject then
        TJSONObject(V).TryGetValue<string>('file', Result);
    finally
      V.Free;
    end;
  finally
    Running(nil);
    FProgress := nil;
    H.Free;
    Empty.Free;
    Answer.Free;
    F.Free;
  end;
end;

initialization
  Randomize;

end.
