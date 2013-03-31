unit VideWizard;

interface

uses
  Classes,
  System.SysUtils,
  ToolsAPI,
  Vcl.AppEvnts,
  Vcl.Forms,
  Winapi.Windows,
  Winapi.Messages;

type
  TVIDEWizard = class(TNotifierObject, IOTAWizard)
  private
    FEvents: TApplicationEvents;
    procedure DoApplicationMessage(var Msg: TMsg; var Handled: Boolean);
  public
    constructor Create;
    // IOTAWizard interafce methods(required for all wizards/experts)
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

var VideWiz: TVIDEWizard;

implementation

uses Vcl.Dialogs;

function IsEditControl(AControl: TComponent): Boolean;
begin
  Result := (AControl <> nil) and AControl.ClassNameIs('TEditControl') and SameText(AControl.Name, 'Editor');
end;

constructor TVIDEWizard.Create;
begin
  // XXX free Application Events.
  FEvents := TApplicationEvents.Create(nil);
  FEvents.OnMessage := DoApplicationMessage;
end;

procedure TVIDEWizard.DoApplicationMessage(var Msg: TMsg; var Handled: Boolean);
var
  Key: Word;
  ScanCode: Word;
  Shift: TShiftState;
  Chars: array[1..2] of WideChar;
  NumChars: Integer;
  KeyState: TKeyboardState;
  i: Integer;
begin
  if (Msg.message = WM_KEYDOWN) and IsEditControl(Screen.ActiveControl) then
  begin
    Key := Msg.wParam;
    ScanCode := (Msg.lParam and $00FF0000) shr 16;
    Shift := KeyDataToShiftState(Msg.lParam);

    // If we've pressed ctrl or alt then we don't want to translate
    // the keyboard state into a character.
    if not ((ssCtrl in Shift) or (ssAlt in Shift)) then
    begin
      GetKeyboardState(keyState);
      NumChars := ToUnicode(Key, ScanCode, KeyState, @Chars, 2, 0);

      for i := 1 to NumChars do
      begin
        ShowMessage(Chars[i]);
      end;
    end;
  end;
end;

procedure TVIDEWizard.Execute;
begin
end;

function TVIDEWizard.GetIDString: string;
begin
  Result := 'VIDE.VIDEWizard';
end;

function TVIDEWizard.GetName: string;
begin
  Result := 'VIDE Wizard';
end;

function TVIDEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

end.
