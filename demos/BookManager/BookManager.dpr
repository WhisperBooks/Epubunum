program BookManager;

{ BookManager - EpubBuilder's companion on another computer (or the same
  one): finds EpubBuilder on the network by itself, pairs with it once
  (a 6-digit code EpubBuilder shows), then sends it books, audio and
  pictures - dropped on the window, each to its place - fetches the books
  it made, and shows its progress and log as it works.

  Not a Steam program. Needs nothing of EpubUnum's packages: uLink is
  Indy, which comes with Delphi. }

uses
  System.StartUpCopy,
  FMX.Forms,
  uDebugLog in '..\common\uDebugLog.pas',
  uMachine in '..\common\uMachine.pas',
  // the folders shared with EpubBuilder and EpubReader (Documents/EpubUnum)
  uEpubUnum in '..\common\uEpubUnum.pas',
  // the link to EpubBuilder (Indy)
  uLink in '..\common\uLink.pas',
  // where dropped files go
  uRoute in 'src\uRoute.pas',
  // the transfers and the poll (threads)
  uTransfers in 'src\uTransfers.pas',
  uManager in 'src\uManager.pas' {frmManager};

{$R *.res}

begin
{$IFDEF DEBUG}
  // Debug builds list leaked blocks when the program ends (Windows)
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  Application.Initialize;
  Application.CreateForm(TfrmManager, frmManager);
  Application.Run;
end.
