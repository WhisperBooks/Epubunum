(* Epub.inc
  Shared compiler settings for every unit of EpubUnum (EPUB reading and, later,
  writing; github.com/WhisperBooks/Epubunum).
  Include it right after the unit line of EVERY library unit:
  @longCode(#
  unit Epub.Something;
  {$I Epub.inc}
  interface
  #)
  It makes the same source compile with Delphi (FMX / VCL) and Free Pascal
  (FPC 3.2.2+, {$mode delphi}). EpubUnum calls no C library, so there is no
  record layout to match.
  Defines produced here (use them instead of compiler-specific symbols):
  - EPUB_WINDOWS, EPUB_MACOS, EPUB_LINUX, EPUB_ANDROID, EPUB_IOS
  - EPUB_ANONYMOUS_METHODS     (compiler supports "reference to")
*)

{ ---------------------------------------------------------------- compiler }
{$ifdef FPC}
  {$mode delphi}
  {$H+}
  {$macro on}
  {$scopedenums off}
  // FPC 3.3.1+ (trunk) supports function references / anonymous functions.
  // PasDoc cannot evaluate FPC_FULLVERSION; no compiler defines PASDOC.
  {$ifndef PASDOC}
  {$if FPC_FULLVERSION >= 30301}
    {$modeswitch functionreferences}
    {$modeswitch anonymousfunctions}
    {$define EPUB_ANONYMOUS_METHODS}
  {$endif}
  {$endif}
{$else}
  {$SCOPEDENUMS OFF}
  {$define EPUB_ANONYMOUS_METHODS}
{$endif}

{ ---------------------------------------------------------------- platform }
{ ANDROID is tested before LINUX because FPC's Android target is Linux-based.
  iOS is supported: EpubUnum is pure Pascal (a reader app may run there). }
{$if defined(IOS) or defined(IPHONESIM)}
  {$define EPUB_IOS}
{$elseif defined(MSWINDOWS)}
  {$define EPUB_WINDOWS}
{$elseif defined(ANDROID)}
  {$define EPUB_ANDROID}
{$elseif defined(DARWIN) or defined(MACOS)}
  {$define EPUB_MACOS}
{$elseif defined(LINUX)}
  {$define EPUB_LINUX}
{$endif}
