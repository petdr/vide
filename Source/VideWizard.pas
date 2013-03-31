unit VideWizard;

interface

uses
  Classes,
  ToolsAPI;

type
  THelloWizard = class(TNotifierObject, IOTAMenuWizard, IOTAWizard)
  public
    // IOTAWizard interafce methods(required for all wizards/experts)
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    // IOTAMenuWizard (creates a simple menu item on the help menu)
    function GetMenuText: string;
  end;

var VideWiz: THelloWizard;

implementation

uses Vcl.Dialogs;

procedure THelloWizard.Execute;
begin
  ShowMessage('Hello World!');
end;

function THelloWizard.GetIDString: string;
begin
  Result := 'EB.HelloWizard';
end;

function THelloWizard.GetMenuText: string;
begin
  Result := '&Hello Wizard';
end;

function THelloWizard.GetName: string;
begin
  Result := 'Hello Wizard';
end;

function THelloWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

end.
