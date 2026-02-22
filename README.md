# TacitNode 🏗️⚡

**A hybrid edge-to-cloud AI copilot for industrial field workers.**

TacitNode bridges the "Great Crew Change" knowledge gap by acting as a digital mentor that looks over a junior technician's shoulder. It processes real-time camera feeds on-device for instant, offline-capable guidance — and intelligently escalates complex diagnostics to the cloud when needed.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  TacitNode App                  │
│                                                 │
│  📷 Camera Feed                                 │
│       │                                         │
│       ▼                                         │
│  🤖 CopilotService (Cactus LLM - on-device)    │
│       │                                         │
│       ├── validate_routine_step ──▶ ⚡ Local    │
│       │   (zero latency, offline)     Response  │
│       │                                         │
│       └── escalate_to_expert ──▶ ☁️  Gemini    │
│           (cloud fallback)           API        │
│                                                 │
│  🖥️ Debug Console (live routing decisions)      │
└─────────────────────────────────────────────────┘
```

## Key Features

- **On-device function calling** via [Cactus Compute](https://cactuscompute.com) — identifies components and validates procedure steps at zero latency
- **Intelligent cloud escalation** — automatically routes complex diagnostics to Gemini API when the local model can't handle it
- **Live debug console** — color-coded overlay showing raw JSON routing decisions (`Local Inference` vs `Cloud Escalation`) in real-time
- **Camera-first interface** — full-screen live feed with semi-transparent overlays, designed for hands-free field use
- **Offline-capable** — local inference works without any network connection, critical for remote industrial sites

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Local LLM | Cactus SDK (`qwen3-0.6`) |
| Cloud Fallback | Gemini 2.0 Flash API |
| Camera | `camera` package |
| Secrets | `flutter_dotenv` (`.env` gitignored) |

## Getting Started

### Prerequisites

- Flutter SDK `^3.10.1`
- A physical device with a camera (iOS or Android) for full demo
- A [Gemini API key](https://aistudio.google.com/api-keys) for cloud escalation

### Setup

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/tacit_node.git
cd tacit_node

# Install dependencies
flutter pub get

# Create your .env file
echo 'GEMINI_API_KEY=your_key_here' > .env

# Run on a connected device
flutter run
```

> **Note:** On first launch, the app downloads the `qwen3-0.6` model (~600 MB). This requires a one-time internet connection.

### Platform Setup

| Platform | Required Config |
|----------|----------------|
| Android | Camera + Internet permissions (pre-configured in `AndroidManifest.xml`) |
| iOS | `NSCameraUsageDescription` (pre-configured in `Info.plist`) |
| macOS | Network client entitlement (pre-configured). No camera support — runs in text-only mode. |

## Project Structure

```
lib/
├── main.dart                          # App entry, theme, .env loading
├── models/
│   └── routing_decision.dart          # RoutingDecision, ConsoleEntry, enums
├── screens/
│   └── copilot_screen.dart            # Full-screen camera + overlay UI
├── services/
│   ├── camera_service.dart            # Camera lifecycle, frame capture
│   ├── cloud_service.dart             # Gemini API fallback
│   └── copilot_service.dart           # Core orchestrator (Cactus LLM + routing)
└── widgets/
    ├── debug_console.dart             # Color-coded terminal overlay
    └── model_status_bar.dart          # TACITNODE branding + status chips
```

## How Routing Works

1. **Technician asks a question** (e.g., *"What is this?"*) while pointing the camera at equipment
2. **Local model processes the query** using Cactus on-device inference (~12 tok/s)
3. **Tool call decision:**
   - `validate_routine_step` → responds locally in milliseconds (green in debug console)
   - `escalate_to_expert` → captures frame, encodes to base64, sends to Gemini API (amber in debug console)
4. **If no tool is called** → automatic cloud escalation as safety fallback

## Demo Script

1. **Offline mode** — Disconnect WiFi. Point camera at a standard component (LED, breadboard). Ask *"What is this?"* → instant local response ⚡
2. **Introduce a fault** — Ask *"Why is this circuit failing?"* → watch the debug console show `☁️ Cloud Escalation Triggered` → Gemini response streams back
3. **Show the judges** the exact JSON routing decision in the debug console

## License

This project is part of the Cactus × DeepMind FunctionGemma Hackathon.
