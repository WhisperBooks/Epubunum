{ @abstract(Main form of EpubReader: open an EPUB, read it in a Skia view,
  and - for a book with media overlays - play its audio with the words
  highlighted as they are read.)

  The book component (EpubUnum1), the view (View1) and their events are
  set up in uMain.fmx. The sound is FFmpegAPI's TFFmpegAudioPlayer
  (TFFMpegAPI, installed separately): the book's audio file streamed by
  FFmpeg to the platform's output (WASAPI, PulseAudio), and its clock - the
  sound really being heard - picks the clip to highlight. No FFmpeg: the
  book still reads, without sound.

  No main menu (on Linux FMX's GTK menu bar shows only first letters, and
  SteamOS runs every window full screen): a tool bar of icon buttons, as
  Sprite3D's results view draws them (a TPath icon in a TButton, coloured
  by the style), and keys - P play / pause, Ctrl+O open, Ctrl+Plus /
  Ctrl+Minus text size; the view scrolls with the wheel, the arrows, Page
  Up / Page Down and Space. A click on a word starts the audio there. }
unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.IOUtils, System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts,
  FMX.ListBox, FMX.Controls.Presentation, FMX.Objects,
  Epub.Zip, Epub.Layout, Epub.Book, Epub.Components, Epub.FMX, Epub.FMX.View,
  // sound: DCUs of TFFMpegAPI's runtime package FFmpegAPI
  FFmpeg.API, FFmpeg.Player;

type
  { The reader's main form. }
  TfrmMain = class(TForm)
    { The book. }
    EpubUnum1: TEpubUnum;
    { The page view (Skia). }
    View1: TEpubView;
    { Tool bar (its buttons are made in FormCreate). }
    layTop: TLayout;
    { Title, document and playing state. }
    lblStatus: TLabel;
    { Table of contents. }
    lbToc: TListBox;
    { Between contents and page. }
    Splitter1: TSplitter;
    { Follows the audio: highlights the clip being read. }
    tmPlay: TTimer;
    { Chooses the book. }
    dlgOpen: TOpenDialog;
    { Sets up the temporary audio folder; opens a book named on the
      command line. }
    procedure FormCreate(Sender: TObject);
    { Stops the audio and removes the temporary files. }
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    { Keys: P, Ctrl+O, Ctrl+Plus / Ctrl+Minus. }
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    { Chooses and opens a book. }
    procedure btnOpenClick(Sender: TObject);
    { Previous document. }
    procedure btnPrevClick(Sender: TObject);
    { Next document. }
    procedure btnNextClick(Sender: TObject);
    { Previous clip (sentence). }
    procedure btnPrevClipClick(Sender: TObject);
    { Next clip (sentence). }
    procedure btnNextClipClick(Sender: TObject);
    { Play / pause. }
    procedure btnPlayClick(Sender: TObject);
    { Smaller text. }
    procedure btnSmallerClick(Sender: TObject);
    { Larger text. }
    procedure btnLargerClick(Sender: TObject);
    { The book is open: contents, first document, clip map. }
    procedure EpubUnum1Open(Sender: TObject);
    { The book could not be opened. }
    procedure EpubUnum1OpenFailed(Sender: TObject; const AMessage: string);
    { A contents entry was chosen. }
    procedure lbTocChange(Sender: TObject);
    { A word was clicked: play from its clip. }
    procedure View1WordClick(Sender: TObject; AWord: Integer);
    { Another document is shown. }
    procedure View1DocumentChange(Sender: TObject);
    { Follows the audio. }
    procedure tmPlayTimer(Sender: TObject);
  private
    { Opens a book. }
    btnOpen: TButton;
    { Previous document of the reading order. }
    btnPrev: TButton;
    { Previous clip. }
    btnPrevClip: TButton;
    { Plays / pauses the book's audio (media overlays). }
    btnPlay: TButton;
    { Next clip. }
    btnNextClip: TButton;
    { Next document of the reading order. }
    btnNext: TButton;
    { Smaller text. }
    btnSmaller: TButton;
    { Larger text. }
    btnLarger: TButton;
    { FFmpeg (nil when its libraries are not found: no sound). }
    FFFmpeg: TFFmpegLibrary;
    { The sound (nil without FFmpeg). }
    FPlayer: TFFmpegAudioPlayer;
    { Why there is no sound / it is silent ('' when all is well). }
    FSoundNote: string;
    { Folder the audio files are extracted to. }
    FAudioFolder: string;
    { Archive path of the audio file in the player, '' when none. }
    FAudioPath: string;
    { The clip highlighted, -1 when none. }
    FClip: Integer;
    { The audio is playing. }
    FPlaying: Boolean;
    { First word of each clip (-1 when it has none). }
    FClipFirst: TArray<Integer>;
    { Last word of each clip. }
    FClipLast: TArray<Integer>;
    { Opens AFileName. }
    procedure OpenBook(const AFileName: string);
    { Plays from the start of clip AClip. }
    procedure StartClip(AClip: Integer);
    { Stops the audio (the highlight stays). }
    procedure StopPlaying;
    { First clip of document ADoc, -1 when none. }
    function FirstClipOfDocument(ADoc: Integer): Integer;
    { The clip reading word AWord, -1 when none. }
    function ClipOfWord(AWord: Integer): Integer;
    { Next / previous linear document from ADoc, -1 when none. }
    function StepDocument(ADoc, AStep: Integer): Integer;
    { Enables the buttons and writes the status. }
    procedure UpdateControls;
    { Makes the tool bar's buttons. }
    procedure BuildToolBar;
    { An icon button (Sprite3D's way: a TPath in a TButton). }
    function AddIconButton(const AIcon, AHint: string; AOnClick: TNotifyEvent): TButton;
    { A text button. }
    function AddTextButton(const AText, AHint: string; AOnClick: TNotifyEvent): TButton;
    { An icon takes the colour the style gives the button's text. }
    procedure IconButtonApplyStyle(Sender: TObject);
    { Shows AIcon on button AButton. }
    procedure SetIcon(AButton: TButton; const AIcon: string);
    { Loads FFmpeg and the sound output (FSoundNote says what is missing). }
    procedure StartSound;
  end;

var
  { The main form. }
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  FmxWineCanvas, FmxSkiaCanvas;

const
  { Text size step, px. }
  SIZE_STEP = 2;
  // The tool bar's icons: SVG path data in a 24 by 24 box (Sprite3D's
  // transport icons; the folder is new). FMX.Objects' TPath (the shape)
  // hides System.IOUtils' TPath (file names): both are written qualified.
  { Open: a folder. }
  ICON_OPEN = 'M3 6h6l2 2h10v10H3z';
  { Previous document: bar and two triangles pointing left. }
  ICON_FIRST = 'M5 6h2v12H5z M8 12l6-6v12z M14 12l6-6v12z';
  { Previous clip: triangle left and bar. }
  ICON_PREVIOUS = 'M7 12l7-6v12z M15 6h2v12h-2z';
  { Play: triangle right. }
  ICON_PLAY = 'M8 5v14l11-7z';
  { Pause: two bars. }
  ICON_PAUSE = 'M6 5h4v14H6z M14 5h4v14h-4z';
  { Next clip: bar and triangle right. }
  ICON_NEXT = 'M7 6h2v12H7z M10 6v12l7-6z';
  { Next document: two triangles right and bar. }
  ICON_LAST = 'M4 6v12l6-6z M10 6v12l6-6z M17 6h2v12h-2z';
  { Icon box, px. }
  ICON_SIZE = 24;
  { Button width, px. }
  BUTTON_WIDTH = 36;

function TfrmMain.AddIconButton(const AIcon, AHint: string; AOnClick: TNotifyEvent): TButton;
var
  Icon: FMX.Objects.TPath;
begin
  Result := TButton.Create(Self);
  Result.Parent := layTop;
  // left-aligned controls are ordered by their X: each goes after the last
  Result.Position.X := layTop.ChildrenCount * 1000;
  Result.Align := TAlignLayout.Left;
  Result.Width := BUTTON_WIDTH;
  Result.Margins.Left := 2;
  Result.Margins.Top := 6;
  Result.Margins.Bottom := 6;
  Result.Text := '';
  Result.Hint := AHint;
  Result.ShowHint := True;
  Result.OnClick := AOnClick;
  Result.OnApplyStyleLookup := IconButtonApplyStyle;
  Icon := FMX.Objects.TPath.Create(Self);
  Icon.Parent := Result;
  Icon.Align := TAlignLayout.Center;
  Icon.Width := ICON_SIZE;
  Icon.Height := ICON_SIZE;
  Icon.WrapMode := TPathWrapMode.Original;
  Icon.Data.Data := AIcon;
  Icon.Stroke.Kind := TBrushKind.None;
  Icon.Fill.Color := TAlphaColors.Black;   // the style's colour once styled
  Icon.HitTest := False;
  Result.TagObject := Icon;
end;

function TfrmMain.AddTextButton(const AText, AHint: string; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := layTop;
  Result.Position.X := layTop.ChildrenCount * 1000;
  Result.Align := TAlignLayout.Left;
  Result.Width := BUTTON_WIDTH;
  Result.Margins.Left := 2;
  Result.Margins.Top := 6;
  Result.Margins.Bottom := 6;
  Result.Text := AText;
  Result.Hint := AHint;
  Result.ShowHint := True;
  Result.OnClick := AOnClick;
end;

procedure TfrmMain.IconButtonApplyStyle(Sender: TObject);
var
  Button: TButton;
begin
  Button := Sender as TButton;
  if Button.TagObject is FMX.Objects.TPath then
    FMX.Objects.TPath(Button.TagObject).Fill.Color := Button.ResultingTextSettings.FontColor;
end;

procedure TfrmMain.SetIcon(AButton: TButton; const AIcon: string);
begin
  if (AButton <> nil) and (AButton.TagObject is FMX.Objects.TPath) then
    FMX.Objects.TPath(AButton.TagObject).Data.Data := AIcon;
end;

procedure TfrmMain.BuildToolBar;
begin
  btnOpen := AddIconButton(ICON_OPEN, 'Open a book (Ctrl+O)', btnOpenClick);
  btnPrev := AddIconButton(ICON_FIRST, 'Previous chapter', btnPrevClick);
  btnPrevClip := AddIconButton(ICON_PREVIOUS, 'Previous sentence', btnPrevClipClick);
  btnPlay := AddIconButton(ICON_PLAY, 'Play / pause (P)', btnPlayClick);
  btnNextClip := AddIconButton(ICON_NEXT, 'Next sentence', btnNextClipClick);
  btnNext := AddIconButton(ICON_LAST, 'Next chapter', btnNextClick);
  btnSmaller := AddTextButton('A-', 'Smaller text (Ctrl+Minus)', btnSmallerClick);
  btnLarger := AddTextButton('A+', 'Larger text (Ctrl+Plus)', btnLargerClick);
  lblStatus.Position.X := layTop.ChildrenCount * 1000;   // after the buttons
end;

procedure TfrmMain.StartSound;
begin
  try
    // any FFmpeg 8 build - GPL or LGPL (owner): the licence is shown
    FFFmpeg := TFFmpegLibrary.Create('');
    FPlayer := TFFmpegAudioPlayer.Create(FFFmpeg);
    FSoundNote := FPlayer.OutputNote;
    {$IFDEF POSIX}
    WriteLn(ErrOutput, FFFmpeg.Description);
    WriteLn(ErrOutput, 'Sound output: ', FPlayer.Output.Description);
    {$ENDIF}
  except
    on E: Exception do
    begin
      FreeAndNil(FPlayer);
      FreeAndNil(FFFmpeg);
      FSoundNote := 'No sound: ' + E.Message;
    end;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FClip := -1;
  BuildToolBar;
  StartSound;
  FAudioFolder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetTempPath, 'EpubReader-' + IntToStr(Random(MaxInt)));
  // which canvas FMX really draws the form with (GDI+, Direct2D, Skia ...)
  // and what the Wine / Proton units decided - stderr, as TSteamAPI's demos
  {$IFDEF POSIX}
  WriteLn(ErrOutput, 'FMX canvas in use: ', FmxCanvasClassName);
  {$ENDIF}
  if FmxWineCanvasNote <> '' then
    Caption := Caption + ' [' + FmxWineCanvasName + ']';
  UpdateControls;
  if ParamCount > 0 then
    OpenBook(ParamStr(1));
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  StopPlaying;
  FreeAndNil(FPlayer);
  FreeAndNil(FFFmpeg);
  try
    if TDirectory.Exists(FAudioFolder) then
      TDirectory.Delete(FAudioFolder, True);
  except
    // a file still held by the player: left for the system's temp cleanup
  end;
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (KeyChar = 'p') or (KeyChar = 'P') then
  begin
    btnPlayClick(nil);
    KeyChar := #0;
  end
  else if (ssCtrl in Shift) and ((KeyChar = 'o') or (KeyChar = 'O') or (Key = Ord('O'))) then
  begin
    btnOpenClick(nil);
    Key := 0;
    KeyChar := #0;
  end
  else if (ssCtrl in Shift) and ((KeyChar = '+') or (KeyChar = '=')) then
  begin
    btnLargerClick(nil);
    KeyChar := #0;
  end
  else if (ssCtrl in Shift) and (KeyChar = '-') then
  begin
    btnSmallerClick(nil);
    KeyChar := #0;
  end;
end;

procedure TfrmMain.OpenBook(const AFileName: string);
begin
  StopPlaying;
  FAudioPath := '';
  FClip := -1;
  EpubUnum1.Active := False;
  EpubUnum1.FileName := AFileName;
  EpubUnum1.Active := True;   // OnOpen or OnOpenFailed follows
  UpdateControls;
end;

procedure TfrmMain.btnOpenClick(Sender: TObject);
begin
  dlgOpen.Filter := 'EPUB books (*.epub)|*.epub|All files (*.*)|*.*';
  if dlgOpen.Execute then
    OpenBook(dlgOpen.FileName);
end;

procedure TfrmMain.EpubUnum1Open(Sender: TObject);
var
  B: TEpubBook;
  I, F, L, First: Integer;
begin
  B := EpubUnum1.Book;
  Caption := 'EpubReader - ' + B.Title;
  lbToc.BeginUpdate;
  try
    lbToc.Clear;
    for I := 0 to High(B.Toc) do
      lbToc.Items.Add(StringOfChar(' ', B.Toc[I].Level * 3) + B.Toc[I].Title);
  finally
    lbToc.EndUpdate;
  end;
  B.LoadText;
  SetLength(FClipFirst, Length(B.Clips));
  SetLength(FClipLast, Length(B.Clips));
  for I := 0 to High(B.Clips) do
    if B.ClipWords(I, F, L) then
    begin
      FClipFirst[I] := F;
      FClipLast[I] := L;
    end
    else
    begin
      FClipFirst[I] := -1;
      FClipLast[I] := -1;
    end;
  // the first linear document with words
  First := 0;
  for I := 0 to High(B.Documents) do
    if B.Documents[I].Linear and (B.Documents[I].WordCount > 0) then
    begin
      First := I;
      Break;
    end;
  View1.ShowDocument(First);
  View1.SetFocus;
  UpdateControls;
end;

procedure TfrmMain.EpubUnum1OpenFailed(Sender: TObject; const AMessage: string);
begin
  lbToc.Clear;
  View1.Clear;
  Caption := 'EpubReader';
  UpdateControls;
  ShowMessage(AMessage);
end;

procedure TfrmMain.lbTocChange(Sender: TObject);
var
  B: TEpubBook;
  I: Integer;
begin
  B := EpubUnum1.Book;
  I := lbToc.ItemIndex;
  if (B = nil) or (I < 0) or (I > High(B.Toc)) or (B.Toc[I].Document < 0) then
    Exit;
  View1.ShowFragment(B.Toc[I].Document, B.Toc[I].Fragment);
  UpdateControls;
end;

function TfrmMain.StepDocument(ADoc, AStep: Integer): Integer;
var
  B: TEpubBook;
begin
  Result := -1;
  B := EpubUnum1.Book;
  if B = nil then
    Exit;
  Result := ADoc + AStep;
  while (Result >= 0) and (Result <= High(B.Documents)) and not B.Documents[Result].Linear do
    Inc(Result, AStep);
  if (Result < 0) or (Result > High(B.Documents)) then
    Result := -1;
end;

procedure TfrmMain.btnPrevClick(Sender: TObject);
var
  D: Integer;
begin
  D := StepDocument(View1.Document, -1);
  if D >= 0 then
    View1.ShowDocument(D);
end;

procedure TfrmMain.btnNextClick(Sender: TObject);
var
  D: Integer;
begin
  D := StepDocument(View1.Document, 1);
  if D >= 0 then
    View1.ShowDocument(D);
end;

procedure TfrmMain.btnSmallerClick(Sender: TObject);
begin
  if View1.FontSize > 10 then
    View1.FontSize := View1.FontSize - SIZE_STEP;
end;

procedure TfrmMain.btnLargerClick(Sender: TObject);
begin
  if View1.FontSize < 60 then
    View1.FontSize := View1.FontSize + SIZE_STEP;
end;

function TfrmMain.FirstClipOfDocument(ADoc: Integer): Integer;
var
  B: TEpubBook;
  I: Integer;
begin
  Result := -1;
  B := EpubUnum1.Book;
  if B = nil then
    Exit;
  for I := 0 to High(B.Clips) do
    if B.Clips[I].Document = ADoc then
      Exit(I);
end;

function TfrmMain.ClipOfWord(AWord: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FClipFirst) do
    if (AWord >= FClipFirst[I]) and (AWord <= FClipLast[I]) then
      Exit(I);
  Result := -1;
end;

procedure TfrmMain.StartClip(AClip: Integer);
var
  B: TEpubBook;
  C: TEpubClip;
  Target: string;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AClip < 0) or (AClip > High(B.Clips)) then
    Exit;
  C := B.Clips[AClip];
  if FPlayer = nil then
  begin
    // no sound: show the clip at least
    FClip := AClip;
    if C.Document <> View1.Document then
      View1.ShowDocument(C.Document);
    if FClipFirst[AClip] >= 0 then
    begin
      View1.Highlight(FClipFirst[AClip], FClipLast[AClip]);
      View1.ScrollToWord(FClipFirst[AClip]);
    end;
    UpdateControls;
    Exit;
  end;
  try
    if C.AudioPath <> FAudioPath then
    begin
      // FFmpeg streams a file: the book's audio is extracted once
      Target := System.IOUtils.TPath.Combine(FAudioFolder, StringReplace(C.AudioPath, '/', '_', [rfReplaceAll]));
      if not TFile.Exists(Target) then
      begin
        ForceDirectories(FAudioFolder);
        B.Zip.Extract(C.AudioPath, Target);
      end;
      FPlayer.Open(Target);
      FAudioPath := C.AudioPath;
    end;
    FPlayer.Play(C.ClipBegin);
  except
    on E: Exception do
    begin
      FSoundNote := E.Message;
      UpdateControls;
      Exit;
    end;
  end;
  FPlaying := True;
  FClip := -2;   // the timer highlights the clip it finds
  tmPlay.Enabled := True;
  UpdateControls;
end;

procedure TfrmMain.StopPlaying;
begin
  tmPlay.Enabled := False;
  if FPlaying and (FPlayer <> nil) then
    FPlayer.Pause;
  FPlaying := False;
  UpdateControls;
end;

procedure TfrmMain.btnPlayClick(Sender: TObject);
var
  B: TEpubBook;
  C: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (Length(B.Clips) = 0) then
    Exit;
  if FPlaying then
  begin
    StopPlaying;
    Exit;
  end;
  if (FPlayer <> nil) and (FClip >= 0) and (B.Clips[FClip].Document = View1.Document) and
    (FPlayer.FileName <> '') and not FPlayer.Ended then
  begin
    // resume where it was paused
    FPlayer.Resume;
    FPlaying := True;
    tmPlay.Enabled := True;
    UpdateControls;
    Exit;
  end;
  C := FirstClipOfDocument(View1.Document);
  if C < 0 then
    C := 0;
  StartClip(C);
end;

procedure TfrmMain.btnPrevClipClick(Sender: TObject);
begin
  if FClip > 0 then
    StartClip(FClip - 1);
end;

procedure TfrmMain.btnNextClipClick(Sender: TObject);
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  if (B <> nil) and (FClip >= 0) and (FClip < High(B.Clips)) then
    StartClip(FClip + 1);
end;

procedure TfrmMain.View1WordClick(Sender: TObject; AWord: Integer);
var
  C: Integer;
begin
  C := ClipOfWord(AWord);
  if C >= 0 then
    StartClip(C);
end;

procedure TfrmMain.View1DocumentChange(Sender: TObject);
begin
  UpdateControls;
end;

procedure TfrmMain.tmPlayTimer(Sender: TObject);
var
  B: TEpubBook;
  T: Double;
  C, I: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (FPlayer = nil) or not FPlaying then
    Exit;
  // the time of the sound really being heard
  T := FPlayer.Position;
  C := B.ClipAt(FAudioPath, T);
  if (C <> FClip) and (C >= 0) then
  begin
    FClip := C;
    if B.Clips[C].Document <> View1.Document then
      View1.ShowDocument(B.Clips[C].Document);
    if FClipFirst[C] >= 0 then
    begin
      View1.Highlight(FClipFirst[C], FClipLast[C]);
      View1.ScrollToWord(FClipFirst[C]);
    end;
    UpdateControls;
  end;
  if FPlayer.LastError <> '' then
  begin
    FSoundNote := FPlayer.LastError;
    StopPlaying;
    Exit;
  end;
  // this audio file has played out: go on with the next file's first clip
  if FPlayer.Ended then
  begin
    I := Max(FClip, 0);
    while (I <= High(B.Clips)) and (B.Clips[I].AudioPath = FAudioPath) do
      Inc(I);
    if I <= High(B.Clips) then
      StartClip(I)
    else
      StopPlaying;
  end;
end;

procedure TfrmMain.UpdateControls;
var
  B: TEpubBook;
  S: string;
begin
  B := EpubUnum1.Book;
  btnPrev.Enabled := (B <> nil) and (StepDocument(View1.Document, -1) >= 0);
  btnNext.Enabled := (B <> nil) and (StepDocument(View1.Document, 1) >= 0);
  btnPlay.Enabled := (B <> nil) and (Length(B.Clips) > 0);
  btnPrevClip.Enabled := btnPlay.Enabled and (FClip > 0);
  btnNextClip.Enabled := btnPlay.Enabled and (FClip >= 0) and (FClip < High(B.Clips));
  if FPlaying then
    SetIcon(btnPlay, ICON_PAUSE)
  else
    SetIcon(btnPlay, ICON_PLAY);
  if B = nil then
    S := 'No book open'
  else
  begin
    S := Format('%s - document %d of %d', [B.Title, View1.Document + 1, Length(B.Documents)]);
    if Length(B.Clips) = 0 then
      S := S + ' - no audio (no media overlays)'
    else if FPlaying then
      S := S + Format(' - playing %s', [ExtractFileName(StringReplace(FAudioPath, '/', PathDelim, [rfReplaceAll]))]);
  end;
  if FSoundNote <> '' then
    S := S + ' - ' + FSoundNote;
  lblStatus.Text := S;
end;

end.
