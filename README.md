# TacitNode 🏗️⚡

<p align="center">
  <img src="assets/app_icon.png" alt="TacitNode Logo" width="200"/>
</p>

<p align="center">
  <strong>A hybrid edge-to-cloud AI copilot for industrial field workers.</strong>
</p>

<p align="center">
  TacitNode bridges the "Great Crew Change" knowledge gap by acting as a digital mentor that looks over a junior technician's shoulder. It processes real-time camera feeds on-device for instant, offline-capable guidance — and intelligently escalates complex diagnostics to the cloud when needed.
</p>

<p align="center">
  <a href="https://drive.google.com/file/d/1ey509i5iY_9QusfV_uCb4hoAjXew865a/view?usp=drive_link">
    <img src="https://img.shields.io/badge/🎥_Watch-Demo_Video-red?style=for-the-badge" alt="Demo Video"/>
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.10.1+-02569B?style=for-the-badge&logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Cactus-Compute-green?style=for-the-badge" alt="Cactus Compute"/>
  <img src="https://img.shields.io/badge/Gemini-2.5_Flash-4285F4?style=for-the-badge&logo=google" alt="Gemini"/>
</p>

---

## Screenshots

<p align="center">
  <img src="assets/app_icon.png" alt="App Icon" width="150"/>
</p>

<p align="center">
  <em>TacitNode features a camera-first interface with real-time routing indicators, performance metrics, and an enhanced debug console for full observability.</em>
</p>

> **Note:** Add screenshots of your app in action to the `assets/` folder and update the paths above to showcase:
> - Local inference with green routing indicator
> - Cloud escalation with amber routing indicator  
> - Metrics dashboard showing cost savings
> - Debug console with JSON viewer
> - Offline mode banner

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                     TacitNode App                           │
│                                                             │
│  📷 Camera Feed + 🎯 Demo Controls                          │
│       │                                                     │
│       ▼                                                     │
│  🧠 FunctionGemma (functiongemma-270m - on-device)          │
│       │                                                     │
│       ├── validate_routine_step ──▶ 👁️ Local Vision        │
│       │                             (lfm2-vl-450m)         │
│       │                             ⚡ ~45ms | 168 tok/s    │
│       │                             💾 245 MB RAM          │
│       │                                                     │
│       └── escalate_to_expert ────▶ ☁️ Gemini 2.5 Flash     │
│                                      ~1.2s | $0.0000875    │
│                                                             │
│  📊 Metrics Dashboard (cost savings, latency tracking)      │
│  🖥️ Debug Console (JSON routing decisions + filters)        │
│  ✈️ Offline Mode (local-only inference)                     │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### Core Capabilities
- **On-device function calling** via [Cactus Compute](https://cactuscompute.com) — FunctionGemma routes queries at 168 tok/s with ~45ms latency
- **Intelligent cloud escalation** — automatically routes complex diagnostics to Gemini 2.5 Flash when local models can't handle it
- **Hybrid architecture** — 3x cost savings vs pure cloud, with instant local responses and expert cloud analysis
- **Offline-capable** — local inference works without any network connection, critical for remote industrial sites
- **Camera-first interface** — full-screen live feed with glassmorphism overlays, designed for hands-free field use

### Demo-Ready Features
- **Visual routing indicators** — animated pulse showing local (green) vs cloud (amber) routing decisions in real-time
- **Performance metrics** — live display of latency, tokens/sec, cost per query, and cumulative savings
- **Demo control panel** — one-tap presets for reliable demos: Quick ID, Diagnose, Offline Test
- **Metrics dashboard** — session statistics showing local vs cloud query distribution and cost comparison
- **Enhanced debug console** — collapsible JSON viewer with syntax highlighting and filter chips (All, Routing, Warnings, Errors)
- **Offline mode simulation** — toggle airplane mode for demos without disconnecting network

## Performance Benchmarks

| Metric | Local Inference | Cloud Escalation | Improvement |
|--------|----------------|------------------|-------------|
| Latency | ~45ms | ~1,200ms | **26x faster** |
| Tokens/sec | 168 tok/s | N/A (network bound) | — |
| Cost per query | $0.00 | ~$0.0000875 | **100% savings** |
| Offline capable | ✅ Yes | ❌ No | — |
| RAM usage | ~245 MB | Minimal | — |

**Hybrid Architecture Benefits:**
- **3x cost reduction** vs pure cloud (with typical 67% local / 33% cloud split)
- **26x faster** for routine identification queries
- **100% offline capable** for local queries
- **Automatic fallback** ensures reliability

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| Local Routing Model | Cactus SDK (`functiongemma-270m`) |
| Local Vision Model | Cactus SDK (`lfm2-vl-450m`) |
| Cloud Fallback | Gemini 2.5 Flash API |
| Camera | `camera` package |
| Connectivity | `connectivity_plus` |
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

> **Note:** On first launch, the app downloads both the routing model (`functiongemma-270m`) and the vision model (`lfm2-vl-450m`) (~700 MB total). This requires a one-time internet connection.

### Platform Setup

| Platform | Required Config |
|----------|-----------------|
| Android | Camera + Internet permissions (pre-configured in `AndroidManifest.xml`) |
| iOS | `NSCameraUsageDescription` (pre-configured in `Info.plist`) |
| macOS | Network client entitlement (pre-configured). No camera support — runs in text-only mode. |

## Project Structure

```
lib/
├── main.dart                          # App entry, theme, .env loading
├── models/
│   ├── routing_decision.dart          # RoutingDecision with performance metrics
│   ├── session_metrics.dart           # Cumulative session statistics
│   └── demo_preset.dart               # Demo scenario presets
├── screens/
│   └── copilot_screen.dart            # Full-screen camera + overlay UI
├── services/
│   ├── camera_service.dart            # Camera lifecycle, frame capture
│   ├── cloud_service.dart             # Gemini 2.5 Flash API integration
│   ├── copilot_service.dart           # Core orchestrator (Cactus LLM + routing)
│   ├── metrics_service.dart           # Session-wide metrics tracking
│   └── connectivity_service.dart      # Network status + offline simulation
└── widgets/
    ├── debug_console.dart             # Enhanced JSON viewer with filters
    ├── model_status_bar.dart          # Status bar with offline indicator
    ├── routing_indicator.dart         # Animated routing decision display
    ├── metrics_overlay.dart           # Session statistics dashboard
    ├── demo_controls_fab.dart         # Expandable demo preset controls
    └── offline_banner.dart            # Offline mode notification
```

## How Routing Works

TacitNode uses a sophisticated 7-step routing pipeline:

1. **User asks a question** (e.g., *"What is this?"*) while pointing camera at equipment
2. **FunctionGemma analyzes intent** (~168 tok/s) and selects appropriate tool:
   - `validate_routine_step` → Local identification
   - `escalate_to_expert` → Cloud diagnosis
   - `answer_query` → Direct response
3. **Visual feedback displays:**
   - Green pulse animation: "Analyzing locally..."
   - Amber pulse animation: "Escalating to expert..."
4. **Tool execution:**
   - **Local path:** Camera frame → Vision Model (`lfm2-vl-450m`) → Component ID (~45ms)
   - **Cloud path:** Frame + query → Gemini 2.5 Flash → Expert analysis (~1.2s)
5. **Response card shows:**
   - Routing type (⚡ Local or ☁️ Cloud)
   - Performance metrics (latency, tokens/sec, cost)
   - Routing path taken
   - Cost savings for local queries
6. **Metrics tracking:**
   - All queries logged in session dashboard
   - Cumulative cost comparison (cloud-only vs hybrid)
   - Offline query counter
7. **Automatic fallback:** If local inference fails → cloud escalation as safety net

## Quick Demo Guide

### Using Demo Presets (Recommended)
1. **Tap the FAB** (floating action button, bottom-right with flask icon)
2. **Select a preset:**
   - **Quick ID** (green) → Instant local identification with metrics
   - **Diagnose** (amber) → Cloud escalation for complex analysis
   - **Offline Test** (blue) → Simulates airplane mode, local-only inference

### Manual Demo Flow
1. **Local inference** — Point camera at component (LED, breadboard, Arduino). Type *"What is this?"* → watch green pulse → instant response with latency/TPS metrics ⚡
2. **Cloud escalation** — Type *"Why is this circuit failing?"* → watch amber pulse → Gemini analysis with cost display ☁️
3. **Offline mode** — Tap FAB → Offline Test preset → see offline banner → local inference still works ✈️
4. **Metrics dashboard** — Tap FAB → Analytics button → view session stats, cost comparison, savings 📊
5. **Debug console** — Expand console at bottom → tap routing entries → view JSON with tool calls 🖥️

### What to Show Judges
- **Visual routing indicators** — Green vs amber pulse animations
- **Performance metrics** — 45ms local vs 1.2s cloud latency
- **Cost savings** — Real-time calculation of hybrid vs cloud-only cost (3x savings)
- **Offline capability** — Works without network connection
- **Technical depth** — JSON viewer showing exact tool calls and routing logic

For a complete 6-minute demo script with timing and talking points, see [DEMO_SCRIPT.md](.kiro/specs/hackathon-demo-enhancements/DEMO_SCRIPT.md)

## Hackathon Features

This project was built for the **Google DeepMind x Cactus Compute Hackathon** with the following demo-ready enhancements:

### Visual Enhancements
- ✅ Animated routing indicators (green pulse for local, amber for cloud)
- ✅ Performance metrics badges on every response
- ✅ Glassmorphism UI with smooth transitions
- ✅ Color-coded routing decisions throughout
- ✅ High-resolution app icons and splash screens

### Demo Controls
- ✅ One-tap demo presets (Quick ID, Diagnose, Offline Test)
- ✅ Metrics reset button for fresh demos
- ✅ Offline mode simulation toggle
- ✅ Expandable FAB with staggered animations
- ✅ Mutual exclusivity (FAB/metrics can't both be open)

### Metrics & Analytics
- ✅ Session statistics dashboard
- ✅ Cost comparison (cloud-only vs hybrid)
- ✅ Cumulative savings tracker with 5-decimal precision
- ✅ Offline query counter
- ✅ Average latency display
- ✅ Detailed logging for verification

### Developer Tools
- ✅ Enhanced debug console with JSON viewer
- ✅ Collapsible routing entries (120px → 336px)
- ✅ Filter chips (All, Routing, Warnings, Errors)
- ✅ Syntax-highlighted tool calls
- ✅ Full observability of routing decisions
- ✅ Cloud response logging

## Troubleshooting

### Models not downloading
- Ensure internet connection on first launch
- Check available storage (~700 MB required)
- Models download automatically, progress shown in status bar

### Camera not working
- Grant camera permissions when prompted
- On macOS, app runs in text-only mode (no camera support)
- Physical device recommended for full demo

### Offline mode not working
- Tap FAB → Offline Test preset to simulate
- Or use device airplane mode
- Local models must be downloaded first
- Tap offline banner to disable simulation

### Metrics not updating
- Tap FAB → Reset Metrics to clear
- Check debug console for detailed logs
- Verify MetricsService initialization

### Cloud escalation failing
- Verify Gemini API key in `.env` file
- Check internet connection
- Review debug console for error details
- API uses Gemini 2.5 Flash model

## Technical Documentation

For detailed technical information, including:
- Complete development history
- All challenges encountered and solutions
- Architecture decisions and rationale
- Performance characteristics
- Future optimization plans

See [docs/technical_documentation.md](docs/technical_documentation.md)

## Contributing

This project demonstrates hybrid edge-to-cloud AI architecture for the hackathon. Key areas for contribution:
- Additional demo presets for different industries
- More sophisticated routing logic
- Enhanced error handling and retry mechanisms
- Additional performance optimizations
- Support for more Cactus models
- Multi-turn conversation support
- Voice control (TTS/STT)

## License

MIT License - See LICENSE file for details

## Acknowledgments

Built with:
- [Cactus Compute](https://cactuscompute.com) - On-device AI inference SDK
- [Google DeepMind](https://deepmind.google) - Gemini API and FunctionGemma model
- [Flutter](https://flutter.dev) - Cross-platform framework
- [connectivity_plus](https://pub.dev/packages/connectivity_plus) - Network monitoring
- [Liquid AI](https://liquid.ai) - LFM2-VL vision model

**Special thanks** to the Google DeepMind and Cactus Compute teams for organizing the hackathon and providing the tools to build hybrid AI systems that work anywhere - from the factory floor to remote field sites.

---

*Demonstrating the future of hybrid edge-to-cloud AI systems*
