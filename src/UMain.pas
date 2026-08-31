unit UMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Math, ExtCtrls, LCLIntf,
  StdCtrls, ComCtrls, Menus, MMSystem, UGameTypes, UDatabase, UGameEngine,
  uSetting, cyPageControl, ColorSpeedButton, Types,UAbout;

type
  { TFormMain }
  TFormMain = class(TForm)
    btnBuyProxy: TButton;
    btnBuyQuantum: TButton;
    btnOpenSettings: TColorSpeedButton;
    cbAction: TComboBox;
    cbLanguage: TComboBox;
    cbTarget: TComboBox;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    mnAbout: TMenuItem;
    mnWeb: TMenuItem;
    mnEzit: TMenuItem;
    Separator1: TMenuItem;
    spGoArena: TColorSpeedButton;
    btnExecute: TColorSpeedButton;
    spGoBM: TColorSpeedButton;
    spGoSetting: TColorSpeedButton;
    cyPageControl1: TcyPageControl;
    edtTaunt: TEdit;
    Image1: TImage;
    lblAction: TLabel;
    lblAIPersona: TLabel;
    lblBandwidth: TLabel;
    lblBudget: TLabel;
    lblFunds: TLabel;
    lblHeat: TLabel;
    lblLanguage: TLabel;
    lblTarget: TLabel;
    lblTaunt: TLabel;
    lblUpgProxy: TLabel;
    lblUpgQuantum: TLabel;
    lbvBudget: TLabel;
    memLog: TMemo;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    pbMap: TPaintBox;
    pbTelemetry: TPaintBox;
    pnlLeft: TPanel;
    pnlRight: TPanel;
    tbsArena: TTabSheet;
    tbBlackMarket: TTabSheet;
    tbsSetting: TTabSheet;
    tbBudget: TTrackBar;
    tmrRender: TTimer;
    procedure btnExecuteClick(Sender: TObject);
    procedure cbActionChange(Sender: TObject);
    procedure btnBuyQuantumClick(Sender: TObject);
    procedure btnBuyProxyClick(Sender: TObject);
    procedure btnOpenSettingsClick(Sender: TObject); // <-- Event handler baru
    procedure cbActionDrawItem(
      Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure cbLanguageDrawItem(
      Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure cbTargetDrawItem(
      Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure edtTauntKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure mnAboutClick(Sender: TObject);
    procedure mnEzitClick(Sender: TObject);
    procedure mnWebClick(Sender: TObject);
    procedure pbMapPaint(Sender: TObject);
    procedure spGoArenaClick(Sender: TObject);
    procedure spGoBMClick(Sender: TObject);
    procedure spGoSettingClick(Sender: TObject);
    procedure tbBudgetChange(Sender: TObject);
    procedure tmrRenderTimer(Sender: TObject);
    procedure pbTelemetryPaint(Sender: TObject); // <-- TAMBAHKAN BARIS INI
  private
    FDatabase: TGameDatabase;
    FEngine: TCartelEngine;
    FMapBuffer: TBitmap;
    FScanlineY: Integer;

    FGlitchActive: Integer;
    FMatrixDrops: array of Double;
    FMatrixSpeeds: array of Double;
    frmAbout : TfrmAbout;
    FDataFlowOffset: Double;

    procedure EngineLog(const ASender, AMessage: String);
    procedure EngineCycleComplete(Sender: TObject);
    procedure EngineAIBusy(Sender: TObject);

    procedure UpdateMapGraphics;
    procedure RefreshUIState;
    procedure RefreshMarketUI;
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
var
  DBDir, DBPath: String;
begin
  Randomize;

  FMapBuffer := TBitmap.Create;
  FMapBuffer.Width := pbMap.Width;
  FMapBuffer.Height := pbMap.Height;
  FScanlineY := 0;
  FGlitchActive := 0;
  FDataFlowOffset := 0.0;

  DBDir := ExpandFileName(ExtractFilePath(Application.ExeName) + '..\data\');
  if not DirectoryExists(DBDir) then ForceDirectories(DBDir);
  DBPath := DBDir + 'cartelnet.db';

  FDatabase := TGameDatabase.Create(DBPath);
  FDatabase.InitializeSchema;

  FEngine := TCartelEngine.Create(FDatabase, DEFAULT_AI_ENDPOINT);
  FEngine.OnLog := @EngineLog;
  FEngine.OnCycleComplete := @EngineCycleComplete;
  FEngine.OnAIBusy := @EngineAIBusy;

  if Assigned(cbAction) then
  begin
    cbAction.Items.Clear;
    cbAction.Items.AddObject('Attack Node (Hijack)', TObject(IntPtr(taAttackNode)));
    cbAction.Items.AddObject('Scan Network (Reveal)', TObject(IntPtr(taScanNode)));
    cbAction.Items.AddObject('DDoS Attack (Freeze)', TObject(IntPtr(taDDoSNode)));
    cbAction.Items.AddObject('Bribe Interpol (-Heat)', TObject(IntPtr(taBribeInterpol)));
    cbAction.Items.AddObject('Deploy Trap (Counter-Intel)', TObject(IntPtr(taDeployTrap)));
    cbAction.ItemIndex := 0;
  end;

  if Assigned(cbLanguage) then
  begin
    cbLanguage.Items.Clear;
    cbLanguage.Items.Add('English');
    cbLanguage.Items.Add('Indonesian (Bahasa Indonesia)');
    cbLanguage.Items.Add('Russian');
    cbLanguage.Items.Add('Japanese (Romaji)');
    cbLanguage.Items.Add('Hacker Leetspeak (1337)');
    cbLanguage.ItemIndex := 0;
  end;

  FEngine.StartNewGame;
  RefreshMarketUI;

  memLog.Clear;
  memLog.Lines.Add('[SYSTEM] INITIATING CARTELNET V1.0...');
  memLog.Lines.Add('[SYSTEM] MOUNTING ENCRYPTED VOLUMES... [OK]');
  memLog.Lines.Add('[SYSTEM] BYPASSING INTERPOL PROXIES... [OK]');
  memLog.Lines.Add('[SYSTEM] ESTABLISHING SECURE CONNECTION TO DARKNET... [OK]');
  memLog.Lines.Add('[SYSTEM] WARNING: HIGHLY ADAPTIVE ENTITY "GHOST" DETECTED IN SECTOR 7.');
  memLog.Lines.Add('[SYSTEM] TERMINAL READY. AWAITING OPERATOR INPUT...');

  pbTelemetry.OnPaint := @pbTelemetryPaint;

  WindowState:=wsMaximized;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  tmrRender.Enabled := False;
  FEngine.Free;
  FDatabase.Free;
  FMapBuffer.Free;
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  lbvBudget.Caption:=Inttostr(tbBudget.Position);
end;

procedure TFormMain.MenuItem3Click(Sender: TObject);
begin
  OpenDocument(ExtractFilePath(Application.ExeName) + 'tutorial.pdf');
end;

procedure TFormMain.mnAboutClick(Sender: TObject);
begin
  if Assigned(frmAbout) then frmAbout.free;

  frmAbout:= TfrmAbout.Create(self);
  frmAbout.ShowModal;
end;

procedure TFormMain.mnEzitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TFormMain.mnWebClick(Sender: TObject);
begin
  OpenDocument('https://github.com/CodeInPas');
end;

{ --- RENDERING & ANIMASI --- }

procedure TFormMain.UpdateMapGraphics;
var
  i, gridX, gridY, c, trail, fadeY, ColCount: Integer;
  NodeData: TNodeData;
  x1, y1, x2, y2: Integer;
  dx, dy, dist, currDist: Double;
  px, py: Integer;
  EventText: String;
begin
  if (FMapBuffer.Width <> pbMap.Width) or (FMapBuffer.Height <> pbMap.Height) then
  begin
    FMapBuffer.Width := pbMap.Width;
    FMapBuffer.Height := pbMap.Height;
    SetLength(FMatrixDrops, 0);
  end;

  FMapBuffer.Canvas.Brush.Color := RGBToColor(10, 15, 10);
  FMapBuffer.Canvas.Brush.Style := bsSolid;
  FMapBuffer.Canvas.FillRect(0, 0, FMapBuffer.Width, FMapBuffer.Height);

  // 1. Matrix Rain
  ColCount := FMapBuffer.Width div 15;
  if Length(FMatrixDrops) <> ColCount then
  begin
    SetLength(FMatrixDrops, ColCount);
    SetLength(FMatrixSpeeds, ColCount);
    for c := 0 to ColCount - 1 do
    begin
      FMatrixDrops[c] := Random(FMapBuffer.Height);
      FMatrixSpeeds[c] := 0.8 + (Random(20) / 10.0);
    end;
  end;

  FMapBuffer.Canvas.Font.Name := 'Consolas';
  FMapBuffer.Canvas.Font.Size := 10;
  FMapBuffer.Canvas.Brush.Style := bsClear;

  for c := 0 to ColCount - 1 do
  begin
    for trail := 0 to 6 do
    begin
      fadeY := Trunc(FMatrixDrops[c]) - (trail * 12);
      if fadeY > 0 then
      begin
        FMapBuffer.Canvas.Font.Color := RGBToColor(10, Max(15, 60 - (trail * 8)), 10);
        FMapBuffer.Canvas.TextOut(c * 15, fadeY, IntToStr(Random(2)));
      end;
    end;
    FMatrixDrops[c] := FMatrixDrops[c] + FMatrixSpeeds[c];
    if FMatrixDrops[c] > FMapBuffer.Height + 100 then
    begin
      FMatrixDrops[c] := -50;
      FMatrixSpeeds[c] := 0.8 + (Random(20) / 10.0);
    end;
  end;

  // 2. Holographic Grid
  FMapBuffer.Canvas.Pen.Color := RGBToColor(18, 30, 18);
  FMapBuffer.Canvas.Pen.Width := 1;
  gridX := 0;
  while gridX < FMapBuffer.Width do
  begin
    FMapBuffer.Canvas.MoveTo(gridX, 0);
    FMapBuffer.Canvas.LineTo(gridX, FMapBuffer.Height);
    Inc(gridX, 50);
  end;
  gridY := 0;
  while gridY < FMapBuffer.Height do
  begin
    FMapBuffer.Canvas.MoveTo(0, gridY);
    FMapBuffer.Canvas.LineTo(FMapBuffer.Width, gridY);
    Inc(gridY, 50);
  end;

  if Assigned(FEngine) and (Length(FEngine.Map) > 0) then
  begin
    // 3. Garis Koneksi (Kabel)
    FMapBuffer.Canvas.Pen.Color := RGBToColor(0, 90, 90);
    FMapBuffer.Canvas.Pen.Width := 2;
    for i := 1 to High(FEngine.Map) do
    begin
      FMapBuffer.Canvas.MoveTo(FEngine.Map[i-1].CoordX + 25, FEngine.Map[i-1].CoordY + 25);
      FMapBuffer.Canvas.LineTo(FEngine.Map[i].CoordX + 25, FEngine.Map[i].CoordY + 25);
    end;
    if Length(FEngine.Map) > 2 then
    begin
      FMapBuffer.Canvas.MoveTo(FEngine.Map[High(FEngine.Map)].CoordX + 25, FEngine.Map[High(FEngine.Map)].CoordY + 25);
      FMapBuffer.Canvas.LineTo(FEngine.Map[0].CoordX + 25, FEngine.Map[0].CoordY + 25);
    end;

    // Animasi Data Flow
    FDataFlowOffset := FDataFlowOffset + 1.5;
    if FDataFlowOffset >= 30.0 then
      FDataFlowOffset := FDataFlowOffset - 30.0;

    FMapBuffer.Canvas.Pen.Style := psClear;
    FMapBuffer.Canvas.Brush.Style := bsSolid;

    for i := 0 to High(FEngine.Map) do
    begin
      x1 := FEngine.Map[i].CoordX + 25;
      y1 := FEngine.Map[i].CoordY + 25;

      if i = High(FEngine.Map) then
      begin
        if Length(FEngine.Map) > 2 then
        begin
          x2 := FEngine.Map[0].CoordX + 25;
          y2 := FEngine.Map[0].CoordY + 25;
        end
        else Continue;
      end
      else
      begin
        x2 := FEngine.Map[i+1].CoordX + 25;
        y2 := FEngine.Map[i+1].CoordY + 25;
      end;

      dx := x2 - x1;
      dy := y2 - y1;
      dist := Hypot(dx, dy);

      if dist > 0 then
      begin
        case FEngine.Map[i].Owner of
          noPlayer: FMapBuffer.Canvas.Brush.Color := clLime;
          noAI:     FMapBuffer.Canvas.Brush.Color := clRed;
          else      FMapBuffer.Canvas.Brush.Color := RGBToColor(0, 150, 150);
        end;

        currDist := FDataFlowOffset;
        while currDist < dist do
        begin
          px := Round(x1 + (dx * currDist / dist));
          py := Round(y1 + (dy * currDist / dist));
          FMapBuffer.Canvas.Ellipse(px - 2, py - 2, px + 3, py + 3);
          currDist := currDist + 30.0;
        end;
      end;
    end;
    FMapBuffer.Canvas.Pen.Style := psSolid;

    // 4. Render Titik Node
    for i := 0 to High(FEngine.Map) do
    begin
      NodeData := FEngine.Map[i];

      if not NodeData.IsVisible then
      begin
        FMapBuffer.Canvas.Brush.Color := RGBToColor(5, 5, 5);
        FMapBuffer.Canvas.Pen.Color := clDkGray;
        FMapBuffer.Canvas.Pen.Style := psDot;
        FMapBuffer.Canvas.Pen.Width := 2;
        FMapBuffer.Canvas.Ellipse(NodeData.CoordX, NodeData.CoordY, NodeData.CoordX + 50, NodeData.CoordY + 50);

        FMapBuffer.Canvas.Pen.Style := psSolid;
        FMapBuffer.Canvas.Brush.Style := bsClear;
        FMapBuffer.Canvas.Font.Color := RGBToColor(120, 120, 120);
        FMapBuffer.Canvas.TextOut(NodeData.CoordX - 10, NodeData.CoordY + 55, 'UNKNOWN');
      end
      else
      begin
        if NodeData.Owner = noPlayer then
        begin
          FMapBuffer.Canvas.Brush.Color := RGBToColor(0, 160, 0);
          FMapBuffer.Canvas.Pen.Color := clLime;
        end
        else if NodeData.Owner = noAI then
        begin
          FMapBuffer.Canvas.Brush.Color := RGBToColor(160, 0, 0);
          FMapBuffer.Canvas.Pen.Color := clRed;
        end
        else
        begin
          FMapBuffer.Canvas.Brush.Color := RGBToColor(50, 50, 50);
          FMapBuffer.Canvas.Pen.Color := clSilver;
        end;

        FMapBuffer.Canvas.Brush.Style := bsSolid;
        FMapBuffer.Canvas.Pen.Width := 2;
        FMapBuffer.Canvas.Ellipse(NodeData.CoordX, NodeData.CoordY, NodeData.CoordX + 50, NodeData.CoordY + 50);

        FMapBuffer.Canvas.Brush.Color := RGBToColor(25, 25, 25);
        FMapBuffer.Canvas.Ellipse(NodeData.CoordX + 15, NodeData.CoordY + 15, NodeData.CoordX + 35, NodeData.CoordY + 35);

        FMapBuffer.Canvas.Brush.Style := bsClear;
        FMapBuffer.Canvas.Font.Color := clWhite;
        FMapBuffer.Canvas.Font.Style := [fsBold];
        FMapBuffer.Canvas.TextOut(NodeData.CoordX - 25, NodeData.CoordY + 55, NodeData.NodeName);

        FMapBuffer.Canvas.Font.Color := clSilver;
        FMapBuffer.Canvas.Font.Style := [];
        FMapBuffer.Canvas.TextOut(NodeData.CoordX - 10, NodeData.CoordY + 70, 'FW: ' + IntToStr(NodeData.FirewallLevel));

        if NodeData.FreezeTimer > 0 then
        begin
          FMapBuffer.Canvas.Font.Color := clAqua;
          FMapBuffer.Canvas.TextOut(NodeData.CoordX - 15, NodeData.CoordY + 85, '[FROZEN: ' + IntToStr(NodeData.FreezeTimer) + ']');
        end;

        if NodeData.HasTrap and (NodeData.Owner = noPlayer) then
        begin
          FMapBuffer.Canvas.Font.Color := RGBToColor(255, 100, 0);
          FMapBuffer.Canvas.TextOut(NodeData.CoordX - 5, NodeData.CoordY - 20, '[TRAPPED]');
        end;
      end;
    end;
  end;

  // --- 5. RENDER THE DARKNET WIRE (HUD ANOMALI GLOBAL) ---
  if Assigned(FEngine) and (FEngine.Snapshot.CurrentEvent <> geNone) then
  begin
    case FEngine.Snapshot.CurrentEvent of
      geInterpolCrackdown: EventText := 'SYSTEM ANOMALY: INTERPOL CRACKDOWN (HEAT x2)';
      geZeroDayExploit:    EventText := 'SYSTEM ANOMALY: ZERO-DAY EXPLOIT (FIREWALLS -50%)';
      geCryptoCrash:       EventText := 'SYSTEM ANOMALY: CRYPTO CRASH (INCOME -50%)';
      geBotnetSwarm:       EventText := 'SYSTEM ANOMALY: BOTNET SWARM (BANDWIDTH x2)';
      geHiddenServer:      EventText := 'SYSTEM ANOMALY: HIDDEN SERVER DETECTED (NEW NODE)';
    else
      EventText := '';
    end;

    // --- ANIMASI KHUSUS: INTERPOL CRACKDOWN (PATROLI SIBER) ---
    if FEngine.Snapshot.CurrentEvent = geInterpolCrackdown then
    begin
      // 1. Efek Lampu Sirine Polisi (Border Merah / Biru bergantian setiap 300ms)
      if (GetTickCount64 div 300) mod 2 = 0 then
        FMapBuffer.Canvas.Pen.Color := RGBToColor(200, 0, 0)     // Merah Polisi
      else
        FMapBuffer.Canvas.Pen.Color := RGBToColor(0, 100, 255);  // Biru Polisi

      FMapBuffer.Canvas.Pen.Width := 8;
      FMapBuffer.Canvas.Brush.Style := bsClear;
      // Gambar border tebal di sekeliling map
      FMapBuffer.Canvas.Rectangle(4, 4, FMapBuffer.Width - 4, FMapBuffer.Height - 4);

      // 2. Efek Garis Pelacakan (Radar Crosshair)
      FMapBuffer.Canvas.Pen.Width := 1;
      FMapBuffer.Canvas.Pen.Color := RGBToColor(200, 0, 0);
      FMapBuffer.Canvas.Pen.Style := psDot;

      // Garis Vertikal dan Horizontal membelah layar
      FMapBuffer.Canvas.MoveTo(FMapBuffer.Width div 2, 0);
      FMapBuffer.Canvas.LineTo(FMapBuffer.Width div 2, FMapBuffer.Height);
      FMapBuffer.Canvas.MoveTo(0, FMapBuffer.Height div 2);
      FMapBuffer.Canvas.LineTo(FMapBuffer.Width, FMapBuffer.Height div 2);

      // Lingkaran Target Radar
      FMapBuffer.Canvas.Ellipse(
        (FMapBuffer.Width div 2) - 150, (FMapBuffer.Height div 2) - 150,
        (FMapBuffer.Width div 2) + 150, (FMapBuffer.Height div 2) + 150
      );

      FMapBuffer.Canvas.Pen.Style := psSolid; // Kembalikan ke style normal
    end;
    // --- AKHIR ANIMASI KHUSUS ---


    if EventText <> '' then
    begin
      EventText := EventText + ' - ' + IntToStr(FEngine.Snapshot.EventDuration) + ' CYCLES REMAINING';

      FMapBuffer.Canvas.Font.Size := 10;
      FMapBuffer.Canvas.Font.Style := [fsBold];

      if (GetTickCount64 div 500) mod 2 = 0 then
        FMapBuffer.Canvas.Font.Color := clYellow
      else
        FMapBuffer.Canvas.Font.Color := clRed;

      FMapBuffer.Canvas.Brush.Style := bsSolid;
      FMapBuffer.Canvas.Brush.Color := RGBToColor(30, 0, 0);
      FMapBuffer.Canvas.Pen.Color := clRed;
      FMapBuffer.Canvas.Pen.Width := 1;

      FMapBuffer.Canvas.Rectangle(10, 10, 10 + FMapBuffer.Canvas.TextWidth(EventText) + 20, 10 + FMapBuffer.Canvas.TextHeight(EventText) + 10);

      FMapBuffer.Canvas.Brush.Style := bsClear;
      FMapBuffer.Canvas.TextOut(20, 15, EventText);
    end;
  end;

  // 6. Scanline
  FMapBuffer.Canvas.Pen.Color := RGBToColor(0, 180, 0);
  FMapBuffer.Canvas.Pen.Width := 1;
  FMapBuffer.Canvas.MoveTo(0, FScanlineY);
  FMapBuffer.Canvas.LineTo(FMapBuffer.Width, FScanlineY);

  Inc(FScanlineY, 4);
  if FScanlineY > FMapBuffer.Height then FScanlineY := 0;

  // 7. Glitch Effect
  if FGlitchActive > 0 then
  begin
    for i := 0 to 6 do
    begin
      if Random(2) = 0 then
        FMapBuffer.Canvas.Brush.Color := RGBToColor(220, 0, 0)
      else
        FMapBuffer.Canvas.Brush.Color := RGBToColor(0, 220, 220);

      gridY := Random(FMapBuffer.Height);
      FMapBuffer.Canvas.FillRect(0, gridY, FMapBuffer.Width, gridY + Random(8) + 1);

      gridX := Random(60) - 30;
      FMapBuffer.Canvas.CopyRect(
        Rect(gridX, gridY, FMapBuffer.Width + gridX, gridY + 25),
        FMapBuffer.Canvas,
        Rect(0, gridY, FMapBuffer.Width, gridY + 25)
      );
    end;
    Dec(FGlitchActive);
  end;

  FMapBuffer.Canvas.Brush.Style := bsSolid;
end;

procedure TFormMain.pbMapPaint(Sender: TObject);
var
  OffsetX, OffsetY: Integer;
begin
  if not Assigned(FMapBuffer) then Exit;

  OffsetX := 0;
  OffsetY := 0;

  // --- THE PARANOIA PROTOCOL: CRT SCREEN SHAKE (GLITCH) ---
  // Jika Heat Level mencapai 85% atau lebih, layar akan bergetar hebat
  if Assigned(FEngine) and (FEngine.Snapshot.PlayerState.HeatLevel >= 85) then
  begin
    // Peluang 50% terjadi glitch setiap frame (karena timer berjalan sangat cepat)
    if Random(10) > 4 then
    begin
      OffsetX := Random(15) - 7; // Geser horizontal secara acak antara -7 hingga +7 piksel
      OffsetY := Random(15) - 7; // Geser vertikal secara acak antara -7 hingga +7 piksel
    end;
  end;

  // Bersihkan latar belakang dengan warna hitam agar tidak ada artefak gambar yang membekas saat layar bergetar
  if (OffsetX <> 0) or (OffsetY <> 0) then
  begin
    pbMap.Canvas.Brush.Color := clBlack;
    pbMap.Canvas.FillRect(Rect(0, 0, pbMap.Width, pbMap.Height));
  end;

  // Gambar peta ke layar dengan mengaplikasikan koordinat distorsi (offset)
  pbMap.Canvas.Draw(OffsetX, OffsetY, FMapBuffer);
end;

procedure TFormMain.spGoArenaClick(Sender: TObject);
begin
  tbsArena.show;
end;

procedure TFormMain.spGoBMClick(Sender: TObject);
begin
  tbBlackMarket.show;
end;

procedure TFormMain.spGoSettingClick(Sender: TObject);
begin
  tbsSetting.show;
end;

procedure TFormMain.tbBudgetChange(Sender: TObject);
begin
  lbvBudget.Caption:=Inttostr(tbBudget.Position);
end;

procedure TFormMain.tmrRenderTimer(Sender: TObject);
begin
  UpdateMapGraphics;
  pbMap.Invalidate;
  pbTelemetry.Invalidate; // <-- TAMBAHKAN BARIS INI UNTUK ANIMASI TELEMETRY
end;

procedure TFormMain.pbTelemetryPaint(Sender: TObject);
var
  i, MidY, WaveY, Amplitude: Integer;
  TimeShift: Int64;
  HeatLevel: Integer;
begin
  // 1. Gambar latar belakang layar CRT Hitam
  pbTelemetry.Canvas.Brush.Color := clBlack;
  pbTelemetry.Canvas.FillRect(0, 0, pbTelemetry.Width, pbTelemetry.Height);

  // 2. Gambar Grid Radar Matrix (Garis putus-putus hijau gelap)
  pbTelemetry.Canvas.Pen.Color := RGBToColor(0, 40, 0);
  pbTelemetry.Canvas.Pen.Style := psDot;
  for i := 1 to 5 do
  begin
    pbTelemetry.Canvas.Line(0, i * 20, pbTelemetry.Width, i * 20);
    pbTelemetry.Canvas.Line(i * 50, 0, i * 50, pbTelemetry.Height);
  end;
  pbTelemetry.Canvas.Pen.Style := psSolid;

  // 3. Ambil nilai Heat Level dari Engine
  HeatLevel := 0;
  if Assigned(FEngine) then
    HeatLevel := FEngine.Snapshot.PlayerState.HeatLevel;

  // 4. Amplitudo (keliaran sinyal) bergantung pada seberapa tinggi Heat pemain
  Amplitude := 10 + (HeatLevel div 3);
  TimeShift := GetTickCount64 div 20; // Kecepatan animasi bergerak ke arah kiri

  // 5. Tentukan warna sinyal (Hijau -> Kuning -> Merah)
  if HeatLevel >= 85 then
    pbTelemetry.Canvas.Pen.Color := clRed
  else if HeatLevel >= 50 then
    pbTelemetry.Canvas.Pen.Color := clYellow
  else
    pbTelemetry.Canvas.Pen.Color := clLime;

  pbTelemetry.Canvas.Pen.Width := 2;
  MidY := pbTelemetry.Height div 2;
  pbTelemetry.Canvas.MoveTo(0, MidY);

  // 6. Loop untuk menggambar gelombang sinyal secara matematis sepanjang lebar komponen
  for i := 0 to pbTelemetry.Width do
  begin
    // Kombinasi gelombang sinus berirama
    WaveY := MidY + Round(Sin((i + TimeShift) * 0.05) * Amplitude);

    // Tambahkan lonjakan acak (Glitch Spikes) secara berkala
    if i mod 30 = (TimeShift mod 30) then
      WaveY := WaveY - (Random(Amplitude * 2) - Amplitude);

    pbTelemetry.Canvas.LineTo(i, WaveY);
  end;

  // 7. Tambahkan Teks Overlay bergaya Sistem Navigasi
  pbTelemetry.Canvas.Font.Color := RGBToColor(200, 12, 200);
  pbTelemetry.Canvas.Font.Size := 8;
  pbTelemetry.Canvas.Brush.Style := bsClear;
  pbTelemetry.Canvas.TextOut(5, 5, 'TX/RX NODE UPLINK');

  if HeatLevel >= 85 then
  begin
    pbTelemetry.Canvas.Font.Color := clRed;
    pbTelemetry.Canvas.TextOut(5, pbTelemetry.Height - 15, 'WARNING: INTERPOL TRACER ACTIVE');
  end
  else
    pbTelemetry.Canvas.TextOut(5, pbTelemetry.Height - 15, 'STATUS: ENCRYPTED');
end;

{ --- UI LOGIC & EVENTS --- }

procedure TFormMain.cbActionChange(Sender: TObject);
var
  SelAction: TTacticalAction;
begin
  if not Assigned(cbAction) or (cbAction.ItemIndex = -1) then Exit;
  SelAction := TTacticalAction(IntPtr(cbAction.Items.Objects[cbAction.ItemIndex]));

  if SelAction = taBribeInterpol then
  begin
    if Assigned(cbTarget) then cbTarget.Enabled := False;
    if Assigned(tbBudget) then tbBudget.Enabled := True;
  end
  else if (SelAction = taScanNode) or (SelAction = taDeployTrap) then
  begin
    if Assigned(cbTarget) then cbTarget.Enabled := True;
    if Assigned(tbBudget) then tbBudget.Enabled := False;
  end
  else
  begin
    if Assigned(cbTarget) then cbTarget.Enabled := True;
    if Assigned(tbBudget) then tbBudget.Enabled := True;
  end;

  RefreshUIState;
end;

procedure TFormMain.RefreshUIState;
var
  i: Integer;
  SelAction: TTacticalAction;
begin
  if not Assigned(FEngine) then Exit;

  if Assigned(lblFunds) then
    lblFunds.Caption := Format('Crypto : $%d', [FEngine.Snapshot.PlayerState.CryptoFunds]);
  if Assigned(lblBandwidth) then
    lblBandwidth.Caption := Format('Bandwidth: %d TBps', [FEngine.Snapshot.PlayerState.BotnetBandwidth]);
  if Assigned(lblHeat) then
  begin
    lblHeat.Caption := Format('Heat : %d%%', [FEngine.Snapshot.PlayerState.HeatLevel]);
    if FEngine.Snapshot.PlayerState.HeatLevel >= 80 then
    begin
      lblHeat.Font.Color := clRed;
      PlaySound(PChar(SND_ALERT_CRITICAL), 0, SND_ASYNC or SND_ALIAS);
    end
    else
    begin
      lblHeat.Font.Color := clLime;
    end;
  end;

  if Assigned(lblAIPersona) then
  begin
    if FEngine.Snapshot.AIPersona <> '' then
      lblAIPersona.Caption := 'Ghost Status: ' + UpperCase(FEngine.Snapshot.AIPersona)
    else
      lblAIPersona.Caption := 'Ghost Status: ANALYZING';
  end;

  if Assigned(tbBudget) then
    tbBudget.Max := Max(1, FEngine.Snapshot.PlayerState.CryptoFunds div 1000);

  SelAction := taIdle;
  if Assigned(cbAction) and (cbAction.ItemIndex <> -1) then
    SelAction := TTacticalAction(IntPtr(cbAction.Items.Objects[cbAction.ItemIndex]));

  if Assigned(cbTarget) then
  begin
    cbTarget.Items.Clear;
    for i := 0 to High(FEngine.Map) do
    begin
      if SelAction = taDeployTrap then
      begin
        if FEngine.Map[i].Owner = noPlayer then
          cbTarget.Items.AddObject(FEngine.Map[i].NodeName, TObject(IntPtr(i)));
      end
      else
      begin
        if FEngine.Map[i].Owner <> noPlayer then
        begin
          if FEngine.Map[i].IsVisible then
            cbTarget.Items.AddObject(FEngine.Map[i].NodeName, TObject(IntPtr(i)))
          else
            cbTarget.Items.AddObject('UNKNOWN NODE ' + IntToStr(i), TObject(IntPtr(i)));
        end;
      end;
    end;
    if cbTarget.Items.Count > 0 then cbTarget.ItemIndex := 0;
  end;

  RefreshMarketUI;
end;

procedure TFormMain.RefreshMarketUI;
var
  qLvl, pLvl: Integer;
  qCost, pCost: Int64;
begin
  if not Assigned(FDatabase) or not Assigned(FEngine) then Exit;

  qLvl := FDatabase.GetUpgradeLevel('UPG_QUANTUM');
  pLvl := FDatabase.GetUpgradeLevel('UPG_PROXY');

  // --- PERBAIKAN: Menggunakan Round() alih-alih type-cast Int64() ---
  qCost := Round(Power(qLvl + 1, 2) * 25000 + 25000);
  pCost := Round(Power(pLvl + 1, 2) * 25000 + 25000);

  if Assigned(lblUpgQuantum) then
    lblUpgQuantum.Caption := Format('Quantum Decryption (Lvl %d/5) - Cost: $%d', [qLvl, qCost]);
  if Assigned(lblUpgProxy) then
    lblUpgProxy.Caption := Format('Offshore Proxy (Lvl %d/5) - Cost: $%d', [pLvl, pCost]);

  if Assigned(btnBuyQuantum) then
    btnBuyQuantum.Enabled := (qLvl < 5) and (FEngine.Snapshot.PlayerState.CryptoFunds >= qCost);
  if Assigned(btnBuyProxy) then
    btnBuyProxy.Enabled := (pLvl < 5) and (FEngine.Snapshot.PlayerState.CryptoFunds >= pCost);
end;

procedure TFormMain.btnBuyQuantumClick(Sender: TObject);
var
  qLvl: Integer;
begin
  if not Assigned(FDatabase) then Exit;
  qLvl := FDatabase.GetUpgradeLevel('UPG_QUANTUM');
  FDatabase.SetUpgradeLevel('UPG_QUANTUM', qLvl + 1);
  EngineLog('SYSTEM', 'UPGRADE ACQUIRED: Quantum Decryption Level ' + IntToStr(qLvl + 1));
  RefreshMarketUI;
end;

procedure TFormMain.btnBuyProxyClick(Sender: TObject);
var
  pLvl: Integer;
begin
  if not Assigned(FDatabase) then Exit;
  pLvl := FDatabase.GetUpgradeLevel('UPG_PROXY');
  FDatabase.SetUpgradeLevel('UPG_PROXY', pLvl + 1);
  EngineLog('SYSTEM', 'UPGRADE ACQUIRED: Offshore Proxy Level ' + IntToStr(pLvl + 1));
  RefreshMarketUI;
end;

{ --- ENGINE EVENT HANDLERS --- }

procedure TFormMain.EngineLog(const ASender, AMessage: String);
var
  LogString: String;
begin
  LogString := Format('[%s] %s: %s', [FormatDateTime('hh:nn:ss', Now), ASender, AMessage]);
  if Assigned(memLog) then
  begin
    memLog.Lines.Add(LogString);
    memLog.SelStart := Length(memLog.Text);
  end;

  if Assigned(FDatabase) then
    FDatabase.InsertLog(ASender, AMessage);

  if Pos('ANOMALY:', AMessage) > 0 then
  begin
    FGlitchActive := 30;
    PlaySound(PChar(SND_ALERT_CRITICAL), 0, SND_ASYNC or SND_ALIAS);
  end
  else if Pos('TRAP TRIGGERED!', AMessage) > 0 then
  begin
    FGlitchActive := 12;
    PlaySound(PChar(SND_ALERT_CRITICAL), 0, SND_ASYNC or SND_ALIAS);
  end
  else if Pos('repelled', AMessage) > 0 then
  begin
    PlaySound(PChar(SND_ACTION_FAIL), 0, SND_ASYNC or SND_ALIAS);
  end
  else if (ASender = 'GHOST (AI)') and (Pos('Infiltrated and seized', AMessage) > 0) then
  begin
    FGlitchActive := 18;
    PlaySound(PChar(SND_ALERT_CRITICAL), 0, SND_ASYNC or SND_ALIAS);
  end
  else
  begin
    PlaySound(PChar(SND_TERMINAL_BEEP), 0, SND_ASYNC or SND_ALIAS);
  end;
end;

procedure TFormMain.EngineCycleComplete(Sender: TObject);
begin
  if Assigned(btnExecute) then
  begin
    btnExecute.Enabled := True;
    btnExecute.Caption := 'EXECUTE EXPLOIT';
  end;
  RefreshUIState;
end;

procedure TFormMain.EngineAIBusy(Sender: TObject);
begin
  if Assigned(btnExecute) then
  begin
    btnExecute.Enabled := False;
    btnExecute.Caption := 'AI IS THINKING...';
  end;
end;

procedure TFormMain.btnExecuteClick(Sender: TObject);
var
  TargetNodeID: String;
  Idx: Integer;
  SelAction: TTacticalAction;
  PlayerTaunt: String;
  AILanguage: String;
begin
  if not Assigned(cbAction) or (cbAction.ItemIndex = -1) or not Assigned(FEngine) then Exit;
  SelAction := TTacticalAction(IntPtr(cbAction.Items.Objects[cbAction.ItemIndex]));
  TargetNodeID := '';

  if Assigned(cbTarget) and cbTarget.Enabled and (cbTarget.ItemIndex <> -1) then
  begin
    Idx := Integer(cbTarget.Items.Objects[cbTarget.ItemIndex]);
    if (Idx >= 0) and (Idx <= High(FEngine.Map)) then
      TargetNodeID := FEngine.Map[Idx].NodeID;
  end;

  PlayerTaunt := '';
  if Assigned(edtTaunt) then
  begin
    PlayerTaunt := Trim(edtTaunt.Text);

    if PlayerTaunt <> '' then
      EngineLog('PLAYER (COMM)', PlayerTaunt);

    edtTaunt.Text := '';
  end;

  AILanguage := 'English';
  if Assigned(cbLanguage) and (cbLanguage.ItemIndex <> -1) then
    AILanguage := cbLanguage.Text;

  FEngine.SubmitPlayerTurn(
    SelAction,
    TargetNodeID,
    tbBudget.Position * 1000,
    FEngine.Snapshot.PlayerState.BotnetBandwidth,
    PlayerTaunt,
    AILanguage
  );
end;
procedure TFormMain.btnOpenSettingsClick(Sender: TObject);
begin
  FormSetting := TFormSetting.Create(Self);
  try
    if FormSetting.ShowModal = mrOk then
    begin
      // Perbarui endpoint pada engine game yang sedang berjalan
      FEngine.AIEndpoint := FormSetting.SelectedEndpoint;
      EngineLog('SYSTEM', 'AI Service Endpoint updated to: ' + FormSetting.SelectedEndpoint);
    end;
  finally
    FormSetting.Free;
  end;
end;

procedure TFormMain.cbActionDrawItem(
  Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  CB: TComboBox;
  TextY: Integer;
begin
  CB := Control as TComboBox;

  // Background gelap seragam
  CB.Canvas.Brush.Color := RGBToColor(20, 20, 20);
  CB.Canvas.FillRect(ARect);
  CB.BorderStyle:=bsnone;

  // Teks hijau terminal
  CB.Canvas.Font.Color := RGBToColor(0, 255, 0);

  // Menghitung posisi Y agar teks berada tepat di tengah secara vertikal
  TextY := ARect.Top + (ARect.Height - CB.Canvas.TextHeight(CB.Items[Index])) div 2;

  CB.Canvas.TextOut(ARect.Left + 8, TextY, CB.Items[Index]);

end;

procedure TFormMain.cbLanguageDrawItem(
  Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  CB: TComboBox;
  TextY: Integer;
begin
  CB := Control as TComboBox;

  // Background gelap seragam
  CB.Canvas.Brush.Color := RGBToColor(20, 20, 20);
  CB.Canvas.FillRect(ARect);
  CB.BorderStyle:=bsnone;

  // Teks hijau terminal
  CB.Canvas.Font.Color := RGBToColor(0, 255, 0);

  // Menghitung posisi Y agar teks berada tepat di tengah secara vertikal
  TextY := ARect.Top + (ARect.Height - CB.Canvas.TextHeight(CB.Items[Index])) div 2;

  CB.Canvas.TextOut(ARect.Left + 8, TextY, CB.Items[Index]);
end;

procedure TFormMain.cbTargetDrawItem(
  Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  CB: TComboBox;
  TextY: Integer;
begin
  CB := Control as TComboBox;

  // Background gelap seragam
  CB.Canvas.Brush.Color := RGBToColor(20, 20, 20);
  CB.Canvas.FillRect(ARect);
  CB.BorderStyle:=bsnone;

  // Teks hijau terminal
  CB.Canvas.Font.Color := RGBToColor(0, 255, 0);

  // Menghitung posisi Y agar teks berada tepat di tengah secara vertikal
  TextY := ARect.Top + (ARect.Height - CB.Canvas.TextHeight(CB.Items[Index])) div 2;

  CB.Canvas.TextOut(ARect.Left + 8, TextY, CB.Items[Index]);

end;

procedure TFormMain.edtTauntKeyPress(Sender: TObject; var Key: char);
begin
  if edtTaunt.text<>'' then
   if key=#13 then
      btnExecuteClick(sender);
end;

end.
