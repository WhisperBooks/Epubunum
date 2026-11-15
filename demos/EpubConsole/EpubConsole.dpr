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
    EpubConsole <book.epub> --overlay TIMINGS OUT.epub
                [--audio FILE | --book-audio PATH]... [--block]
                [--narrator NAME]           a copy of the book with media
                                            overlays from timed words (see
                                            README.md for TIMINGS)
    EpubConsole <book.epub> --words OUT.txt  every word: its number (what TIMINGS
                                            use), document, role and text
    EpubConsole <book.epub> --clip-timings OUT.txt
                                            TIMINGS made from the book's own
                                            overlays, each clip shared out
                                            over its words by length (a test
                                            aid, not an aligner)

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
  Epub.Book,
  Epub.Writer;

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

{ Writes ALines as UTF-8 without a BOM. }
procedure SaveLines(ALines: TStringList; const AFileName: string);
var
  Bytes: TBytes;
  Stream: TFileStream;
begin
  ALines.LineBreak := #10;
  Bytes := EpubUtf8Bytes(ALines.Text);
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(Bytes) > 0 then
      Stream.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    Stream.Free;
  end;
end;

{ Writes every word of ABook: number (from 1), document (from 1), role,
  text - tab separated. }
procedure WriteWords(ABook: TEpubBook; const AFileName: string);
var
  Out: TStringList;
  I: Integer;
begin
  Out := TStringList.Create;
  try
    Out.Capacity := ABook.WordCount;
    for I := 0 to ABook.WordCount - 1 do
      Out.Add(Format('%d'#9'%d'#9'%s'#9'%s', [I + 1, ABook.Words[I].Document + 1,
        EpubWordRoleName(ABook.Words[I].Role), ABook.Words[I].Text]));
    SaveLines(Out, AFileName);
    WriteLn(Format('%d word(s) written to %s', [Out.Count, AFileName]));
  finally
    Out.Free;
  end;
end;

{ Writes timings from the book's overlays: each clip's time shared out over
  its words by their length, audio files numbered as AudioFiles lists them
  (give them as --book-audio in that order). }
procedure WriteClipTimings(ABook: TEpubBook; const AFileName: string);
var
  Out, Audio: TStringList;
  I, W, F, L, Chars, A: Integer;
  T, Len: Double;
  FS: TFormatSettings;
begin
  FS := FormatSettings;
  FS.DecimalSeparator := '.';
  Out := TStringList.Create;
  Audio := ABook.AudioFiles;
  try
    Out.Add('# word begin end audio - from the overlays of ' + ExtractFileName(ABook.FileName));
    for I := 0 to Audio.Count - 1 do
      Out.Add(Format('# audio %d: --book-audio %s', [I + 1, Audio[I]]));
    for I := 0 to High(ABook.Clips) do
    begin
      if (ABook.Clips[I].ClipEnd <= ABook.Clips[I].ClipBegin) or not ABook.ClipWords(I, F, L) then
        Continue;
      A := Audio.IndexOf(ABook.Clips[I].AudioPath) + 1;
      Chars := 0;
      for W := F to L do
        Inc(Chars, Length(ABook.Words[W].Text) + 1);
      T := ABook.Clips[I].ClipBegin;
      for W := F to L do
      begin
        Len := (ABook.Clips[I].ClipEnd - ABook.Clips[I].ClipBegin) * (Length(ABook.Words[W].Text) + 1) / Chars;
        Out.Add(Format('%d %.3f %.3f %d', [W + 1, T, T + Len, A], FS));
        T := T + Len;
      end;
    end;
    SaveLines(Out, AFileName);
    WriteLn(Format('%d timed word(s) written to %s', [Out.Count - 1 - Audio.Count, AFileName]));
  finally
    Out.Free;
    Audio.Free;
  end;
end;

{ Writes a copy of ABook with overlays from timings file ATimings. }
procedure WriteOverlay(ABook: TEpubBook; const ATimings, AOut: string; AAudio: TStringList; ABlock: Boolean;
  const ANarrator: string);
var
  W: TEpubWriter;
  Lines, Parts: TStringList;
  I, Audio, Bad: Integer;
  Line: string;
  B, E: Double;
  FS: TFormatSettings;
  Started: TDateTime;
  R: TEpubWriteReport;
begin
  FS := FormatSettings;
  FS.DecimalSeparator := '.';
  Started := Now;
  W := TEpubWriter.Create(ABook);
  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    // audio files are numbered in the order given: --audio and --book-audio
    // keep their own order inside AAudio (Objects: 1 = in the book)
    for I := 0 to AAudio.Count - 1 do
      if AAudio.Objects[I] <> nil then
        W.AddBookAudio(AAudio[I])
      else
        W.AddAudioFile(AAudio[I]);
    if AAudio.Count = 0 then
      raise EEpubError.Create('--overlay needs an audio file: --audio FILE or --book-audio PATH');
    if ABlock then
      W.Level := eolBlock;
    W.Narrator := ANarrator;
    Lines.LoadFromFile(ATimings);
    Parts.Delimiter := ' ';
    Bad := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(StringReplace(Lines[I], #9, ' ', [rfReplaceAll]));
      if (Line = '') or (Line[1] = '#') then
        Continue;
      Parts.DelimitedText := Line;
      Audio := 1;
      if (Parts.Count < 3) or not TryStrToFloat(Parts[1], B, FS) or not TryStrToFloat(Parts[2], E, FS) or
        ((Parts.Count > 3) and not TryStrToInt(Parts[3], Audio)) or (StrToIntDef(Parts[0], 0) < 1) then
      begin
        Inc(Bad);
        Continue;
      end;
      W.AddWord(StrToInt(Parts[0]) - 1, Audio - 1, B, E);
    end;
    if Bad > 0 then
      WriteLn(Format('  %d line(s) of %s could not be read', [Bad, ATimings]));
    W.SaveToFile(AOut);
    R := W.Report;
    WriteLn(Format('%s written in %d ms: %d document(s), %d clip(s), %s of audio', [AOut,
      MilliSecondsBetween(Now, Started), R.Documents, R.Clips, TimeText(R.Duration)]));
    WriteLn(Format('  %d new id(s), %d id(s) of the book used, %d timed word(s) left out', [R.NewIds,
      R.ReusedIds, R.Skipped]));
    if R.Upgraded then
      WriteLn('  The book was EPUB 2: it is EPUB 3 now (overlays need it)');
    if R.Warnings <> '' then
      WriteLn('  Warning: ', StringReplace(Trim(R.Warnings), #10, sLineBreak + '  Warning: ', [rfReplaceAll]));
  finally
    Parts.Free;
    Lines.Free;
    W.Free;
  end;
end;

var
  Book: TEpubBook;
  Arg, FileName, TextFile, AudioPath, ExtractDir: string;
  OverlayTimings, OverlayOut, ClipTimings, Narrator, WordsFile: string;
  OverlayAudio: TStringList;
  Block: Boolean;
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
  OverlayAudio := TStringList.Create;
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
      OverlayTimings := '';
      OverlayOut := '';
      ClipTimings := '';
      WordsFile := '';
      Narrator := '';
      Block := False;
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
        else if (Arg = '--overlay') and (I + 1 <= ParamCount) then
        begin
          OverlayTimings := ParamStr(I);
          OverlayOut := ParamStr(I + 1);
          Inc(I, 2);
        end
        else if (Arg = '--audio') and (I <= ParamCount) then
        begin
          OverlayAudio.Add(ParamStr(I));
          Inc(I);
        end
        else if (Arg = '--book-audio') and (I <= ParamCount) then
        begin
          OverlayAudio.AddObject(ParamStr(I), OverlayAudio);   // any object: in the book
          Inc(I);
        end
        else if Arg = '--block' then
          Block := True
        else if (Arg = '--narrator') and (I <= ParamCount) then
        begin
          Narrator := ParamStr(I);
          Inc(I);
        end
        else if (Arg = '--words') and (I <= ParamCount) then
        begin
          WordsFile := ParamStr(I);
          Inc(I);
        end
        else if (Arg = '--clip-timings') and (I <= ParamCount) then
        begin
          ClipTimings := ParamStr(I);
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
        WriteLn('                   [--overlay TIMINGS OUT.epub (--audio FILE | --book-audio PATH)...');
        WriteLn('                    [--block] [--narrator NAME]] [--clip-timings OUT.txt] [--words OUT.txt]');
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

      if WordsFile <> '' then
        WriteWords(Book, WordsFile);

      if ClipTimings <> '' then
        WriteClipTimings(Book, ClipTimings);

      if OverlayTimings <> '' then
        WriteOverlay(Book, OverlayTimings, OverlayOut, OverlayAudio, Block, Narrator);
      ExitCode := 0;
    except
      on E: Exception do
        WriteLn(ErrOutput, E.ClassName, ': ', E.Message);
    end;
  finally
    Book.Free;
    OverlayAudio.Free;
  end;
end.
