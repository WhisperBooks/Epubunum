(* @abstract(@link(TEpubUnum) for FireMonkey - the non-visual component that
  opens an EPUB book.)

  Drop one on a form (palette page "EpubUnum"), set
  @link(TEpubUnum.FileName) and @link(TEpubUnum.Active); the book is then
  in @code(Book) (TEpubBook: metadata, contents, text, media overlays).
  Show it with a @code(TEpubView) (Epub.FMX.View) linked to it. Everything
  except the exception display lives in the framework-free
  @code(TCustomEpub) (Epub.Components).
  @longCode(#
  procedure TfrmMain.btnOpenClick(Sender: TObject);
  begin
    if dlgOpen.Execute then
    begin
      EpubUnum1.FileName := dlgOpen.FileName;
      EpubUnum1.Active := True;   // OnOpen or OnOpenFailed follows
    end;
  end;
  #) *)
unit Epub.FMX;

{$I ..\lib\Epub.inc}

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.Forms,
  Epub.Zip, Epub.Book, Epub.Components;

type
  { FireMonkey TEpubUnum: @code(TCustomEpub) with its properties published
    and handler exceptions shown by Application.ShowException. }
  [ComponentPlatformsAttribute(EPUB_COMPONENT_PLATFORMS)]
  TEpubUnum = class(TCustomEpub)
  protected
    { Application.ShowException (Application.HandleException would show
      ExceptObject, which is nil outside an except block). }
    procedure ShowHandlerException(E: Exception); override;
  published
    { Opens the book. At design time the value is only stored. }
    property Active;
    { The .epub file. }
    property FileName;
    { The book was opened. }
    property OnOpen;
    { Opening failed (not an EPUB, damaged, copy protected, ...). }
    property OnOpenFailed;
    { The book was closed. }
    property OnClose;
  end;

implementation

procedure TEpubUnum.ShowHandlerException(E: Exception);
begin
  if Application <> nil then
    Application.ShowException(E);
end;

end.
