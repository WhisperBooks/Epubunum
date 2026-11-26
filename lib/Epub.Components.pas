(* @abstract(@link(TCustomEpub): the framework-free base of the EpubUnum
  component - a book opened by setting FileName and Active.)

  Framework units (Epub.FMX, later a VCL one) only publish the properties
  and show handler exceptions their way. Opening is quick (the ZIP
  directory and the package documents), so it happens on the calling
  thread; the text (TEpubBook.Words) and each document's layout are read
  when first asked for.

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Components;

{$I Epub.inc}

interface

uses
  SysUtils, Classes,
  Epub.Zip, Epub.Book;

{$ifndef FPC}
const
  { Platforms of the EpubUnum components (ComponentPlatformsAttribute):
    Windows (the owner builds in the 32-bit IDE), macOS, Linux and
    Android - the packages' platforms. iOS can follow (EpubUnum is pure
    Pascal). }
  EPUB_COMPONENT_PLATFORMS = pidWin32 or pidWin64 or pidOSX64 or pidOSXArm64 or pidLinux64 or
    pidAndroidArm64;
{$endif}

type
  { Opening failed; AMessage says why (not an EPUB, damaged, copy
    protected, ...). }
  TEpubErrorEvent = procedure(Sender: TObject; const AMessage: string) of object;

  { An EPUB book as a component: set @link(FileName) and @link(Active). }
  TCustomEpub = class(TComponent)
  private
    { Backing field of @link(Active). }
    FActive: Boolean;
    { Active as read from the form file (applied in Loaded). }
    FStreamedActive: Boolean;
    { Backing field of @link(FileName). }
    FFileName: string;
    { Backing field of @link(Book). }
    FBook: TEpubBook;
    { Backing field of @link(BookSerial). }
    FBookSerial: Integer;
    { Backing field of @link(OnOpen). }
    FOnOpen: TNotifyEvent;
    { Backing field of @link(OnOpenFailed). }
    FOnOpenFailed: TEpubErrorEvent;
    { Backing field of @link(OnClose). }
    FOnClose: TNotifyEvent;
    { Opens or closes (a failure goes to OnOpenFailed). }
    procedure SetActive(const AValue: Boolean);
    { Changes the file (reopens when active). }
    procedure SetFileName(const AValue: string);
  protected
    { Applies Active read from the form file. }
    procedure Loaded; override;
    { Shows an exception an event handler raised (framework units override
      it; here it is dropped). }
    procedure ShowHandlerException(E: Exception); virtual;
  public
    { Closes the book. }
    destructor Destroy; override;
    { Opens @link(FileName).
      @raises(EEpubError when it cannot be opened - @link(Active) := True
        reports through OnOpenFailed instead.) }
    procedure Open;
    { Makes ABook the open book - one opened elsewhere, in a thread, so
      that the window is not held while a long book is read (zip 327).
      Call it from the thread the component is used in. The book open
      before is closed; ABook is the component's from now on (it frees
      it); @link(FileName) becomes the book's; OnOpen follows. Nil only
      closes. }
    procedure Adopt(ABook: TEpubBook);
    { Closes the book. }
    procedure Close;
    { The open book (nil when closed). }
    property Book: TEpubBook read FBook;
    { A number that changes every time a book is opened or closed: what was
      made from @link(Book) (a view's layout, word indexes) belongs to the
      book only while this is the same. (Comparing Book itself is not
      enough: a new book can get the address of the one just freed.) }
    property BookSerial: Integer read FBookSerial;
    { The book is open (setting it opens or closes; a failure goes to
      OnOpenFailed). At design time the value is only stored. }
    property Active: Boolean read FActive write SetActive default False;
    { The .epub file. }
    property FileName: string read FFileName write SetFileName;
    { The book was opened. }
    property OnOpen: TNotifyEvent read FOnOpen write FOnOpen;
    { Opening failed (Active := True). }
    property OnOpenFailed: TEpubErrorEvent read FOnOpenFailed write FOnOpenFailed;
    { The book was closed. }
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

destructor TCustomEpub.Destroy;
begin
  Close;
  inherited;
end;

procedure TCustomEpub.Loaded;
begin
  inherited;
  if csDesigning in ComponentState then
    FActive := FStreamedActive
  else if FStreamedActive then
    SetActive(True);
  FStreamedActive := False;
end;

procedure TCustomEpub.ShowHandlerException(E: Exception);
begin
  // framework units override this
end;

procedure TCustomEpub.SetActive(const AValue: Boolean);
begin
  if csLoading in ComponentState then
  begin
    FStreamedActive := AValue;
    Exit;
  end;
  if csDesigning in ComponentState then
  begin
    FActive := AValue;
    Exit;
  end;
  if AValue = FActive then
    Exit;
  if AValue then
  begin
    try
      Open;
    except
      on E: Exception do
        if Assigned(FOnOpenFailed) then
          try
            FOnOpenFailed(Self, E.Message);
          except
            on H: Exception do
              ShowHandlerException(H);
          end;
    end;
  end
  else
    Close;
end;

procedure TCustomEpub.SetFileName(const AValue: string);
var
  WasActive: Boolean;
begin
  if AValue = FFileName then
    Exit;
  WasActive := FActive and not (csDesigning in ComponentState);
  if WasActive then
    Close;
  FFileName := AValue;
  if WasActive then
    SetActive(True);
end;

procedure TCustomEpub.Open;
begin
  if FBook <> nil then
    Exit;
  if FFileName = '' then
    raise EEpubError.Create('No FileName set');
  FBook := TEpubBook.Create(FFileName);
  Inc(FBookSerial);
  FActive := True;
  if Assigned(FOnOpen) then
    try
      FOnOpen(Self);
    except
      on E: Exception do
        ShowHandlerException(E);
    end;
end;

procedure TCustomEpub.Adopt(ABook: TEpubBook);
begin
  Close;
  if ABook = nil then
    Exit;
  FBook := ABook;
  FFileName := ABook.FileName;
  Inc(FBookSerial);
  FActive := True;
  if Assigned(FOnOpen) then
    try
      FOnOpen(Self);
    except
      on E: Exception do
        ShowHandlerException(E);
    end;
end;

procedure TCustomEpub.Close;
var
  WasOpen: Boolean;
begin
  WasOpen := FBook <> nil;
  FreeAndNil(FBook);
  if WasOpen then
    Inc(FBookSerial);
  FActive := False;
  if WasOpen and Assigned(FOnClose) and not (csDestroying in ComponentState) then
    try
      FOnClose(Self);
    except
      on E: Exception do
        ShowHandlerException(E);
    end;
end;

end.
