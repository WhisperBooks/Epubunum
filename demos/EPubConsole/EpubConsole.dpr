{ EpubConsole - console demo and smoke test of EpubUnum, without the
  component (TEpubBook directly).

  Usage:
    EpubConsole <book.epub>                 metadata, reading order, contents,
                                            word roles, media overlays
    EpubConsole <book.epub> --text OUT.txt  the text of the reading order, a
                                            paragraph per line (what an aligner
                                            reads); --body-only leaves out
                                            captions, notes and navigation
    EpubConsole <book.epub> --layout N      the blocks of document N (from 1)
    EpubConsole <book.epub> --at AUDIO S    the clip and words read at S seconds
                                            of audio file AUDIO (its path in
                                            the book)
    EpubConsole <book.epub> --extract DIR   every file of the book under DIR

  Like any user project it lists only its own sources: the library comes
  from the runtime package EpubUnum (Delphi's Dcp folder) - build it first. }
program EpubConsole;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  DateUtils,
  // the library: DCUs of the runtime package EpubUnum (Delphi's Dcp folder)
  Epub.Zip,
  Epub.Layout,
  Epub.Book;

{ "h:mm:ss.mmm" of ASeconds. }
function TimeText(ASeconds: Double): string;
var
  Ms: Int64;
begin
  if ASeconds < 0 then
    ASeconds := 0;
  Ms := Round(ASeconds * 1000);
  Result := Format('%d:%.2d:%.2d.%.3d', [Ms div 3600000, (Ms div 60000) mod 60, (Ms div 1000) mod 60,
    Ms mod 1000]);
end;

{ The words AFirst..ALast of ABook joined by spaces. }
function WordsText(ABook: TEpubBook; AFirst, ALast: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := AFirst to ALast do
  begin
    if I > AFirst then
      Result := Result + ' ';
    Result := Result + ABook.Words[I].Text;
  end;
end;

{ Writes the text of the reading order, one block per line. }
procedure WriteText(ABook: TEpubBook; const AFileName: string; ABodyOnly: Boolean);
var
  Out: TStringList;
  D, K, W: Integer;
  L: TEpubDocLayout;
  Line: string;
  Blk: TEpubBlock;
  Bytes: TBytes;
  Stream: TFileStream;
begin
  Out := TStringList.Create;
  try
    for D := 0 to High(ABook.Documents) do
    begin
      if ABook.Documents[D].WordCount = 0 then
        Continue;
      L := ABook.DocumentLayout(D);
      try
        for K := 0 to L.BlockCount - 1 do
        begin
          Blk := L.Blocks[K];
          if Length(Blk.Words) = 0 then
            Continue;
          if ABodyOnly and (Blk.Role in [ewrCaption, ewrNote, ewrNav]) then
            Continue;
          Line := '';
          for W := 0 to High(Blk.Words) do
          begin
            if W > 0 then
              Line := Line + ' ';
            Line := Line + L.Words[Blk.Words[W].Word].Text;
          end;
          Out.Add(Line);
        end;
      finally
        L.Free;
      end;
    end;
    // UTF-8 without a BOM, the same with Delphi and FPC
    Bytes := EpubUtf8Bytes(Out.Text);
    Stream := TFileStream.Create(AFileName, fmCreate);
    try
      if Length(Bytes) > 0 then
        Stream.WriteBuffer(Bytes[0], Length(Bytes));
    finally
      Stream.Free;
    end;
    WriteLn(Format('%d paragraph(s) written to %s', [Out.Count, AFileName]));
  finally
    Out.Free;
  end;
end;

var
  Book: TEpubBook;
  Arg, FileName, TextFile, AudioPath, ExtractDir: string;
  LayoutDoc, I, K, F, L, Notes: Integer;
  AtTime: Double;
  BodyOnly: Boolean;
  Roles: array[TEpubWordRole] of Integer;
  R: TEpubWordRole;
  S: string;
  Lay: TEpubDocLayout;
  Audio: TStringList;
  Started: TDateTime;
  FS: TFormatSettings;
begin
  ExitCode := 1;
  Book := nil;
  try
    try
      FS := FormatSettings;
      FS.DecimalSeparator := '.';
      FileName := '';
      TextFile := '';
      AudioPath := '';
      ExtractDir := '';
      LayoutDoc := 0;
      AtTime := -1;
      BodyOnly := False;
      I := 1;
      while I <= ParamCount do
      begin
        Arg := ParamStr(I);
        Inc(I);
        if (Arg = '--text') and (I <= ParamCount) then
        begin
          TextFile := ParamStr(I);
          Inc(I);
        end
        else if Arg = '--body-only' then
          BodyOnly := True
        else if (Arg = '--layout') and (I <= ParamCount) then
        begin
          LayoutDoc := StrToInt(ParamStr(I));
          Inc(I);
        end
        else if (Arg = '--at') and (I + 1 <= ParamCount) then
        begin
          AudioPath := ParamStr(I);
          AtTime := StrToFloat(ParamStr(I + 1), FS);
          Inc(I, 2);
        end
        else if (Arg = '--extract') and (I <= ParamCount) then
        begin
          ExtractDir := ParamStr(I);
          Inc(I);
        end
        else if (Length(Arg) > 1) and (Arg[1] = '-') then
        begin
          WriteLn(ErrOutput, 'Unknown option ', Arg, ' (run without arguments for the usage)');
          Exit;
        end
        else if FileName = '' then
          FileName := Arg;
      end;
      if FileName = '' then
      begin
        WriteLn('Usage: EpubConsole <book.epub> [--text OUT.txt [--body-only]] [--layout N]');
        WriteLn('                   [--at AUDIO SECONDS] [--extract DIR]');
        Exit;
      end;

      Started := Now;
      Book := TEpubBook.Create(FileName);
      Book.LoadText;
      WriteLn(Format('%s: EPUB %s, opened and read in %d ms', [FileName, Book.Version,
        MilliSecondsBetween(Now, Started)]));
      WriteLn('  Title:      ', Book.Title);
      for I := 0 to Book.Creators.Count - 1 do
        WriteLn('  Creator:    ', Book.Creators[I]);
      WriteLn('  Language:   ', Book.Language);
      WriteLn('  Identifier: ', Book.Identifier);
      if Book.Publisher <> '' then
        WriteLn('  Publisher:  ', Book.Publisher);
      if Book.CoverPath <> '' then
        WriteLn('  Cover:      ', Book.CoverPath);
      WriteLn(Format('  %d manifest item(s), %d document(s) in the reading order, %d contents entr(ies)',
        [Length(Book.Items), Length(Book.Documents), Length(Book.Toc)]));
      for I := 0 to High(Book.Toc) do
      begin
        S := '';
        if Book.Toc[I].Fragment <> '' then
          S := '#' + Book.Toc[I].Fragment;
        WriteLn(Format('    %s%s  (document %d%s)', [StringOfChar(' ', Book.Toc[I].Level * 2), Book.Toc[I].Title,
          Book.Toc[I].Document + 1, S]));
      end;
      FillChar(Roles, SizeOf(Roles), 0);
      for I := 0 to Book.WordCount - 1 do
        Inc(Roles[Book.Words[I].Role]);
      S := '';
      for R := Low(R) to High(R) do
        if Roles[R] > 0 then
          S := S + Format(', %s %d', [EpubWordRoleName(R), Roles[R]]);
      WriteLn(Format('  %d word(s)%s', [Book.WordCount, S]));
      if Length(Book.Clips) = 0 then
        WriteLn('  No media overlays (no synced audio)')
      else
      begin
        Audio := Book.AudioFiles;
        try
          WriteLn(Format('  Media overlays: %d clip(s) over %d audio file(s), %s in all; active class "%s"',
            [Length(Book.Clips), Audio.Count, TimeText(Book.MediaDuration), Book.ActiveClass]));
          for I := 0 to Audio.Count - 1 do
            WriteLn('    ', Audio[I]);
        finally
          Audio.Free;
        end;
        Notes := 0;
        for I := 0 to High(Book.Clips) do
          if not Book.ClipWords(I, F, L) then
            Inc(Notes);
        if Notes > 0 then
          WriteLn(Format('  %d clip(s) point at no words', [Notes]));
      end;

      if TextFile <> '' then
        WriteText(Book, TextFile, BodyOnly);

      if LayoutDoc > 0 then
      begin
        if LayoutDoc > Length(Book.Documents) then
          raise EEpubError.CreateFmt('There is no document %d (the book has %d)', [LayoutDoc, Length(Book.Documents)]);
        Lay := Book.DocumentLayout(LayoutDoc - 1);
        try
          WriteLn(Format('Document %d (%s): %d block(s), %d word(s), %d id(s)', [LayoutDoc,
            Book.Documents[LayoutDoc - 1].Path, Lay.BlockCount, Lay.WordCount, Length(Lay.Ids)]));
          for I := 0 to Lay.BlockCount - 1 do
            with Lay.Blocks[I] do
            begin
              if Kind = ebkImage then
                S := ImagePath
              else
                S := Copy(StringReplace(Text, #10, ' / ', [rfReplaceAll]), 1, 70);
              WriteLn(Format('  %4d %-12s %-8s %3d word(s) %2d run(s)  %s', [I + 1, EpubBlockKindName(Kind),
                EpubWordRoleName(Role), Length(Words), Length(Runs), S]));
            end;
        finally
          Lay.Free;
        end;
      end;

      if AtTime >= 0 then
      begin
        K := Book.ClipAt(AudioPath, AtTime);
        if K < 0 then
          WriteLn(Format('Nothing is read at %s of %s', [TimeText(AtTime), AudioPath]))
        else
        begin
          WriteLn(Format('At %s of %s: clip %d (%s --> %s), %s#%s', [TimeText(AtTime), AudioPath, K + 1,
            TimeText(Book.Clips[K].ClipBegin), TimeText(Book.Clips[K].ClipEnd), Book.Clips[K].TextPath,
            Book.Clips[K].TextId]));
          if Book.ClipWords(K, F, L) then
            WriteLn('  ', WordsText(Book, F, L));
        end;
      end;

      if ExtractDir <> '' then
        WriteLn('Extracted to ', Book.ExtractAll(ExtractDir));
      ExitCode := 0;
    except
      on E: Exception do
        WriteLn(ErrOutput, E.ClassName, ': ', E.Message);
    end;
  finally
    Book.Free;
  end;
end.
