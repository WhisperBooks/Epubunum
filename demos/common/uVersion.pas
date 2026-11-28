{ The version of EpubUnum's programs: major.minor.build (owner, 2026-11-26,
  a standing rule: "Can we start using major.minor.build versioning ...
  This will get version bumps when everything is working smoothly.
  Internally the build number must be integer and sorted that way").

  VERSION_BUILD is the number of the delivery (zip) that last changed the
  repository: every zip sets it to its own number. VERSION_MAJOR and
  VERSION_MINOR change only when the owner says. Versions are compared
  part by part as integers (0.0.99 comes before 0.0.342), never as text.

  The debug log's first lines carry the version (uDebugLog). }
unit uVersion;

interface

const
  { Major version (changed by the owner only). }
  VERSION_MAJOR = 0;
  { Minor version (changed by the owner only). }
  VERSION_MINOR = 0;
  { The build: the number of the zip that last changed the repository. }
  VERSION_BUILD = 408;

{ This build's version, 'major.minor.build' ('0.0.351').
  @returns(the version) }
function VersionText: string;

{ Compares two versions part by part as integers ('0.0.99' before
  '0.0.342'); a part missing or not a number counts as 0, a 'v' in front
  is ignored.
  @param(A  a version)
  @param(B  another)
  @returns(< 0 when A comes before B, 0 when they are the same, > 0 after) }
function VersionCompare(const A, B: string): Integer;

implementation

uses
  System.SysUtils;

function VersionText: string;
begin
  Result := Format('%d.%d.%d', [VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD]);
end;

{ The parts of version AText as integers. }
function VersionParts(const AText: string): TArray<Int64>;
var
  Parts: TArray<string>;
  I: Integer;
  T: string;
begin
  T := Trim(AText);
  if (T <> '') and CharInSet(T.Chars[0], ['v', 'V']) then
    T := T.Substring(1);
  Parts := T.Split(['.']);
  SetLength(Result, Length(Parts));
  for I := 0 to High(Parts) do
    Result[I] := StrToInt64Def(Trim(Parts[I]), 0);
end;

function VersionCompare(const A, B: string): Integer;
var
  PA, PB: TArray<Int64>;
  I, N: Integer;
  X, Y: Int64;
begin
  PA := VersionParts(A);
  PB := VersionParts(B);
  N := Length(PA);
  if Length(PB) > N then
    N := Length(PB);
  for I := 0 to N - 1 do
  begin
    if I < Length(PA) then
      X := PA[I]
    else
      X := 0;
    if I < Length(PB) then
      Y := PB[I]
    else
      Y := 0;
    if X < Y then
      Exit(-1);
    if X > Y then
      Exit(1);
  end;
  Result := 0;
end;

end.
