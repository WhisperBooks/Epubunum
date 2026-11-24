{ @abstract(BookManager's window: the EpubBuilder chosen at the top; tabs
  to send it books, audio and pictures (a drop target), to fetch the books
  it made, and to follow its progress and its log.)

  Owner, 2026-11-20: a desktop drop target for EpubBuilder ("drag a book
  to it and builder sticks it in books, drag audio -> audio, drag folder -
  send right bits to right locations"), receiving the books made, its
  real-time progress and log in a tab, space-aware, and nothing typed to
  connect (TSteamAPI's remote logger was "hard to connect to"). Not a Steam
  program. The window is built in code (as EpubBuilder's): uManager.fmx
  only holds the form. }
unit uManager;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, System.StrUtils,
  System.IOUtils, System.IniFiles, System.JSON,
  // TJSONArray's inline getters expand only with it (H2443)
  System.Generics.Collections, System.Generics.Defaults,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.DialogService, FMX.DialogService.Sync,
  FMX.StdCtrls, FMX.Layouts, FMX.ListBox, FMX.Edit, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  // FMX.Objects has a TPath (a shape) that hides System.IOUtils.TPath:
  // that one is written in full here
  FMX.Controls.Presentation, FMX.TabControl, FMX.Objects, FMX.Styles.Objects,
  uDebugLog, uMachine, uEpubUnum, uLink, uLinkSite, uRoute, uTransfers;

type
  { Where a transfer is. }
  TTransferState = (
    { Not started. }
    tsWaiting,
    { Running. }
    tsRunning,
    { Done. }
    tsDone,
    { Sent: the builder had that file already. Fetched: here already. }
    tsSkipped,
    { Did not work. }
    tsFailed,
    { Stopped. }
    tsCancelled);

  { A transfer, as the Send tab lists it. }
  TTransferRow = record
    { Its number (the worker's job id). }
    Id: Integer;
    { Which way. }
    Way: TTransferWay;
    { What the list shows: the file's name, with its folder on the
      builder. }
    Name: string;
    { 'book', 'audio' or 'cover' (sent); 'book' (fetched). }
    Kind: string;
    { Fetched: the book's path on the builder. }
    Remote: string;
    { Bytes in all (0 = not known yet). }
    Size: Int64;
    { Bytes done. }
    Done: Int64;
    { Where it is. }
    State: TTransferState;
    { Why it failed, or where the file is now. }
    Text: string;
  end;

  { A book EpubBuilder made (its /books). }
  TBuilderBook = record
    { Its path on the builder (asked for by it). }
    Path: string;
    { Its file name. }
    Name: string;
    { Bytes. }
    Size: Int64;
    { When it was written, as the builder says it (ISO 8601). }
    Modified: string;
    { A file of that name and size is in the fetch folder. }
    Here: Boolean;
  end;

  { BookManager's window. }
  TfrmManager = class(TForm)
    { Makes the window, the link's threads and the finder; reads the
      settings. }
    procedure FormCreate(Sender: TObject);
    { Asks before transfers not finished are stopped. }
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    { Stops the threads (their events not run yet are dropped), saves. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Frees what the threads shared. }
    procedure FormDestroy(Sender: TObject);
  private
    { The builder row: the list, the link's state, Pair. }
    layTop: TLayout;
    { The builders heard. }
    cbBuilder: TComboBox;
    { Asks the builder to pair (it shows a code). }
    btnPair: TButton;
    { The link's state. }
    lblLink: TLabel;
    { The code row, shown while pairing. }
    layPair: TLayout;
    { The code EpubBuilder shows. }
    edCode: TEdit;
    { Account...: this BookManager joins its owner's account at the link
      site (uLinkSite), after which an EpubBuilder of the same account
      pairs without a code. }
    btnAccount: TButton;
    { The link site's row: the code to type there, shown while joining. }
    laySite: TLayout;
    { The code, and where to type it. }
    lblSite: TLabel;
    { Asks the link site whether the code was typed. }
    tmSite: TTimer;
    { The tabs. }
    tcMain: TTabControl;
    { Send to EpubBuilder. }
    tabSend: TTabItem;
    { Books made. }
    tabBooks: TTabItem;
    { Progress. }
    tabProgress: TTabItem;
    { Log. }
    tabLog: TTabItem;
    { The drop target. }
    rcDrop: TRectangle;
    { What the builder has room for. }
    lblSpace: TLabel;
    { The transfer running. }
    pbTransfer: TProgressBar;
    { The transfer running, in words. }
    lblTransfer: TLabel;
    { The transfers (a drop target too). }
    lbTransfers: TListBox;
    { Where fetched books go. }
    lblFetchFolder: TLabel;
    { The books made. }
    lbBooks: TListBox;
    { Progress: the book being built. }
    lblPTitle: TLabel;
    { Progress: job n of m, the queue. }
    lblPJob: TLabel;
    { Progress: the percentage. }
    pbBuild: TProgressBar;
    { Progress: the time. }
    lblPTime: TLabel;
    { Progress: what it does now. }
    lblPNow: TLabel;
    { Progress: the speed. }
    lblPSpeed: TLabel;
    { The builder's log. }
    mmLog: TMemo;
    { The status line. }
    lblStatus: TLabel;
    { Drops builders not heard any more from the list (every 2 s). }
    tmPeers: TTimer;
    { Dark mode, in the builder row (owner, 2026-11-22: "BookManager
      should have a DarkMode option"). }
    chkDark: TCheckBox;
    { Dark: the tabs' names, drawn here (the style's tab strip is hidden:
      its colours are the style's, light). }
    layTabs: TLayout;
    { Dark: a box per tab in layTabs. }
    FTabBoxes: array[0..3] of TRectangle;
    { Dark: each box's name. }
    FTabLabels: array[0..3] of TLabel;
    { Dark: a dark sheet behind each tab's controls. }
    FTabBacks: array[0..3] of TRectangle;
    { Dark: looked at again twice a second (a style applied again, a
      list's new rows). }
    tmDark: TTimer;
    { Dark mode is on ([View] Dark in the settings; on at first, as
      EpubBuilder's). }
    FDark: Boolean;
    { What the window was last given. }
    FWindowDark: Boolean;
    { The log's style could not be darkened: said once in the debug log. }
    FDarkNoted: Boolean;
    { This program's name, sent when pairing: 'BookManager on <machine>'. }
    FClientName: string;
    { The builders' places and tokens (shared with the threads). }
    FTargets: TLinkTargets;
    { Hears the builders. }
    FFinder: TLinkFinder;
    { The transfers. }
    FWorker: TTransferWorker;
    { The progress, log, books and space of the builder chosen. }
    FPoller: TLinkPoller;
    { The builders heard. }
    FPeers: TLinkPeerArray;
    { The builder id of each line of cbBuilder ('' = none). }
    FComboIds: TArray<string>;
    { cbBuilder is being filled (its OnChange ignored). }
    FFilling: Boolean;
    { The builder chosen ('' = none). }
    FBuilderId: string;
    { The builder chosen, as last heard. }
    FBuilder: TLinkPeer;
    { The builder chosen last time (from the settings). }
    FLastId: string;
    { The poll's generation of the builder chosen. }
    FGeneration: Integer;
    { Tokens: builder id=token. }
    FTokens: TStringList;
    { The last round of the poll worked. }
    FConnected: Boolean;
    { The builder chosen is heard on the network (it says where it is
      every two seconds; closed or asleep it is not). }
    FHeard: Boolean;
    { What went wrong in the last round ('' = nothing). }
    FLastError: string;
    { The client asking to pair (nil = not pairing). }
    FPairClient: TLinkClient;
    { This installation's id at the link site ([Link] Id; '' = none made
      yet). }
    FSiteId: string;
    { Its key there ([Link] Key; '' = not made known yet). }
    FSiteKey: string;
    { An account has it ([Link] Claimed: as the site last said). }
    FSiteClaimed: Boolean;
    { A call to the link site is on its way (one at a time). }
    FSiteBusy: Boolean;
    { When the code shown stops working (0 = none shown). }
    FSiteCodeUntil: TDateTime;
    { The transfers listed (the order of lbTransfers). }
    FRows: TArray<TTransferRow>;
    { The last transfer's number. }
    FNextId: Integer;
    { When the transfer running started (ms). }
    FRunTick: Cardinal;
    { The books made, as last fetched. }
    FBooks: TArray<TBuilderBook>;
    { Where fetched books go. }
    FFetchFolder: string;
    { Where Add files... / Add folder... start. }
    FAddFolder: string;
    { The builder's free space for books (-1 = not known). }
    FBooksFree: Int64;
    { The builder's free space for audio (-1 = not known). }
    FAudioFree: Int64;
    { What the builder never lets an upload take. }
    FReserve: Int64;
    { The window is closing: events are ignored. }
    FClosing: Boolean;
    { The settings file: BookManager.ini in the EpubUnum settings folder. }
    function SettingsFile: string;
    { Reads the settings. }
    procedure LoadSettings;
    { Writes the settings. }
    procedure SaveSettings;
    { Makes the window's controls. }
    procedure BuildWindow;
    { Tab AIndex of the four (0 = Send ... 3 = Log). }
    function TabOf(AIndex: Integer): TTabItem;
    { Gives the window its colours, dark or light (FDark), as
      EpubBuilder's desktop window: the form's fill, the labels and the
      check box light, the lists without a background and their rows
      light, the log's style background no longer drawn; the tabs' names
      in layTabs and a dark sheet behind each tab. Buttons, the list of
      builders, the code box and the bars keep the style's colours. Light:
      all of it put back. }
    procedure ApplyDark;
    { ApplyDark before the window is first drawn: the log's and the
      lists' styles are applied first (their backgrounds are in them). }
    procedure DarkBeforeShow;
    { Dark: the boxes of layTabs from the tabs - their names, and which
      one shows. }
    procedure UpdateTabStrip;
    { A box of layTabs clicked: its tab shows. }
    procedure TabBoxClick(Sender: TObject);
    { tcMain: another tab shows. }
    procedure TabChanged(Sender: TObject);
    { chkDark: dark mode on or off, kept in the settings. }
    procedure chkDarkChange(Sender: TObject);
    { tmDark: ApplyDark while dark. }
    procedure tmDarkTimer(Sender: TObject);
    { A row (Top-aligned layout) under AParent, after those there. }
    function AddRow(AParent: TFmxObject): TLayout;
    { A button in ARow, after those there. }
    function AddButton(ARow: TFmxObject; const AText: string; AOnClick: TNotifyEvent; AWidth: Single): TButton;
    { A label in AParent, Top-aligned, AY its order. }
    function AddLabel(AParent: TFmxObject; ASize: Single; AY: Single): TLabel;
    { The status line (and the debug log). }
    procedure SetStatus(const AText: string);
    { The token for the builder AId ('' = not paired). }
    function TokenOf(const AId: string): string;
    { Keeps (or, with '', forgets) the token for the builder AId. }
    procedure SetTokenFor(const AId, AToken: string);
    { The finder heard a builder come, go or move. }
    procedure FinderChange(Sender: TObject);
    { tmPeers: FinderChange. }
    procedure tmPeersTimer(Sender: TObject);
    { Fills cbBuilder with the builders heard (and the one chosen). }
    procedure FillBuilders;
    { cbBuilder: another builder chosen. }
    procedure cbBuilderChange(Sender: TObject);
    { Follows the builder AId: the poll, the tabs emptied. }
    procedure ChooseBuilder(const AId: string);
    { lblLink and btnPair from the link's state. }
    procedure UpdateLink;
    { Pair...: with a ticket of the link site when this BookManager is in
      an account (PairWithTicket), else with the code (PairWithCode). }
    procedure btnPairClick(Sender: TObject);
    { The builder shows a code; the code row opens.
      @param(ANote said before the status line's text ('' = nothing):
        why pairing without a code did not work) }
    procedure PairWithCode(const ANote: string);
    { Pairs without a code, in a thread: asks the builder whether it takes
      a ticket, the link site for one, and hands it over. TicketAnswered
      is called with what came of it. }
    procedure PairWithTicket(const ATarget: TLinkTarget);
    { PairWithTicket's end (main thread): the token kept, or - AToken ''
      - the code asked for after all, with AWhy said. }
    procedure TicketAnswered(const ABuilderId, AToken, AWhy: string);
    { The builder chosen gave AToken: kept, the poll started again.
      @param(AHow said in the status line: 'Paired' / 'Paired without a
        code') }
    procedure PairDone(const AToken, AHow: string);
    { Account...: makes this BookManager known to the link site when it
      is not, asks whether an account has it, and - when none has - for a
      code to show. In a thread; SiteAnswered is called. }
    procedure btnAccountClick(Sender: TObject);
    { The link site's row's Cancel: the code is no longer waited for. }
    procedure btnSiteCancelClick(Sender: TObject);
    { tmSite: asks the link site whether the code shown was typed. }
    procedure tmSiteTimer(Sender: TObject);
    { Asks the link site, in a thread (FSiteBusy while it runs).
      @param(AWantCode ask for a code to show when no account has this
        BookManager (Account...); False only asks (tmSite)) }
    procedure AskSite(AWantCode: Boolean);
    { The link site's answer (main thread): the id and key to keep,
      whether an account has this BookManager, the code to show (its
      Code '' = none was asked for), how many other installations the
      account has, and - AError not '' - why the site was not asked. }
    procedure SiteAnswered(const AId, AKey: string; AClaimed: Boolean; const ACode: TLinkSiteCode;
      AOthers: Integer; const AError: string);
    { The link site's row hidden, its timer stopped. }
    procedure HideSite;
    { The code row's Pair: the code sent, the token kept. }
    procedure btnPairOkClick(Sender: TObject);
    { The code row's Cancel. }
    procedure btnPairCancelClick(Sender: TObject);
    { The code box: Enter = Pair. }
    procedure edCodeKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    { A drag with files came over the drop target. }
    procedure DropEnter(Sender: TObject; const Data: TDragObject; const Point: TPointF);
    { The drag left. }
    procedure DropLeave(Sender: TObject);
    { Files may be dropped (copied). }
    procedure DropOver(Sender: TObject; const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);
    { Files dropped: sent. }
    procedure DropDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
    { Add files...: chosen files sent. }
    procedure btnAddFilesClick(Sender: TObject);
    { Add folder...: a chosen folder sent. }
    procedure btnAddFolderClick(Sender: TObject);
    { The builder is chosen and paired; else says why, False. }
    function ReadyToSend: Boolean;
    { Sends the files and folders APaths, each to its place (uRoute). }
    procedure SendPaths(const APaths: array of string);
    { A transfer added (the list and the worker). }
    procedure AddTransfer(const AJob: TTransferJob; const AName: string; ASize: Int64);
    { The row of transfer AId (-1 = none). }
    function RowIndex(AId: Integer): Integer;
    { What the list shows for row I. }
    function RowText(I: Integer): string;
    { Shows row I in the list. }
    procedure ShowRow(I: Integer);
    { The transfer bar and its line. }
    procedure UpdateTransferBar;
    { Cancel: the transfer selected. }
    procedure btnCancelClick(Sender: TObject);
    { Cancel all: every transfer waiting or running. }
    procedure btnCancelAllClick(Sender: TObject);
    { Clear finished: the finished ones off the list. }
    procedure btnClearClick(Sender: TObject);
    { Transfers not finished. }
    function Unfinished: Integer;
    { The worker started a transfer. }
    procedure WorkerStart(AId: Integer);
    { A transfer's progress. }
    procedure WorkerProgress(AId: Integer; ADone, ATotal: Int64);
    { A transfer ended. }
    procedure WorkerDone(AId: Integer; AOk, ASkipped: Boolean; const AText: string);
    { Refresh: the books made asked for now. }
    procedure btnRefreshClick(Sender: TObject);
    { Fetch checked: the books ticked (else the one selected). }
    procedure btnFetchCheckedClick(Sender: TObject);
    { Fetch all new: every book not here. }
    procedure btnFetchNewClick(Sender: TObject);
    { Folder...: where fetched books go. }
    procedure btnFetchFolderClick(Sender: TObject);
    { Fetches the books AIndexes of FBooks (those here are skipped). }
    procedure Fetch(const AIndexes: TArray<Integer>);
    { The file a fetched book AName becomes. }
    function LocalBook(const AName: string): string;
    { A fetch of book I may go on from its .part file only when that is of
      the same build (size and time, kept in '.part.from' beside it); else
      the .part goes and the fetch starts afresh. }
    procedure CheckPart(I: Integer);
    { FBooks from /books' JSON. }
    procedure ShowBooks(const AJson: string);
    { lbBooks from FBooks (the ticks kept). }
    procedure FillBooks;
    { A round of the poll. }
    procedure Poll(const AResult: TLinkPollResult);
    { The Progress tab from /status' JSON. }
    procedure ShowProgress(const AJson: string);
    { The Progress tab: nothing known. }
    procedure ClearProgress(const ATitle: string);
    { Lines added to the Log tab. }
    procedure AddLogLines(const ALines: TArray<string>);
    { The free space from /space' JSON. }
    procedure ShowSpace(const AJson: string);
  public
  end;

var
  { The window. }
  frmManager: TfrmManager;

implementation

{$R *.fmx}

const
  { Space between controls. }
  GAP = 8;
  { A row's height. }
  ROW_HEIGHT = 32;
  { Log lines kept in the Log tab. }
  LOG_KEEP = 5000;
  { Dark mode's colours, EpubBuilder's (its PAD_DARK_...): the window. }
  DARK_WINDOW = $FF1A1C22;
  { Dark mode: text. }
  DARK_TEXT = $FFE0E0E0;
  { Dark mode: the box of the tab that shows. }
  DARK_ROW = $FF34405A;
  { Dark mode: the frame of the other tabs' boxes. }
  DARK_FRAME = $FF4A4F5C;
  { The tabs' names in layTabs: the tab items' texts. }
  TAB_NAMES: array[0..3] of string = ('Send to EpubBuilder', 'Books made', 'Progress', 'Log');
  { Room left free on this computer's drive when books are fetched
    (1 GiB). }
  FETCH_RESERVE = Int64(1024) * 1024 * 1024;

{ Bytes as '1.2 GB', '340.5 MB', '12 KB'. }
function SizeText(ABytes: Int64): string;
begin
  if ABytes >= 1000000000 then
    Result := Format('%.1f GB', [ABytes / 1E9])
  else if ABytes >= 1000000 then
    Result := Format('%.1f MB', [ABytes / 1E6])
  else
    Result := Format('%d KB', [(ABytes + 999) div 1000]);
end;

{ ADone of ATotal in per cent, 0 - 100 (0 when ATotal is not known). }
function PercentOf(ADone, ATotal: Int64): Double;
begin
  Result := 0;
  if ATotal > 0 then
    Result := ADone * 100.0 / ATotal;
  if Result < 0 then
    Result := 0;
  if Result > 100 then
    Result := 100;
end;

{ AValue, or 0 when below. }
function NonNeg(AValue: Int64): Int64;
begin
  Result := AValue;
  if Result < 0 then
    Result := 0;
end;

var
  { The window is closing or gone: an answer of the link site that comes
    after that (its threads are not waited for) touches nothing. }
  GManagerGone: Boolean = False;

{ TfrmManager }

function TfrmManager.SettingsFile: string;
begin
  Result := System.IOUtils.TPath.Combine(EpubUnumConfigFolder, 'BookManager.ini');
end;

procedure TfrmManager.LoadSettings;
var
  Ini: TMemIniFile;
  I: Integer;
begin
  FFetchFolder := EpubUnumFolder(EU_TRANSCRIBED);
  FAddFolder := System.IOUtils.TPath.GetDocumentsPath;
  FDark := True;
  try
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      Ini.ReadSectionValues('Paired', FTokens);
      FLastId := Ini.ReadString('Builder', 'Id', '');
      FFetchFolder := Ini.ReadString('Folders', 'Fetch', FFetchFolder);
      FAddFolder := Ini.ReadString('Folders', 'Add', FAddFolder);
      FDark := Ini.ReadBool('View', 'Dark', True);
      FSiteId := Ini.ReadString('Link', 'Id', '');
      FSiteKey := Ini.ReadString('Link', 'Key', '');
      FSiteClaimed := Ini.ReadBool('Link', 'Claimed', False);
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      DebugLog('settings: ' + E.Message);
  end;
  for I := 0 to FTokens.Count - 1 do
    FTargets.SetToken(FTokens.Names[I], FTokens.ValueFromIndex[I]);
end;

procedure TfrmManager.SaveSettings;
var
  Ini: TMemIniFile;
  I: Integer;
begin
  try
    Ini := TMemIniFile.Create(SettingsFile, TEncoding.UTF8);
    try
      Ini.EraseSection('Paired');
      for I := 0 to FTokens.Count - 1 do
        if FTokens.Names[I] <> '' then
          Ini.WriteString('Paired', FTokens.Names[I], FTokens.ValueFromIndex[I]);
      if FBuilderId <> '' then
        Ini.WriteString('Builder', 'Id', FBuilderId);
      Ini.WriteString('Folders', 'Fetch', FFetchFolder);
      Ini.WriteString('Folders', 'Add', FAddFolder);
      Ini.WriteBool('View', 'Dark', FDark);
      // the link site: nothing is written until Account... was used
      if FSiteId <> '' then
      begin
        Ini.WriteString('Link', 'Id', FSiteId);
        Ini.WriteString('Link', 'Key', FSiteKey);
        Ini.WriteBool('Link', 'Claimed', FSiteClaimed);
      end;
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    on E: Exception do
      SetStatus('The settings were not saved: ' + E.Message);
  end;
end;

function TfrmManager.AddRow(AParent: TFmxObject): TLayout;
begin
  Result := TLayout.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Height := ROW_HEIGHT;
  Result.Margins.Rect := RectF(GAP, GAP div 2, GAP, 0);
  // rows stack in the order made
  Result.Position.Y := 100000;
end;

function TfrmManager.AddButton(ARow: TFmxObject; const AText: string; AOnClick: TNotifyEvent;
  AWidth: Single): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := ARow;
  Result.Align := TAlignLayout.Left;
  Result.Width := AWidth;
  Result.Margins.Rect := RectF(0, 0, GAP div 2, 0);
  // after the controls already there
  Result.Position.X := 100000;
  Result.Text := AText;
  Result.OnClick := AOnClick;
end;

function TfrmManager.AddLabel(AParent: TFmxObject; ASize: Single; AY: Single): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Top;
  Result.Position.Y := AY;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Size];
  Result.TextSettings.Font.Size := ASize;
  Result.Height := ASize * 1.8;
  Result.Margins.Rect := RectF(GAP * 2, GAP div 2, GAP * 2, 0);
  Result.WordWrap := False;
  Result.Trimming := TTextTrimming.Character;
end;

function TfrmManager.TabOf(AIndex: Integer): TTabItem;
begin
  case AIndex of
    0: Result := tabSend;
    1: Result := tabBooks;
    2: Result := tabProgress;
  else
    Result := tabLog;
  end;
end;

procedure TfrmManager.BuildWindow;
var
  Row: TLayout;
  L: TLabel;
  B: TButton;
  I: Integer;

  { The dark sheet of tab AIndex: made before the tab's controls, so
    behind them; shown while dark. }
  procedure AddBack(AIndex: Integer; ATab: TTabItem);
  begin
    FTabBacks[AIndex] := TRectangle.Create(Self);
    FTabBacks[AIndex].Parent := ATab;
    FTabBacks[AIndex].Align := TAlignLayout.Contents;
    FTabBacks[AIndex].Fill.Color := DARK_WINDOW;
    FTabBacks[AIndex].Stroke.Kind := TBrushKind.None;
    FTabBacks[AIndex].HitTest := False;
    FTabBacks[AIndex].Visible := False;
  end;

begin
  // the status line, at the bottom
  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := Self;
  lblStatus.Align := TAlignLayout.Bottom;
  lblStatus.Height := 26;
  lblStatus.Margins.Rect := RectF(GAP, 0, GAP, GAP div 2);
  lblStatus.WordWrap := False;
  lblStatus.Trimming := TTextTrimming.Character;

  // the builder: list, state, Pair
  layTop := TLayout.Create(Self);
  layTop.Parent := Self;
  layTop.Align := TAlignLayout.Top;
  layTop.Height := ROW_HEIGHT + GAP;
  layTop.Padding.Rect := RectF(GAP, GAP, GAP, 0);
  L := TLabel.Create(Self);
  L.Parent := layTop;
  L.Align := TAlignLayout.Left;
  L.Width := 90;
  L.Text := 'EpubBuilder';
  // at the far right
  chkDark := TCheckBox.Create(Self);
  chkDark.Parent := layTop;
  chkDark.Align := TAlignLayout.Right;
  chkDark.Position.X := 100000;
  chkDark.Width := 110;
  chkDark.Margins.Left := GAP * 2;
  chkDark.Text := 'Dark mode';
  btnPair := TButton.Create(Self);
  btnPair.Parent := layTop;
  btnPair.Align := TAlignLayout.Right;
  btnPair.Width := 110;
  btnPair.Margins.Left := GAP;
  btnPair.Text := 'Pair...';
  btnPair.OnClick := btnPairClick;
  btnAccount := TButton.Create(Self);
  btnAccount.Parent := layTop;
  btnAccount.Align := TAlignLayout.Right;
  btnAccount.Width := 110;
  btnAccount.Margins.Left := GAP;
  btnAccount.Text := 'Account...';
  btnAccount.OnClick := btnAccountClick;
  lblLink := TLabel.Create(Self);
  lblLink.Parent := layTop;
  lblLink.Align := TAlignLayout.Right;
  lblLink.Width := 300;
  lblLink.Margins.Left := GAP;
  lblLink.WordWrap := False;
  lblLink.Trimming := TTextTrimming.Character;
  cbBuilder := TComboBox.Create(Self);
  cbBuilder.Parent := layTop;
  cbBuilder.Align := TAlignLayout.Client;
  cbBuilder.OnChange := cbBuilderChange;

  // the code row, while pairing
  layPair := TLayout.Create(Self);
  layPair.Parent := Self;
  layPair.Align := TAlignLayout.Top;
  layPair.Position.Y := 100;
  layPair.Height := ROW_HEIGHT + GAP;
  layPair.Padding.Rect := RectF(GAP, GAP, GAP, 0);
  L := TLabel.Create(Self);
  L.Parent := layPair;
  L.Align := TAlignLayout.Left;
  L.Width := 330;
  L.Text := 'Type the 6-digit code EpubBuilder shows now:';
  edCode := TEdit.Create(Self);
  edCode.Parent := layPair;
  edCode.Align := TAlignLayout.Left;
  edCode.Position.X := 100000;
  edCode.Width := 110;
  edCode.MaxLength := 6;
  edCode.OnKeyDown := edCodeKeyDown;
  B := AddButton(layPair, 'Pair', btnPairOkClick, 90);
  B.Margins.Left := GAP;
  AddButton(layPair, 'Cancel', btnPairCancelClick, 90);
  layPair.Visible := False;

  // the link site's row, while this BookManager joins an account
  laySite := TLayout.Create(Self);
  laySite.Parent := Self;
  laySite.Align := TAlignLayout.Top;
  laySite.Position.Y := 100;
  laySite.Height := ROW_HEIGHT + GAP;
  laySite.Padding.Rect := RectF(GAP, GAP, GAP, 0);
  B := TButton.Create(Self);
  B.Parent := laySite;
  B.Align := TAlignLayout.Right;
  B.Width := 90;
  B.Text := 'Cancel';
  B.OnClick := btnSiteCancelClick;
  lblSite := TLabel.Create(Self);
  lblSite.Parent := laySite;
  lblSite.Align := TAlignLayout.Client;
  lblSite.WordWrap := False;
  lblSite.Trimming := TTextTrimming.Character;
  laySite.Visible := False;

  // dark: the tabs' names, in this program's colours
  layTabs := TLayout.Create(Self);
  layTabs.Parent := Self;
  layTabs.Align := TAlignLayout.Top;
  layTabs.Position.Y := 200;
  layTabs.Height := ROW_HEIGHT + GAP;
  layTabs.Padding.Rect := RectF(GAP, GAP, GAP, 0);
  for I := 0 to High(FTabBoxes) do
  begin
    FTabBoxes[I] := TRectangle.Create(Self);
    FTabBoxes[I].Parent := layTabs;
    FTabBoxes[I].Align := TAlignLayout.Left;
    FTabBoxes[I].Position.X := 100000;
    FTabBoxes[I].Width := 200;
    FTabBoxes[I].Margins.Right := GAP div 2;
    FTabBoxes[I].XRadius := 6;
    FTabBoxes[I].YRadius := 6;
    FTabBoxes[I].Stroke.Color := DARK_FRAME;
    FTabBoxes[I].Fill.Kind := TBrushKind.None;
    FTabBoxes[I].HitTest := True;
    FTabBoxes[I].Tag := I;
    FTabBoxes[I].OnClick := TabBoxClick;
    FTabLabels[I] := TLabel.Create(Self);
    FTabLabels[I].Parent := FTabBoxes[I];
    FTabLabels[I].Align := TAlignLayout.Client;
    FTabLabels[I].HitTest := False;
    // its colour is this program's: ApplyDark leaves it alone
    FTabLabels[I].StyledSettings := FTabLabels[I].StyledSettings - [TStyledSetting.FontColor,
      TStyledSetting.Other];
    FTabLabels[I].TextSettings.FontColor := DARK_TEXT;
    FTabLabels[I].TextSettings.HorzAlign := TTextAlign.Center;
    FTabLabels[I].WordWrap := False;
    FTabLabels[I].Text := TAB_NAMES[I];
  end;
  layTabs.Visible := False;

  tcMain := TTabControl.Create(Self);
  tcMain.Parent := Self;
  tcMain.Align := TAlignLayout.Client;
  tcMain.Margins.Rect := RectF(GAP, GAP, GAP, GAP div 2);

  // --- Send to EpubBuilder
  tabSend := TTabItem.Create(tcMain);
  tabSend.Parent := tcMain;
  tabSend.Text := TAB_NAMES[0];
  AddBack(0, tabSend);
  rcDrop := TRectangle.Create(Self);
  rcDrop.Parent := tabSend;
  rcDrop.Align := TAlignLayout.Top;
  rcDrop.Height := 120;
  rcDrop.Margins.Rect := RectF(GAP, GAP, GAP, 0);
  rcDrop.Fill.Kind := TBrushKind.None;
  rcDrop.Stroke.Color := TAlphaColors.Gray;
  rcDrop.Stroke.Thickness := 2;
  rcDrop.Stroke.Dash := TStrokeDash.Dash;
  rcDrop.XRadius := 10;
  rcDrop.YRadius := 10;
  rcDrop.HitTest := True;
  rcDrop.OnDragEnter := DropEnter;
  rcDrop.OnDragLeave := DropLeave;
  rcDrop.OnDragOver := DropOver;
  rcDrop.OnDragDrop := DropDrop;
  L := TLabel.Create(Self);
  L.Parent := rcDrop;
  L.Align := TAlignLayout.Top;
  L.Height := 44;
  L.Margins.Top := 18;
  L.StyledSettings := L.StyledSettings - [TStyledSetting.Size, TStyledSetting.Style, TStyledSetting.Other];
  L.TextSettings.Font.Size := 20;
  L.TextSettings.Font.Style := [TFontStyle.fsBold];
  L.TextSettings.HorzAlign := TTextAlign.Center;
  L.Text := 'Drop books, audio, pictures or folders here';
  L := TLabel.Create(Self);
  L.Parent := rcDrop;
  L.Align := TAlignLayout.Top;
  L.Position.Y := 100;
  L.Height := 40;
  L.Margins.Rect := RectF(GAP * 2, 0, GAP * 2, 0);
  L.StyledSettings := L.StyledSettings - [TStyledSetting.Other];
  L.TextSettings.HorzAlign := TTextAlign.Center;
  L.WordWrap := True;
  L.Text := 'Books go to its books folder, audio to its audio folder (a folder''s files stay together), ' +
    'pictures to Covers (named as the book they are for).';

  Row := AddRow(tabSend);
  AddButton(Row, 'Add files...', btnAddFilesClick, 110);
  AddButton(Row, 'Add folder...', btnAddFolderClick, 110);
  AddButton(Row, 'Cancel', btnCancelClick, 80);
  AddButton(Row, 'Cancel all', btnCancelAllClick, 90);
  AddButton(Row, 'Clear finished', btnClearClick, 120);
  lblSpace := TLabel.Create(Self);
  lblSpace.Parent := Row;
  lblSpace.Align := TAlignLayout.Client;
  lblSpace.Margins.Left := GAP;
  lblSpace.WordWrap := False;
  lblSpace.Trimming := TTextTrimming.Character;

  Row := AddRow(tabSend);
  lblTransfer := TLabel.Create(Self);
  lblTransfer.Parent := Row;
  lblTransfer.Align := TAlignLayout.Left;
  lblTransfer.Width := 420;
  lblTransfer.WordWrap := False;
  lblTransfer.Trimming := TTextTrimming.Character;
  pbTransfer := TProgressBar.Create(Self);
  pbTransfer.Parent := Row;
  pbTransfer.Align := TAlignLayout.Client;
  pbTransfer.Margins.Rect := RectF(GAP, 8, 0, 8);
  pbTransfer.Max := 100;

  lbTransfers := TListBox.Create(Self);
  lbTransfers.Parent := tabSend;
  lbTransfers.Align := TAlignLayout.Client;
  lbTransfers.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  lbTransfers.OnDragEnter := DropEnter;
  lbTransfers.OnDragLeave := DropLeave;
  lbTransfers.OnDragOver := DropOver;
  lbTransfers.OnDragDrop := DropDrop;

  // --- Books made
  tabBooks := TTabItem.Create(tcMain);
  tabBooks.Parent := tcMain;
  tabBooks.Text := TAB_NAMES[1];
  AddBack(1, tabBooks);
  Row := AddRow(tabBooks);
  Row.Margins.Top := GAP;
  AddButton(Row, 'Refresh', btnRefreshClick, 90);
  AddButton(Row, 'Fetch checked', btnFetchCheckedClick, 120);
  AddButton(Row, 'Fetch all new', btnFetchNewClick, 120);
  AddButton(Row, 'Folder...', btnFetchFolderClick, 90);
  lblFetchFolder := TLabel.Create(Self);
  lblFetchFolder.Parent := Row;
  lblFetchFolder.Align := TAlignLayout.Client;
  lblFetchFolder.Margins.Left := GAP;
  lblFetchFolder.WordWrap := False;
  lblFetchFolder.Trimming := TTextTrimming.Character;
  lbBooks := TListBox.Create(Self);
  lbBooks.Parent := tabBooks;
  lbBooks.Align := TAlignLayout.Client;
  lbBooks.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  lbBooks.ShowCheckboxes := True;

  // --- Progress (as EpubBuilder's progress panel)
  tabProgress := TTabItem.Create(tcMain);
  tabProgress.Parent := tcMain;
  tabProgress.Text := TAB_NAMES[2];
  AddBack(2, tabProgress);
  lblPTitle := AddLabel(tabProgress, 26, 0);
  lblPTitle.StyledSettings := lblPTitle.StyledSettings - [TStyledSetting.Style];
  lblPTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  lblPTitle.Margins.Top := GAP * 2;
  lblPJob := AddLabel(tabProgress, 18, 100);
  pbBuild := TProgressBar.Create(Self);
  pbBuild.Parent := tabProgress;
  pbBuild.Align := TAlignLayout.Top;
  pbBuild.Position.Y := 200;
  pbBuild.Height := 24;
  pbBuild.Margins.Rect := RectF(GAP * 2, GAP, GAP * 2, GAP);
  pbBuild.Max := 100;
  lblPTime := AddLabel(tabProgress, 18, 300);
  lblPNow := AddLabel(tabProgress, 18, 400);
  lblPSpeed := AddLabel(tabProgress, 18, 500);

  // --- Log (EpubBuilder's)
  tabLog := TTabItem.Create(tcMain);
  tabLog.Parent := tcMain;
  tabLog.Text := TAB_NAMES[3];
  AddBack(3, tabLog);
  mmLog := TMemo.Create(Self);
  mmLog.Parent := tabLog;
  mmLog.Align := TAlignLayout.Client;
  mmLog.Margins.Rect := RectF(GAP, GAP, GAP, GAP);
  mmLog.ReadOnly := True;
  mmLog.WordWrap := True;

  tcMain.ActiveTab := tabSend;
  tcMain.OnChange := TabChanged;

  tmPeers := TTimer.Create(Self);
  tmPeers.Interval := 2000;
  tmPeers.OnTimer := tmPeersTimer;
  tmDark := TTimer.Create(Self);
  tmDark.Interval := 500;
  tmDark.OnTimer := tmDarkTimer;
  tmSite := TTimer.Create(Self);
  tmSite.Enabled := False;
  tmSite.Interval := 5000;
  tmSite.OnTimer := tmSiteTimer;
end;

procedure TfrmManager.UpdateTabStrip;
var
  I: Integer;
begin
  if not FWindowDark then
    Exit;
  for I := 0 to High(FTabBoxes) do
  begin
    // a tab's name changes ("Books made (12, 3 new)", "Progress (45 %)")
    if FTabLabels[I].Text <> TabOf(I).Text then
      FTabLabels[I].Text := TabOf(I).Text;
    if tcMain.ActiveTab = TabOf(I) then
    begin
      FTabBoxes[I].Fill.Kind := TBrushKind.Solid;
      FTabBoxes[I].Fill.Color := DARK_ROW;
      FTabLabels[I].TextSettings.FontColor := TAlphaColors.White;
    end
    else
    begin
      FTabBoxes[I].Fill.Kind := TBrushKind.None;
      FTabLabels[I].TextSettings.FontColor := DARK_TEXT;
    end;
  end;
end;

procedure TfrmManager.TabBoxClick(Sender: TObject);
begin
  if Sender is TRectangle then
    tcMain.ActiveTab := TabOf(TRectangle(Sender).Tag);
  UpdateTabStrip;
end;

procedure TfrmManager.TabChanged(Sender: TObject);
begin
  UpdateTabStrip;
end;

procedure TfrmManager.ApplyDark;
const
  { FMX's own list style with no background: the dark sheet shows through
    (EpubBuilder's lists, the reader's contents). }
  DARK_LIST_STYLE = 'transparentlistboxstyle';
  { Marks a control whose colour this changed: only those are put back. }
  DARK_MARK = 'dark';

  { The log: its style's background picture no longer drawn, then its
    text light; the style's own again when dark is off. }
  procedure DarkMemo(AMemo: TMemo);
  var
    Obj: TFmxObject;
  begin
    if not FDark then
    begin
      if not (TStyledSetting.FontColor in AMemo.StyledSettings) then
      begin
        AMemo.StyledSettings := AMemo.StyledSettings + [TStyledSetting.FontColor];
        // the style's own background again
        AMemo.NeedStyleLookup;
        AMemo.ApplyStyleLookup;
        AMemo.Repaint;
      end;
      Exit;
    end;
    // the background is a picture taken from the style: with no picture
    // to look up it draws nothing, and its children (the text) still do
    Obj := AMemo.FindStyleResource('background');
    if not (Obj is TCustomStyleObject) then
    begin
      if not FDarkNoted then
      begin
        FDarkNoted := True;
        if Obj = nil then
          DebugLog('dark: the log''s style has no "background" yet - looked for again')
        else
          DebugLog('dark: the log keeps the style''s colours - its background is a ' + Obj.ClassName +
            ', not a style picture');
      end;
      Exit;
    end;
    if TCustomStyleObject(Obj).SourceLookup <> '' then
    begin
      TCustomStyleObject(Obj).SourceLookup := '';
      TCustomStyleObject(Obj).Source := nil;
      DebugLog('dark: the background of the log (' + Obj.ClassName + ') is no longer drawn');
      AMemo.Repaint;
    end;
    // light text only once the background is known to be gone
    if TStyledSetting.FontColor in AMemo.StyledSettings then
    begin
      AMemo.StyledSettings := AMemo.StyledSettings - [TStyledSetting.FontColor];
      AMemo.TextSettings.FontColor := DARK_TEXT;
      AMemo.Repaint;
    end;
  end;

  { A label that had the style's colour: light, and marked; a marked one
    gets the style's colour back. }
  procedure DarkLabel(ALabel: TLabel);
  begin
    if FDark then
    begin
      if TStyledSetting.FontColor in ALabel.StyledSettings then
      begin
        ALabel.StyledSettings := ALabel.StyledSettings - [TStyledSetting.FontColor];
        ALabel.TextSettings.FontColor := DARK_TEXT;
        ALabel.TagString := DARK_MARK;
      end;
    end
    else if ALabel.TagString = DARK_MARK then
    begin
      ALabel.TagString := '';
      ALabel.StyledSettings := ALabel.StyledSettings + [TStyledSetting.FontColor];
    end;
  end;

  { The check box's text, as a label's. }
  procedure DarkCheck(ACheck: TCheckBox);
  begin
    if FDark then
    begin
      if TStyledSetting.FontColor in ACheck.StyledSettings then
      begin
        ACheck.StyledSettings := ACheck.StyledSettings - [TStyledSetting.FontColor];
        ACheck.TextSettings.FontColor := DARK_TEXT;
        ACheck.TagString := DARK_MARK;
      end;
    end
    else if ACheck.TagString = DARK_MARK then
    begin
      ACheck.TagString := '';
      ACheck.StyledSettings := ACheck.StyledSettings + [TStyledSetting.FontColor];
    end;
  end;

  { A list: no background of its own, its rows' text light (new rows come
    with the style's colour: looked at again by tmDark and after a list
    is filled). }
  procedure DarkList(AList: TListBox);
  var
    I: Integer;
    Row: TListBoxItem;
  begin
    if FDark then
    begin
      if AList.StyleLookup <> DARK_LIST_STYLE then
      begin
        AList.StyleLookup := DARK_LIST_STYLE;
        AList.NeedStyleLookup;
        AList.ApplyStyleLookup;
      end;
    end
    else if AList.StyleLookup = DARK_LIST_STYLE then
    begin
      AList.StyleLookup := '';
      AList.NeedStyleLookup;
      AList.ApplyStyleLookup;
    end;
    for I := 0 to AList.Count - 1 do
    begin
      Row := AList.ListItems[I];
      if FDark then
      begin
        if TStyledSetting.FontColor in Row.StyledSettings then
        begin
          Row.StyledSettings := Row.StyledSettings - [TStyledSetting.FontColor];
          Row.TextSettings.FontColor := DARK_TEXT;
          Row.TagString := DARK_MARK;
        end;
      end
      else if Row.TagString = DARK_MARK then
      begin
        Row.TagString := '';
        Row.StyledSettings := Row.StyledSettings + [TStyledSetting.FontColor];
      end;
    end;
  end;

var
  I: Integer;
  C: TComponent;
begin
  if (mmLog = nil) or (tmDark = nil) then
    Exit;
  if FDark <> FWindowDark then
  begin
    FWindowDark := FDark;
    if FDark then
    begin
      Fill.Kind := TBrushKind.Solid;
      Fill.Color := DARK_WINDOW;
      // the style's tab strip (light) gives way to layTabs, under the
      // builder row and the code row
      tcMain.TabPosition := TTabPosition.None;
      layTabs.Position.Y := 10000;
    end
    else
    begin
      Fill.Kind := TBrushKind.None;
      tcMain.TabPosition := TTabPosition.PlatformDefault;
    end;
    layTabs.Visible := FDark;
    for I := 0 to High(FTabBacks) do
      FTabBacks[I].Visible := FDark;
    DebugLog('dark: ' + IfThen(FDark, 'on', 'off'));
  end;
  // every control was made with the form as its owner
  for I := 0 to ComponentCount - 1 do
  begin
    C := Components[I];
    if C is TLabel then
      DarkLabel(TLabel(C))
    else if C is TCheckBox then
      DarkCheck(TCheckBox(C))
    else if C is TListBox then
      DarkList(TListBox(C))
    else if C is TMemo then
      DarkMemo(TMemo(C));
  end;
  UpdateTabStrip;
  tmDark.Enabled := FDark and not FClosing;
end;

procedure TfrmManager.DarkBeforeShow;
begin
  if not FDark then
    Exit;
  try
    mmLog.ApplyStyleLookup;
    lbTransfers.ApplyStyleLookup;
    lbBooks.ApplyStyleLookup;
    ApplyDark;
  except
    on E: Exception do
      DebugLog('dark before show: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmManager.chkDarkChange(Sender: TObject);
begin
  if FClosing or (chkDark.IsChecked = FDark) then
    Exit;
  FDark := chkDark.IsChecked;
  try
    ApplyDark;
  except
    on E: Exception do
      DebugLog('dark: ' + E.ClassName + ': ' + E.Message);
  end;
  SaveSettings;
end;

procedure TfrmManager.tmDarkTimer(Sender: TObject);
begin
  try
    if FDark and not FClosing then
      ApplyDark;
  except
    on E: Exception do
      DebugLog('dark: ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure TfrmManager.FormCreate(Sender: TObject);
begin
  OnCloseQuery := FormCloseQuery;
  OnClose := FormClose;
  OnDestroy := FormDestroy;
  FBooksFree := -1;
  FAudioFree := -1;
  FReserve := LINK_RESERVE;
  DebugLogOpen(ChangeFileExt(SettingsFile, '-debug.log'));
  DebugLog('machine: ' + MachineText);
  FClientName := 'BookManager on ' + MachineName;
  if MachineName = '' then
    FClientName := 'BookManager';
  FTokens := TStringList.Create;
  FTargets := TLinkTargets.Create(FClientName);
  BuildWindow;
  LoadSettings;
  // dark unless turned off, before the first frame
  chkDark.IsChecked := FDark;
  chkDark.OnChange := chkDarkChange;
  DarkBeforeShow;
  lblFetchFolder.Text := 'Fetched to: ' + FFetchFolder;
  ClearProgress('Not connected');

  FWorker := TTransferWorker.Create(FTargets);
  FWorker.OnStart := WorkerStart;
  FWorker.OnProgress := WorkerProgress;
  FWorker.OnDone := WorkerDone;
  FWorker.Start;
  FPoller := TLinkPoller.Create(FTargets);
  FPoller.OnPoll := Poll;
  FPoller.Start;
  // the builders say where they are every two seconds
  FFinder := TLinkFinder.Create;
  FFinder.OnChange := FinderChange;
  tmPeers.Enabled := True;
  FillBuilders;
  UpdateLink;
  UpdateTransferBar;
  SetStatus(Format('Looking for EpubBuilder on the network (UDP %d)...', [LINK_DISCOVERY_PORT]));
end;

procedure TfrmManager.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  N: Integer;
begin
  N := Unfinished;
  if N = 0 then
    Exit;
  CanClose := TDialogServiceSync.MessageDialog(Format('%d transfer(s) not finished.', [N]) + sLineBreak +
    sLineBreak + 'Closing stops them: a book being fetched goes on from where it stopped the next time; a ' +
    'file being sent starts again.' + sLineBreak + sLineBreak + 'Stop them and close?', TMsgDlgType.mtWarning,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes;
end;

procedure TfrmManager.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FClosing := True;
  GManagerGone := True;
  tmPeers.Enabled := False;
  tmDark.Enabled := False;
  tmSite.Enabled := False;
  // each stops its call (closing the connection) and waits; the events it
  // queued and that have not run are dropped
  FreeAndNil(FPoller);
  FreeAndNil(FWorker);
  FreeAndNil(FFinder);
  FreeAndNil(FPairClient);
  SaveSettings;
  DebugLog('closed');
end;

procedure TfrmManager.FormDestroy(Sender: TObject);
begin
  GManagerGone := True;
  // the threads first (FormClose did it unless the window never closed)
  FreeAndNil(FPoller);
  FreeAndNil(FWorker);
  FreeAndNil(FFinder);
  FreeAndNil(FPairClient);
  FreeAndNil(FTargets);
  FreeAndNil(FTokens);
end;

procedure TfrmManager.SetStatus(const AText: string);
begin
  lblStatus.Text := AText;
  DebugLog(AText);
end;

function TfrmManager.TokenOf(const AId: string): string;
begin
  Result := '';
  if AId <> '' then
    Result := FTokens.Values[AId];
end;

procedure TfrmManager.SetTokenFor(const AId, AToken: string);
begin
  if AId = '' then
    Exit;
  // '' removes the line
  FTokens.Values[AId] := AToken;
  FTargets.SetToken(AId, AToken);
  SaveSettings;
end;

{ --- the builders }

procedure TfrmManager.FinderChange(Sender: TObject);
var
  P: TLinkPeer;
  I: Integer;
  Heard: Boolean;
begin
  if FClosing then
    Exit;
  FPeers := FFinder.Peers;
  Heard := False;
  for P in FPeers do
  begin
    FTargets.SetPlace(P.Id, P.Host, P.Port);
    if P.Id = FBuilderId then
    begin
      FBuilder := P;
      Heard := True;
    end;
  end;
  // closed or asleep: not asked until it is heard again (then at once)
  if (FBuilderId <> '') and (Heard <> FHeard) then
  begin
    FHeard := Heard;
    FPoller.SetHeard(Heard);
    if Heard then
      SetStatus(Format('EpubBuilder on %s is back.', [FBuilder.Name]))
    else
    begin
      FConnected := False;
      ClearProgress('Not heard');
      SetStatus(Format('EpubBuilder on %s is not heard any more (closed, or its computer asleep).',
        [FBuilder.Name]));
    end;
  end;
  // none chosen yet: the one of last time, else the only one heard
  if FBuilderId = '' then
  begin
    for I := 0 to High(FPeers) do
      if FPeers[I].Id = FLastId then
      begin
        FillBuilders;
        ChooseBuilder(FLastId);
        Exit;
      end;
    if Length(FPeers) = 1 then
    begin
      FillBuilders;
      ChooseBuilder(FPeers[0].Id);
      Exit;
    end;
  end;
  FillBuilders;
  UpdateLink;
end;

procedure TfrmManager.tmPeersTimer(Sender: TObject);
begin
  FinderChange(nil);
end;

procedure TfrmManager.FillBuilders;
var
  Texts: TStringList;
  Ids: TArray<string>;
  P: TLinkPeer;
  Heard: Boolean;
  S: string;
  I, Pick: Integer;
begin
  Texts := TStringList.Create;
  try
    Ids := nil;
    Heard := False;
    for P in FPeers do
    begin
      S := Format('%s (%s)', [P.Name, P.Host]);
      if TokenOf(P.Id) = '' then
        S := S + ' - not paired';
      Texts.Add(S);
      Ids := Ids + [P.Id];
      if P.Id = FBuilderId then
        Heard := True;
    end;
    // the one chosen stays in the list while it is not heard (asleep)
    if (FBuilderId <> '') and not Heard then
    begin
      Texts.Add(Format('%s (%s) - not heard now', [FBuilder.Name, FBuilder.Host]));
      Ids := Ids + [FBuilderId];
    end;
    if Texts.Count = 0 then
    begin
      Texts.Add('Looking for EpubBuilder on the network...');
      Ids := Ids + [''];
    end;
    Pick := 0;
    for I := 0 to High(Ids) do
      if (Ids[I] <> '') and (Ids[I] = FBuilderId) then
        Pick := I;
    // unchanged: left alone (no flicker while a list is open)
    if (cbBuilder.Items.Text = Texts.Text) and (cbBuilder.ItemIndex = Pick) then
      Exit;
    FFilling := True;
    try
      cbBuilder.Items.Assign(Texts);
      FComboIds := Ids;
      cbBuilder.ItemIndex := Pick;
    finally
      FFilling := False;
    end;
  finally
    Texts.Free;
  end;
end;

procedure TfrmManager.cbBuilderChange(Sender: TObject);
var
  I: Integer;
begin
  if FFilling or FClosing then
    Exit;
  I := cbBuilder.ItemIndex;
  if (I < 0) or (I > High(FComboIds)) or (FComboIds[I] = '') or (FComboIds[I] = FBuilderId) then
    Exit;
  ChooseBuilder(FComboIds[I]);
end;

procedure TfrmManager.ChooseBuilder(const AId: string);
var
  P: TLinkPeer;
begin
  FBuilderId := AId;
  for P in FPeers do
    if P.Id = AId then
      FBuilder := P;
  FConnected := False;
  FHeard := True;
  FLastError := '';
  FBooksFree := -1;
  FAudioFree := -1;
  FBooks := nil;
  FillBooks;
  lblSpace.Text := '';
  ClearProgress('Connecting...');
  mmLog.Lines.Clear;
  layPair.Visible := False;
  FreeAndNil(FPairClient);
  FGeneration := FPoller.Follow(AId);
  SaveSettings;
  FillBuilders;
  UpdateLink;
  if TokenOf(AId) = '' then
    SetStatus(Format('EpubBuilder on %s found - press Pair... to connect (once).', [FBuilder.Name]))
  else
    SetStatus(Format('EpubBuilder on %s (%s:%d).', [FBuilder.Name, FBuilder.Host, FBuilder.Port]));
end;

procedure TfrmManager.UpdateLink;
var
  Paired: Boolean;
begin
  Paired := TokenOf(FBuilderId) <> '';
  btnPair.Enabled := FBuilderId <> '';
  if Paired then
    btnPair.Text := 'Pair again...'
  else
    btnPair.Text := 'Pair...';
  if FBuilderId = '' then
    lblLink.Text := 'None heard yet'
  else if not Paired then
    lblLink.Text := 'Not paired yet'
  else if not FHeard then
    lblLink.Text := 'Not heard (closed or asleep)'
  else if FConnected then
    lblLink.Text := 'Connected'
  else if FLastError <> '' then
    lblLink.Text := 'No answer: ' + FLastError
  else
    lblLink.Text := 'Connecting...';
end;

procedure TfrmManager.btnPairClick(Sender: TObject);
var
  T: TLinkTarget;
begin
  if (FBuilderId = '') or not FTargets.Get(FBuilderId, T) or (T.Host = '') then
  begin
    SetStatus('No EpubBuilder heard yet: start it on a computer of this network.');
    Exit;
  end;
  // in an account of the link site: a builder of the same account needs
  // no code (it is asked first; the code is the way when it does not work)
  if FSiteClaimed and (FSiteKey <> '') and not FSiteBusy then
    PairWithTicket(T)
  else
    PairWithCode('');
end;

procedure TfrmManager.PairWithTicket(const ATarget: TLinkTarget);
var
  BuilderId, Host, SiteId, SiteKey, ClientName: string;
  Port: Integer;
begin
  BuilderId := FBuilderId;
  Host := ATarget.Host;
  Port := ATarget.Port;
  SiteId := FSiteId;
  SiteKey := FSiteKey;
  ClientName := FClientName;
  FSiteBusy := True;
  btnPair.Enabled := False;
  SetStatus('Asking link.epubunum.com for a ticket to pair without a code...');
  TThread.CreateAnonymousThread(
    procedure
    var
      Client: TLinkClient;
      Site: TLinkSite;
      Info: TJSONObject;
      Token, Why: string;
      Takes: Boolean;
    begin
      Token := '';
      Why := '';
      Client := nil;
      Site := nil;
      try
        try
          Client := TLinkClient.Create(Host, Port, ClientName, '');
          Info := Client.Info;
          try
            Takes := Info.GetValue<Boolean>('ticket', False);
          finally
            Info.Free;
          end;
          if not Takes then
            Why := 'that EpubBuilder takes no tickets (it is in no account, or is an older build)'
          else
          begin
            Site := TLinkSite.Create('BookManager', SiteId, SiteKey);
            Token := Client.PairTicket(Site.Ticket(BuilderId));
          end;
        except
          on E: Exception do
          begin
            Token := '';
            Why := E.Message;
          end;
        end;
      finally
        Site.Free;
        Client.Free;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not GManagerGone then
            TicketAnswered(BuilderId, Token, Why);
        end);
    end).Start;
end;

procedure TfrmManager.TicketAnswered(const ABuilderId, AToken, AWhy: string);
begin
  FSiteBusy := False;
  if FClosing then
    Exit;
  UpdateLink;
  // another builder was chosen meanwhile: nothing of this one is kept
  if ABuilderId <> FBuilderId then
    Exit;
  if AToken <> '' then
    PairDone(AToken, 'Paired without a code')
  else
  begin
    DebugLog('no pairing by ticket: ' + AWhy);
    PairWithCode('Without a code it did not work (' + AWhy + '). ');
  end;
end;

procedure TfrmManager.PairDone(const AToken, AHow: string);
begin
  FreeAndNil(FPairClient);
  layPair.Visible := False;
  SetTokenFor(FBuilderId, AToken);
  // from the start, now that it answers
  FGeneration := FPoller.Follow(FBuilderId);
  FConnected := False;
  FLastError := '';
  FillBuilders;
  UpdateLink;
  SetStatus(Format('%s with EpubBuilder on %s: books and audio can be sent, its books fetched.',
    [AHow, FBuilder.Name]));
end;

procedure TfrmManager.PairWithCode(const ANote: string);
var
  T: TLinkTarget;
begin
  if (FBuilderId = '') or not FTargets.Get(FBuilderId, T) or (T.Host = '') then
  begin
    SetStatus(ANote + 'No EpubBuilder heard yet: start it on a computer of this network.');
    Exit;
  end;
  FreeAndNil(FPairClient);
  FPairClient := TLinkClient.Create(T.Host, T.Port, FClientName, '');
  try
    FPairClient.PairAsk;
  except
    on E: Exception do
    begin
      FreeAndNil(FPairClient);
      SetStatus(ANote + 'Pairing did not start: ' + E.Message);
      Exit;
    end;
  end;
  // under the builder row, above the dark tabs' names
  layPair.Position.Y := layTop.Position.Y + 1;
  layPair.Visible := True;
  edCode.Text := '';
  edCode.SetFocus;
  SetStatus(ANote + Format('EpubBuilder on %s shows a code now: type it here (it works for 5 minutes).',
    [FBuilder.Name]));
end;

procedure TfrmManager.btnPairOkClick(Sender: TObject);
var
  Token, Code: string;
begin
  if FPairClient = nil then
    Exit;
  Code := Trim(edCode.Text);
  if Length(Code) <> 6 then
  begin
    SetStatus('The code has 6 digits.');
    Exit;
  end;
  try
    Token := FPairClient.PairConfirm(Code);
  except
    on E: Exception do
    begin
      SetStatus('Not paired: ' + E.Message);
      // refused on EpubBuilder, run out, five wrong codes: over - Pair...
      // asks again; a wrong code may be typed again
      if ContainsText(E.Message, 'refused') or ContainsText(E.Message, 'ask again') then
      begin
        FreeAndNil(FPairClient);
        layPair.Visible := False;
      end
      else
        edCode.SetFocus;
      Exit;
    end;
  end;
  PairDone(Token, 'Paired');
end;

procedure TfrmManager.btnPairCancelClick(Sender: TObject);
begin
  FreeAndNil(FPairClient);
  layPair.Visible := False;
  SetStatus('Not paired.');
end;

procedure TfrmManager.btnAccountClick(Sender: TObject);
begin
  if FSiteBusy then
    Exit;
  SetStatus('Asking link.epubunum.com...');
  AskSite(True);
end;

procedure TfrmManager.btnSiteCancelClick(Sender: TObject);
begin
  HideSite;
  SetStatus('The code is no longer waited for. Account... gives a new one.');
end;

procedure TfrmManager.HideSite;
begin
  tmSite.Enabled := False;
  laySite.Visible := False;
  FSiteCodeUntil := 0;
end;

procedure TfrmManager.tmSiteTimer(Sender: TObject);
begin
  if FClosing or FSiteBusy then
    Exit;
  if (FSiteCodeUntil = 0) or (Now > FSiteCodeUntil) then
  begin
    HideSite;
    SetStatus('The code ran out. Account... gives a new one.');
    Exit;
  end;
  AskSite(False);
end;

procedure TfrmManager.AskSite(AWantCode: Boolean);
var
  Id, Key: string;
begin
  if FSiteId = '' then
    FSiteId := LinkSiteId(TGUID.NewGuid.ToString);
  Id := FSiteId;
  Key := FSiteKey;
  FSiteBusy := True;
  TThread.CreateAnonymousThread(
    procedure
    var
      Site: TLinkSite;
      Others: TArray<TLinkSiteInstall>;
      Code: TLinkSiteCode;
      Claimed: Boolean;
      Why: string;
      Count: Integer;
    begin
      Code := Default(TLinkSiteCode);
      Claimed := False;
      Why := '';
      Count := 0;
      Others := nil;
      Site := nil;
      try
        try
          Site := TLinkSite.Create('BookManager', Id, Key);
          // no name is sent: the computer's is not the site's to know
          if Site.Key = '' then
            Site.Register('');
          try
            Claimed := Site.Status(Others);
          except
            on E: ELinkSite do
            begin
              if E.Status <> 401 then
                raise;
              // the site no longer knows this one: made known again, as
              // a new installation
              FreeAndNil(Site);
              Id := LinkSiteId(TGUID.NewGuid.ToString);
              Key := '';
              Site := TLinkSite.Create('BookManager', Id, '');
              Site.Register('');
              Claimed := Site.Status(Others);
            end;
          end;
          Count := Length(Others);
          if AWantCode and not Claimed then
            Code := Site.AskCode;
        except
          on E: Exception do
            Why := E.Message;
        end;
        // a key made is kept whatever came after
        if (Site <> nil) and (Site.Key <> '') then
          Key := Site.Key;
      finally
        Site.Free;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not GManagerGone then
            SiteAnswered(Id, Key, Claimed, Code, Count, Why);
        end);
    end).Start;
end;

procedure TfrmManager.SiteAnswered(const AId, AKey: string; AClaimed: Boolean; const ACode: TLinkSiteCode;
  AOthers: Integer; const AError: string);
begin
  FSiteBusy := False;
  if FClosing then
    Exit;
  if AKey <> '' then
  begin
    FSiteId := AId;
    FSiteKey := AKey;
  end;
  if AError <> '' then
  begin
    SaveSettings;
    // a code already shown stays: the next round asks again
    SetStatus('link.epubunum.com: ' + AError);
    Exit;
  end;
  FSiteClaimed := AClaimed;
  SaveSettings;
  if AClaimed then
  begin
    HideSite;
    SetStatus(Format('This BookManager is in your account at link.epubunum.com (with %d other installations): ' +
      'Pair... needs no code with an EpubBuilder of the same account.', [AOthers]));
    Exit;
  end;
  if ACode.Code = '' then
    // tmSite asked: not typed yet
    Exit;
  lblSite.Text := Format('Sign in at %s and type this code there:    %s', [ACode.Site, ACode.Code]);
  FSiteCodeUntil := Now + ACode.ExpiresIn / SecsPerDay;
  tmSite.Interval := ACode.Interval * 1000;
  // under the builder row, above the dark tabs' names
  laySite.Position.Y := layTop.Position.Y + 1;
  laySite.Visible := True;
  tmSite.Enabled := True;
  SetStatus(Format('Waiting for the code to be typed at %s (it works for %d minutes).',
    [ACode.Site, ACode.ExpiresIn div 60]));
end;

procedure TfrmManager.edCodeKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    Key := 0;
    btnPairOkClick(nil);
  end;
end;

{ --- sending }

procedure TfrmManager.DropEnter(Sender: TObject; const Data: TDragObject; const Point: TPointF);
begin
  if Length(Data.Files) > 0 then
    rcDrop.Stroke.Color := TAlphaColors.Dodgerblue;
end;

procedure TfrmManager.DropLeave(Sender: TObject);
begin
  rcDrop.Stroke.Color := TAlphaColors.Gray;
end;

procedure TfrmManager.DropOver(Sender: TObject; const Data: TDragObject; const Point: TPointF;
  var Operation: TDragOperation);
begin
  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Copy;
end;

procedure TfrmManager.DropDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
begin
  rcDrop.Stroke.Color := TAlphaColors.Gray;
  if Length(Data.Files) > 0 then
    SendPaths(Data.Files);
end;

procedure TfrmManager.btnAddFilesClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Books, audio and pictures|*.epub;*.mobi;*.prc;*.azw;*.azw3;*.m4b;*.m4a;*.aax;*.mp3;*.wav;' +
      '*.flac;*.ogg;*.opus;*.aac;*.jpg;*.jpeg;*.png;*.webp;*.gif;*.EPUB;*.MOBI;*.PRC;*.AZW;*.AZW3;*.M4B;*.M4A;' +
      '*.AAX;*.MP3;*.WAV;*.FLAC;*.OGG;*.OPUS;*.AAC;*.JPG;*.JPEG;*.PNG;*.WEBP;*.GIF|All files (*.*)|*.*';
    D.Options := D.Options + [TOpenOption.ofAllowMultiSelect];
    D.InitialDir := FAddFolder;
    if D.Execute then
    begin
      FAddFolder := ExtractFileDir(D.FileName);
      SaveSettings;
      SendPaths(D.Files.ToStringArray);
    end;
  finally
    D.Free;
  end;
end;

procedure TfrmManager.btnAddFolderClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FAddFolder;
  if not SelectDirectory('Folder to send to EpubBuilder', '', Folder) then
    Exit;
  Folder := ExcludeTrailingPathDelimiter(Folder);
  FAddFolder := ExtractFileDir(Folder);
  SaveSettings;
  SendPaths([Folder]);
end;

function TfrmManager.ReadyToSend: Boolean;
var
  Why: string;
begin
  Why := '';
  if FBuilderId = '' then
    Why := 'No EpubBuilder heard yet: start it on a computer of this network, then try again.'
  else if TokenOf(FBuilderId) = '' then
    Why := Format('Pair with EpubBuilder on %s first (Pair..., at the top).', [FBuilder.Name]);
  Result := Why = '';
  if not Result then
  begin
    SetStatus(Why);
    TDialogServiceSync.MessageDialog(Why, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
  end;
end;

procedure TfrmManager.SendPaths(const APaths: array of string);
var
  Items: TRouteItems;
  Skipped: TArray<string>;
  It: TRouteItem;
  S, Note: string;
  Job: TTransferJob;
  NeedBooks, NeedAudio: Int64;
  Short: Boolean;
begin
  if not ReadyToSend then
    Exit;
  try
    Items := RouteFiles(APaths, Skipped);
  except
    on E: Exception do
    begin
      // a folder that cannot be read, ...
      SetStatus('Not sent: ' + E.Message);
      Exit;
    end;
  end;
  for S in Skipped do
    DebugLog('send: left out: ' + S);
  Note := '';
  if Length(Skipped) = 1 then
    Note := ' Left out: ' + Skipped[0]
  else if Length(Skipped) > 1 then
    Note := Format(' %d left out (first: %s - all in the debug log).', [Length(Skipped), Skipped[0]]);
  if Length(Items) = 0 then
  begin
    SetStatus('Nothing to send.' + Note);
    Exit;
  end;
  // never fills the builder's drive: it refuses what would leave less than
  // its reserve; said before anything is sent
  NeedBooks := RouteSize(Items, 'book') + RouteSize(Items, 'cover');
  NeedAudio := RouteSize(Items, 'audio');
  Short := ((FBooksFree >= 0) and (NeedBooks > 0) and (NeedBooks + FReserve > FBooksFree)) or
    ((FAudioFree >= 0) and (NeedAudio > 0) and (NeedAudio + FReserve > FAudioFree));
  if Short and (TDialogServiceSync.MessageDialog(Format('These files need %s on EpubBuilder''s computer; ' +
    'it has %s free for books and %s for audio, and keeps %s for building.', [SizeText(NeedBooks + NeedAudio),
    SizeText(NonNeg(FBooksFree)), SizeText(NonNeg(FAudioFree)), SizeText(FReserve)]) + sLineBreak + sLineBreak +
    'Those that do not fit will be refused. Send anyway?', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes,
    TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) <> mrYes) then
  begin
    SetStatus('Not sent.');
    Exit;
  end;
  lbTransfers.BeginUpdate;
  try
    for It in Items do
    begin
      Job := Default(TTransferJob);
      Job.Way := twUpload;
      Job.BuilderId := FBuilderId;
      Job.FileName := It.FileName;
      Job.Kind := It.Kind;
      Job.Dir := It.Dir;
      if It.Dir <> '' then
        S := It.Dir + '/' + ExtractFileName(It.FileName)
      else
        S := ExtractFileName(It.FileName);
      AddTransfer(Job, S, It.Size);
    end;
  finally
    lbTransfers.EndUpdate;
  end;
  // dark: the list's new rows light at once
  if FDark then
    ApplyDark;
  tcMain.ActiveTab := tabSend;
  UpdateTransferBar;
  SetStatus(Format('%d file(s) to send to EpubBuilder on %s (%s).%s', [Length(Items), FBuilder.Name,
    SizeText(RouteSize(Items, '')), Note]));
end;

procedure TfrmManager.AddTransfer(const AJob: TTransferJob; const AName: string; ASize: Int64);
var
  R: TTransferRow;
  Job: TTransferJob;
begin
  Inc(FNextId);
  Job := AJob;
  Job.Id := FNextId;
  R := Default(TTransferRow);
  R.Id := Job.Id;
  R.Way := Job.Way;
  R.Name := AName;
  R.Kind := Job.Kind;
  R.Remote := Job.RemotePath;
  R.Size := ASize;
  R.State := tsWaiting;
  FRows := FRows + [R];
  lbTransfers.Items.Add(RowText(High(FRows)));
  FWorker.Add(Job);
end;

function TfrmManager.RowIndex(AId: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FRows) do
    if FRows[I].Id = AId then
      Exit(I);
  Result := -1;
end;

function TfrmManager.RowText(I: Integer): string;
var
  R: TTransferRow;
  What, State: string;
begin
  R := FRows[I];
  State := '';
  if R.Way = twUpload then
    What := 'Send ' + RouteKindText(R.Kind)
  else
    What := 'Fetch book';
  case R.State of
    tsWaiting:
      State := 'Waiting';
    tsRunning:
      if R.Size > 0 then
        State := Format('%.0f %%', [PercentOf(R.Done, R.Size)])
      else
        State := 'Starting';
    tsDone:
      if R.Way = twUpload then
        State := 'Sent'
      else
        State := 'Fetched';
    tsSkipped:
      if R.Way = twUpload then
        State := 'It has it'
      else
        State := 'Here already';
    tsFailed:
      State := 'FAILED';
    tsCancelled:
      State := 'Cancelled';
  end;
  Result := Format('%-12s %-12s %s  (%s)', [State, What, R.Name, SizeText(R.Size)]);
  if (R.State = tsFailed) and (R.Text <> '') then
    Result := Result + ' - ' + R.Text;
end;

procedure TfrmManager.ShowRow(I: Integer);
begin
  if (I >= 0) and (I < lbTransfers.Count) then
    lbTransfers.Items[I] := RowText(I);
end;

procedure TfrmManager.UpdateTransferBar;
var
  I, Waiting, Run: Integer;
  Secs: Double;
  S: string;
begin
  Waiting := 0;
  Run := -1;
  for I := 0 to High(FRows) do
    case FRows[I].State of
      tsWaiting:
        Inc(Waiting);
      tsRunning:
        Run := I;
    end;
  if Run < 0 then
  begin
    pbTransfer.Value := 0;
    if Waiting > 0 then
      lblTransfer.Text := Format('%d waiting', [Waiting])
    else
      lblTransfer.Text := 'Nothing being sent or fetched';
    Exit;
  end;
  pbTransfer.Value := PercentOf(FRows[Run].Done, FRows[Run].Size);
  S := FRows[Run].Name;
  Secs := (TThread.GetTickCount - FRunTick) / 1000;
  if (Secs >= 2) and (FRows[Run].Done > 0) then
    S := S + Format(' - %s/s', [SizeText(Round(FRows[Run].Done / Secs))]);
  if Waiting > 0 then
    S := S + Format(' (%d more waiting)', [Waiting]);
  lblTransfer.Text := S;
end;

function TfrmManager.Unfinished: Integer;
var
  R: TTransferRow;
begin
  Result := 0;
  for R in FRows do
    if R.State in [tsWaiting, tsRunning] then
      Inc(Result);
end;

procedure TfrmManager.btnCancelClick(Sender: TObject);
var
  I: Integer;
begin
  I := lbTransfers.ItemIndex;
  if (I < 0) or (I > High(FRows)) or not (FRows[I].State in [tsWaiting, tsRunning]) then
  begin
    SetStatus('Choose a transfer waiting or running in the list first.');
    Exit;
  end;
  // a waiting one is dropped at once; a running one ends in WorkerDone
  if FWorker.Cancel(FRows[I].Id) then
  begin
    FRows[I].State := tsCancelled;
    ShowRow(I);
    UpdateTransferBar;
  end;
end;

procedure TfrmManager.btnCancelAllClick(Sender: TObject);
var
  I: Integer;
begin
  FWorker.CancelAll;
  for I := 0 to High(FRows) do
    if FRows[I].State = tsWaiting then
    begin
      FRows[I].State := tsCancelled;
      ShowRow(I);
    end;
  UpdateTransferBar;
  SetStatus('Cancelled.');
end;

procedure TfrmManager.btnClearClick(Sender: TObject);
var
  Kept: TArray<TTransferRow>;
  R: TTransferRow;
  I: Integer;
begin
  Kept := nil;
  for R in FRows do
    if R.State in [tsWaiting, tsRunning] then
      Kept := Kept + [R];
  FRows := Kept;
  lbTransfers.BeginUpdate;
  try
    lbTransfers.Items.Clear;
    for I := 0 to High(FRows) do
      lbTransfers.Items.Add(RowText(I));
  finally
    lbTransfers.EndUpdate;
  end;
  // dark: the list's new rows light at once
  if FDark then
    ApplyDark;
  UpdateTransferBar;
end;

procedure TfrmManager.WorkerStart(AId: Integer);
var
  I: Integer;
begin
  if FClosing then
    Exit;
  I := RowIndex(AId);
  if I < 0 then
    Exit;
  FRows[I].State := tsRunning;
  FRows[I].Done := 0;
  FRunTick := TThread.GetTickCount;
  ShowRow(I);
  UpdateTransferBar;
end;

procedure TfrmManager.WorkerProgress(AId: Integer; ADone, ATotal: Int64);
var
  I: Integer;
begin
  if FClosing then
    Exit;
  I := RowIndex(AId);
  if I < 0 then
    Exit;
  FRows[I].Done := ADone;
  if ATotal > 0 then
    FRows[I].Size := ATotal;
  ShowRow(I);
  UpdateTransferBar;
end;

procedure TfrmManager.WorkerDone(AId: Integer; AOk, ASkipped: Boolean; const AText: string);
var
  I: Integer;
  Way: string;
begin
  if FClosing then
    Exit;
  I := RowIndex(AId);
  if I < 0 then
    Exit;
  FRows[I].Text := AText;
  if AOk and ASkipped then
    FRows[I].State := tsSkipped
  else if AOk then
  begin
    FRows[I].State := tsDone;
    FRows[I].Done := FRows[I].Size;
  end
  else if AText = 'cancelled' then
    FRows[I].State := tsCancelled
  else
    FRows[I].State := tsFailed;
  if FRows[I].Way = twUpload then
    Way := 'sent'
  else
    Way := 'fetched';
  if AOk then
    DebugLog(Format('%s: %s -> %s', [Way, FRows[I].Name, AText]))
  else
    SetStatus(Format('Not %s: %s - %s', [Way, FRows[I].Name, AText]));
  ShowRow(I);
  UpdateTransferBar;
  // a book fetched: here now (its .part note no longer needed)
  if AOk and (FRows[I].Way = twDownload) then
  begin
    try
      if FileExists(AText + '.part.from') then
        TFile.Delete(AText + '.part.from');
    except
      // harmless
    end;
    FillBooks;
  end;
  if Unfinished = 0 then
    SetStatus('All transfers finished.');
end;

{ --- the books made }

procedure TfrmManager.btnRefreshClick(Sender: TObject);
begin
  if FBuilderId = '' then
    Exit;
  FPoller.WantBooks;
  SetStatus('Asking EpubBuilder for its books...');
end;

function TfrmManager.LocalBook(const AName: string): string;
var
  C: Char;
  Name: string;
begin
  // the name only, made safe on this computer
  Name := '';
  for C in AName do
    if CharInSet(C, ['/', '\', ':', '*', '?', '"', '<', '>', '|']) or (C < ' ') then
      Name := Name + '_'
    else
      Name := Name + C;
  if (Trim(Name) = '') or (Name = '.') or (Name = '..') then
    Name := 'book.epub';
  Result := System.IOUtils.TPath.Combine(FFetchFolder, Name);
end;

procedure TfrmManager.ShowBooks(const AJson: string);
var
  V, E: TJSONValue;
  A: TJSONArray;
  B: TBuilderBook;
  List: TArray<TBuilderBook>;
begin
  List := nil;
  V := TJSONObject.ParseJSONValue(AJson);
  try
    A := nil;
    if (V is TJSONObject) and TJSONObject(V).TryGetValue<TJSONArray>('books', A) and (A <> nil) then
      for E in A do
        if E is TJSONObject then
        begin
          B := Default(TBuilderBook);
          TJSONObject(E).TryGetValue<string>('path', B.Path);
          TJSONObject(E).TryGetValue<string>('name', B.Name);
          TJSONObject(E).TryGetValue<Int64>('size', B.Size);
          TJSONObject(E).TryGetValue<string>('modified', B.Modified);
          if B.Path <> '' then
            List := List + [B];
        end;
  finally
    V.Free;
  end;
  // newest first
  TArray.Sort<TBuilderBook>(List, TComparer<TBuilderBook>.Construct(
    function(const X, Y: TBuilderBook): Integer
    begin
      Result := CompareStr(Y.Modified, X.Modified);
      if Result = 0 then
        Result := CompareText(X.Name, Y.Name);
    end));
  FBooks := List;
  FillBooks;
end;

procedure TfrmManager.FillBooks;
var
  Checked: TStringList;
  I, New: Integer;
  F, S, When: string;
begin
  Checked := TStringList.Create;
  try
    // the ticks kept across a refresh (by the book's path)
    for I := 0 to lbBooks.Count - 1 do
      if (lbBooks.ListItems[I] <> nil) and lbBooks.ListItems[I].IsChecked then
        Checked.Add(lbBooks.ListItems[I].TagString);
    New := 0;
    lbBooks.BeginUpdate;
    try
      lbBooks.Items.Clear;
      for I := 0 to High(FBooks) do
      begin
        F := LocalBook(FBooks[I].Name);
        FBooks[I].Here := FileExists(F) and (TFile.GetSize(F) = FBooks[I].Size);
        if not FBooks[I].Here then
          Inc(New);
        When := Copy(FBooks[I].Modified, 1, 16).Replace('T', ' ');
        if FBooks[I].Here then
          S := 'here      '
        else
          S := 'new       ';
        S := S + Format('%s  (%s, %s)', [FBooks[I].Name, SizeText(FBooks[I].Size), When]);
        lbBooks.Items.Add(S);
        lbBooks.ListItems[I].TagString := FBooks[I].Path;
        lbBooks.ListItems[I].IsChecked := Checked.IndexOf(FBooks[I].Path) >= 0;
      end;
    finally
      lbBooks.EndUpdate;
    end;
  finally
    Checked.Free;
  end;
  if FBuilderId = '' then
    tabBooks.Text := 'Books made'
  else
    tabBooks.Text := Format('Books made (%d, %d new)', [Length(FBooks), New]);
  // dark: the new rows light at once, the tab's name in layTabs
  if FDark then
    ApplyDark;
end;

procedure TfrmManager.btnFetchCheckedClick(Sender: TObject);
var
  Idx: TArray<Integer>;
  I: Integer;
begin
  Idx := nil;
  for I := 0 to Min(lbBooks.Count, Length(FBooks)) - 1 do
    if lbBooks.ListItems[I].IsChecked then
      Idx := Idx + [I];
  // none ticked: the one selected
  if (Length(Idx) = 0) and (lbBooks.ItemIndex >= 0) and (lbBooks.ItemIndex <= High(FBooks)) then
    Idx := [lbBooks.ItemIndex];
  if Length(Idx) = 0 then
  begin
    SetStatus('Tick the books to fetch (or choose one) first.');
    Exit;
  end;
  Fetch(Idx);
end;

procedure TfrmManager.btnFetchNewClick(Sender: TObject);
var
  Idx: TArray<Integer>;
  I: Integer;
begin
  Idx := nil;
  for I := 0 to High(FBooks) do
    if not FBooks[I].Here then
      Idx := Idx + [I];
  if Length(Idx) = 0 then
  begin
    SetStatus('Every book made is here already.');
    Exit;
  end;
  Fetch(Idx);
end;

procedure TfrmManager.btnFetchFolderClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FFetchFolder;
  if not SelectDirectory('Folder for the books fetched', '', Folder) then
    Exit;
  FFetchFolder := ExcludeTrailingPathDelimiter(Folder);
  lblFetchFolder.Text := 'Fetched to: ' + FFetchFolder;
  SaveSettings;
  FillBooks;
end;

procedure TfrmManager.CheckPart(I: Integer);
var
  Local, Part, Note, Was: string;
begin
  Local := LocalBook(FBooks[I].Name);
  Part := Local + '.part';
  Note := Part + '.from';
  Was := '';
  try
    if FileExists(Note) then
      Was := Trim(TFile.ReadAllText(Note));
    if FileExists(Part) and (Was <> Format('%d %s', [FBooks[I].Size, FBooks[I].Modified])) then
    begin
      // another build of the book (or not known): its bytes would mix
      TFile.Delete(Part);
      DebugLog('fetch: ' + Part + ' was of another build - started afresh');
    end;
    TFile.WriteAllText(Note, Format('%d %s', [FBooks[I].Size, FBooks[I].Modified]));
  except
    on E: Exception do
      DebugLog('fetch: ' + Note + ': ' + E.Message);
  end;
end;

procedure TfrmManager.Fetch(const AIndexes: TArray<Integer>);
var
  I, J, N, Here: Integer;
  Total, Free: Int64;
  Busy: Boolean;
  Job: TTransferJob;
  Todo: TArray<Integer>;
begin
  if not ReadyToSend then
    Exit;
  try
    ForceDirectories(FFetchFolder);
  except
    on E: Exception do
    begin
      SetStatus('Cannot make ' + FFetchFolder + ': ' + E.Message);
      Exit;
    end;
  end;
  Todo := nil;
  Total := 0;
  Here := 0;
  for I in AIndexes do
  begin
    if (I < 0) or (I > High(FBooks)) then
      Continue;
    if FBooks[I].Here then
    begin
      Inc(Here);
      Continue;
    end;
    // asked for already and not finished: once is enough
    Busy := False;
    for J := 0 to High(FRows) do
      if (FRows[J].Way = twDownload) and (FRows[J].Remote = FBooks[I].Path) and
        (FRows[J].State in [tsWaiting, tsRunning]) then
        Busy := True;
    if Busy then
      Continue;
    Todo := Todo + [I];
    Inc(Total, FBooks[I].Size);
  end;
  if Length(Todo) = 0 then
  begin
    if Here > 0 then
      SetStatus('Those books are here already.')
    else
      SetStatus('Those books are being fetched already.');
    Exit;
  end;
  // this computer's drive is not filled either
  Free := LinkFreeSpace(FFetchFolder);
  if (Free >= 0) and (Total + FETCH_RESERVE > Free) then
  begin
    SetStatus(Format('Not fetched: the books need %s, %s is free in %s (%s kept free).', [SizeText(Total),
      SizeText(Free), FFetchFolder, SizeText(FETCH_RESERVE)]));
    TDialogServiceSync.MessageDialog(lblStatus.Text, TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
    Exit;
  end;
  N := 0;
  lbTransfers.BeginUpdate;
  try
    for I in Todo do
    begin
      CheckPart(I);
      Job := Default(TTransferJob);
      Job.Way := twDownload;
      Job.BuilderId := FBuilderId;
      Job.FileName := LocalBook(FBooks[I].Name);
      Job.Kind := 'book';
      Job.RemotePath := FBooks[I].Path;
      AddTransfer(Job, FBooks[I].Name, FBooks[I].Size);
      Inc(N);
    end;
  finally
    lbTransfers.EndUpdate;
  end;
  // dark: the list's new rows light at once
  if FDark then
    ApplyDark;
  UpdateTransferBar;
  SetStatus(Format('%d book(s) to fetch (%s) into %s.', [N, SizeText(Total), FFetchFolder]));
end;

{ --- the poll }

procedure TfrmManager.Poll(const AResult: TLinkPollResult);
begin
  if FClosing or (AResult.BuilderId <> FBuilderId) or (AResult.Generation <> FGeneration) then
    Exit;
  if not AResult.Ok then
  begin
    // the builder no longer knows this program's token (its settings were
    // reset, or it was paired again elsewhere): pair again
    if StartsText('not paired - ', AResult.Error) and (TokenOf(FBuilderId) <> '') then
    begin
      SetTokenFor(FBuilderId, '');
      FillBuilders;
      SetStatus(Format('EpubBuilder on %s no longer knows this BookManager: press Pair... again.',
        [FBuilder.Name]));
    end;
    if FConnected then
    begin
      ClearProgress('No answer');
      DebugLog('poll: ' + AResult.Error);
    end;
    FConnected := False;
    FLastError := AResult.Error;
    UpdateLink;
    Exit;
  end;
  if not FConnected then
    DebugLog('poll: connected');
  FConnected := True;
  FLastError := '';
  ShowProgress(AResult.Status);
  if Length(AResult.Lines) > 0 then
    AddLogLines(AResult.Lines);
  if AResult.Space <> '' then
    ShowSpace(AResult.Space);
  if AResult.Books <> '' then
    ShowBooks(AResult.Books);
  UpdateLink;
end;

procedure TfrmManager.ClearProgress(const ATitle: string);
begin
  lblPTitle.Text := ATitle;
  lblPJob.Text := '';
  lblPTime.Text := '';
  lblPNow.Text := '';
  lblPSpeed.Text := '';
  pbBuild.Value := 0;
  tabProgress.Text := 'Progress';
  UpdateTabStrip;
end;

procedure TfrmManager.ShowProgress(const AJson: string);
var
  V: TJSONValue;
  O: TJSONObject;
  Busy, QueueRunning: Boolean;
  Waiting, Job, Jobs: Integer;
  Percent, Speed: Double;
  Title, Time, NowText, S: string;
begin
  V := TJSONObject.ParseJSONValue(AJson);
  try
    if not (V is TJSONObject) then
      Exit;
    O := TJSONObject(V);
    Busy := False;
    QueueRunning := False;
    Waiting := 0;
    Job := 0;
    Jobs := 0;
    Percent := 0;
    Speed := 0;
    Title := '';
    Time := '';
    NowText := '';
    O.TryGetValue<Boolean>('busy', Busy);
    O.TryGetValue<Boolean>('queueRunning', QueueRunning);
    O.TryGetValue<Integer>('waiting', Waiting);
    O.TryGetValue<Integer>('job', Job);
    O.TryGetValue<Integer>('jobs', Jobs);
    O.TryGetValue<Double>('percent', Percent);
    O.TryGetValue<Double>('speed', Speed);
    O.TryGetValue<string>('title', Title);
    O.TryGetValue<string>('time', Time);
    O.TryGetValue<string>('now', NowText);
  finally
    V.Free;
  end;
  if not Busy then
  begin
    ClearProgress('Idle');
    if Waiting > 0 then
      lblPJob.Text := Format('%d job(s) waiting in the queue', [Waiting]);
    Exit;
  end;
  lblPTitle.Text := Title;
  S := '';
  if Jobs > 0 then
    S := Format('Job %d of %d', [Job, Jobs]);
  if QueueRunning and (Waiting > 0) then
  begin
    if S <> '' then
      S := S + ' - ';
    S := S + Format('%d more waiting', [Waiting]);
  end;
  lblPJob.Text := S;
  pbBuild.Value := PercentOf(Round(Percent * 10), 1000);
  lblPTime.Text := Time;
  lblPNow.Text := NowText;
  if Speed > 0 then
    lblPSpeed.Text := Format('%.1fx real time', [Speed])
  else
    lblPSpeed.Text := '';
  tabProgress.Text := Format('Progress (%.0f %%)', [Percent]);
  UpdateTabStrip;
end;

procedure TfrmManager.AddLogLines(const ALines: TArray<string>);
var
  S: string;
begin
  mmLog.Lines.BeginUpdate;
  try
    for S in ALines do
      mmLog.Lines.Add(S);
    while mmLog.Lines.Count > LOG_KEEP do
      mmLog.Lines.Delete(0);
  finally
    mmLog.Lines.EndUpdate;
  end;
  mmLog.GoToTextEnd;
end;

procedure TfrmManager.ShowSpace(const AJson: string);
var
  V: TJSONValue;
  O: TJSONObject;
  Reserve: Int64;
begin
  V := TJSONObject.ParseJSONValue(AJson);
  try
    if not (V is TJSONObject) then
      Exit;
    O := TJSONObject(V);
    FBooksFree := -1;
    FAudioFree := -1;
    Reserve := LINK_RESERVE;
    O.TryGetValue<Int64>('books.free', FBooksFree);
    O.TryGetValue<Int64>('audio.free', FAudioFree);
    O.TryGetValue<Int64>('reserve', Reserve);
    FReserve := Reserve;
  finally
    V.Free;
  end;
  if (FBooksFree < 0) and (FAudioFree < 0) then
    lblSpace.Text := ''
  else
    lblSpace.Text := Format('EpubBuilder''s room: books %s, audio %s (%s kept for building)',
      [SizeText(NonNeg(FBooksFree - FReserve)), SizeText(NonNeg(FAudioFree - FReserve)), SizeText(FReserve)]);
end;

end.
