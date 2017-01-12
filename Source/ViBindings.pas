unit ViBindings;

interface

uses
  Classes,
  ToolsAPI,
  Winapi.Windows;

type
  TViRegister = record
    IsLine: Boolean;
    Text: String;
  end;

  TViAction = record
    ActionChar: Char;
    FInDelete, FInChange: Boolean;
    FEditCount, FCount: Integer;
    FInsertText: string;
  end;

  TViBindings = class(TObject)
  private
    FInsertMode: Boolean;
    FActive: Boolean;
    FParsingNumber: Boolean;
    FInDelete: Boolean;
    FInChange: Boolean;
    FInMark: Boolean;
    FInGotoMark: Boolean;
    FInRepeatChange: Boolean;
    FEditCount: Integer;
    FCount: Integer;
    FSelectedRegister: Integer;
    FPreviousAction: TViAction;
    FInsertText: String;
    FMarkArray: array[0..255] of TOTAEditPos;
    FRegisterArray: array[0..255] of TViRegister;
    function GetCount: Integer;
    procedure ResetCount;
    procedure UpdateCount(key: Char);
    function GetPositionForMove(key: Char; count: Integer): TOTAEditPos;
    function IsMovementKey(key: Char): Boolean;
  protected
  public
    constructor Create;
    procedure EditKeyDown(Key, ScanCode: Word; Shift: TShiftState; Msg: TMsg; var Handled: Boolean);
    procedure EditChar(Key, ScanCode: Word; Shift: TShiftState; Msg: TMsg; var Handled: Boolean);
    property Count: Integer read GetCount;
    // Are we in insert mode?
    property InsertMode: Boolean read FInsertMode write FInsertMode;
    // Are the vi bindings active?
    property Active: Boolean read FActive write FActive;
  end;

implementation

uses
  System.SysUtils;

function QuerySvcs(const Instance: IUnknown; const Intf: TGUID; out Inst): Boolean;
begin
  Result := (Instance <> nil) and Supports(Instance, Intf, Inst);
end;

function GetEditBuffer: IOTAEditBuffer;
var
  iEditorServices: IOTAEditorServices;
begin
  QuerySvcs(BorlandIDEServices, IOTAEditorServices, iEditorServices);
  if iEditorServices <> nil then
  begin
    Result := iEditorServices.GetTopBuffer;
    Exit;
  end;
  Result := nil;
end;

function GetTopMostEditView: IOTAEditView;
var
  iEditBuffer: IOTAEditBuffer;
begin
  iEditBuffer := GetEditBuffer;
  if iEditBuffer <> nil then
  begin
    Result := iEditBuffer.GetTopView;
    Exit;
  end;
  Result := nil;
end;

function GetEditPosition: IOTAEditPosition;
var
  iEditBuffer: IOTAEditBuffer;
begin
  iEditBuffer := GetEditBuffer;
  if iEditBuffer <> nil then
  begin
    Result := iEditBuffer.GetEditPosition;
    Exit;
  end;
  Result := nil;
end;

{ TiBindings }

constructor TViBindings.Create;
begin
  Active := True;
  InsertMode := False;
  FParsingNumber := False;
  FInDelete := False;
  FInChange := False;
  FInMark := False;
  FInGotoMark := False;
  FInRepeatChange := False;
  FCount := 0;
  FEditCount := 0;
  FSelectedRegister := 0;
end;

procedure TViBindings.EditChar(Key, ScanCode: Word; Shift: TShiftState; Msg: TMsg; var Handled: Boolean);
var
  c: Char;
  EditPosition: IOTAEditPosition;
  EditBlock: IOTAEditBlock;
  Pos: TOTAEditPos;
  count: Integer;
  i: Integer;

  procedure DeleteBlock(IsLine: Boolean);
  begin
    count := GetCount * FEditCount;
    ResetCount;
    Pos := GetPositionForMove(c, count);
    if (c = 'e') or (c = 'E') then Pos.Col := Pos.Col + 1;

    EditBlock := GetTopMostEditView.Block;
    EditBlock.Reset;
    EditBlock.BeginBlock;
    EditBlock.Extend(Pos.Line, Pos.Col);
    FRegisterArray[FSelectedRegister].IsLine := IsLine;
    FRegisterArray[FSelectedRegister].Text := EditBlock.Text;
    EditBlock.Delete;
    EditBlock.EndBlock;
  end;

  procedure SavePreviousAction;
  begin
    self.FPreviousAction.ActionChar := c;
    self.FPreviousAction.FInDelete := FInDelete;
    self.FPreviousAction.FInChange := FInChange;
    self.FPreviousAction.FEditCount := FEditCount;
    self.FPreviousAction.FCount := FCount;
    // self.FPreviousAction.FInsertText := FInsertText;
  end;

  procedure SwitchToInsertModeOrDoPreviousAction;
  begin
    if (FInRepeatChange) then
      EditPosition.InsertText(FPreviousAction.FInsertText)
    else
    begin
      SavePreviousAction;
      InsertMode := True;
    end;
  end;
begin
  if not Active then Exit;

  // IOTAEditReader makes editor appear as a buffer.
  if not InsertMode then
  begin
    c := Chr(Key);
    EditPosition := GetEditPosition;
    if FInMark then
    begin
      FMarkArray[Ord(c)].Col := EditPosition.Column;
      FMarkArray[Ord(c)].Line := EditPosition.Row;
      FInMark := False;
    end
    else if FInGotoMark then
    begin
      EditPosition.Move(FMarkArray[Ord(c)].Line, FMarkArray[Ord(c)].Col);
      FInGotoMark := False;
    end
    else
    if IsMovementKey(c) then
    begin
      if FInDelete then
      begin
        if not FInRepeatChange then
          SavePreviousAction;

        DeleteBlock(False);
        FInDelete := False;
      end
      else if FInChange then
      begin
        if FInRepeatChange then
        begin
          DeleteBlock(False);
          EditPosition.InsertText(FPreviousAction.FInsertText)
        end
        else
        begin
          if (c = 'w') then c := 'e';
          if (c = 'W') then c := 'E';
          SavePreviousAction;
          DeleteBlock(False);
          InsertMode := True;
        end;
        FInChange := False;
      end
      else
      begin
        Pos := GetPositionForMove(c, GetCount);
        EditPosition.Move(Pos.Line, Pos.Col);
      end;
      ResetCount;
    end
    else if CharInSet(c, ['0'..'9']) then
    begin
      UpdateCount(c);
    end
    else if FInDelete and (c = 'd') then
    begin
      if not FInRepeatChange then
        SavePreviousAction;

      EditPosition.MoveBOL;
      c := 'j';
      DeleteBlock(True);
      FInDelete := False;
    end
    else
    begin
      count := GetCount;
      case c of
        'a':
          begin
            EditPosition.MoveRelative(0, 1);
            SwitchToInsertModeOrDoPreviousAction;
          end;
        'A':
          begin
            EditPosition.MoveEOL;
            SwitchToInsertModeOrDoPreviousAction;
          end;
        'c':
          begin
            if FInChange then
            begin
              EditPosition.MoveBOL;
              Self.EditChar(Word('$'), ScanCode, Shift, Msg, Handled);
            end
            else
            begin
              FInChange := True;
              FEditCount := count;
            end;
          end;
        'C':
          begin
            FInChange := True;
            FEditCount := count;
            Self.EditChar(Word('$'), ScanCode, Shift, Msg, Handled);
          end;
        'd':
          begin
            FInDelete := True;
            FEditCount := count;
          end;
        'i':
          begin
            SwitchToInsertModeOrDoPreviousAction;
          end;
        'I':
          begin
            EditPosition.MoveBOL;
            SwitchToInsertModeOrDoPreviousAction;
          end;
        'J':
          begin
            EditPosition.MoveEOL;
            EditPosition.Delete(1);
          end;
        'm':
          begin
            FInMark := true;
          end;
        'n':
          begin
            EditBlock := GetTopMostEditView.Block;
            EditBlock.Reset;
            EditBlock.BeginBlock;
            EditBlock.ExtendRelative(0, Length(EditPosition.SearchOptions.SearchText));
            if AnsiSameText(EditPosition.SearchOptions.SearchText, EditBlock.Text) then
              EditPosition.MoveRelative(0, Length(EditPosition.SearchOptions.SearchText));
            EditBlock.EndBlock;

            EditPosition.SearchOptions.Direction := sdForward;

            for i := 1 to count do
              EditPosition.SearchAgain;

            EditPosition.MoveRelative(0, -Length(EditPosition.SearchOptions.SearchText));
          end;
        'N':
          begin
            EditPosition.SearchOptions.Direction := sdBackward;

            for i := 1 to count do
              EditPosition.SearchAgain;
          end;
        'o':
          begin
            EditPosition.MoveEOL;
            EditPosition.InsertText(#13#10);
            SwitchToInsertModeOrDoPreviousAction;
            (BorlandIDEServices As IOTAEditorServices).TopView.MoveViewToCursor;
          end;
        'O':
          begin
            EditPosition.MoveBOL;
            EditPosition.InsertText(#13#10);
            EditPosition.MoveCursor(mmSkipWhite or mmSkipRight);
            EditPosition.MoveRelative(-1, 0);
            SwitchToInsertModeOrDoPreviousAction;
            (BorlandIDEServices As IOTAEditorServices).TopView.MoveViewToCursor;
          end;
        'p':
          begin
            if (FRegisterArray[FSelectedRegister].IsLine) then
            begin
              EditPosition.MoveBOL;
              EditPosition.MoveRelative(1, 0);
              EditPosition.Save;
            end
            else
            begin
              EditPosition.MoveRelative(0, 1);
            end;

            EditPosition.InsertText(FRegisterArray[FSelectedRegister].Text);
            if (FRegisterArray[FSelectedRegister].IsLine) then
              EditPosition.Restore;
          end;
        'P':
          begin
            if (FRegisterArray[FSelectedRegister].IsLine) then
            begin
              EditPosition.MoveBOL;
              EditPosition.Save;
            end;
            EditPosition.InsertText(FRegisterArray[FSelectedRegister].Text);
            if (FRegisterArray[FSelectedRegister].IsLine) then
              EditPosition.Restore;
          end;
        'R':
          begin
            // XXX Fix me for '.' command
            GetTopMostEditView.Buffer.BufferOptions.InsertMode := False;
            InsertMode := True;
          end;
        's':
          begin
            EditPosition.Delete(1);
            SwitchToInsertModeOrDoPreviousAction;
          end;
        'S':
          begin
            FInChange := True;
            EditPosition.MoveBOL;
            Self.EditChar(Word('$'), ScanCode, Shift, Msg, Handled);
          end;
        'u':
          begin
            GetEditBuffer.Undo;
          end;
        'x':
          begin
            SavePreviousAction;
            EditPosition.Delete(count);
          end;
        'X':
          begin
            SavePreviousAction;
            EditPosition.MoveRelative(0, -count);
            EditPosition.Delete(count);
          end;
        '.':
          begin
            FInRepeatChange := True;
            FInDelete := FPreviousAction.FInDelete;
            FInChange := FPreviousAction.FInChange;
            FEditCount := FPreviousAction.FEditCount;
            FCount := FPreviousAction.FCount;
            self.EditChar(Ord(FPreviousAction.ActionChar), ScanCode, Shift, Msg, Handled);
            FInRepeatChange := False;
          end;
        '*':
          begin
            if EditPosition.IsWordCharacter then
              EditPosition.MoveCursor(mmSkipWord or mmSkipLeft)
            else
              EditPosition.MoveCursor(mmSkipNonWord or mmSkipRight or mmSkipStream);

            Pos := GetPositionForMove('e', 1);

            EditBlock := GetTopMostEditView.Block;
            EditBlock.Reset;
            EditBlock.BeginBlock;
            EditBlock.Extend(Pos.Line, Pos.Col + 1);
            EditPosition.SearchOptions.SearchText := EditBlock.Text;
            EditBlock.EndBlock;

            // Move to one position after what we're searching for.
            EditPosition.Move(Pos.Line, Pos.Col+1);

            EditPosition.SearchOptions.CaseSensitive := False;
            EditPosition.SearchOptions.Direction := sdForward;
            EditPosition.SearchOptions.FromCursor := True;
            EditPosition.SearchOptions.RegularExpression := False;
            EditPosition.SearchOptions.WholeFile := True;
            EditPosition.SearchOptions.WordBoundary := True;

            for i := 1 to count do
              EditPosition.SearchAgain;

            // Move back to the start of the text we searched for.
            EditPosition.MoveRelative(0, -Length(EditPosition.SearchOptions.SearchText));

            (BorlandIDEServices As IOTAEditorServices).TopView.MoveViewToCursor;
          end;
        '''':
          begin
            FInGotoMark := True;
          end;
      end;
      ResetCount;
    end;
    Handled := True;
    (BorlandIDEServices As IOTAEditorServices).TopView.Paint;
  end;
end;

procedure TViBindings.EditKeyDown(Key, ScanCode: Word; Shift: TShiftState; Msg: TMsg; var Handled: Boolean);
begin
  if not Active then Exit;

  if InsertMode then
  begin
    if (Key = VK_ESCAPE) then
    begin
      GetTopMostEditView.Buffer.BufferOptions.InsertMode := True;
      InsertMode := False;
      Handled := True;
      Self.FPreviousAction.FInsertText := FInsertText;
      FInsertText := '';
    end;
  end
  else
  begin
    if (((Key >= Ord('A')) and (Key <= Ord('Z'))) or
        ((Key >= Ord('0')) and (Key <= Ord('9'))) or
        ((Key >= 186) and (Key <= 192)) or
        ((Key >= 219) and (Key <= 222))) and
        not ((ssCtrl in Shift) or (ssAlt in Shift)) and
        not InsertMode then
    begin
      // If the keydown is a standard keyboard press not altered with a ctrl or alt key
      // then create a WM_CHAR message so we can do all the locale mapping of the keyboard
      // and then handle the resulting key in TViBindings.EditChar
      // XXX can we switch to using ToAscii like we do for setting FInsertText
      TranslateMessage(Msg);
      Handled := True;
    end;
  end;
end;

function TViBindings.IsMovementKey(key: Char): Boolean;
begin
  if (key = '0') and FParsingNumber then
    Result:= False
  else
    Result := CharInSet(key, ['0', '$', 'b', 'B', 'e', 'E', 'h', 'j', 'k', 'l', 'w', 'W']);
end;

procedure TViBindings.ResetCount;
begin
  FCount := 0;
  FParsingNumber := False;
end;

procedure TViBindings.UpdateCount(key: Char);
begin
  FParsingNumber := True;
  if CharInSet(key, ['0'..'9']) then
    FCount := 10 * FCount + (Ord(key) - Ord('0'));
end;

type TViCharClass = (viWhiteSpace, viWord, viSpecial);

// Given a movement key and a count return the position in the buffer where that movement would take you.
// TOTAEditPos
function TViBindings.GetCount: Integer;
begin
  if (FCount = 0) then
    Result := 1
  else
    Result := FCount;
end;

function TViBindings.GetPositionForMove(key: Char; count: Integer) : TOTAEditPos;
var
  Pos: TOTAEditPos;
  EditPosition: IOTAEditPosition;
  i: Integer;
  nextChar: TViCharClass;

  function CharAtRelativeLocation(col: Integer): TViCharClass;
  begin
    EditPosition.Save;
    EditPosition.MoveRelative(0, col);
    if EditPosition.IsWhiteSpace or (EditPosition.Character = #$D) then
    begin
      Result := viWhiteSpace
    end
    else if EditPosition.IsWordCharacter then
    begin
      Result := viWord;
    end
    else
    begin
      Result := viSpecial;
    end;
    EditPosition.Restore;
  end;
begin
  EditPosition := GetEditPosition;
  EditPosition.Save;

  case Key of
    '0':
      begin
        EditPosition.MoveBOL;
      end;
    '$':
      begin
        EditPosition.MoveEOL;
      end;
    'b':
      begin
        for i := 1 to count do
        begin
          nextChar := CharAtRelativeLocation(-1);
          if EditPosition.IsWordCharacter and ((nextChar = viSpecial) or (nextChar = viWhiteSpace)) then
            EditPosition.MoveRelative(0, -1);

          if EditPosition.IsSpecialCharacter and ((nextChar = viWord) or (nextChar = viWhiteSpace)) then
            EditPosition.MoveRelative(0, -1);

          if EditPosition.IsWhiteSpace then
          begin
            EditPosition.MoveCursor(mmSkipWhite or mmSkipLeft or mmSkipStream);
            EditPosition.MoveRelative(0, -1);
          end;

          if EditPosition.IsWordCharacter then
          begin
            // Skip to first non word character.
            EditPosition.MoveCursor(mmSkipWord or mmSkipLeft);
          end
          else if EditPosition.IsSpecialCharacter then
          begin
            // Skip to the first non special character
            EditPosition.MoveCursor(mmSkipSpecial or mmSkipLeft);
          end;
        end;
      end;
    'B':
      begin
        for i := 1 to count do
        begin
          EditPosition.MoveCursor(mmSkipWhite or mmSkipLeft or mmSkipStream);
          EditPosition.MoveCursor(mmSkipNonWhite or mmSkipLeft);
        end;
      end;
    'e':
      begin
        for i := 1 to count do
        begin
          nextChar := CharAtRelativeLocation(1);
          if (EditPosition.IsWordCharacter and (nextChar = viWhiteSpace) or (nextChar = viSpecial)) then
            EditPosition.MoveRelative(0, 1);

          if (EditPosition.IsSpecialCharacter and (nextChar = viWhiteSpace) or (nextChar = viWord)) then
            EditPosition.MoveRelative(0, 1);

          if EditPosition.IsWhiteSpace then
            EditPosition.MoveCursor(mmSkipWhite or mmSkipRight or mmSkipStream);

          if EditPosition.IsSpecialCharacter then
            EditPosition.MoveCursor(mmSkipSpecial or mmSkipRight);

          if EditPosition.IsWordCharacter then
            EditPosition.MoveCursor(mmSkipWord or mmSkipRight);

          EditPosition.MoveRelative(0, -1);
        end;
      end;
    'E':
      begin
        for i := 1 to count do
        begin
          if (EditPosition.IsWordCharacter or EditPosition.IsSpecialCharacter) and (CharAtRelativeLocation(1) = viWhiteSpace) then
            EditPosition.MoveRelative(0, 1);

          if EditPosition.IsWhiteSpace then
            EditPosition.MoveCursor(mmSkipWhite or mmSkipRight or mmSkipStream);

          EditPosition.MoveCursor(mmSkipNonWhite or mmSkipRight);
          EditPosition.MoveRelative(0, -1);
        end;
      end;
    'h':
      begin
        EditPosition.MoveRelative(0, -count);
      end;
    'j':
      begin
        EditPosition.MoveRelative(+count, 0);
      end;
    'k':
      begin
        EditPosition.MoveRelative(-count, 0);
      end;
    'l':
      begin
        EditPosition.MoveRelative(0, +count);
      end;
    'w':
      begin
        for i := 1 to count do
        begin
          if EditPosition.IsWordCharacter then
          begin
            // Skip to first non word character.
            EditPosition.MoveCursor(mmSkipWord or mmSkipRight);
          end
          else if EditPosition.IsSpecialCharacter then
          begin
            // Skip to the first non special character
            EditPosition.MoveCursor(mmSkipSpecial or mmSkipRight or mmSkipStream);
          end;

          // If the character is whitespace or EOL then skip that whitespace
          if EditPosition.IsWhiteSpace or (EditPosition.Character = #$D) then
          begin
            EditPosition.MoveCursor(mmSkipWhite or mmSkipRight or mmSkipStream);
          end;
        end;
      end;
    'W':
      begin
        for i := 1 to count do
        begin
          // Goto first white space after the end of the word.
          EditPosition.MoveCursor(mmSkipNonWhite or mmSkipRight);
          // Now skip all the white space until we're at the start of a word again.
          EditPosition.MoveCursor(mmSkipWhite or mmSkipRight or mmSkipStream);
        end;
      end;
  end;

  Pos.Col := EditPosition.Column;
  Pos.Line := EditPosition.Row;
  EditPosition.Restore;

  Result := Pos;
end;

end.

