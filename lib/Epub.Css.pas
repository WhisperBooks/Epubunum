(* @abstract(The small part of CSS a reflowing reader needs: which elements
  are italic, bold, centred, indented, hidden, smaller or larger.)

  Books style text through classes as often as through tags (Calibre turns
  every <i> into <span class="italic">), so the layout (Epub.Layout) asks
  a @link(TEpubStyleSheet) for each element's style. Supported:
  @unorderedList(
    @item(Selectors: @code(elem), @code(.cls), @code(elem.cls),
      @code(.a.b), @code(#id), groups with commas; for a descendant or
      child selector ('div p', 'div > p') only the last part is used - a
      reader's approximation that is right for the usual book styles.)
    @item(Properties: font-style, font-weight, font-variant (small-caps),
      text-decoration (underline, line-through), text-align, text-indent,
      margin-left, display (none, block, inline), vertical-align (super,
      sub), font-size (em, %, rem, px against 16, xx-small .. xx-large,
      smaller, larger), font-family (monospace only), white-space (pre).)
    @item(Specificity and source order decide, and the style attribute
      wins, as in a browser; @code(!important) is ignored.)
  )
  Everything else (colours, fonts, floats, borders) is ignored: the reader
  draws the book in its own theme.

  Framework-free; compiles with Delphi and FPC. *)
unit Epub.Css;

{$I Epub.inc}

interface

uses
  SysUtils, Classes;

type
  { Horizontal alignment of a block. }
  TEpubTextAlign = (
    { Not set (inherit / start). }
    etaInherit,
    { Start (left in left-to-right text). }
    etaStart,
    { Centred. }
    etaCenter,
    { End (right). }
    etaEnd,
    { Justified. }
    etaJustify);

  { A tri-state: not set, off, on. }
  TEpubFlag = (
    { Not set (inherit). }
    efInherit,
    { Explicitly off. }
    efOff,
    { Explicitly on. }
    efOn);

  { How an element is displayed. }
  TEpubDisplay = (
    { Not set (the element's natural display). }
    edInherit,
    { Hidden: the element and its content are not shown (nor read). }
    edNone,
    { A block. }
    edBlock,
    { Inline. }
    edInline);

  { The computed style of an element (only what a reader uses). A field
    left at its inherit value takes the parent's. }
  TEpubStyle = record
    { Italic. }
    Italic: TEpubFlag;
    { Bold. }
    Bold: TEpubFlag;
    { Small capitals. }
    SmallCaps: TEpubFlag;
    { Underlined. }
    Underline: TEpubFlag;
    { Struck through. }
    Strike: TEpubFlag;
    { Monospace font. }
    Mono: TEpubFlag;
    { Keep white space and line breaks (pre). }
    Pre: TEpubFlag;
    { Superscript (1) or subscript (-1); 0 = not set. }
    Shift: Integer;
    { Alignment. }
    Align: TEpubTextAlign;
    { First-line indent in em (NaN when not set). }
    TextIndent: Double;
    { Left margin in em (NaN when not set). }
    MarginLeft: Double;
    { Font size as a factor of the parent's (NaN when not set). }
    SizeFactor: Double;
    { Display. }
    Display: TEpubDisplay;
  end;

  { A parsed style sheet (one or more CSS texts). }
  TEpubStyleSheet = class
  private
    { The rules: selector (one simple selector), declarations, specificity,
      order. }
    FRules: TList;
    { Adds every rule of ACss. }
    procedure Parse(const ACss: string);
  public
    { An empty style sheet. }
    constructor Create;
    { Frees the rules. }
    destructor Destroy; override;
    { Adds the rules of a CSS text (later ones win at equal specificity). }
    procedure Add(const ACss: string);
    { The style the sheet gives an element named ALocal (lower case) with
      the class attribute AClass and id AId, then the style attribute
      AStyleAttr on top. Fields with no rule stay at their inherit value. }
    function StyleOf(const ALocal, AClass, AId, AStyleAttr: string): TEpubStyle;
    { Number of rules. }
    function RuleCount: Integer;
  end;

{ A style with every field at its inherit value. }
function EpubEmptyStyle: TEpubStyle;
{ The style of a style attribute alone (no style sheet). }
function EpubStyleOfAttr(const AStyleAttr: string): TEpubStyle;
{ Applies the declarations of ADecls ('font-style: italic; ...') to AStyle. }
procedure EpubApplyDeclarations(var AStyle: TEpubStyle; const ADecls: string);

implementation

uses
  Math;

type
  { One rule: a simple selector and its declarations. }
  TRule = class
    { Element name ('' = any), lower case. }
    Elem: string;
    { Classes the element must have, lower case. }
    Classes: TStringList;
    { Id the element must have ('' = any). }
    Id: string;
    { The declarations. }
    Decls: string;
    { Specificity: ids * 10000 + classes * 100 + elements. }
    Spec: Integer;
    { Source order. }
    Order: Integer;
    { An empty rule. }
    constructor Create;
    { Frees the class list. }
    destructor Destroy; override;
  end;

constructor TRule.Create;
begin
  inherited Create;
  Classes := TStringList.Create;
end;

destructor TRule.Destroy;
begin
  Classes.Free;
  inherited;
end;

function EpubEmptyStyle: TEpubStyle;
begin
  Result := Default(TEpubStyle);
  Result.TextIndent := NaN;
  Result.MarginLeft := NaN;
  Result.SizeFactor := NaN;
end;

{ A CSS length in em; NaN when it cannot be read. Percentages are of the
  font size (for font-size) - the caller decides what they mean. }
function LengthEm(const AValue: string): Double;
var
  S: string;
  V: Double;
  FS: TFormatSettings;
  Unit_: string;
  I: Integer;
begin
  Result := NaN;
  S := LowerCase(Trim(AValue));
  if S = '' then
    Exit;
  if S = '0' then
    Exit(0);
  I := 1;
  while (I <= Length(S)) and CharInSet(S[I], ['0'..'9', '.', '-', '+']) do
    Inc(I);
  Unit_ := Copy(S, I, MaxInt);
  FS := FormatSettings;   // a copy; only the decimal separator is changed
  FS.DecimalSeparator := '.';
  if not TryStrToFloat(Copy(S, 1, I - 1), V, FS) then
    Exit;
  if (Unit_ = 'em') or (Unit_ = 'rem') then
    Result := V
  else if Unit_ = '%' then
    Result := V / 100
  else if Unit_ = 'px' then
    Result := V / 16
  else if Unit_ = 'pt' then
    Result := V / 12
  else if Unit_ = 'ex' then
    Result := V / 2
  else if Unit_ = '' then
    Result := V;
end;

{ The left margin (em) of a 'margin' shorthand value; NaN when unreadable. }
function MarginLeftOf(const AValue: string): Double;
var
  L: TStringList;
begin
  Result := NaN;
  L := TStringList.Create;
  try
    L.Delimiter := ' ';
    L.StrictDelimiter := False;
    L.DelimitedText := AValue;
    case L.Count of
      1: Result := LengthEm(L[0]);
      2, 3: Result := LengthEm(L[1]);
      4: Result := LengthEm(L[3]);
    end;
  finally
    L.Free;
  end;
end;

procedure EpubApplyDeclarations(var AStyle: TEpubStyle; const ADecls: string);
var
  Parts: TStringList;
  I, P: Integer;
  Prop, Val: string;
  V: Double;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ';';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := ADecls;
    for I := 0 to Parts.Count - 1 do
    begin
      P := Pos(':', Parts[I]);
      if P = 0 then
        Continue;
      Prop := LowerCase(Trim(Copy(Parts[I], 1, P - 1)));
      Val := LowerCase(Trim(Copy(Parts[I], P + 1, MaxInt)));
      Val := Trim(StringReplace(Val, '!important', '', []));
      if Prop = 'font-style' then
      begin
        if (Val = 'italic') or (Val = 'oblique') then
          AStyle.Italic := efOn
        else if Val = 'normal' then
          AStyle.Italic := efOff;
      end
      else if Prop = 'font-weight' then
      begin
        if (Val = 'bold') or (Val = 'bolder') or (Val = '600') or (Val = '700') or (Val = '800') or
          (Val = '900') then
          AStyle.Bold := efOn
        else if (Val = 'normal') or (Val = 'lighter') or (Val = '400') or (Val = '300') then
          AStyle.Bold := efOff;
      end
      else if Prop = 'font-variant' then
      begin
        if Pos('small-caps', Val) > 0 then
          AStyle.SmallCaps := efOn
        else if Val = 'normal' then
          AStyle.SmallCaps := efOff;
      end
      else if (Prop = 'text-decoration') or (Prop = 'text-decoration-line') then
      begin
        if Pos('underline', Val) > 0 then
          AStyle.Underline := efOn;
        if Pos('line-through', Val) > 0 then
          AStyle.Strike := efOn;
        if Val = 'none' then
        begin
          AStyle.Underline := efOff;
          AStyle.Strike := efOff;
        end;
      end
      else if Prop = 'text-align' then
      begin
        if (Val = 'center') then
          AStyle.Align := etaCenter
        else if (Val = 'right') or (Val = 'end') then
          AStyle.Align := etaEnd
        else if (Val = 'left') or (Val = 'start') then
          AStyle.Align := etaStart
        else if Val = 'justify' then
          AStyle.Align := etaJustify;
      end
      else if Prop = 'text-indent' then
      begin
        V := LengthEm(Val);
        if not IsNan(V) then
          AStyle.TextIndent := V;
      end
      else if Prop = 'margin-left' then
      begin
        V := LengthEm(Val);
        if not IsNan(V) then
          AStyle.MarginLeft := V;
      end
      else if Prop = 'margin' then
      begin
        // margin: 1 value = all sides; 2 or 3 = the 2nd is left / right;
        // 4 = top right bottom left
        V := MarginLeftOf(Val);
        if not IsNan(V) then
          AStyle.MarginLeft := V;
      end
      else if Prop = 'display' then
      begin
        if Val = 'none' then
          AStyle.Display := edNone
        else if (Val = 'block') or (Val = 'list-item') then
          AStyle.Display := edBlock
        else if (Val = 'inline') or (Val = 'inline-block') then
          AStyle.Display := edInline;
      end
      else if Prop = 'vertical-align' then
      begin
        if (Val = 'super') or (Val = 'top') then
          AStyle.Shift := 1
        else if (Val = 'sub') or (Val = 'bottom') then
          AStyle.Shift := -1
        else if Val = 'baseline' then
          AStyle.Shift := 0;
      end
      else if Prop = 'white-space' then
      begin
        if Copy(Val, 1, 3) = 'pre' then
          AStyle.Pre := efOn
        else if Val = 'normal' then
          AStyle.Pre := efOff;
      end
      else if Prop = 'font-family' then
      begin
        if (Pos('monospace', Val) > 0) or (Pos('courier', Val) > 0) then
          AStyle.Mono := efOn;
      end
      else if Prop = 'font-size' then
      begin
        if Val = 'xx-small' then
          AStyle.SizeFactor := 0.6
        else if Val = 'x-small' then
          AStyle.SizeFactor := 0.75
        else if (Val = 'small') or (Val = 'smaller') then
          AStyle.SizeFactor := 0.85
        else if Val = 'medium' then
          AStyle.SizeFactor := 1
        else if (Val = 'large') or (Val = 'larger') then
          AStyle.SizeFactor := 1.2
        else if Val = 'x-large' then
          AStyle.SizeFactor := 1.5
        else if Val = 'xx-large' then
          AStyle.SizeFactor := 2
        else
        begin
          V := LengthEm(Val);
          if not IsNan(V) and (V > 0) then
            AStyle.SizeFactor := V;
        end;
      end;
    end;
  finally
    Parts.Free;
  end;
end;

function EpubStyleOfAttr(const AStyleAttr: string): TEpubStyle;
begin
  Result := EpubEmptyStyle;
  if AStyleAttr <> '' then
    EpubApplyDeclarations(Result, AStyleAttr);
end;

{ TEpubStyleSheet }

constructor TEpubStyleSheet.Create;
begin
  inherited Create;
  FRules := TList.Create;
end;

destructor TEpubStyleSheet.Destroy;
var
  I: Integer;
begin
  for I := 0 to FRules.Count - 1 do
    TRule(FRules[I]).Free;
  FRules.Free;
  inherited;
end;

function TEpubStyleSheet.RuleCount: Integer;
begin
  Result := FRules.Count;
end;

procedure TEpubStyleSheet.Add(const ACss: string);
begin
  Parse(ACss);
end;

procedure TEpubStyleSheet.Parse(const ACss: string);
var
  S, Sel, Decls, One, Last: string;
  I, P, Q, Depth, K: Integer;
  Sels: TStringList;
  R: TRule;
  Parts: TStringList;
begin
  // drop comments
  S := ACss;
  repeat
    P := Pos('/*', S);
    if P = 0 then
      Break;
    Q := Pos('*/', Copy(S, P + 2, MaxInt));
    if Q = 0 then
      SetLength(S, P - 1)
    else
      Delete(S, P, Q + 3);
  until False;
  Sels := TStringList.Create;
  Parts := TStringList.Create;
  try
    I := 1;
    while I <= Length(S) do
    begin
      P := I;
      while (I <= Length(S)) and (S[I] <> '{') do
        Inc(I);
      if I > Length(S) then
        Break;
      Sel := Trim(Copy(S, P, I - P));
      Inc(I);
      P := I;
      Depth := 1;
      while (I <= Length(S)) and (Depth > 0) do
      begin
        if S[I] = '{' then
          Inc(Depth)
        else if S[I] = '}' then
          Dec(Depth);
        Inc(I);
      end;
      Decls := Copy(S, P, I - P - 1);
      if (Sel = '') or (Sel[1] = '@') then
        Continue;   // @media / @font-face / @page blocks are skipped whole
      Sels.Delimiter := ',';
      Sels.StrictDelimiter := True;
      Sels.DelimitedText := Sel;
      for K := 0 to Sels.Count - 1 do
      begin
        One := Trim(Sels[K]);
        if One = '' then
          Continue;
        // the last compound selector of 'div p', 'div > p', 'a + b'
        One := StringReplace(One, '>', ' ', [rfReplaceAll]);
        One := StringReplace(One, '+', ' ', [rfReplaceAll]);
        One := StringReplace(One, '~', ' ', [rfReplaceAll]);
        Q := LastDelimiter(' '#9#10#13, One);
        Last := LowerCase(Trim(Copy(One, Q + 1, MaxInt)));
        if (Pos(':', Last) > 0) or (Pos('[', Last) > 0) then
          Continue;   // pseudo-classes and attribute selectors: not supported
        R := TRule.Create;
        R.Decls := Decls;
        R.Order := FRules.Count;
        // split 'p.a.b#x' into element, classes and id
        Parts.Clear;
        P := 1;
        Q := 1;
        while Q <= Length(Last) + 1 do
        begin
          if (Q > Length(Last)) or ((Q > P) and CharInSet(Last[Q], ['.', '#'])) then
          begin
            One := Copy(Last, P, Q - P);
            if One <> '' then
            begin
              if One[1] = '.' then
              begin
                R.Classes.Add(Copy(One, 2, MaxInt));
                Inc(R.Spec, 100);
              end
              else if One[1] = '#' then
              begin
                R.Id := Copy(One, 2, MaxInt);
                Inc(R.Spec, 10000);
              end
              else if One <> '*' then
              begin
                R.Elem := One;
                Inc(R.Spec);
              end;
            end;
            P := Q;
          end;
          Inc(Q);
        end;
        FRules.Add(R);
      end;
    end;
  finally
    Sels.Free;
    Parts.Free;
  end;
end;

function TEpubStyleSheet.StyleOf(const ALocal, AClass, AId, AStyleAttr: string): TEpubStyle;
var
  I, K, Pass, Best: Integer;
  R: TRule;
  Cls: string;
  Match: Boolean;
  Hits: TList;
begin
  Result := EpubEmptyStyle;
  Cls := ' ' + LowerCase(StringReplace(StringReplace(AClass, #9, ' ', [rfReplaceAll]), #10, ' ',
    [rfReplaceAll])) + ' ';
  Hits := TList.Create;
  try
    for I := 0 to FRules.Count - 1 do
    begin
      R := TRule(FRules[I]);
      if (R.Elem <> '') and (R.Elem <> ALocal) then
        Continue;
      if (R.Id <> '') and (R.Id <> LowerCase(AId)) then
        Continue;
      Match := True;
      for K := 0 to R.Classes.Count - 1 do
        if Pos(' ' + R.Classes[K] + ' ', Cls) = 0 then
        begin
          Match := False;
          Break;
        end;
      if Match then
        Hits.Add(R);
    end;
    // apply in specificity order, then source order (selection sort: few hits)
    for Pass := 0 to Hits.Count - 1 do
    begin
      Best := Pass;
      for I := Pass + 1 to Hits.Count - 1 do
        if (TRule(Hits[I]).Spec < TRule(Hits[Best]).Spec) or
          ((TRule(Hits[I]).Spec = TRule(Hits[Best]).Spec) and
           (TRule(Hits[I]).Order < TRule(Hits[Best]).Order)) then
          Best := I;
      if Best <> Pass then
        Hits.Exchange(Pass, Best);
      EpubApplyDeclarations(Result, TRule(Hits[Pass]).Decls);
    end;
  finally
    Hits.Free;
  end;
  if AStyleAttr <> '' then
    EpubApplyDeclarations(Result, AStyleAttr);
end;

end.
