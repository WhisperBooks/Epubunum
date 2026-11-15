{ @abstract(Design-time registration of the EpubUnum FMX components.)

  Compiled only into the design-time package dclEpubUnumFMX, which puts
  @code(TEpubUnum) (the book) and @code(TEpubView) (the Skia page view) on
  the "EpubUnum" page of the tool palette. }
unit Epub.FMX.Reg;

{$I ..\lib\Epub.inc}

interface

{ Registers TEpubUnum and TEpubView on the "EpubUnum" palette page. }
procedure Register;

implementation

uses
  Classes, DesignIntf, DesignEditors, FMX.Types, Epub.FMX, Epub.FMX.View;

type
  { Adds the units the IDE-generated event handlers need (TEpubBook,
    TEpubWordRole, ...) to the form's uses clause. }
  TEpubSelectionEditor = class(TSelectionEditor)
  public
    { Names Epub.Zip, Epub.Layout, Epub.Book and Epub.Components. }
    procedure RequiresUnits(Proc: TGetStrProc); override;
  end;

procedure TEpubSelectionEditor.RequiresUnits(Proc: TGetStrProc);
begin
  Proc('Epub.Zip');
  Proc('Epub.Layout');
  Proc('Epub.Book');
  Proc('Epub.Components');
end;

procedure Register;
begin
  // FMX class group: lets VCL components of the same names be installed
  // as well later, as with FMX / VCL TButton.
  GroupDescendentsWith(TEpubUnum, TFmxObject);
  RegisterComponents('EpubUnum', [TEpubUnum, TEpubView]);
  RegisterSelectionEditor(TEpubUnum, TEpubSelectionEditor);
  RegisterSelectionEditor(TEpubView, TEpubSelectionEditor);
end;

end.
