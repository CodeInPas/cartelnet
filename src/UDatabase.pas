unit UDatabase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Types, sqldb, sqlite3conn, UGameTypes;

type
  TGameDatabase = class
  private
    FConnection: TSQLite3Connection;
    FTransaction: TSQLTransaction;
    FQuery: TSQLQuery;

    procedure ExecuteDirectSQL(const ASQL: String);
  public
    constructor Create(const ADBFilePath: String);
    destructor Destroy; override;

    procedure InitializeSchema;
    procedure InsertLog(const ASender, AMessage: String);
    function GetLatestLogs(const ALimit: Integer = 50): TStringList;
    procedure SaveTelemetry(const ASnapshot: TGameSnapshot);

    function LoadMapNodes: TDarkNetMap;

    // Manajemen Black Market (Upgrades)
    function GetUpgradeLevel(const AUpgradeID: String): Integer;
    procedure SetUpgradeLevel(const AUpgradeID: String; ALevel: Integer);

    // Menarik memori log interaksi untuk LLM
    function GetContextMemory(const ALimit: Integer = 3): TStringArray;
  end;

implementation

{ TGameDatabase }

constructor TGameDatabase.Create(const ADBFilePath: String);
begin
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConnection.Transaction := FTransaction;
  FQuery.Database := FConnection;
  FQuery.Transaction := FTransaction;

  FConnection.DatabaseName := ADBFilePath;
  FConnection.Open;
end;

destructor TGameDatabase.Destroy;
begin
  if FConnection.Connected then
    FConnection.Close;

  FQuery.Free;
  FTransaction.Free;
  FConnection.Free;

  inherited Destroy;
end;

procedure TGameDatabase.ExecuteDirectSQL(const ASQL: String);
begin
  FQuery.SQL.Text := ASQL;
  FQuery.ExecSQL;
  FTransaction.Commit;
end;

procedure TGameDatabase.InitializeSchema;
begin
  ExecuteDirectSQL(
    'CREATE TABLE IF NOT EXISTS tbl_logs (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
    '  log_time DATETIME DEFAULT CURRENT_TIMESTAMP, ' +
    '  sender TEXT, ' +
    '  message TEXT' +
    ');'
  );

  ExecuteDirectSQL(
    'CREATE TABLE IF NOT EXISTS tbl_telemetry (' +
    '  cycle_num INTEGER PRIMARY KEY, ' +
    '  player_funds BIGINT, ' +
    '  ai_funds BIGINT, ' +
    '  player_heat INTEGER, ' +
    '  ai_heat INTEGER' +
    ');'
  );

  ExecuteDirectSQL(
    'CREATE TABLE IF NOT EXISTS tbl_upgrades (' +
    '  upgrade_id TEXT PRIMARY KEY, ' +
    '  upgrade_name TEXT, ' +
    '  current_level INTEGER DEFAULT 0, ' +
    '  max_level INTEGER' +
    ');'
  );

  ExecuteDirectSQL(
    'INSERT OR IGNORE INTO tbl_upgrades (upgrade_id, upgrade_name, current_level, max_level) VALUES ' +
    '(''UPG_QUANTUM'', ''Quantum Decryption (+20% Attack Power)'', 0, 5), ' +
    '(''UPG_PROXY'', ''Offshore Proxy (-10% Heat Generation)'', 0, 5);'
  );
end;

procedure TGameDatabase.InsertLog(const ASender, AMessage: String);
begin
  FQuery.SQL.Text := 'INSERT INTO tbl_logs (sender, message) VALUES (:sender, :msg)';
  FQuery.Params.ParamByName('sender').AsString := ASender;
  FQuery.Params.ParamByName('msg').AsString := AMessage;

  FQuery.ExecSQL;
  FTransaction.Commit;
end;

function TGameDatabase.GetLatestLogs(const ALimit: Integer): TStringList;
var
  FormattedLog: String;
begin
  Result := TStringList.Create;

  FQuery.SQL.Text := 'SELECT log_time, sender, message FROM tbl_logs ORDER BY id DESC LIMIT :limit';
  FQuery.Params.ParamByName('limit').AsInteger := ALimit;
  FQuery.Open;

  try
    while not FQuery.EOF do
    begin
      FormattedLog := Format('[%s] %s: %s', [
        FormatDateTime('yyyy-mm-dd hh:nn:ss', FQuery.FieldByName('log_time').AsDateTime),
        FQuery.FieldByName('sender').AsString,
        FQuery.FieldByName('message').AsString
      ]);

      Result.Insert(0, FormattedLog);
      FQuery.Next;
    end;
  finally
    FQuery.Close;
  end;
end;

procedure TGameDatabase.SaveTelemetry(const ASnapshot: TGameSnapshot);
begin
  FQuery.SQL.Text :=
    'INSERT INTO tbl_telemetry (cycle_num, player_funds, ai_funds, player_heat, ai_heat) ' +
    'VALUES (:cycle, :pfunds, :afunds, :pheat, :aheat) ' +
    'ON CONFLICT(cycle_num) DO UPDATE SET ' +
    'player_funds=excluded.player_funds, ai_funds=excluded.ai_funds';

  FQuery.Params.ParamByName('cycle').AsInteger := ASnapshot.CycleNumber;
  FQuery.Params.ParamByName('pfunds').AsLargeInt := ASnapshot.PlayerState.CryptoFunds;
  FQuery.Params.ParamByName('afunds').AsLargeInt := ASnapshot.AIState.CryptoFunds;
  FQuery.Params.ParamByName('pheat').AsInteger := ASnapshot.PlayerState.HeatLevel;
  FQuery.Params.ParamByName('aheat').AsInteger := ASnapshot.AIState.HeatLevel;

  FQuery.ExecSQL;
  FTransaction.Commit;
end;

function TGameDatabase.GetUpgradeLevel(const AUpgradeID: String): Integer;
begin
  Result := 0;
  FQuery.SQL.Text := 'SELECT current_level FROM tbl_upgrades WHERE upgrade_id = :uid';
  FQuery.Params.ParamByName('uid').AsString := AUpgradeID;
  FQuery.Open;
  try
    if not FQuery.EOF then
      Result := FQuery.FieldByName('current_level').AsInteger;
  finally
    FQuery.Close;
  end;
end;

procedure TGameDatabase.SetUpgradeLevel(const AUpgradeID: String; ALevel: Integer);
begin
  FQuery.SQL.Text := 'UPDATE tbl_upgrades SET current_level = :lvl WHERE upgrade_id = :uid';
  FQuery.Params.ParamByName('lvl').AsInteger := ALevel;
  FQuery.Params.ParamByName('uid').AsString := AUpgradeID;
  FQuery.ExecSQL;
  FTransaction.Commit;
end;

function TGameDatabase.LoadMapNodes: TDarkNetMap;
var
  Idx, RecordCount: Integer;
  OwnerStr: String;
begin
  SetLength(Result, 0);

  FQuery.SQL.Text := 'SELECT * FROM tbl_nodes';
  FQuery.Open;
  try
    RecordCount := 0;
    while not FQuery.EOF do
    begin
      SetLength(Result, RecordCount + 1);

      Result[RecordCount].NodeID := FQuery.FieldByName('node_id').AsString;
      Result[RecordCount].NodeName := FQuery.FieldByName('node_name').AsString;

      OwnerStr := FQuery.FieldByName('owner').AsString;
      if OwnerStr = 'noPlayer' then Result[RecordCount].Owner := noPlayer
      else if OwnerStr = 'noAI' then Result[RecordCount].Owner := noAI
      else Result[RecordCount].Owner := noNeutral;

      Result[RecordCount].FirewallLevel := FQuery.FieldByName('firewall_level').AsInteger;
      Result[RecordCount].BandwidthYield := FQuery.FieldByName('bandwidth_yield').AsInteger;
      Result[RecordCount].IncomeYield := FQuery.FieldByName('income_yield').AsLargeInt;

      Result[RecordCount].CoordX := FQuery.FieldByName('coord_x').AsInteger;
      Result[RecordCount].CoordY := FQuery.FieldByName('coord_y').AsInteger;

      if (Result[RecordCount].Owner = noPlayer) or (Result[RecordCount].Owner = noAI) then
        Result[RecordCount].IsVisible := True
      else
        Result[RecordCount].IsVisible := False;

      Result[RecordCount].FreezeTimer := 0;
      Result[RecordCount].HasTrap := False; // Inisialisasi Trap

      Inc(RecordCount);
      FQuery.Next;
    end;
  finally
    FQuery.Close;
  end;
end;

function TGameDatabase.GetContextMemory(const ALimit: Integer): TStringArray;
var
  TempList: TStringList;
  i: Integer;
begin
  SetLength(Result, 0);
  TempList := TStringList.Create;
  try
    FQuery.SQL.Text :=
      'SELECT sender, message FROM tbl_logs ' +
      'WHERE sender IN (''PLAYER'', ''GHOST (AI)'') ' +
      'ORDER BY id DESC LIMIT :limit';
    FQuery.Params.ParamByName('limit').AsInteger := ALimit;
    FQuery.Open;

    try
      while not FQuery.EOF do
      begin
        TempList.Insert(0, FQuery.FieldByName('sender').AsString + ': ' + FQuery.FieldByName('message').AsString);
        FQuery.Next;
      end;
    finally
      FQuery.Close;
    end;

    SetLength(Result, TempList.Count);
    for i := 0 to TempList.Count - 1 do
      Result[i] := TempList[i];

  finally
    TempList.Free;
  end;
end;

end.
