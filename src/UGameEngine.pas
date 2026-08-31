unit UGameEngine;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, UGameTypes, Math, UDatabase, UAIClient;

type
  TEngineLogEvent = procedure(const ASender, AMessage: String) of object;

  TCartelEngine = class
  private
    FDB: TGameDatabase;
    FSnapshot: TGameSnapshot;
    FMap: TDarkNetMap;
    FAIEndpoint: String;

    FPrevQuantumLvl: Integer;
    FPrevProxyLvl: Integer;

    FOnLog: TEngineLogEvent;
    FOnCycleComplete: TNotifyEvent;
    FOnAIBusy: TNotifyEvent;

    FPlayerAction: TTacticalAction;
    FPlayerTargetNode: String;
    FPlayerBudget: Int64;
    FPlayerBandwidth: Integer;

    procedure InitializeStartingNodes;
    procedure YieldResources;
    procedure CheckWinLossConditions;
    procedure ProcessBlackMarketTransactions;
    procedure ResolveCycle(const AIDecision: TAIDecision);
    procedure HandleAIResponse(const ADecision: TAIDecision; const ASuccess: Boolean; const AErrorMsg: String);
    function FindNodeIndex(const ANodeID: String): Integer;
    procedure ManageGlobalEvents;
    procedure SpawnHiddenNode;
  public
    constructor Create(ADatabase: TGameDatabase; const AEndpoint: String);
    destructor Destroy; override;

    procedure StartNewGame;
    procedure SubmitPlayerTurn(AAction: TTacticalAction; const ATarget: String; ABudget: Int64; ABandwidth: Integer; const ATauntMessage: String = ''; const AAILanguage: String = 'English');

    property Snapshot: TGameSnapshot read FSnapshot;
    property Map: TDarkNetMap read FMap;
    property AIEndpoint: String read FAIEndpoint write FAIEndpoint; // <-- PROPERTI BARU
    property OnLog: TEngineLogEvent read FOnLog write FOnLog;
    property OnCycleComplete: TNotifyEvent read FOnCycleComplete write FOnCycleComplete;
    property OnAIBusy: TNotifyEvent read FOnAIBusy write FOnAIBusy;
  end;

implementation

constructor TCartelEngine.Create(ADatabase: TGameDatabase; const AEndpoint: String);
begin
  FDB := ADatabase;
  FAIEndpoint := AEndpoint;
  SetLength(FMap, 0);
end;

destructor TCartelEngine.Destroy;
begin
  SetLength(FMap, 0);
  inherited Destroy;
end;

procedure TCartelEngine.InitializeStartingNodes;
begin
  FMap := FDB.LoadMapNodes;
  if Length(FMap) = 0 then
  begin
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', 'CRITICAL: No nodes in DB. Load seed data first.');
  end;
end;

procedure TCartelEngine.StartNewGame;
begin
  InitializeStartingNodes;

  FSnapshot.CycleNumber := 1;
  FSnapshot.Status := gsActive;

  FSnapshot.PlayerState.CryptoFunds := STARTING_FUNDS;
  FSnapshot.PlayerState.BotnetBandwidth := STARTING_BANDWIDTH;
  FSnapshot.PlayerState.HeatLevel := 0;

  FSnapshot.AIState.CryptoFunds := STARTING_FUNDS;
  FSnapshot.AIState.BotnetBandwidth := STARTING_BANDWIDTH;
  FSnapshot.AIState.HeatLevel := 0;

  FSnapshot.CurrentEvent := geNone;
  FSnapshot.EventDuration := 0;

  FPrevQuantumLvl := FDB.GetUpgradeLevel('UPG_QUANTUM');
  FPrevProxyLvl := FDB.GetUpgradeLevel('UPG_PROXY');

  if Assigned(FOnLog) then
    FOnLog('SYSTEM', 'CartelNET operational. Topology synchronized from DB.');

  if Assigned(FOnCycleComplete) then
    FOnCycleComplete(Self);
end;

function TCartelEngine.FindNodeIndex(const ANodeID: String): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FMap) do
    if SameText(FMap[i].NodeID, ANodeID) then Exit(i);
end;

procedure TCartelEngine.SpawnHiddenNode;
var
  NewIdx: Integer;
  Prefixes, Suffixes: array of String;
begin
  NewIdx := Length(FMap);
  SetLength(FMap, NewIdx + 1);

  Prefixes := ['Shadow', 'Phantom', 'Abyss', 'Nexus', 'Echo', 'Mirage', 'Ghost'];
  Suffixes := ['Relay', 'Archive', 'Vault', 'Cluster', 'Mainframe', 'Terminal'];

  FMap[NewIdx].NodeID := 'NODE_X' + FormatDateTime('hhnnss', Now) + IntToStr(Random(999));
  FMap[NewIdx].NodeName := Prefixes[Random(Length(Prefixes))] + ' ' + Suffixes[Random(Length(Suffixes))];
  FMap[NewIdx].Owner := noNeutral;
  FMap[NewIdx].FirewallLevel := 100 + Random(80);
  FMap[NewIdx].BandwidthYield := 300 + Random(200);
  FMap[NewIdx].IncomeYield := 15000 + Random(20000);

  FMap[NewIdx].CoordX := 50 + Random(600);
  FMap[NewIdx].CoordY := 50 + Random(350);

  FMap[NewIdx].IsVisible := False;
  FMap[NewIdx].FreezeTimer := 0;
  FMap[NewIdx].HasTrap := False;
end;

procedure TCartelEngine.SubmitPlayerTurn(AAction: TTacticalAction; const ATarget: String; ABudget: Int64; ABandwidth: Integer; const ATauntMessage: String = ''; const AAILanguage: String = 'English');
var
  OpCost: Int64;
begin
  if FSnapshot.Status <> gsActive then Exit;

  // --- TUNING 2: BIAYA OPERASIONAL TETAP (SCAN & TRAP) ---
  OpCost := 0;
  if AAction = taScanNode then
    OpCost := 5000
  else if AAction = taDeployTrap then
    OpCost := 15000;

  if FSnapshot.PlayerState.CryptoFunds < (ABudget + OpCost) then
  begin
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', Format('Operation rejected: Insufficient funds for operational cost ($%d required).', [OpCost]));
    Exit;
  end;

  ABudget := ABudget + OpCost;
  if (OpCost > 0) and (Assigned(FOnLog)) then
    FOnLog('SYSTEM', Format('Operational fee deducted: -$%d for action execution.', [OpCost]));

  if FSnapshot.PlayerState.CryptoFunds < ABudget then
    ABudget := FSnapshot.PlayerState.CryptoFunds;

  FPlayerAction := AAction;
  FPlayerTargetNode := ATarget;
  FPlayerBudget := ABudget;
  FPlayerBandwidth := ABandwidth;

  Dec(FSnapshot.PlayerState.CryptoFunds, ABudget);

  if Assigned(FOnAIBusy) then
    FOnAIBusy(Self);

  FSnapshot.RecentHistory := FDB.GetContextMemory(3);

  if FSnapshot.AIState.HeatLevel > 75 then
    FSnapshot.AIPersona := 'Defensive and Paranoid'
  else if FSnapshot.AIState.CryptoFunds > 300000 then
    FSnapshot.AIPersona := 'Aggressive, Arrogant, and Mocking'
  else if FSnapshot.AIState.CryptoFunds < 50000 then
    FSnapshot.AIPersona := 'Desperate and Cautious'
  else
    FSnapshot.AIPersona := 'Cold, Ruthless, and Calculated';

  TAIWorkerThread.Create(FAIEndpoint, FSnapshot, FMap, ATauntMessage, AAILanguage, @HandleAIResponse);
end;

procedure TCartelEngine.HandleAIResponse(const ADecision: TAIDecision; const ASuccess: Boolean; const AErrorMsg: String);
var
  FallbackDec: TAIDecision;
begin
  if ASuccess then
  begin
    ResolveCycle(ADecision);
  end
  else
  begin
    if Assigned(FOnLog) then
      FOnLog('ERROR', 'AI Connection Failed. ' + AErrorMsg);

    FallbackDec.ActionType := 'idle';
    FallbackDec.OperatorMessage := 'Signal jammed. The DarkNet is drowning in static.';
    FallbackDec.AllocatedBudget := 0;
    FallbackDec.AllocatedBandwidth := 0;

    ResolveCycle(FallbackDec);
  end;
end;

procedure TCartelEngine.ProcessBlackMarketTransactions;
var
  CurrQ, CurrP: Integer;
  QCost, PCost: Int64;
begin
  CurrQ := FDB.GetUpgradeLevel('UPG_QUANTUM');
  while FPrevQuantumLvl < CurrQ do
  begin
    Inc(FPrevQuantumLvl);
    // --- PERBAIKAN: Menggunakan Round() alih-alih type-cast Int64() ---
    QCost := Round(Power(FPrevQuantumLvl, 2) * 25000 + 25000);
    Dec(FSnapshot.PlayerState.CryptoFunds, QCost);
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', Format('Wire Transfer: Offshore account deducted -$%d for Quantum Decryption Lvl %d.', [QCost, FPrevQuantumLvl]));
  end;

  CurrP := FDB.GetUpgradeLevel('UPG_PROXY');
  while FPrevProxyLvl < CurrP do
  begin
    Inc(FPrevProxyLvl);
    // --- PERBAIKAN: Menggunakan Round() alih-alih type-cast Int64() ---
    PCost := Round(Power(FPrevProxyLvl, 2) * 25000 + 25000);
    Dec(FSnapshot.PlayerState.CryptoFunds, PCost);
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', Format('Wire Transfer: Offshore account deducted -$%d for Proxy Lvl %d.', [PCost, FPrevProxyLvl]));
  end;
end;

procedure TCartelEngine.ResolveCycle(const AIDecision: TAIDecision);
var
  IdxPlayer, IdxAI: Integer;
  PlayerAttackPower, AIAttackPower, RequiredPower: Int64;
  ActualAIBudget: Int64;
  HeatPen, HeatReduction: Integer;
  AtkMultiplier, HeatMultiplier: Double;
begin
  ProcessBlackMarketTransactions;

  AtkMultiplier := 1.0 + (FPrevQuantumLvl * 0.20);
  HeatMultiplier := 1.0 - (FPrevProxyLvl * 0.10);

  if FSnapshot.CurrentEvent = geInterpolCrackdown then
    HeatMultiplier := HeatMultiplier * 2.0;

  // --- 1. RESOLUSI AKSI PEMAIN ---
  if FPlayerAction = taAttackNode then
  begin
    IdxPlayer := FindNodeIndex(FPlayerTargetNode);
    if IdxPlayer >= 0 then
    begin
      PlayerAttackPower := Round((FPlayerBandwidth + (FPlayerBudget div 500)) * AtkMultiplier);
      RequiredPower := FMap[IdxPlayer].FirewallLevel * 3;

      if FSnapshot.CurrentEvent = geZeroDayExploit then
        RequiredPower := RequiredPower div 2;

      if PlayerAttackPower >= RequiredPower then
      begin
        FMap[IdxPlayer].Owner := noPlayer;
        FMap[IdxPlayer].FirewallLevel := 60;
        FMap[IdxPlayer].IsVisible := True;
        Inc(FSnapshot.PlayerState.HeatLevel, Round(8 * HeatMultiplier));
        if Assigned(FOnLog) then
          FOnLog('PLAYER', Format('Breach successful! Acquired %s (Power: %d vs Req: %d).',
            [FMap[IdxPlayer].NodeName, PlayerAttackPower, RequiredPower]));
      end
      else
      begin
        FMap[IdxPlayer].FirewallLevel := Max(10, FMap[IdxPlayer].FirewallLevel - 15);
        HeatPen := Round(4 * HeatMultiplier);
        Inc(FSnapshot.PlayerState.HeatLevel, HeatPen);
        if Assigned(FOnLog) then
          FOnLog('PLAYER', Format('Attack on %s repelled (Power: %d vs Req: %d). Firewall degraded to %d.',
            [FMap[IdxPlayer].NodeName, PlayerAttackPower, RequiredPower, FMap[IdxPlayer].FirewallLevel]));
      end;
    end;
  end
  else if FPlayerAction = taScanNode then
  begin
    IdxPlayer := FindNodeIndex(FPlayerTargetNode);
    if IdxPlayer >= 0 then
    begin
      FMap[IdxPlayer].IsVisible := True;
      if Assigned(FOnLog) then
        FOnLog('PLAYER', Format('Network Scan complete. Target [%s] identified with Firewall Level %d.',
          [FMap[IdxPlayer].NodeName, FMap[IdxPlayer].FirewallLevel]));
    end;
  end
  else if FPlayerAction = taDDoSNode then
  begin
    IdxPlayer := FindNodeIndex(FPlayerTargetNode);
    if IdxPlayer >= 0 then
    begin
      FMap[IdxPlayer].FreezeTimer := 2;
      Inc(FSnapshot.PlayerState.HeatLevel, Round(6 * HeatMultiplier));
      if Assigned(FOnLog) then
        FOnLog('PLAYER', Format('Massive DDoS Payload delivered! [%s] will be frozen for 2 cycles.', [FMap[IdxPlayer].NodeName]));
    end;
  end
  else if FPlayerAction = taBribeInterpol then
  begin
    HeatReduction := FPlayerBudget div 1000;
    FSnapshot.PlayerState.HeatLevel := Max(0, FSnapshot.PlayerState.HeatLevel - HeatReduction);
    if Assigned(FOnLog) then
      FOnLog('PLAYER', Format('Bribe of $%d accepted by corrupt officials. Heat reduced by %d%%.', [FPlayerBudget, HeatReduction]));
  end
  else if FPlayerAction = taDeployTrap then
  begin
    IdxPlayer := FindNodeIndex(FPlayerTargetNode);
    if (IdxPlayer >= 0) and (FMap[IdxPlayer].Owner = noPlayer) then
    begin
      FMap[IdxPlayer].HasTrap := True;
      if Assigned(FOnLog) then
        FOnLog('PLAYER', Format('Counter-Intel honeypot deployed at [%s]. Awaiting targets...', [FMap[IdxPlayer].NodeName]));
    end
    else
    begin
      if Assigned(FOnLog) then
        FOnLog('PLAYER', 'Trap deployment failed. Target node is not under your control.');
    end;
  end;

  // --- 2. RESOLUSI AKSI AI (GHOST) ---
  if FSnapshot.AIState.CryptoFunds >= AIDecision.AllocatedBudget then
    ActualAIBudget := AIDecision.AllocatedBudget
  else
    ActualAIBudget := 0;

  Dec(FSnapshot.AIState.CryptoFunds, ActualAIBudget);

  if SameText(AIDecision.ActionType, 'attack') then
  begin
    IdxAI := FindNodeIndex(AIDecision.TargetNodeID);
    if IdxAI >= 0 then
    begin
      if FMap[IdxAI].HasTrap and (FMap[IdxAI].Owner = noPlayer) then
      begin
        FMap[IdxAI].HasTrap := False;

        Inc(FSnapshot.AIState.HeatLevel, 25);
        Inc(FSnapshot.PlayerState.CryptoFunds, 50000);

        if FSnapshot.AIState.CryptoFunds > 50000 then
          Dec(FSnapshot.AIState.CryptoFunds, 50000)
        else
          FSnapshot.AIState.CryptoFunds := 0;

        if Assigned(FOnLog) then
          FOnLog('SYSTEM', Format('TRAP TRIGGERED! Ghost attempted to breach [%s] and hit a honeypot. Tracing IPs... AI Heat +25%%, $50,000 seized!', [FMap[IdxAI].NodeName]));
      end
      else
      begin
        AIAttackPower := AIDecision.AllocatedBandwidth + (ActualAIBudget div 500);
        RequiredPower := FMap[IdxAI].FirewallLevel * 3;

        if FSnapshot.CurrentEvent = geZeroDayExploit then
          RequiredPower := RequiredPower div 2;

        if AIAttackPower >= RequiredPower then
        begin
          FMap[IdxAI].Owner := noAI;
          FMap[IdxAI].FirewallLevel := 60;
          Inc(FSnapshot.AIState.HeatLevel, Round(8 * HeatMultiplier));
          if Assigned(FOnLog) then
            FOnLog('GHOST (AI)', Format('Infiltrated and seized control of %s.', [FMap[IdxAI].NodeName]));
        end
        else
        begin
          FMap[IdxAI].FirewallLevel := Max(10, FMap[IdxAI].FirewallLevel - 10);
          Inc(FSnapshot.AIState.HeatLevel, Round(3 * HeatMultiplier));
          if Assigned(FOnLog) then
            FOnLog('GHOST (AI)', Format('Failed assault on %s. Target firewall weakened.', [FMap[IdxAI].NodeName]));
        end;
      end;
    end;
  end
  else if SameText(AIDecision.ActionType, 'reinforce_node') then
  begin
    IdxAI := FindNodeIndex(AIDecision.TargetNodeID);
    if (IdxAI >= 0) and (FMap[IdxAI].Owner = noAI) then
    begin
      Inc(FMap[IdxAI].FirewallLevel, 30);
      if Assigned(FOnLog) then
        FOnLog('GHOST (AI)', Format('Reinforced defenses at %s (+30 FW).', [FMap[IdxAI].NodeName]));
    end;
  end
  else if SameText(AIDecision.ActionType, 'snitch_to_police') then
  begin
    Inc(FSnapshot.PlayerState.HeatLevel, Round(18 * HeatMultiplier));
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', Format('INTERCEPT: Ghost submitted forged evidence against you to Interpol (+%d%% Heat)!', [Round(18 * HeatMultiplier)]));
  end;

  if Trim(AIDecision.OperatorMessage) <> '' then
    if Assigned(FOnLog) then
      FOnLog('GHOST (AI)', AIDecision.OperatorMessage);

  YieldResources;
  CheckWinLossConditions;

  ManageGlobalEvents;

  // --- TUNING 3: ADAPTIVE AI GHOST (SCALING DIFFICULTY) ---
  if (FSnapshot.CycleNumber mod 5 = 0) then
  begin
    Inc(FSnapshot.AIState.CryptoFunds, 25000);
    Inc(FSnapshot.AIState.BotnetBandwidth, 50);
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', 'INTEL: Ghost has established off-screen backchannels. AI received +$25,000 funds and +50 Bandwidth buff!');
  end;

  Inc(FSnapshot.CycleNumber);
  FDB.SaveTelemetry(FSnapshot);

  if (FSnapshot.PlayerState.HeatLevel >= 80) and (FSnapshot.PlayerState.HeatLevel < MAX_HEAT_LEVEL) then
  begin
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', 'CRITICAL WARNING: Interpol tracers detected. Heat level exceeds safe threshold!');
  end;

  if Assigned(FOnCycleComplete) then
    FOnCycleComplete(Self);
end;

procedure TCartelEngine.ManageGlobalEvents;
var
  EventRoll: Integer;
begin
  if FSnapshot.EventDuration > 0 then
  begin
    Dec(FSnapshot.EventDuration);
    if FSnapshot.EventDuration = 0 then
    begin
      FSnapshot.CurrentEvent := geNone;
      if Assigned(FOnLog) then
        FOnLog('THE WIRE', 'The DarkNet has stabilized. Network anomalies resolved.');
    end;
  end
  else
  begin
    if Random(100) < 15 then
    begin
      FSnapshot.EventDuration := 3;
      EventRoll := Random(5);
      case EventRoll of
        0:
        begin
          FSnapshot.CurrentEvent := geInterpolCrackdown;
          if Assigned(FOnLog) then FOnLog('THE WIRE', 'ANOMALY: Interpol Cyber-Swarm active! Heat generation doubled for 3 cycles.');
        end;
        1:
        begin
          FSnapshot.CurrentEvent := geZeroDayExploit;
          if Assigned(FOnLog) then FOnLog('THE WIRE', 'ANOMALY: Global Zero-Day leak! All node firewalls are highly vulnerable for 3 cycles.');
        end;
        2:
        begin
          FSnapshot.CurrentEvent := geCryptoCrash;
          if Assigned(FOnLog) then FOnLog('THE WIRE', 'ANOMALY: Crypto Market Crash! Income generation halved for 3 cycles.');
        end;
        3:
        begin
          FSnapshot.CurrentEvent := geBotnetSwarm;
          if Assigned(FOnLog) then FOnLog('THE WIRE', 'ANOMALY: Rogue Botnet Swarm! Bandwidth generation doubled for 3 cycles.');
        end;
        4:
        begin
          FSnapshot.CurrentEvent := geHiddenServer;
          SpawnHiddenNode;
          if Assigned(FOnLog) then FOnLog('THE WIRE', 'ANOMALY: Encrypted deep-web transmission intercepted! A new Hidden Server has appeared on the network map.');
        end;
      end;
    end;
  end;
end;

procedure TCartelEngine.YieldResources;
var
  i: Integer;
  CurrIncome: Int64;
  CurrBandwidth: Integer;
  PlayerIncomeMultiplier: Double;
begin
  FSnapshot.PlayerState.BotnetBandwidth := 0;
  FSnapshot.AIState.BotnetBandwidth := 0;

  // --- TUNING 4: PARANOIA MEKANIK (PENALTI HEAT PASIF) ---
  PlayerIncomeMultiplier := 1.0;
  if FSnapshot.PlayerState.HeatLevel > 80 then
    PlayerIncomeMultiplier := 0.5 // Potongan 50% jika Heat di atas 80%
  else if FSnapshot.PlayerState.HeatLevel > 50 then
    PlayerIncomeMultiplier := 0.75; // Potongan 25% jika Heat di atas 50%

  for i := 0 to High(FMap) do
  begin
    if FMap[i].FreezeTimer > 0 then
    begin
      Dec(FMap[i].FreezeTimer);
      Continue;
    end;

    CurrIncome := FMap[i].IncomeYield;
    CurrBandwidth := FMap[i].BandwidthYield;

    if FSnapshot.CurrentEvent = geCryptoCrash then
      CurrIncome := CurrIncome div 2
    else if FSnapshot.CurrentEvent = geBotnetSwarm then
      CurrBandwidth := CurrBandwidth * 2;

    case FMap[i].Owner of
      noPlayer:
      begin
        // Terapkan penalti Heat pasif khusus pemain
        Inc(FSnapshot.PlayerState.CryptoFunds, Round(CurrIncome * PlayerIncomeMultiplier));
        Inc(FSnapshot.PlayerState.BotnetBandwidth, CurrBandwidth);
      end;
      noAI:
      begin
        Inc(FSnapshot.AIState.CryptoFunds, CurrIncome);
        Inc(FSnapshot.AIState.BotnetBandwidth, CurrBandwidth);
      end;
    end;
  end;
end;

procedure TCartelEngine.CheckWinLossConditions;
begin
  if FSnapshot.PlayerState.HeatLevel >= MAX_HEAT_LEVEL then
  begin
    FSnapshot.Status := gsPlayerBusted;
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', 'CRITICAL FATAL: Heat reached 100%. Federal tactical teams raided your server bunker. GAME OVER.');
  end
  else if FSnapshot.PlayerState.CryptoFunds <= 0 then
  begin
    FSnapshot.Status := gsPlayerBankrupt;
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', 'CRITICAL FATAL: Crypto reserves drained. Syndicate dissolved. GAME OVER.');
  end
  else if FSnapshot.AIState.CryptoFunds <= 0 then
  begin
    FSnapshot.Status := gsPlayerWon;
    if Assigned(FOnLog) then
      FOnLog('SYSTEM', 'VICTORY: Ghost ran out of operational funds. You have established total DarkNet hegemony.');
  end;
end;

end.
