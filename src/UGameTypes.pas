unit UGameTypes;

{$mode ObjFPC}{$H+} // Menggunakan mode Free Pascal modern dengan String dinamis

interface

uses
  Classes, SysUtils;

type
  { --- ENUMERASI GLOBAL --- }

  // Faksi/Entitas pemilik sebuah Node di DarkNet
  TNodeOwner = (noNeutral, noPlayer, noAI);

  // --- PERUBAHAN EKSPANSI: Tambahan Aksi Taktis ---
  TTacticalAction = (
    taIdle,
    taAttackNode,
    taUpgradeFirewall,
    taLaunderMoney,
    taSnitchPolice,
    taDDoSNode,      // Aksi baru: Membekukan node lawan
    taScanNode,      // Aksi baru: Membuka Fog of War
    taBribeInterpol, // Aksi baru: Menurunkan Heat Level dengan dana besar
    taDeployTrap     // Aksi baru: Memasang honeypot/jebakan pada node milik sendiri
  );

  // Status kondisi utama Game Loop
  TGameStatus = (gsActive, gsPlayerWon, gsAIWon, gsPlayerBusted, gsPlayerBankrupt);

  // --- PERUBAHAN EKSPANSI 3: THE DARKNET WIRE (GLOBAL EVENTS) ---
  TGlobalEvent = (
    geNone,                 // Kondisi jaringan normal (tidak ada event)
    geInterpolCrackdown,    // Patroli Siber: Segala aksi agresif memicu penalti Heat ganda
    geZeroDayExploit,       // Kerentanan Massal: Seluruh firewall di peta melemah drastis
    geCryptoCrash,          // Pasar Anjlok: Pendapatan (Income) dari node berkurang secara masif
    geBotnetSwarm,          // Swarm Liar: Bandwidth yield meningkat, namun jaringan menjadi tidak stabil
    geHiddenServer          // --- EVENT BARU: Server rahasia (Node Baru) muncul di DarkNet! ---
  );

  { --- STRUKTUR DATA (RECORDS) --- }

  // Representasi satu titik jaringan (Node) di Peta TCanvas
  TNodeData = record
    NodeID: String;          // Identifier unik (misal: 'NODE_01')
    NodeName: String;        // Nama visual (misal: 'Dark Market Alpha')
    Owner: TNodeOwner;       // Pemilik saat ini
    FirewallLevel: Integer;  // HP/Pertahanan node (0-100)
    BandwidthYield: Integer; // Tambahan bandwidth yang diberikan ke pemilik
    IncomeYield: Int64;      // Tambahan crypto per tick
    CoordX: Integer;         // Titik koordinat render X pada TCanvas
    CoordY: Integer;         // Titik koordinat render Y pada TCanvas

    // --- PERUBAHAN EKSPANSI: Variabel Runtime ---
    IsVisible: Boolean;      // Fog of War: True jika sudah di-scan/dimiliki
    FreezeTimer: Integer;    // DDoS: Sisa putaran node tidak menghasilkan resource (0 = Aktif)
    HasTrap: Boolean;        // Trap: True jika ada jebakan Counter-Intel di node ini
  end;

  // Array dinamis untuk menyimpan daftar seluruh Node
  TDarkNetMap = array of TNodeData;

  // Status sumber daya sindikat (digunakan untuk Pemain maupun AI)
  TSyndicateState = record
    CryptoFunds: Int64;      // Menggunakan Int64 karena nilai uang virtual bisa sangat besar
    BotnetBandwidth: Integer;// Daya retas/pertahanan aktif
    HeatLevel: Integer;      // 0-100 (Ancaman pelacakan polisi)
    Reputation: Integer;     // Level respek di pasar gelap
  end;

  // Snapshot komprehensif untuk direkam ke dalam Database SQLite setiap cycle
  TGameSnapshot = record
    CycleNumber: Integer;
    Status: TGameStatus;
    PlayerState: TSyndicateState;
    AIState: TSyndicateState;

    // --- PERUBAHAN EKSPANSI 2: LLM Memory & Persona ---
    AIPersona: String;             // Status emosi/taktik ('Aggressive', 'Defensive', 'Desperate', 'Neutral')
    RecentHistory: array of String;// Menyimpan 3 log interaksi terakhir antara pemain dan AI

    // --- PERUBAHAN EKSPANSI 3: Global Event Tracking ---
    CurrentEvent: TGlobalEvent;    // Event global yang sedang aktif di DarkNet
    EventDuration: Integer;        // Sisa cycle (putaran) sebelum event global berakhir
  end;

  // Struktur penampung hasil parsing JSON dari server llama.cpp
  TAIDecision = record
    ThoughtProcess: String;  // Alasan AI melakukan aksi (log internal)
    ActionType: String;      // Aksi mentah dari JSON (harus dikonversi ke TTacticalAction nanti)
    TargetNodeID: String;    // Target serangan/pertahanan AI
    AllocatedBudget: Int64;  // Dana yang dikeluarkan AI untuk aksi ini
    AllocatedBandwidth: Integer;
    OperatorMessage: String; // Pesan taunt/chat yang akan tampil di Terminal TMemo
  end;

const
  { --- KONSTANTA GLOBAL DEFAULT --- }
  // Batas toleransi maksimal pelacakan sebelum Game Over
  MAX_HEAT_LEVEL = 100;

  // Resource awal (bisa ditimpa oleh konfigurasi file INI nanti)
  STARTING_FUNDS = 150000;
  STARTING_BANDWIDTH = 500;

  // Default Endpoint LLM HTTP
  DEFAULT_AI_ENDPOINT = 'http://127.0.0.1:8080/v1/chat/completions';

  { --- AUDIO & ATMOSPHERE CONSTANTS --- }
  // Referensi Windows System Sounds untuk pemanggilan via MMSystem
  SND_ALERT_CRITICAL = 'SystemExclamation'; // Saat Ghost meretas atau Heat sangat tinggi
  SND_ACTION_FAIL    = 'SystemHand';        // Saat serangan repelled/gagal
  SND_ACTION_SUCCESS = 'SystemAsterisk';    // Saat operasi taktis berhasil
  SND_TERMINAL_BEEP  = 'SystemDefault';     // Ketikan log standar terminal

implementation

end.
