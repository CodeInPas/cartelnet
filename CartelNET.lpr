program CartelNET;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // Menyertakan widgetset LCL
  Forms,
  UMain, UGameTypes, UDatabase, UAIClient, UGameEngine,uSetting;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='CartelNET: Dark Operator';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.

