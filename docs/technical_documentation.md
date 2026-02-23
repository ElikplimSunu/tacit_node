# TacitNode: Technical Documentation

## 1. Project Overview

TacitNode is a hybrid edge-to-cloud AI copilot designed to assist industrial field technicians with real-time equipment diagnostics. Built for the **Google DeepMind x Cactus Compute Hackathon**, it demonstrates intelligent routing between on-device inference and cloud escalation, achieving 3x cost savings and 26x faster response times for routine queries.

Because field technicians often operate in environments with poor or non-existent internet connectivity, TacitNode's core requirement is to run a **100% local AI pipeline** for routine tasks, resorting to cloud escalation only for complex diagnostics that require deeper reasoning.

The application is built using Flutter and leverages the **Cactus Compute SDK** to run large language models (LLMs) and vision-language models (VLMs) natively on Android and iOS devices (tested on Samsung Galaxy S25 Ultra).

**Demo Video:** [Watch the full demo](https://drive.google.com/file/d/1ey509i5iY_9QusfV_uCb4hoAjXew865a/view?usp=drive_link)

---

## 2. Core Architecture: The Hybrid Routing System

TacitNode employs a sophisticated **Dual-Model Architecture** with intelligent routing to balance performance, cost, and capability:

### The Three-Tier System

1. **Tier 1: The Routing Model (`functiongemma-270m`)**
   * **Role:** Acts as the "brain" and orchestrator. A text-only model optimized specifically for function calling.
   * **Performance:** ~168 tok/s, ~45ms latency
   * **Behavior:** Analyzes user queries and makes routing decisions via tool calls:
     * `validate_routine_step` → Triggers local vision model for component identification
     * `escalate_to_expert` → Routes to cloud for complex diagnostics
     * `answer_query` → Provides direct responses for simple questions

2. **Tier 2: The Vision Model (`lfm2-vl-450m`)**
   * **Role:** Acts as the "eyes". A lightweight (450M parameter) vision-language model by Liquid AI.
   * **Performance:** ~12-15 tok/s for vision inference
   * **Behavior:** Triggered only when routing model calls `validate_routine_step` with `component_name: "unknown"`. Analyzes camera frames and returns component identification.

3. **Tier 3: The Cloud Fallback (Gemini 2.5 Flash API)**
   * **Role:** Acts as the "expert consultant".
   * **Performance:** ~1.2s latency, ~$0.0000875 per query
   * **Behavior:** Triggered via `escalate_to_expert` tool or as automatic fallback when local models fail.

### The Pipeline Flow (Happy Path)

1. **User:** *"What do you see?"* (points camera at an LED)
2. **App:** Captures photo and saves to temporary file path
3. **Routing Model:** Recognizes identification request, outputs `validate_routine_step({"component_name": "unknown"})`
4. **Copilot Service:** Intercepts `"unknown"` placeholder, hands image file path to Vision Model
5. **Vision Model:** Analyzes image, returns: `"LED. A red light-emitting diode."`
6. **App:** Displays result with green "LOCAL INFERENCE" badge, showing 45ms latency and 168 tok/s
7. **Metrics Service:** Records query, updates cost savings calculation

### Intelligent Routing Logic

The routing decision is made based on:
- **Query intent analysis** by FunctionGemma
- **Keyword detection** for visual queries ("what", "identify", "see")
- **Automatic fallback** if local inference fails
- **Offline detection** forces local-only mode

---

## 3. Codebase Structure

### Core Services

* **`lib/services/copilot_service.dart`** (870+ lines)
  * The core orchestrator managing both Cactus SDK model instances
  * Implements the 1-turn architecture with tool interception
  * Handles model lifecycle, tool definitions, system prompts
  * Contains fallback logic and error recovery mechanisms

* **`lib/services/cloud_service.dart`**
  * Gemini 2.5 Flash API integration with retry logic
  * Handles rate limiting (HTTP 429) with exponential backoff
  * Supports both image+text and text-only escalations
  * Concise prompt engineering for 2-3 sentence responses

* **`lib/services/camera_service.dart`**
  * Device camera lifecycle management
  * Dual capture: file paths (for local VLMs) and Base64 (for cloud APIs)
  * Frame caching and cleanup

* **`lib/services/metrics_service.dart`**
  * Session-wide statistics tracking
  * Cost calculation (Gemini 2.5 Flash pricing: $0.125/$0.50 per 1M tokens)
  * Real-time savings computation
  * Detailed logging for debugging

* **`lib/services/connectivity_service.dart`**
  * Network status monitoring via `connectivity_plus`
  * Offline mode simulation for demos
  * Stream-based connectivity updates

### UI Components

* **`lib/screens/copilot_screen.dart`**
  * Full-screen camera preview with glassmorphism overlays
  * Orchestrates all UI widgets and state management
  * Handles query processing and response display
  * Manages FAB positioning relative to debug console

* **`lib/widgets/routing_indicator.dart`**
  * Animated pulse indicators (green for local, amber for cloud)
  * Smooth transitions between routing states
  * Visual feedback during inference

* **`lib/widgets/metrics_overlay.dart`**
  * Session statistics dashboard
  * Cost comparison (cloud-only vs hybrid)
  * Displays with 5 decimal precision for accuracy
  * Collapsible card with glassmorphism

* **`lib/widgets/demo_controls_fab.dart`**
  * Expandable FAB with staggered animations
  * Three demo presets: Quick ID, Diagnose, Offline Test
  * Metrics toggle and reset controls
  * Smooth expand/collapse with rotation animation

* **`lib/widgets/debug_console.dart`**
  * Enhanced JSON viewer with syntax highlighting
  * Collapsible entries (120px collapsed, 336px expanded)
  * Filter chips (All, Routing, Warnings, Errors)
  * Full observability of routing decisions

* **`lib/widgets/offline_banner.dart`**
  * Displays when offline or simulating offline mode
  * Tap-to-disable for simulated offline mode
  * Clear visual indicator of network status

### Data Models

* **`lib/models/routing_decision.dart`**
  * Enhanced with performance metrics (latency, TPS, cost)
  * Routing path tracking
  * Offline query detection
  * Formatted display helpers

* **`lib/models/session_metrics.dart`**
  * Cumulative statistics (local/cloud/offline query counts)
  * Cost calculations with Gemini 2.5 Flash pricing
  * Average latency tracking
  * Savings percentage computation

* **`lib/models/demo_preset.dart`**
  * Predefined demo scenarios
  * Query templates with offline simulation flags
  * Color-coded for visual distinction

---

## 4. Development History: Challenges & Solutions

### Phase 1: Model Selection & Tool Calling

#### Challenge 1.1: Unreliable Tool Calling (Malformed JSON)
* **Problem:** Initial use of `qwen3-0.6` produced inconsistent JSON, wrapping tool calls in conversational text
* **Solution:** Switched to `functiongemma-270m` (FunctionGemma), a model fine-tuned specifically for tool calling
* **Result:** Immediate elimination of JSON parsing errors

#### Challenge 1.2: Wrong Model Name
* **Problem:** Used `gemma3-270m` which doesn't exist in Cactus registry
* **Solution:** Corrected to `functiongemma-270m` (the official Cactus slug)
* **Result:** Model loaded successfully

### Phase 2: Vision Pipeline Architecture

#### Challenge 2.1: The "Blind" Routing Model
* **Problem:** Passed images to FunctionGemma (text-only model), causing inference failures
* **Solution:** Split pipeline - FunctionGemma processes only text, vision model gets images separately
* **Result:** Stable routing decisions, no more crashes

#### Challenge 2.2: FunctionGemma Hallucinating Components
* **Problem:** Model guessed component names without seeing images
* **Solution:** 
  * Made tool arguments `required: true`
  * Added explicit instruction: *"If asked to identify, set component_name to 'unknown'"*
  * Implemented interception logic for `"unknown"` placeholder
* **Result:** Reliable vision model triggering

#### Challenge 2.3: Context Leakage (Chat History Hallucinations)
* **Problem:** Model reused previous answers instead of analyzing new images
* **Solution:** Added `_lm.reset()` at start of each `processQuery()` call
* **Result:** Every query treated as fresh interaction

#### Challenge 2.4: Vision Model Hallucinations
* **Problem:** `lfm2-vl-450m` produced overly specific, incorrect identifications
* **Solution:** 
  * Narrowed prompt to: *"What electronic component, PCB, or circuit board is this?"*
  * Added sanitization to remove model tokens (`<|im_end|>`, `<|im_start|>`)
* **Result:** Accurate, domain-specific identifications

### Phase 3: Cloud Integration

#### Challenge 3.1: Gemini API 404 Errors
* **Problem:** Used wrong API version (`v1beta`) and model name
* **Solution:** 
  * Changed to `v1` API endpoint
  * Updated model from `gemini-2.0-flash` to `gemini-2.5-flash`
  * Verified available models via API
* **Result:** Successful cloud escalations

#### Challenge 3.2: Verbose Cloud Responses
* **Problem:** Gemini returned lengthy responses that got truncated in UI
* **Solution:**
  * Updated prompt: *"Provide CONCISE, actionable diagnosis in 2-3 sentences max"*
  * Reduced `maxOutputTokens` from 1024 to 300
* **Result:** Concise, actionable responses that fit in UI

#### Challenge 3.3: Rate Limiting (HTTP 429)
* **Problem:** Rapid queries hit Gemini API rate limits
* **Solution:** Implemented exponential backoff with retry delay parsing from error response
* **Result:** Graceful handling of rate limits

### Phase 4: Demo-Ready Features

#### Challenge 4.1: Cost Display Bug
* **Problem:** Metrics showed `${estimatedCost!.toStringAsFixed(4)}` literally
* **Solution:** Fixed string interpolation: `'\$${estimatedCost!.toStringAsFixed(4)}'`
* **Result:** Correct cost display

#### Challenge 4.2: Cost Precision Issues
* **Problem:** 4 decimal places caused rounding errors ($0.00035 showed as $0.0003)
* **Solution:** Increased precision to 5 decimal places in metrics overlay
* **Result:** Accurate cost display matching logs

#### Challenge 4.3: FAB Overlapping Send Button
* **Problem:** Demo controls FAB covered input when debug console expanded
* **Solution:**
  * Positioned FAB relative to console height using `AnimatedPositioned`
  * Calculated: `bottom = (consoleHeight) + inputBarHeight + margin`
  * Collapsed: 136px + 80px + 20px = 236px
  * Expanded: 336px + 80px + 20px = 436px
* **Result:** Smooth animation, no overlap

#### Challenge 4.4: Debug Console Corner Gaps
* **Problem:** Rounded corners showed camera background through gaps
* **Solution:**
  * Moved console up 16px using `Transform.translate`
  * Increased console heights by 16px to reach screen bottom
  * Extended input bar bottom padding to 24px
* **Result:** Seamless visual integration

#### Challenge 4.5: Metrics Overlay Visibility
* **Problem:** Metrics card partially visible when closed
* **Solution:** Adjusted hidden position to `top: -400, right: -300`
* **Result:** Completely off-screen when closed

#### Challenge 4.6: FAB and Metrics Mutual Exclusivity
* **Problem:** Both FAB menu and metrics could be open simultaneously
* **Solution:**
  * Added state tracking for FAB expansion
  * Implemented mutual exclusion logic
  * Each closes the other when opened
* **Result:** Clean, focused UI

### Phase 5: Offline Capabilities

#### Challenge 5.1: Offline Mode Toggle
* **Problem:** No way to exit simulated offline mode
* **Solution:**
  * Made offline banner tappable
  * Added "Tap to disable" hint
  * Calls `toggleOfflineSimulation()` on tap
* **Result:** Easy offline mode control

#### Challenge 5.2: Offline Query Tracking
* **Problem:** Offline queries not distinguished in metrics
* **Solution:** Added `offlineQueries` counter to session metrics
* **Result:** Accurate offline usage tracking

### Phase 6: App Branding

#### Challenge 6.1: Low-Resolution Splash Screens
* **Problem:** 640x640 source image produced compressed splash screens
* **Solution:**
  * Upscaled to 2048x2048 using `sips`
  * Added 20% padding (2560x2560 canvas) for better composition
  * Regenerated all density variants
* **Result:** Crisp, high-quality splash screens

#### Challenge 6.2: Adaptive Icon Foregrounds
* **Problem:** Old placeholder icons still in use
* **Solution:**
  * Updated `flutter_launcher_icons` config with adaptive icon settings
  * Set background color to `#0F0F23`
  * Regenerated all icon densities
* **Result:** Consistent branding across all platforms

---

## 5. Key Technical Decisions

### 1-Turn Architecture vs Agent Loops
**Decision:** Use 1-turn tool interception instead of multi-turn agent loops

**Rationale:**
- Small models struggle with state management across turns
- Interception is instant (no second LLM call needed)
- Eliminates hallucination from accumulated context
- 26x faster than cloud, 10x faster than multi-turn

### Explicit Model Reset
**Decision:** Call `_lm.reset()` before every query

**Rationale:**
- Prevents context leakage between queries
- Ensures consistent routing behavior
- Treats each query as isolated interaction
- Eliminates "memory" hallucinations

### Dual Capture Strategy
**Decision:** Capture frames as both file paths and Base64

**Rationale:**
- Local VLMs require file paths (Cactus SDK limitation)
- Cloud APIs require Base64 encoding
- Minimal overhead, maximum flexibility

### Metrics Logging Strategy
**Decision:** Use `TLog.info()` for metrics instead of `print()`

**Rationale:**
- Consistent with app's logging framework
- Appears in same stream as other logs
- Easier to filter and debug
- Production-ready approach

---

## 6. Performance Characteristics

### Local Inference
- **Routing latency:** ~45ms
- **Vision inference:** ~80-120ms (12-15 tok/s)
- **Total time:** ~165ms for complete identification
- **Cost:** $0.00
- **RAM usage:** ~245 MB
- **Offline capable:** ✅ Yes

### Cloud Escalation
- **Network latency:** ~1,200ms
- **Cost:** ~$0.0000875 per query
- **Offline capable:** ❌ No
- **Response quality:** Higher for complex diagnostics

### Hybrid System
- **Cost savings:** 50% (with 50/50 local/cloud split)
- **Average latency:** ~682ms (50/50 split)
- **Typical usage:** 67% local, 33% cloud
- **Actual savings:** 3x cost reduction vs pure cloud

---

## 7. Future Optimizations

### Short-term (Post-Hackathon)
1. **Multi-turn conversations:** Add chat history for follow-up questions
2. **Hands-free operation:** Implement TTS/STT for voice control
3. **Enhanced error recovery:** More sophisticated fallback strategies
4. **Model caching:** Reduce cold-start time

### Medium-term
1. **Additional models:** Test Qwen 1.5B, DeepSeek-R1-Distill
2. **Grammar constraints:** JSON-schema enforcement at C++ level
3. **Streaming responses:** Real-time token display
4. **Batch processing:** Multiple component identification

### Long-term
1. **Fine-tuned routing model:** Domain-specific FunctionGemma
2. **Federated learning:** Improve models from field usage
3. **Multi-modal fusion:** Combine vision, thermal, audio sensors
4. **Edge deployment:** Optimize for lower-end devices

---

## 8. Lessons Learned

### What Worked Well
- **FunctionGemma:** Reliable tool calling with proper prompting
- **1-turn architecture:** Fast, predictable, easy to debug
- **Explicit resets:** Eliminated context leakage issues
- **Dual-model split:** Clear separation of concerns
- **Demo presets:** Made demos reliable and repeatable

### What Was Challenging
- **Small model constraints:** Required strict prompting and domain grounding
- **C++ engine quirks:** Incomplete history clearing, occasional crashes
- **Mobile memory limits:** Careful model selection required
- **API versioning:** Gemini API changes required adaptation
- **UI polish:** Many iterations to get animations smooth

### Key Takeaways
1. **Small models need boundaries:** Explicit instructions > implicit reasoning
2. **Reset is critical:** Don't trust SDK to clear state completely
3. **Interception > Loops:** For small models, simpler is faster
4. **Domain grounding:** Narrow prompts produce better results
5. **Fallbacks are essential:** Always have a backup plan

---

## 9. Hackathon Submission Notes

### What Makes This Special
- **Real-world problem:** Addresses actual industrial training gap
- **Hybrid architecture:** Demonstrates intelligent routing
- **Production-ready:** Robust error handling, offline support
- **Demo-optimized:** One-tap presets, visual feedback, metrics
- **Technical depth:** Full observability, detailed logging

### Technical Highlights
- 3x cost savings vs pure cloud
- 26x faster for local queries
- 100% offline capable for routine tasks
- Real-time performance metrics
- Intelligent routing with automatic fallback

### Demo Flow
1. Show local inference speed (Quick ID preset)
2. Demonstrate cloud escalation (Diagnose preset)
3. Prove offline capability (Offline Test preset)
4. Display metrics dashboard (cost savings)
5. Show debug console (technical depth)

---

## 10. References

- [Cactus Compute SDK Documentation](https://cactuscompute.com/docs)
- [FunctionGemma Model Card](https://huggingface.co/google/functiongemma-270m)
- [Gemini API Documentation](https://ai.google.dev/gemini-api/docs)
- [Flutter Camera Plugin](https://pub.dev/packages/camera)
- [Connectivity Plus](https://pub.dev/packages/connectivity_plus)

---

**Built for the Google DeepMind x Cactus Compute Hackathon**  
Demonstrating the future of hybrid edge-to-cloud AI systems.
