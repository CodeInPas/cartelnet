# CartelNET 
CartelNET: Dark Operator is a tactical cyber-warfare strategy game featuring a dynamic, LLM-powered AI adversary (Google Gemini / Llama.cpp) 

<img width="1092" height="569" alt="image" src="https://github.com/user-attachments/assets/db04bc2f-a31e-40b7-b725-1e51746f7f94" />

---
# 🕹️ CartelNET: Dark Operator

**CartelNET: Dark Operator** is a tactical cyber-warfare strategy game built with Free Pascal / Lazarus. 
You play as a rogue operator fighting for dominance over the DarkNet against **"Ghost"**—a highly advanced, dynamic AI cartel boss powered by real Large Language Models (LLMs) like Google Gemini and Llama.cpp.

Unlike traditional games with hard-coded enemy behaviors, Ghost reads your tactical moves, analyzes the board state, and responds to your custom text taunts in real-time.

---

## ✨ Features
* **LLM-Powered Enemy AI:** Ghost uses real-time API integrations (Google Gemini or Local Llama.cpp) to evaluate board states, manage budgets, and generate dynamic, personality-driven dialogue.
* **Asynchronous Engine:** Fluid desktop UI that remains fully responsive while fetching complex AI payloads in the background.
* **Procedural Global Anomalies:** Random system events (like Interpol Crackdowns or Crypto Crashes) that force both you and the AI to constantly adapt your strategies.
* **Live Telemetry & Glitch Aesthetics:** Real-time CRT screen shake effects, dynamic signal oscilloscopes, and "Paranoia Protocol" elements when Interpol traces your signal.

---

## 📊 Syndicate Telemetry (Your Dashboard)
To win the turf war, you must manage your illicit resources carefully:
* 💰 **Crypto:** The currency of the DarkNet. Used to launch attacks, deploy traps, and purchase upgrades.
* ⚡ **Bandwidth (TBps):** Your digital firepower. High bandwidth is required to break through heavily fortified node firewalls.
* 🚨 **Heat Level:** The most critical metric. If your Heat reaches **85% or higher**, Interpol traces will lock onto your signal, triggering the *Paranoia Protocol* (screen glitches) and risking a raid.
* 🧠 **Ghost Status:** A real-time psychological profile of your AI opponent (e.g., *COLD AND CALCULATED* or *DESPERATE*). Ghost adapts its strategy based on this state.

---

## 🌐 The Tactical Map (Nodes)
The DarkNet topology consists of Servers and Gateways (Nodes).
* 🟢 **Green Nodes:** Your controlled territory.
* 🔴 **Red Nodes:** Ghost’s controlled territory.
* ⚪ **White/Gray Nodes:** Neutral or heavily encrypted nodes.
* **Firewall (FW):** The defense points of a node. You must deal more damage than the current FW level to capture it.
* **Status Tags:** Nodes can be temporarily inflicted with effects like `[TRAPPED]` (Counter-Intel) or `[FROZEN]` (DDoS applied).

---

## ⚔️ Operations & Exploits
Select an operation, target a node, allocate your budget, and hit **EXECUTE EXPLOIT**.
1. **Attack / Breach:** Standard assault to lower a target's firewall and capture it.
2. **DDoS Attack (Freeze):** Temporarily paralyzes a node.
3. **Deploy Trap (Counter-Intel):** Fortifies your node with a hidden trap that punishes Ghost if attacked.
4. **Reinforce Defenses:** Spends budget to increase the firewall of a node you already own.
5. **💬 Operator Message (Taunt):** Ghost reads these messages! Taunt, threaten, or bluff. The AI will analyze your words and reply directly to you based on the current game state.

---

## 🌩️ Global System Anomalies
The DarkNet is volatile. Every few turns, a global event may trigger:
* 🚓 **Interpol Crackdown:** Heat generation is doubled. Lay low!
* 🔓 **Zero-Day Exploit:** All node firewalls are globally weakened by 50%.
* 📉 **Crypto Crash:** Passive income is halved.
* 🤖 **Rogue Botnet Swarm:** Bandwidth generation is doubled.
* 💎 **Hidden Server Appeared:** A highly valuable neutral node spawns on the map.

---

## 🛒 The Black Market
Spend excess Crypto on permanent syndicate upgrades:
* **Quantum Decryption:** Permanently increases your base attack power.
* **Offshore Proxy:** Improves network stealth, reducing the amount of Heat generated per turn.

---

## 🛠️ Setup & Configuration

### Prerequisites
* Compiled executable of `CartelNET.exe`.
* An active Internet connection (for Google Gemini Cloud AI).
* *Optional:* Llama.cpp server running locally on `http://127.0.0.1:8080` (for Local AI mode).

### API Configuration
Before starting your first operation, you must configure the AI Service:
1. Open the game and navigate to the **Settings** tab.
2. Select your preferred **AI Provider**:
   * **Google Gemini Cloud (API):** Highly recommended for the smartest opponent. Requires a free API Key from Google AI Studio.
   * **Local AI (Llama.cpp):** Runs locally. Best used with models like *Qwen2-7B-Instruct* for optimal JSON formatting and multi-language support.
3. If using Gemini, paste your API Key in the designated field.
4. Click **SAVE**. The AI engine is now connected.

---


## ☕ Support the Project

If you find **CartelNET** helpful and want to support its ongoing development, consider buying me a coffee or sending a tip. Any support is deeply appreciated!

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20Me%20a%20Coffee-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://Ko-fi.com/ainovasinusantara)
[![PayPal](https://img.shields.io/badge/PayPal-Donate-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://paypal.me/KangOz)

> **💡 Your support keeps the momentum going!**  
> Every contribution directly fuels my passion, energy, and motivation to continuously build, maintain, and release even more useful open-source desktop applications for the developer community.
---
## Download Release ( Binary )
https://github.com/CodeInPas/cartelnet/releases/tag/releasev01
