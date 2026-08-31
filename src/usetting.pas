unit uSetting;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StrUtils, Dialogs, StdCtrls, IniFiles;

type
  { TFormSetting }
  TFormSetting = class(TForm)
    btnCancel: TButton;
    btnSave: TButton;
    cbProvider: TComboBox;
    edtApiKey: TEdit;
    edtEndpoint: TEdit;
    lblApiKey: TLabel;
    lblEndpoint: TLabel;
    lblProvider: TLabel;
    procedure btnCancelClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure LoadSettings;
    procedure SaveSettings;
  public
    SelectedEndpoint: String;
  end;

var
  FormSetting: TFormSetting;

implementation

{$R *.lfm}

{ TFormSetting }

procedure TFormSetting.FormCreate(Sender: TObject);
begin
  cbProvider.Items.Clear;
  cbProvider.Items.Add('Local AI (Llama.cpp)');
  cbProvider.Items.Add('Google Gemini Cloud (API)');
  LoadSettings;
end;

procedure TFormSetting.FormShow(Sender: TObject);
begin
  edtEndpoint.text := AnsiReplaceStr(edtEndpoint.text,'YOUR_API_KEY',edtApiKey.text) ;
end;

procedure TFormSetting.LoadSettings;
var
  Ini: TIniFile;
  IniPath: String;
  ProviderIdx: Integer;
begin
  IniPath := ExpandFileName(ExtractFilePath(Application.ExeName) + '..\data\cartelnet.ini');
  Ini := TIniFile.Create(IniPath);
  try
    ProviderIdx := Ini.ReadInteger('AI', 'Provider', 0);
    cbProvider.ItemIndex := ProviderIdx;
    edtEndpoint.Text := Ini.ReadString('AI', 'Endpoint', 'http://127.0.0.1:8080/v1/chat/completions');
    edtApiKey.Text := Ini.ReadString('AI', 'ApiKey', '');
  finally
    Ini.Free;
  end;
  cbProviderChange(Self);
end;

procedure TFormSetting.SaveSettings;
var
  Ini: TIniFile;
  IniPath: String;
begin
  IniPath := ExpandFileName(ExtractFilePath(Application.ExeName) + '..\data\cartelnet.ini');
  Ini := TIniFile.Create(IniPath);
  try
    Ini.WriteInteger('AI', 'Provider', cbProvider.ItemIndex);
    Ini.WriteString('AI', 'Endpoint', edtEndpoint.Text);
    Ini.WriteString('AI', 'ApiKey', edtApiKey.Text);
  finally
    Ini.Free;
  end;
  SelectedEndpoint := edtEndpoint.Text;
end;

procedure TFormSetting.cbProviderChange(Sender: TObject);
begin
  if cbProvider.ItemIndex = 0 then
  begin
    edtEndpoint.Text := 'http://127.0.0.1:8080/v1/chat/completions';
     edtApiKey.Enabled := False;
  end
  else
  begin
    edtEndpoint.Text := 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=YOUR_API_KEY';
    edtApiKey.Enabled := True;
  end;
end;

procedure TFormSetting.btnSaveClick(Sender: TObject);
begin
  SaveSettings;
  ModalResult := mrOk;
end;

procedure TFormSetting.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
