{ The outside components EpubReader ships, with their licences, for
  About > Licences (owner, 2026-11-26: "There are external licenses we need
  to display at some point - a button on About can show another submenu
  with license info"; zip 344).

  Only what the build being made contains is listed: Skia and Skia4Delphi
  everywhere, FFmpeg on a desktop (a phone plays with the system's own
  player), the Android libraries Delphi deploys on Android, Steamworks in
  a Steam build. The texts are pages for the menu's box (LicencePages):
  the box does not scroll, so a licence is shown a page at a time. }
unit uLicences;

interface

type
  { One component and its licence. }
  TLicenceInfo = record
    { The component ('Skia'). }
    Name: string;
    { Its licence, short ('BSD 3-Clause'). }
    Licence: string;
    { The notice: what it is, the copyright, the licence's text or where
      it is (paragraphs split by blank lines). }
    Text: string;
  end;

{ The components of this build, in the order shown.
  @returns(the list) }
function ReaderLicences: TArray<TLicenceInfo>;

{ AText cut into pages of about AChars characters at its blank lines (a
  paragraph longer than that is a page of its own).
  @param(AText  the text)
  @param(AChars  a page's length)
  @returns(the pages, one at least) }
function LicencePages(const AText: string; AChars: Integer): TArray<string>;

implementation

uses
  System.SysUtils;

const
  { A blank line: the texts' paragraphs. }
  PARA = #10#10;

  { Skia's LICENSE (skia.googlesource.com/skia, LICENSE), as published. }
  SKIA_TEXT =
    'Skia, the 2D graphics library that draws the page, the library and the menus.' + PARA +
    'Copyright (c) 2011 Google Inc. All rights reserved.' + PARA +
    'Redistribution and use in source and binary forms, with or without modification, are permitted ' +
    'provided that the following conditions are met:' + PARA +
    '* Redistributions of source code must retain the above copyright notice, this list of conditions ' +
    'and the following disclaimer.' + PARA +
    '* Redistributions in binary form must reproduce the above copyright notice, this list of conditions ' +
    'and the following disclaimer in the documentation and/or other materials provided with the ' +
    'distribution.' + PARA +
    '* Neither the name of the copyright holder nor the names of its contributors may be used to endorse ' +
    'or promote products derived from this software without specific prior written permission.' + PARA +
    'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR ' +
    'IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND ' +
    'FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR ' +
    'CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL ' +
    'DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, ' +
    'DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER ' +
    'IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF ' +
    'THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.';

  { Skia4Delphi's: the MIT licence. THE COPYRIGHT LINE IS TO BE CHECKED
    against the LICENSE that comes with it (zip 344: not read). }
  SKIA4DELPHI_TEXT =
    'Skia4Delphi, Skia for Delphi (part of RAD Studio).' + PARA +
    'Copyright (c) the Skia4Delphi Project.' + PARA +
    'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and ' +
    'associated documentation files (the "Software"), to deal in the Software without restriction, ' +
    'including without limitation the rights to use, copy, modify, merge, publish, distribute, ' +
    'sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is ' +
    'furnished to do so, subject to the following conditions:' + PARA +
    'The above copyright notice and this permission notice shall be included in all copies or ' +
    'substantial portions of the Software.' + PARA +
    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT ' +
    'NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND ' +
    'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES ' +
    'OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN ' +
    'CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.';

  { FFmpeg's notice (a desktop build). }
  FFMPEG_TEXT =
    'FFmpeg''s libraries (avutil, avcodec, avformat, swresample) decode and play the sound. FFmpeg is a ' +
    'trademark of Fabrice Bellard, originator of the FFmpeg project.' + PARA +
    'They are used under the GNU Lesser General Public License, version 2.1 or later - unless the build ' +
    'of them that came with this program says otherwise (About says which licence the libraries loaded ' +
    'carry). They are separate files beside the program and can be replaced by another build of the same ' +
    'version.' + PARA +
    'The licence''s full text and the build''s configure line are in the licences folder beside the ' +
    'program (FFmpeg-COPYING.LGPLv2.1, FFmpeg-BUILD-INFO.txt). Their source: https://ffmpeg.org/releases/ ' +
    '(the version in FFmpeg-BUILD-INFO.txt). More: https://ffmpeg.org/legal.html';

  { The Android libraries Delphi deploys (an Android build). }
  ANDROID_TEXT =
    'On Android, Delphi''s runtime comes with AndroidX and other Android libraries of the Android Open ' +
    'Source Project and Google.' + PARA +
    'Copyright (c) The Android Open Source Project, and Google LLC.' + PARA +
    'Licensed under the Apache License, Version 2.0 (the "License"); you may not use these files except ' +
    'in compliance with the License. You may obtain a copy of the License at ' +
    'https://www.apache.org/licenses/LICENSE-2.0' + PARA +
    'Unless required by applicable law or agreed to in writing, software distributed under the License ' +
    'is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or ' +
    'implied. See the License for the specific language governing permissions and limitations under the ' +
    'License.';

  { Steamworks' notice (a Steam build). }
  STEAM_TEXT =
    'The Steamworks SDK (steam_api) lets the program use Steam: Steam Input for game pads, the overlay ' +
    'and Big Picture.' + PARA +
    'Steamworks SDK Copyright (c) Valve Corporation. Used under the Steamworks SDK Access Agreement.' +
    PARA + 'Steam and the Steam logo are trademarks and/or registered trademarks of Valve Corporation in ' +
    'the U.S. and/or other countries.';

{ One entry. }
function Entry(const AName, ALicence, AText: string): TLicenceInfo;
begin
  Result.Name := AName;
  Result.Licence := ALicence;
  Result.Text := AText;
end;

function ReaderLicences: TArray<TLicenceInfo>;
begin
  Result := [Entry('Skia', 'BSD 3-Clause', SKIA_TEXT), Entry('Skia4Delphi', 'MIT', SKIA4DELPHI_TEXT)];
  {$IF Defined(ANDROID)}
  Result := Result + [Entry('Android libraries', 'Apache 2.0', ANDROID_TEXT)];
  {$ELSEIF not Defined(IOS)}
  Result := Result + [Entry('FFmpeg', 'LGPL 2.1+', FFMPEG_TEXT)];
  {$ENDIF}
  {$IFDEF STEAMBUILD}
  Result := Result + [Entry('Steamworks', 'Valve', STEAM_TEXT)];
  {$ENDIF}
end;

function LicencePages(const AText: string; AChars: Integer): TArray<string>;
var
  Paras: TArray<string>;
  Page: string;
  I: Integer;
begin
  Result := nil;
  Paras := AText.Split([PARA]);
  Page := '';
  for I := 0 to High(Paras) do
  begin
    // the page is full: this paragraph starts the next
    if (Page <> '') and (Length(Page) + Length(PARA) + Length(Paras[I]) > AChars) then
    begin
      Result := Result + [Page];
      Page := '';
    end;
    if Page = '' then
      Page := Paras[I]
    else
      Page := Page + PARA + Paras[I];
  end;
  if (Page <> '') or (Length(Result) = 0) then
    Result := Result + [Page];
end;

end.
