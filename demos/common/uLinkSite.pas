(* @abstract(The link site (https://link.epubunum.com) from a program: this
  installation made known, joined to its owner's account, and paired with
  the account's other installations without the 6-digit code.)

  Owner, 2026-11-23: an activation website for the installs that cannot
  show a code - "ONE activation scheme for every install that has no
  screen or wants no code: BookServer, a headless BookManager, the
  headless EpubBuilder, the Apple TV"; 2026-11-24: sign-in there is by a
  mailed link, an install without a screen joins with a one-time key made
  on the site, and the site keeps no addresses of installs (finding stays
  the local network's - uLink). The site's side is web/link (its README
  has the endpoints and the limits).

  How it goes:
  @orderedList(
    @item(@bold(Made known), once: @link(TLinkSite.Register) sends the
      install id - the id uLink announces - and gets a key. The caller
      keeps both in its settings.)
    @item(@bold(Joined to an account), one of two ways. Without a screen:
      the owner makes a one-time key on the site and starts the program
      with it; @link(TLinkSite.Claim) sends it. With a screen:
      @link(TLinkSite.AskCode) gives a code to show; the owner types it
      on the site; @link(TLinkSite.Status) is asked every
      TLinkSiteCode.Interval seconds until it says True.)
    @item(@bold(Paired without the code): the client asks
      @link(TLinkSite.Ticket) with the server's id (uLink's /info) and
      hands the ticket to the server (uLink's TLinkClient.PairTicket);
      the server's TLinkServer.TicketCheck asks @link(TLinkSite.Check)
      and gives its own token. The site is not needed again.))

  Every call BLOCKS (up to LINK_SITE_TIMEOUT twice): use it from a
  thread, or from uLink's server threads. A call that does not work
  raises @link(ELinkSite) with the site's own words. An object is used
  by one thread at a time.

  Nothing here is needed by a program that pairs with the code: a Steam
  program never needs an outside site. HTTPS is the system's own
  (System.Net.HttpClient) - no OpenSSL to ship. *)
unit uLinkSite;

interface

uses
  System.SysUtils, System.JSON;

const
  { The site. }
  LINK_SITE_URL = 'https://link.epubunum.com';
  { How long the site may take to be reached, and to answer, ms. }
  LINK_SITE_TIMEOUT = 15000;

type
  { A call to the link site that did not work: the site's reason, or
    what went wrong on the way. }
  ELinkSite = class(Exception)
  private
    { Backing field of Status. }
    FStatus: Integer;
  public
    { An error with the HTTP status it came with (0 = not reached). }
    constructor Create(AStatus: Integer; const AText: string);
    { The HTTP status: 0 the site was not reached, 401 it does not know
      this installation (register again, as a new one), 403 not allowed,
      409 already so, 429 too many. }
    property Status: Integer read FStatus;
  end;

  { An installation, as the site tells of it. }
  TLinkSiteInstall = record
    { Its id (lower case), the id it announces on the local network. }
    InstallId: string;
    { 'BookServer', 'BookManager', 'EpubBuilder' ... }
    App: string;
    { What its owner calls it ('' = nothing). }
    Title: string;
    { Its system ('' = not said). }
    Os: string;
    { Title and the program, for a list: 'Attic server (BookServer)'. }
    function Shown: string;
  end;

  { A code to show (TLinkSite.AskCode). }
  TLinkSiteCode = record
    { The code, as it is shown: 'ABCD-EFGH'. }
    Code: string;
    { The site's address with the code in it (for a QR code). }
    Url: string;
    { The site's address to show beside the code ('link.epubunum.com'). }
    Site: string;
    { The code works this long, s. }
    ExpiresIn: Integer;
    { Ask Status this often, s. }
    Interval: Integer;
  end;

  { This installation at the link site. }
  TLinkSite = class
  private
    { 'BookServer', 'BookManager', 'EpubBuilder' ... }
    FApp: string;
    { Backing field of InstallId. }
    FInstallId: string;
    { Backing field of Key. }
    FKey: string;
    { POSTs ABody (freed here) to APath of the site: the answer's JSON,
      to be freed. Raises ELinkSite when the site was not reached, did
      not answer JSON, or refused. }
    function Post(const APath: string; ABody: TJSONObject): TJSONObject;
    { A request's body with this installation's id and key. Raises
      ELinkSite when it has no key yet (Register first). }
    function Signed: TJSONObject;
    { An installation out of the site's JSON. }
    class function InstallOf(AJson: TJSONObject): TLinkSiteInstall; static;
  public
    { This installation.
      @param(AApp the program: 'BookServer', 'BookManager' ...)
      @param(AInstallId its id - the id uLink announces (a UUID; braces
        and capitals do not matter))
      @param(AKey the key Register once gave, from the settings ('' =
        not made known yet)) }
    constructor Create(const AApp, AInstallId, AKey: string);
    { Makes the installation known to the site, once: the key to keep
      (also in Key). Status 409: the site knows the id already and the
      key was lost - only a new id helps.
      @param(ATitle what the owner calls it ('' = nothing; never the
        computer's own name unless the owner chose it)) }
    function Register(const ATitle: string): string;
    { Joins the owner's account with the one-time key made on the site
      (as typed: capitals and dashes do not matter). Status 403: the key
      is wrong, used or too old. }
    procedure Claim(const AActivationKey: string);
    { A code to show, for the owner to type on the site. A new one ends
      the one before. Status 409: it has an account already. }
    function AskCode: TLinkSiteCode;
    { Whether an account has this installation.
      @param(AOthers the account's other installations: those a ticket
        can be asked for, or taken from) }
    function Status(out AOthers: TArray<TLinkSiteInstall>): Boolean;
    { A ticket to pair with the installation AServerId of the same
      account (the id of its /info), good for two minutes, once. Status
      403: it is not one of the account's, or this one has no account. }
    function Ticket(const AServerId: string): string;
    { Whether a ticket a client handed over is good: the client it was
      given to. Status 403: it is not (not for this installation, used,
      too old). }
    function Check(const ATicket: string): TLinkSiteInstall;
    { Leaves the account (it stays known to the site). }
    procedure Release;
    { The id, lower case, without braces. }
    property InstallId: string read FInstallId;
    { The key ('' = not made known yet). }
    property Key: string read FKey;
  end;

{ An install id as the site writes it: lower case, without braces. }
function LinkSiteId(const AId: string): string;

{ Opens a page of the link site in the system's own browser - the page a
  code is typed on, with the code in it already (TLinkSiteCode.Url).
  Owner, 2026-11-24: "It would be nicer if there was a button that
  automatically opened your default web browser at the desired page."
  Only an address of the site itself, made of plain characters, is
  opened (it comes from the site's answer and goes to the system's
  shell). Windows: the shell's "open"; macOS: open; Linux: xdg-open.
  @param(AUrl the address)
  @returns(True when the system took it - not whether a browser showed) }
function LinkSiteOpen(const AUrl: string): Boolean;

implementation

uses
  {$IFDEF MSWINDOWS} Winapi.Windows, Winapi.ShellAPI, {$ENDIF}
  {$IFDEF POSIX} Posix.Stdlib, {$ENDIF}
  System.Classes, System.Net.HttpClient, System.Net.URLClient,
  // TJSONArray's inline getters expand only with it (H2443)
  System.Generics.Collections,
  // THTTPClient.SetContentType's inline body expands only with it (H2443)
  System.NetConsts,
  uMachine;

function LinkSiteId(const AId: string): string;
begin
  Result := LowerCase(Trim(AId));
  Result := StringReplace(StringReplace(Result, '{', '', [rfReplaceAll]), '}', '', [rfReplaceAll]);
end;

function LinkSiteOpen(const AUrl: string): Boolean;
const
  { What an address of the site is made of: nothing a shell reads. }
  PLAIN = ['A'..'Z', 'a'..'z', '0'..'9', ':', '/', '?', '&', '=', '.', '_', '-', '%'];
var
  I: Integer;
  {$IFDEF POSIX}
  Line: UTF8String;
  {$ENDIF}
begin
  Result := False;
  if (AUrl <> LINK_SITE_URL) and (Copy(AUrl, 1, Length(LINK_SITE_URL) + 1) <> LINK_SITE_URL + '/') then
    Exit;
  if Length(AUrl) > 200 then
    Exit;
  for I := 1 to Length(AUrl) do
    if not CharInSet(AUrl[I], PLAIN) then
      Exit;
  {$IF Defined(MSWINDOWS)}
  Result := ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL) > 32;
  {$ELSEIF Defined(MACOS)}
  Line := UTF8String('open "' + AUrl + '"');
  Result := _system(MarshaledAString(Line)) = 0;
  {$ELSEIF Defined(POSIX)}
  // in the background: the browser may stay open as long as it likes
  Line := UTF8String('xdg-open "' + AUrl + '" >/dev/null 2>&1 &');
  Result := _system(MarshaledAString(Line)) = 0;
  {$ENDIF}
end;

{ ELinkSite }

constructor ELinkSite.Create(AStatus: Integer; const AText: string);
begin
  inherited Create(AText);
  FStatus := AStatus;
end;

{ TLinkSiteInstall }

function TLinkSiteInstall.Shown: string;
begin
  if Title <> '' then
    Result := Title + ' (' + App + ')'
  else
    Result := App;
end;

{ TLinkSite }

constructor TLinkSite.Create(const AApp, AInstallId, AKey: string);
begin
  inherited Create;
  FApp := AApp;
  FInstallId := LinkSiteId(AInstallId);
  FKey := AKey;
end;

function TLinkSite.Post(const APath: string; ABody: TJSONObject): TJSONObject;
var
  Client: THTTPClient;
  Source: TStringStream;
  Resp: IHTTPResponse;
  Value: TJSONValue;
  HttpStatus: Integer;
  Why: string;
begin
  Result := nil;
  Source := nil;
  Client := nil;
  try
    try
      Source := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
    finally
      ABody.Free;
    end;
    try
      Client := THTTPClient.Create;
      Client.UserAgent := FApp;
      Client.ContentType := 'application/json';
      Client.ConnectionTimeout := LINK_SITE_TIMEOUT;
      Client.ResponseTimeout := LINK_SITE_TIMEOUT;
      Resp := Client.Post(LINK_SITE_URL + APath, Source);
      HttpStatus := Resp.StatusCode;
      Value := TJSONObject.ParseJSONValue(Resp.ContentAsString(TEncoding.UTF8));
    except
      on E: Exception do
        raise ELinkSite.Create(0, 'the link site was not reached: ' + E.Message);
    end;
  finally
    // the answer goes before the client it came from
    Resp := nil;
    Client.Free;
    Source.Free;
  end;
  if not (Value is TJSONObject) then
  begin
    Value.Free;
    raise ELinkSite.Create(HttpStatus, Format('the link site answered %d', [HttpStatus]));
  end;
  Result := TJSONObject(Value);
  if (HttpStatus <> 200) or not Result.GetValue<Boolean>('ok', False) then
  begin
    Why := Result.GetValue<string>('error', '');
    if Why = '' then
      Why := Format('the link site answered %d', [HttpStatus]);
    FreeAndNil(Result);
    raise ELinkSite.Create(HttpStatus, Why);
  end;
end;

function TLinkSite.Signed: TJSONObject;
begin
  if (FInstallId = '') or (FKey = '') then
    raise ELinkSite.Create(401, 'this installation is not known to the link site yet');
  Result := TJSONObject.Create;
  Result.AddPair('install_id', FInstallId);
  Result.AddPair('key', FKey);
end;

class function TLinkSite.InstallOf(AJson: TJSONObject): TLinkSiteInstall;
begin
  Result := Default(TLinkSiteInstall);
  if AJson = nil then
    Exit;
  // a value the site left out is JSON's null: '' here
  Result.InstallId := AJson.GetValue<string>('install_id', '');
  Result.App := AJson.GetValue<string>('app', '');
  if not (AJson.GetValue('label') is TJSONNull) then
    Result.Title := AJson.GetValue<string>('label', '');
  if not (AJson.GetValue('os') is TJSONNull) then
    Result.Os := AJson.GetValue<string>('os', '');
end;

function TLinkSite.Register(const ATitle: string): string;
var
  Body, Answer: TJSONObject;
begin
  if FInstallId = '' then
    raise ELinkSite.Create(400, 'no install id to make known');
  Body := TJSONObject.Create;
  Body.AddPair('install_id', FInstallId);
  Body.AddPair('app', FApp);
  if Trim(ATitle) <> '' then
    Body.AddPair('label', Trim(ATitle));
  // what the machine is - never what it is called
  Body.AddPair('os', MachineOs);
  Answer := Post('/api/register.php', Body);
  try
    Result := Answer.GetValue<string>('key', '');
  finally
    Answer.Free;
  end;
  if Result = '' then
    raise ELinkSite.Create(200, 'no key in the link site''s answer');
  FKey := Result;
end;

procedure TLinkSite.Claim(const AActivationKey: string);
var
  Body: TJSONObject;
begin
  Body := Signed;
  Body.AddPair('activation_key', Trim(AActivationKey));
  Post('/api/claim.php', Body).Free;
end;

function TLinkSite.AskCode: TLinkSiteCode;
var
  Answer: TJSONObject;
begin
  Result := Default(TLinkSiteCode);
  Answer := Post('/api/code.php', Signed);
  try
    Result.Code := Answer.GetValue<string>('code', '');
    Result.Url := Answer.GetValue<string>('url', '');
    Result.Site := Answer.GetValue<string>('site', '');
    Result.ExpiresIn := Answer.GetValue<Integer>('expires_in', 600);
    Result.Interval := Answer.GetValue<Integer>('interval', 5);
  finally
    Answer.Free;
  end;
  if Result.Code = '' then
    raise ELinkSite.Create(200, 'no code in the link site''s answer');
  if Result.Interval < 1 then
    Result.Interval := 5;
end;

function TLinkSite.Status(out AOthers: TArray<TLinkSiteInstall>): Boolean;
var
  Answer: TJSONObject;
  List: TJSONArray;
  I: Integer;
begin
  AOthers := nil;
  Answer := Post('/api/status.php', Signed);
  try
    Result := Answer.GetValue<Boolean>('claimed', False);
    if Answer.TryGetValue<TJSONArray>('installs', List) then
    begin
      SetLength(AOthers, List.Count);
      for I := 0 to List.Count - 1 do
        if List.Items[I] is TJSONObject then
          AOthers[I] := InstallOf(TJSONObject(List.Items[I]))
        else
          AOthers[I] := Default(TLinkSiteInstall);
    end;
  finally
    Answer.Free;
  end;
end;

function TLinkSite.Ticket(const AServerId: string): string;
var
  Body, Answer: TJSONObject;
begin
  Body := Signed;
  Body.AddPair('server', LinkSiteId(AServerId));
  Answer := Post('/api/ticket.php', Body);
  try
    Result := Answer.GetValue<string>('ticket', '');
  finally
    Answer.Free;
  end;
  if Result = '' then
    raise ELinkSite.Create(200, 'no ticket in the link site''s answer');
end;

function TLinkSite.Check(const ATicket: string): TLinkSiteInstall;
var
  Body, Answer, Client: TJSONObject;
begin
  Body := Signed;
  Body.AddPair('ticket', Trim(ATicket));
  Answer := Post('/api/check.php', Body);
  try
    Client := nil;
    Answer.TryGetValue<TJSONObject>('client', Client);
    Result := InstallOf(Client);
  finally
    Answer.Free;
  end;
  if Result.InstallId = '' then
    raise ELinkSite.Create(200, 'no client in the link site''s answer');
end;

procedure TLinkSite.Release;
begin
  Post('/api/release.php', Signed).Free;
end;

end.
