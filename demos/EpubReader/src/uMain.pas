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
  Ctrl+Minus text size, D dark mode; the view scrolls with the wheel, the
  arrows, Page Up / Page Down and Space. A click on a word starts the
  audio there.

  Chapters are the table of contents' entries (the reading order's
  documents when it has none): previous / next chapter, and a click in the
  contents, show the chapter AND move the audio to its first clip (played
  at once when playing, else from there on Play). Previous / next step by
  sentence or by paragraph (the drop-down), whatever the overlay's clips
  are - a word-level book has a clip per word. Previous goes back to the
  start of the sentence being read; pressed again near that start, to the
  one before. }
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
    { Previous sentence / paragraph (cbStep). }
    procedure btnPrevClipClick(Sender: TObject);
    { Next sentence / paragraph (cbStep). }
    procedure btnNextClipClick(Sender: TObject);
    { Sentence or paragraph steps: the buttons' hints. }
    procedure cbStepChange(Sender: TObject);
    { Dark / light page and panels. }
    procedure btnDarkClick(Sender: TObject);
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
    { What previous / next step by: sentence (0) or paragraph (1). }
    cbStep: TComboBox;
    { Dark mode on / off. }
    btnDark: TButton;
    { Dark mode is on. }
    FDark: Boolean;
    { Chapters in reading order: their first word in Book.Words. }
    FChapterWord: TArray<Integer>;
    { Chapters: their entry in Book.Toc (-1 = a document, no contents). }
    FChapterToc: TArray<Integer>;
    { Chapters: their document. }
    FChapterDoc: TArray<Integer>;
    { lbToc's selection is being set from code (no chapter jump). }
    FSyncingToc: Boolean;
    { Clip that Play starts from after a jump while paused, -1 = none (Play
      resumes). }
    FSeekClip: Integer;
    { The layout used to find paragraphs (blocks) of words: document
      FUnitDoc's. }
    FUnitLayout: TEpubDocLayout;
    { Document of FUnitLayout, -1 = none. }
    FUnitDoc: Integer;
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
    { Makes the chapter list (FChapterWord / Toc / Doc). }
    procedure BuildChapters;
    { The chapter word AWord is in, -1 before the first. }
    function ChapterOfWord(AWord: Integer): Integer;
    { Shows chapter AChapter and moves the audio to its first clip. }
    procedure GoChapter(AChapter: Integer);
    { The word being read or shown: the clip's first word, else the shown
      document's first word; -1 without a book. }
    function CurrentWord: Integer;
    { The first clip with words at or after word AWord, -1 when none. }
    function ClipFromWord(AWord: Integer): Integer;
    { Goes to clip AClip: played from there when playing, else highlighted
      and Play starts there. }
    procedure GoClip(AClip: Integer);
    { The block (paragraph) of word AWord in its document's layout. }
    function WordBlock(AWord: Integer): Integer;
    { A sentence (or paragraph, by cbStep) starts at word AWord. }
    function IsUnitStart(AWord: Integer): Boolean;
    { The start of the sentence / paragraph that word AWord is in. }
    function UnitStart(AWord: Integer): Integer;
    { Selects in lbToc the chapter of word AWord (no jump). }
    procedure SyncToc(AWord: Integer);
    { Colours of the page and the panels for FDark. }
    procedure ApplyTheme;
    { lbToc's style is (re)applied: its background for FDark. }
    procedure TocApplyStyle(Sender: TObject);
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
  { Dark mode: a crescent moon. }
  ICON_DARK = 'M15 3C10 3 6 7 6 12s4 9 9 9c-3-2-5-5-5-9s2-7 5-9z';
  { Icon box, px. }
  ICON_SIZE = 24;
  { cbStep: steps by sentence. }
  STEP_SENTENCE = 0;
  { cbStep: steps by paragraph. }
  STEP_PARAGRAPH = 1;
  { Previous goes to the sentence before when the one being read started
    less than this long ago, s. }
  BACK_GRACE = 1.5;
  { Dark mode: page. }
  DARK_PAGE = $FF1E1E1E;
  { Dark mode: text. }
  DARK_TEXT = $FFD8D8D8;
  { Dark mode: highlight (dark amber: light text stays readable on it). }
  DARK_HIGHLIGHT = $FF6B5310;
  { Dark mode: links. }
  DARK_LINK = $FF7AB8FF;
  { Dark mode: window and contents panel. }
  DARK_PANEL = $FF2B2B2B;
  { Dark mode: panel text. }
  DARK_PANEL_TEXT = $FFE0E0E0;
  { Button width, px. }
  BUTTON_WIDTH = 36;
  { Longest extension kept for an extracted audio file, the dot included. }
  MAX_AUDIO_EXTENSION = 8;

{ The extension of APath (a path inside a book) for the extracted copy:
  '.mp3', '.m4a', ... when it is a dot and a few ASCII letters or digits,
  else '' - nothing of the book's path that could name another folder. }
function SafeAudioExtension(const APath: string): string;
var
  I, P: Integer;
begin
  Result := '';
  P := LastDelimiter('.', APath);
  if (P = 0) or (Length(APath) - P + 1 > MAX_AUDIO_EXTENSION) or (P = Length(APath)) then
    Exit;
  for I := P + 1 to Length(APath) do
    if not CharInSet(APath[I], ['a'..'z', 'A'..'Z', '0'..'9']) then
      Exit;
  Result := Copy(APath, P, MaxInt);
end;

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
  btnPrev := AddIconButton(ICON_FIRST, 'Previous chapter (the audio follows)', btnPrevClick);
  btnPrevClip := AddIconButton(ICON_PREVIOUS, 'Previous sentence', btnPrevClipClick);
  btnPlay := AddIconButton(ICON_PLAY, 'Play / pause (P)', btnPlayClick);
  btnNextClip := AddIconButton(ICON_NEXT, 'Next sentence', btnNextClipClick);
  btnNext := AddIconButton(ICON_LAST, 'Next chapter (the audio follows)', btnNextClick);
  // what previous / next step by
  cbStep := TComboBox.Create(Self);
  cbStep.Parent := layTop;
  cbStep.Position.X := layTop.ChildrenCount * 1000;
  cbStep.Align := TAlignLayout.Left;
  cbStep.Width := 110;
  cbStep.Margins.Left := 4;
  cbStep.Margins.Top := 9;
  cbStep.Margins.Bottom := 9;
  cbStep.Items.Add('Sentence');
  cbStep.Items.Add('Paragraph');
  cbStep.ItemIndex := STEP_SENTENCE;
  cbStep.Hint := 'What previous / next step by';
  cbStep.ShowHint := True;
  cbStep.OnChange := cbStepChange;
  btnSmaller := AddTextButton('A-', 'Smaller text (Ctrl+Minus)', btnSmallerClick);
  btnLarger := AddTextButton('A+', 'Larger text (Ctrl+Plus)', btnLargerClick);
  btnDark := AddIconButton(ICON_DARK, 'Dark mode (D)', btnDarkClick);
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
  FSeekClip := -1;
  FUnitDoc := -1;
  lbToc.OnApplyStyleLookup := TocApplyStyle;
  BuildToolBar;
  StartSound;
  // a new name every run (Random without Randomize gave the same one, so
  // two readers shared - and deleted - one folder)
  FAudioFolder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetTempPath,
    'EpubReader-' + System.IOUtils.TPath.GetGUIDFileName);
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
  FreeAndNil(FUnitLayout);
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
  end
  else if ((KeyChar = 'd') or (KeyChar = 'D')) and not (ssCtrl in Shift) then
  begin
    btnDarkClick(nil);
    KeyChar := #0;
  end;
end;

procedure TfrmMain.OpenBook(const AFileName: string);
begin
  StopPlaying;
  FAudioPath := '';
  FClip := -1;
  FSeekClip := -1;
  FreeAndNil(FUnitLayout);
  FUnitDoc := -1;
  FChapterWord := nil;
  FChapterToc := nil;
  FChapterDoc := nil;
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
  if FDark then
    ApplyTheme;   // the new items' text colour
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
  BuildChapters;
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
  I, K: Integer;
begin
  if FSyncingToc then
    Exit;
  B := EpubUnum1.Book;
  I := lbToc.ItemIndex;
  if (B = nil) or (I < 0) or (I > High(B.Toc)) or (B.Toc[I].Document < 0) then
    Exit;
  // the chapter of this entry (entries at one place share a chapter)
  for K := 0 to High(FChapterToc) do
    if FChapterToc[K] = I then
    begin
      GoChapter(K);
      Exit;
    end;
  View1.ShowFragment(B.Toc[I].Document, B.Toc[I].Fragment);
  UpdateControls;
end;

procedure TfrmMain.BuildChapters;
var
  B: TEpubBook;
  I, K, W, N: Integer;
  Doc: TEpubDocument;
begin
  B := EpubUnum1.Book;
  FChapterWord := nil;
  FChapterToc := nil;
  FChapterDoc := nil;
  if B = nil then
    Exit;
  SetLength(FChapterWord, Length(B.Toc) + Length(B.Documents));
  SetLength(FChapterToc, Length(FChapterWord));
  SetLength(FChapterDoc, Length(FChapterWord));
  N := 0;
  for I := 0 to High(B.Toc) do
  begin
    if B.Toc[I].Document < 0 then
      Continue;
    Doc := B.Documents[B.Toc[I].Document];
    W := Doc.FirstWord;
    if B.Toc[I].Fragment <> '' then
      for K := 0 to High(Doc.Ids) do
        if (Doc.Ids[K].Id = B.Toc[I].Fragment) and (Doc.Ids[K].FirstWord >= 0) then
        begin
          W := Doc.Ids[K].FirstWord;
          Break;
        end;
    // in reading order only; an entry at the place of the one before
    // (a part and its first chapter) is that chapter
    if (N > 0) and (W <= FChapterWord[N - 1]) then
      Continue;
    FChapterWord[N] := W;
    FChapterToc[N] := I;
    FChapterDoc[N] := B.Toc[I].Document;
    Inc(N);
  end;
  if N = 0 then
    // no contents: the linear documents with words
    for I := 0 to High(B.Documents) do
      if B.Documents[I].Linear and (B.Documents[I].WordCount > 0) then
      begin
        FChapterWord[N] := B.Documents[I].FirstWord;
        FChapterToc[N] := -1;
        FChapterDoc[N] := I;
        Inc(N);
      end;
  SetLength(FChapterWord, N);
  SetLength(FChapterToc, N);
  SetLength(FChapterDoc, N);
end;

function TfrmMain.ChapterOfWord(AWord: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FChapterWord) do
    if FChapterWord[I] <= AWord then
      Result := I
    else
      Break;
end;

function TfrmMain.CurrentWord: Integer;
var
  B: TEpubBook;
begin
  Result := -1;
  B := EpubUnum1.Book;
  if B = nil then
    Exit;
  if (FClip >= 0) and (FClip <= High(FClipFirst)) and (FClipFirst[FClip] >= 0) and
    (B.Clips[FClip].Document = View1.Document) then
    Result := FClipFirst[FClip]
  else if (View1.Document >= 0) and (View1.Document <= High(B.Documents)) then
    Result := B.Documents[View1.Document].FirstWord;
end;

function TfrmMain.ClipFromWord(AWord: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FClipFirst) do
    if FClipFirst[I] >= AWord then
      Exit(I);
  Result := -1;
end;

procedure TfrmMain.GoClip(AClip: Integer);
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AClip < 0) or (AClip > High(B.Clips)) then
    Exit;
  if FPlaying then
  begin
    StartClip(AClip);
    Exit;
  end;
  // paused or stopped: show it; Play starts here
  FClip := AClip;
  FSeekClip := AClip;
  if B.Clips[AClip].Document <> View1.Document then
    View1.ShowDocument(B.Clips[AClip].Document);
  if FClipFirst[AClip] >= 0 then
  begin
    View1.Highlight(FClipFirst[AClip], FClipLast[AClip]);
    View1.ScrollToWord(FClipFirst[AClip]);
    SyncToc(FClipFirst[AClip]);
  end;
  UpdateControls;
end;

procedure TfrmMain.GoChapter(AChapter: Integer);
var
  B: TEpubBook;
  C, Limit: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AChapter < 0) or (AChapter > High(FChapterWord)) then
    Exit;
  if FChapterToc[AChapter] >= 0 then
    View1.ShowFragment(FChapterDoc[AChapter], B.Toc[FChapterToc[AChapter]].Fragment)
  else
    View1.ShowDocument(FChapterDoc[AChapter]);
  SyncToc(FChapterWord[AChapter]);
  // the audio follows: the chapter's first clip - one inside the chapter
  // (a chapter without audio does not jump to a later chapter's)
  C := ClipFromWord(FChapterWord[AChapter]);
  if AChapter < High(FChapterWord) then
    Limit := FChapterWord[AChapter + 1]
  else
    Limit := MaxInt;
  if (C >= 0) and (FClipFirst[C] < Limit) then
    GoClip(C)
  else
  begin
    // nothing to hear here: stop, and Play starts with the shown chapter
    StopPlaying;
    FClip := -1;
    FSeekClip := -1;
    View1.ClearHighlight;
    UpdateControls;
  end;
end;

procedure TfrmMain.SyncToc(AWord: Integer);
var
  K: Integer;
begin
  K := ChapterOfWord(AWord);
  if (K < 0) or (FChapterToc[K] < 0) or (lbToc.ItemIndex = FChapterToc[K]) then
    Exit;
  FSyncingToc := True;
  try
    lbToc.ItemIndex := FChapterToc[K];
  finally
    FSyncingToc := False;
  end;
end;

function TfrmMain.WordBlock(AWord: Integer): Integer;
var
  B: TEpubBook;
  D: Integer;
begin
  B := EpubUnum1.Book;
  D := B.Words[AWord].Document;
  if (FUnitLayout = nil) or (FUnitDoc <> D) then
  begin
    FreeAndNil(FUnitLayout);
    FUnitLayout := B.DocumentLayout(D);
    FUnitDoc := D;
  end;
  Result := B.BlockOfWord(FUnitLayout, D, AWord);
end;

function TfrmMain.IsUnitStart(AWord: Integer): Boolean;
var
  B: TEpubBook;
begin
  B := EpubUnum1.Book;
  if AWord <= 0 then
    Exit(True);
  if B.Words[AWord - 1].Document <> B.Words[AWord].Document then
    Exit(True);
  if (cbStep.ItemIndex <> STEP_PARAGRAPH) and EpubEndsSentence(B.Words[AWord - 1].Text) then
    Exit(True);
  Result := WordBlock(AWord - 1) <> WordBlock(AWord);
end;

function TfrmMain.UnitStart(AWord: Integer): Integer;
begin
  Result := AWord;
  while not IsUnitStart(Result) do
    Dec(Result);
end;

procedure TfrmMain.cbStepChange(Sender: TObject);
begin
  if cbStep.ItemIndex = STEP_PARAGRAPH then
  begin
    btnPrevClip.Hint := 'Previous paragraph';
    btnNextClip.Hint := 'Next paragraph';
  end
  else
  begin
    btnPrevClip.Hint := 'Previous sentence';
    btnNextClip.Hint := 'Next sentence';
  end;
end;

procedure TfrmMain.btnDarkClick(Sender: TObject);
begin
  FDark := not FDark;
  ApplyTheme;
end;

procedure TfrmMain.ApplyTheme;
var
  I: Integer;
begin
  // the page
  if FDark then
  begin
    View1.BackgroundColor := DARK_PAGE;
    View1.TextColor := DARK_TEXT;
    View1.HighlightColor := DARK_HIGHLIGHT;
    View1.LinkColor := DARK_LINK;
  end
  else
  begin
    // TEpubView's own defaults: warm paper
    View1.BackgroundColor := $FFFBF7EF;
    View1.TextColor := $FF222222;
    View1.HighlightColor := $FFFFE08A;
    View1.LinkColor := $FF1A5FB4;
  end;
  // the window behind the tool bar
  if FDark then
  begin
    Fill.Kind := TBrushKind.Solid;
    Fill.Color := DARK_PANEL;
  end
  else
    Fill.Kind := TBrushKind.None;
  // the status line
  if FDark then
  begin
    lblStatus.StyledSettings := lblStatus.StyledSettings - [TStyledSetting.FontColor];
    lblStatus.TextSettings.FontColor := DARK_PANEL_TEXT;
  end
  else
    lblStatus.StyledSettings := lblStatus.StyledSettings + [TStyledSetting.FontColor];
  // the contents: the items' text here, the background in TocApplyStyle
  for I := 0 to lbToc.Count - 1 do
    if FDark then
    begin
      lbToc.ListItems[I].StyledSettings := lbToc.ListItems[I].StyledSettings - [TStyledSetting.FontColor];
      lbToc.ListItems[I].TextSettings.FontColor := DARK_PANEL_TEXT;
    end
    else
      lbToc.ListItems[I].StyledSettings := lbToc.ListItems[I].StyledSettings + [TStyledSetting.FontColor];
  // Dark: FMX's transparent list box style, so the form's dark Fill shows
  // through - the plain style's white background (not reliably reachable
  // by name) left light text on white: unreadable (owner, zip 10).
  if FDark then
    lbToc.StyleLookup := 'transparentlistboxstyle'
  else
    lbToc.StyleLookup := '';
  lbToc.NeedStyleLookup;
  lbToc.ApplyStyleLookup;
  // the tool bar's buttons keep the platform style (their icons follow it)
end;

procedure TfrmMain.TocApplyStyle(Sender: TObject);
var
  O: TFmxObject;
begin
  // a fresh copy of the style: light as the style made it; dark: its
  // background made dark too, should the style still have one (a style
  // without 'transparentlistboxstyle' falls back to the plain one)
  if not FDark then
    Exit;
  O := lbToc.FindStyleResource('background');
  if O is TShape then
  begin
    TShape(O).Fill.Kind := TBrushKind.Solid;
    TShape(O).Fill.Color := DARK_PANEL;
  end
  else if O is TControl then
    TControl(O).Opacity := 0;   // a background of another kind: hidden
end;

procedure TfrmMain.btnPrevClick(Sender: TObject);
var
  K, W: Integer;
begin
  // the start of this chapter; at its start already, the one before
  W := CurrentWord;
  K := ChapterOfWord(W);
  if (K >= 0) and (FClip >= 0) and (W > FChapterWord[K]) and
    (ClipFromWord(FChapterWord[K]) <> FClip) then
    GoChapter(K)
  else if K > 0 then
    GoChapter(K - 1)
  else if K = 0 then
    GoChapter(0);
end;

procedure TfrmMain.btnNextClick(Sender: TObject);
var
  K: Integer;
begin
  K := ChapterOfWord(CurrentWord);
  if K < High(FChapterWord) then
    GoChapter(K + 1);
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
  I, First: Integer;
begin
  B := EpubUnum1.Book;
  if (B = nil) or (AClip < 0) or (AClip > High(B.Clips)) then
    Exit;
  C := B.Clips[AClip];
  FSeekClip := -1;
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
      // The file name is made HERE, never from the path inside the book:
      // that path is the book's to choose, and one with backslashes and
      // '..', or an absolute one (which TPath.Combine returns as it is),
      // wrote the book's bytes anywhere on the disk. It is
      // <book number>-<first clip of this audio file><extension>, so a
      // second book never finds the first one's file under its own name.
      First := AClip;
      for I := 0 to AClip do
        if B.Clips[I].AudioPath = C.AudioPath then
        begin
          First := I;
          Break;
        end;
      Target := System.IOUtils.TPath.Combine(FAudioFolder, Format('%d-%d%s', [EpubUnum1.BookSerial, First,
        SafeAudioExtension(C.AudioPath)]));
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
  if FSeekClip >= 0 then
  begin
    // a jump while paused: play from there
    C := FSeekClip;
    StartClip(C);
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
var
  B: TEpubBook;
  W, S, C: Integer;
  AtStart: Boolean;
begin
  B := EpubUnum1.Book;
  W := CurrentWord;
  if (B = nil) or (W < 0) or (Length(B.Clips) = 0) then
    Exit;
  S := UnitStart(W);
  C := ClipFromWord(S);
  // at (or just past) the start of this sentence: the one before
  if FPlaying and (C >= 0) and (FPlayer <> nil) and SameText(B.Clips[C].AudioPath, FAudioPath) then
    AtStart := FPlayer.Position - B.Clips[C].ClipBegin < BACK_GRACE
  else
    AtStart := (C < 0) or (FClip <= C);
  if AtStart and (S > 0) then
  begin
    S := UnitStart(S - 1);
    C := ClipFromWord(S);
  end;
  if C >= 0 then
    GoClip(C);
end;

procedure TfrmMain.btnNextClipClick(Sender: TObject);
var
  B: TEpubBook;
  W, C: Integer;
begin
  B := EpubUnum1.Book;
  W := CurrentWord;
  if (B = nil) or (W < 0) or (Length(B.Clips) = 0) then
    Exit;
  repeat
    Inc(W);
  until (W >= B.WordCount) or IsUnitStart(W);
  if W >= B.WordCount then
    Exit;
  C := ClipFromWord(W);
  // always forward, even when a clip holds several sentences
  if (C >= 0) and (C <= FClip) then
    C := FClip + 1;
  if (C >= 0) and (C <= High(B.Clips)) then
    GoClip(C);
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
      SyncToc(FClipFirst[C]);
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
  btnPrev.Enabled := (B <> nil) and (Length(FChapterWord) > 0);
  btnNext.Enabled := (B <> nil) and (ChapterOfWord(CurrentWord) < High(FChapterWord));
  btnPlay.Enabled := (B <> nil) and (Length(B.Clips) > 0);
  btnPrevClip.Enabled := btnPlay.Enabled;
  btnNextClip.Enabled := btnPlay.Enabled;
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
