unit UAIClient;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser, UGameTypes, openssl, opensslsockets;

type
  TAIResponseEvent = procedure(const Decision: TAIDecision; const Success: Boolean; const ErrorMsg: String) of object;

  TAIWorkerThread = class(TThread)
  private
    FEndpoint: String;
    FPayload: String;
    FCallback: TAIResponseEvent;
    FDecision: TAIDecision;
    FSuccess: Boolean;
    FErrorMsg: String;

    procedure SyncCallback;
  protected
    procedure Execute; override;
  public
    constructor Create(const AEndpoint: String; const ASnapshot: TGameSnapshot; const AMap: TDarkNetMap; const ATauntMessage: String; const AAILanguage: String; ACallback: TAIResponseEvent);
  end;

implementation

function BuildLlamaPayload(const Snapshot: TGameSnapshot; const Map: TDarkNetMap; const PlayerTaunt: String; const AILanguage: String): String;
var
  Root, MsgUser, ResFormat: TJSONObject;
  Messages, NodesArr, HistArr: TJSONArray;
  NodeObj: TJSONObject;
  i: Integer;
  OwnerName, EventStr, FullPromptText: String;
begin
  Root := TJSONObject.Create;
  try
    Messages := TJSONArray.Create;

    case Snapshot.CurrentEvent of
      geInterpolCrackdown: EventStr := 'Interpol Crackdown (Heat penalty is doubled. High risk of getting busted!)';
      geZeroDayExploit:    EventStr := 'Zero-Day Exploit (All firewalls are weakened by 50%. Easy to attack!)';
      geCryptoCrash:       EventStr := 'Crypto Market Crash (Income generation is halved. Funds are tight!)';
      geBotnetSwarm:       EventStr := 'Rogue Botnet Swarm (Bandwidth generation is doubled. High attack power!)';
      geHiddenServer:      EventStr := 'Hidden Server Appeared (A highly valuable, heavily fortified neutral node has just spawned. Capture it for massive rewards!)';
      else                 EventStr := 'None';
    end;

    NodesArr := TJSONArray.Create;
    for i := 0 to High(Map) do
    begin
      NodeObj := TJSONObject.Create;
      NodeObj.Add('node_id', Map[i].NodeID);
      NodeObj.Add('firewall', Map[i].FirewallLevel);
      case Map[i].Owner of
        noPlayer: OwnerName := 'player';
        noAI: OwnerName := 'ai';
        else OwnerName := 'neutral';
      end;
      NodeObj.Add('owner', OwnerName);
      NodesArr.Add(NodeObj);
    end;

    HistArr := TJSONArray.Create;
    for i := 0 to High(Snapshot.RecentHistory) do
    begin
      HistArr.Add(Snapshot.RecentHistory[i]);
    end;

    NodeObj := TJSONObject.Create;
    NodeObj.Add('cycle', Snapshot.CycleNumber);
    NodeObj.Add('ai_funds', Snapshot.AIState.CryptoFunds);
    NodeObj.Add('ai_heat', Snapshot.AIState.HeatLevel);
    NodeObj.Add('ai_bandwidth', Snapshot.AIState.BotnetBandwidth);
    NodeObj.Add('player_funds', Snapshot.PlayerState.CryptoFunds);
    NodeObj.Add('player_heat', Snapshot.PlayerState.HeatLevel);
    NodeObj.Add('recent_history', HistArr);
    NodeObj.Add('player_taunt', PlayerTaunt);
    NodeObj.Add('global_event', EventStr);
    NodeObj.Add('available_nodes', NodesArr);

    FullPromptText :=
      'INSTRUCTIONS:\n' +
      'You are Ghost, a cyber-cartel boss in a DarkNet turf war. Persona: "' + Snapshot.AIPersona + '".\n' +
      'CRITICAL INSTRUCTION: You MUST write your "operator_message" strictly in the following language/style: ' + AILanguage + '.\n' +
      'Your "thought_process" can remain in English, but the final message delivered to the player MUST be in ' + AILanguage + '.\n' +
      'Rules:\n' +
      '1. Target a valid node_id from available_nodes only.\n' +
      '2. action_type must be one of: "attack", "reinforce_node", "snitch_to_police", "idle".\n' +
      '3. Respond strictly in valid JSON format with keys: thought_process, action_type, target_node, allocated_budget, allocated_bandwidth, operator_message.\n\n' +
      'GAME STATE JSON:\n' + NodeObj.AsJSON;

    NodeObj.Free;

    MsgUser := TJSONObject.Create;
    MsgUser.Add('role', 'user');
    MsgUser.Add('content', FullPromptText);
    Messages.Add(MsgUser);

    Root.Add('messages', Messages);

    ResFormat := TJSONObject.Create;
    ResFormat.Add('type', 'json_object');
    Root.Add('response_format', ResFormat);
    Root.Add('temperature', 0.6);

    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

function BuildGeminiPayload(const Snapshot: TGameSnapshot; const Map: TDarkNetMap; const PlayerTaunt: String; const AILanguage: String): String;
var
  Root, SysInstruction, ContentObj, PartObj, GenConfig: TJSONObject;
  ContentsArr, PartsArr, NodesArr, HistArr: TJSONArray;
  NodeObj: TJSONObject;
  i: Integer;
  OwnerName, EventStr, SystemPrompt, UserPromptContent: String;
begin
  Root := TJSONObject.Create;
  try
    case Snapshot.CurrentEvent of
      geInterpolCrackdown: EventStr := 'Interpol Crackdown (Heat penalty is doubled. High risk of getting busted!)';
      geZeroDayExploit:    EventStr := 'Zero-Day Exploit (All firewalls are weakened by 50%. Easy to attack!)';
      geCryptoCrash:       EventStr := 'Crypto Market Crash (Income generation is halved. Funds are tight!)';
      geBotnetSwarm:       EventStr := 'Rogue Botnet Swarm (Bandwidth generation is doubled. High attack power!)';
      geHiddenServer:      EventStr := 'Hidden Server Appeared (A highly valuable, heavily fortified neutral node has just spawned. Capture it for massive rewards!)';
      else                 EventStr := 'None';
    end;

    SystemPrompt :=
      'You are Ghost, a cyber-cartel boss in a DarkNet turf war. ' +
      'Your current mental state and persona is: "' + Snapshot.AIPersona + '". ' +
      'Let this persona dictate your tactical strategy and the tone of your operator_message. ' +
      'Read the recent_history to understand what just happened. Hold grudges if the player attacked you, or mock them if they failed. ' +
      'If the player sends a "player_taunt", you MUST directly react and reply to it in your operator_message. ' +
      'If "global_event" is not "None", adapt your strategy to survive the anomaly and optionally comment on it. ' +
      'CRITICAL INSTRUCTION: You MUST write your "operator_message" strictly in the following language/style: ' + AILanguage + '. ' +
      'Your "thought_process" can remain in English, but the final message delivered to the player MUST be in ' + AILanguage + '. ' +
      'Rules: ' +
      '1. Target a valid node_id from available_nodes only. ' +
      '2. action_type must be one of: "attack", "reinforce_node", "snitch_to_police", "idle". ' +
      '3. Respond strictly in valid JSON format with keys: ' +
      'thought_process, action_type, target_node, allocated_budget, allocated_bandwidth, operator_message.';

    SysInstruction := TJSONObject.Create;
    PartsArr := TJSONArray.Create;
    PartObj := TJSONObject.Create;
    PartObj.Add('text', SystemPrompt);
    PartsArr.Add(PartObj);
    SysInstruction.Add('parts', PartsArr);
    Root.Add('system_instruction', SysInstruction);

    ContentsArr := TJSONArray.Create;
    ContentObj := TJSONObject.Create;
    ContentObj.Add('role', 'user');

    NodesArr := TJSONArray.Create;
    for i := 0 to High(Map) do
    begin
      NodeObj := TJSONObject.Create;
      NodeObj.Add('node_id', Map[i].NodeID);
      NodeObj.Add('firewall', Map[i].FirewallLevel);
      case Map[i].Owner of
        noPlayer: OwnerName := 'player';
        noAI: OwnerName := 'ai';
        else OwnerName := 'neutral';
      end;
      NodeObj.Add('owner', OwnerName);
      NodesArr.Add(NodeObj);
    end;

    HistArr := TJSONArray.Create;
    for i := 0 to High(Snapshot.RecentHistory) do
      HistArr.Add(Snapshot.RecentHistory[i]);

    NodeObj := TJSONObject.Create;
    NodeObj.Add('cycle', Snapshot.CycleNumber);
    NodeObj.Add('ai_funds', Snapshot.AIState.CryptoFunds);
    NodeObj.Add('ai_heat', Snapshot.AIState.HeatLevel);
    NodeObj.Add('ai_bandwidth', Snapshot.AIState.BotnetBandwidth);
    NodeObj.Add('player_funds', Snapshot.PlayerState.CryptoFunds);
    NodeObj.Add('player_heat', Snapshot.PlayerState.HeatLevel);
    NodeObj.Add('recent_history', HistArr);
    NodeObj.Add('player_taunt', PlayerTaunt);
    NodeObj.Add('global_event', EventStr);
    NodeObj.Add('available_nodes', NodesArr);

    UserPromptContent := NodeObj.AsJSON;
    NodeObj.Free;

    PartsArr := TJSONArray.Create;
    PartObj := TJSONObject.Create;
    PartObj.Add('text', UserPromptContent);
    PartsArr.Add(PartObj);
    ContentObj.Add('parts', PartsArr);
    ContentsArr.Add(ContentObj);

    Root.Add('contents', ContentsArr);

    GenConfig := TJSONObject.Create;
    GenConfig.Add('temperature', 0.6);
    GenConfig.Add('response_mime_type', 'application/json');
    Root.Add('generation_config', GenConfig);

    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

{ TAIWorkerThread }

constructor TAIWorkerThread.Create(const AEndpoint: String; const ASnapshot: TGameSnapshot; const AMap: TDarkNetMap; const ATauntMessage: String; const AAILanguage: String; ACallback: TAIResponseEvent);
begin
  inherited Create(False);
  FreeOnTerminate := True;

  FEndpoint := AEndpoint;
  FCallback := ACallback;

  if Pos('googleapis.com', FEndpoint) > 0 then
    FPayload := BuildGeminiPayload(ASnapshot, AMap, ATauntMessage, AAILanguage)
  else
    FPayload := BuildLlamaPayload(ASnapshot, AMap, ATauntMessage, AAILanguage);

  FSuccess := False;
end;

procedure TAIWorkerThread.Execute;
var
  HTTPClient: TFPHTTPClient;
  ReqStream: TStringStream;
  RawResponse: String;
  JSONResp, ChoiceNode, InnerJSONData: TJSONData;
  InnerJSON: TJSONObject;
  RawContent, CleanJSON: String;
  StartIdx, EndIdx, i, j: Integer;
begin
  FSuccess := False;
  FErrorMsg := 'Unknown Thread Error';

  try
    HTTPClient := TFPHTTPClient.Create(nil);
    try
      HTTPClient.ConnectTimeout := 20000;
      HTTPClient.IOTimeout := 20000;

      ReqStream := TStringStream.Create(FPayload);
      try
        HTTPClient.AddHeader('Content-Type', 'application/json');
        HTTPClient.RequestBody := ReqStream;

        RawResponse := HTTPClient.Post(FEndpoint);

        // --- Simpan respons mentah AI ke file JSON untuk debugging ---
        try
          with TStringList.Create do
          try
            Text := RawResponse;
            SaveToFile(ExtractFilePath(ParamStr(0)) + '..\data\ai_response_debug.json');
          finally
            Free;
          end;
        except
        end;

        JSONResp := GetJSON(RawResponse);
        try
          RawContent := '';

          // --- LOGIKA PARSING DINAMIS ---
          if Pos('streamGenerateContent', FEndpoint) > 0 then
          begin
            // 1. Google Gemini Streaming API (Gemma-4-26b-it)
            if JSONResp.JSONType = jtArray then
            begin
              for j := 0 to TJSONArray(JSONResp).Count - 1 do
              begin
                ChoiceNode := TJSONArray(JSONResp).Items[j].FindPath('candidates[0].content.parts[0]');
                if Assigned(ChoiceNode) and (ChoiceNode.JSONType = jtObject) then
                begin
                  if not TJSONObject(ChoiceNode).Get('thought', False) then
                    RawContent := RawContent + TJSONObject(ChoiceNode).Get('text', '');
                end;
              end;
            end;
          end
          else if Pos('googleapis.com', FEndpoint) > 0 then
          begin
            // 2. Google Gemini Standard API (Non-Streaming dengan antisipasi 'thought' parts)
            ChoiceNode := JSONResp.FindPath('candidates[0].content.parts');
            if Assigned(ChoiceNode) and (ChoiceNode.JSONType = jtArray) then
            begin
              for j := 0 to TJSONArray(ChoiceNode).Count - 1 do
              begin
                if not TJSONObject(TJSONArray(ChoiceNode).Items[j]).Get('thought', False) then
                  RawContent := RawContent + TJSONObject(TJSONArray(ChoiceNode).Items[j]).Get('text', '');
              end;
            end
            else
            begin
              // Fallback jika parts bukan array kompleks
              ChoiceNode := JSONResp.FindPath('candidates[0].content.parts[0].text');
              if Assigned(ChoiceNode) then
                RawContent := ChoiceNode.AsString;
            end;
          end
          else
          begin
            // 3. Llama.cpp Local API
            ChoiceNode := JSONResp.FindPath('choices[0].message.content');
            if Assigned(ChoiceNode) then
              RawContent := ChoiceNode.AsString;
          end;

          if RawContent <> '' then
          begin
            StartIdx := Pos('{', RawContent);
            EndIdx := 0;
            for i := Length(RawContent) downto 1 do
            begin
              if RawContent[i] = '}' then
              begin
                EndIdx := i;
                Break;
              end;
            end;

            if (StartIdx > 0) and (EndIdx > StartIdx) then
              CleanJSON := Copy(RawContent, StartIdx, EndIdx - StartIdx + 1)
            else
              CleanJSON := RawContent;

            InnerJSONData := GetJSON(CleanJSON);
            try
              if InnerJSONData.JSONType = jtObject then
              begin
                InnerJSON := TJSONObject(InnerJSONData);

                FDecision.ThoughtProcess     := InnerJSON.Get('thought_process', '');
                FDecision.ActionType         := InnerJSON.Get('action_type', 'idle');
                FDecision.TargetNodeID       := InnerJSON.Get('target_node', '');
                FDecision.AllocatedBudget    := InnerJSON.Get('allocated_budget', Int64(0));
                FDecision.AllocatedBandwidth := InnerJSON.Get('allocated_bandwidth', 0);
                FDecision.OperatorMessage    := InnerJSON.Get('operator_message', 'No comment.');

                FSuccess := True;
                FErrorMsg := '';
              end
              else
                FErrorMsg := 'AI output is not a JSON object.';
            finally
              InnerJSONData.Free;
            end;
          end
          else
            FErrorMsg := 'Malformed response envelope from AI server.';
        finally
          JSONResp.Free;
        end;
      finally
        ReqStream.Free;
      end;
    finally
      HTTPClient.Free;
    end;
  except
    on E: Exception do
      FErrorMsg := 'Exception: ' + E.ClassName + ' - ' + E.Message;
  end;

  if Assigned(FCallback) then
    Synchronize(@SyncCallback);
end;

procedure TAIWorkerThread.SyncCallback;
begin
  if Assigned(FCallback) then
    FCallback(FDecision, FSuccess, FErrorMsg);
end;

end.
