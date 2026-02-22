# TacitNode: Technical Documentation

## 1. Project Overview

TacitNode is a field equipment copilot designed to assist technicians with local, on-device AI. Because field technicians often operate in environments with poor or non-existent internet connectivity, the core requirement of TacitNode is to run a **100% local AI pipeline** for routine tasks, resorting to cloud escalation only for complex diagnostics.

The application is built using Flutter and leverages the **Cactus Compute SDK** to run large language models (LLMs) and vision-language models (VLMs) natively on Android and iOS devices (tested specifically on high-end Android hardware like the Samsung Galaxy S25 Ultra).

---

## 2. Core Architecture: The Dual-Model Pipeline

To achieve both reliable tool calling and on-device vision without exceeding mobile memory constraints, TacitNode employs a specialized **Dual-Model Architecture**:

1. **The Routing Model (`gemma3-270m`)**
    * **Role:** Acts as the "brain" and orchestrator. It is a text-only model optimized specifically for function calling (FunctionGemma).
    * **Behavior:** It analyzes the user's text query and makes a routing decision.
        * If the user asks a routine visual question (*"What do you see?"*, *"What is this component?"*), it calls the `validate_routine_step` tool.
        * If the user asks a complex diagnostic question (*"Why is this failing?"*), it calls the `escalate_to_expert` tool.
2. **The Vision Model (`lfm2-vl-450m`)**
    * **Role:** Acts as the "eyes". It is a lightweight (450M parameter) vision-language model developed by Liquid AI.
    * **Behavior:** It is triggered *only* when the Routing Model decides that visual identification is required. It takes the raw file path of the camera frame, analyzes the image, and returns the component name and description.
3. **The Cloud Fallback (Gemini API)**
    * **Role:** Acts as the "Tier 2 Support".
    * **Behavior:** Triggered only via the `escalate_to_expert` tool or if the local models exhaust their capabilities/fail to parse.

### The Pipeline Flow (Happy Path)

1. **User:** *"What do you see?"* (points camera at an LED).
2. **App:** Captures a photo and saves it to a temporary file path.
3. **Routing Model:** Receives the text query. Recognizing it as an identification request, it outputs a JSON tool call for `validate_routine_step`, explicitly passing placeholder arguments (`component_name: "unknown"`).
4. **Copilot Service:** Intercepts the `"unknown"` tool call. Realizing vision is needed, it hands the image file path to the Vision Model.
5. **Vision Model:** Analyzes the image and replies with: `"LED. A red light-emitting diode."`
6. **App:** Patches the Vision Model's answer into the routing decision and presents the result to the user as a 100% local inference.

---

## 3. Codebase Structure

The Flutter project follows a service-oriented architecture:

* **`lib/services/copilot_service.dart`**
  * The core orchestrator. Manages the lifecycle of both Cactus SDK model instances (`_lm` and `_visionLm`).
  * Contains the `processQuery` loop, tool definitions, the system prompt, and the hand-off logic between the text model, the vision model, and the cloud.
* **`lib/services/cloud_service.dart`**
  * Handles HTTP communication with the Gemini API for cloud escalations. Includes robust retry logic.
* **`lib/services/camera_service.dart`**
  * Manages the device camera. Handles capturing frames as both raw file paths (for local VLMs) and Base64-encoded strings (for cloud APIs).
* **`lib/screens/copilot_screen.dart`**
  * The main UI. Displays the live camera feed, chat history, input field, and the component identification overlay.
* **`lib/widgets/model_status_bar.dart`**
  * A bespoke UI widget that provides real-time feedback on model initialization, download progress (handling the sequential download of both models), and inference speeds (tokens/sec).

---

## 4. Development History: Errors Faced & Solutions

Developing a reliable, multi-model AI pipeline on edge devices presented several unique challenges. Here is a chronological breakdown of the major hurdles and how they were solved:

### Challenge 1: Unreliable Tool Calling (Malformed JSON)

* **The Problem:** Initially, the app used `qwen3-0.6` as the local model. Because it is a general-purpose "thinking" model, it struggled to reliably output clean JSON for tool calls, often wrapping them in unwanted conversational text or breaking JSON syntax.
* **The Fix:** We swapped the routing model to `gemma3-270m` (FunctionGemma). Because FunctionGemma is fine-tuned specifically for tool calling, the formatting parsing errors immediately disappeared.

### Challenge 2: The "Blind" Routing Model

* **The Problem:** We originally passed both the text query and the image file to the routing model. However, FunctionGemma is a **text-only** model. When it received image data in its prompt context, it choked, resulting in failed inference and immediate cloud escalation.
* **The Fix:** We split the pipeline. We stripped the image from FunctionGemma's `ChatMessage` entirely. FunctionGemma now operates *only* on the user's text. The image is held in memory and given exclusively to the vision model (`lfm2-vl-450m`) *after* FunctionGemma decides vision is required.

### Challenge 3: FunctionGemma Hallucinating Components

* **The Problem:** Even after splitting the pipeline, FunctionGemma was trying to guess what was in the image. Because the tool schema allowed `component_name` to be optional, the model would either output `"null"` strings, refuse to call the tool entirely, or randomly hallucinate a component (e.g., guessing `"LED"`) just to satisfy the schema without actually seeing the camera feed.
* **The Fix:** Small language models require strict boundaries. We changed the tool schema to make arguments **`required: true`**, but added explicit instructions in both the schema descriptions and the main `_systemPrompt`: *"If asked to identify something, you MUST set the component_name exactly to 'unknown'."*
* We then updated `_handleLocalValidation()` to intercept this specific `"unknown"` String and trigger the vision model. This played perfectly to the text model's strengths—it no longer had to guess; it just followed the rule.

### Challenge 4: Context Leakage (Chat History Hallucinations)

* **The Problem:** After successfully identifying an LED, the user pointed the camera at a circuit board and asked *"What do you see?"*. FunctionGemma instantly shouted *"LED"* again, bypassing the vision model entirely. The Cactus SDK was maintaining conversation history, causing the model to use its short-term memory instead of treating it as a new visual query.
* **The Fix:** We implemented an explicit `_lm.reset()` call at the very beginning of the `processQuery()` loop. This gives the routing model "amnesia" between queries, ensuring every *"What do you see?"* is treated as an isolated, pristine interaction.

### Challenge 5: Small Vision Model Hallucinations (`<|im_end|>`)

* **The Problem:** While the routing was fixed, the `lfm2-vl-450m` vision model struggled with "open-ended" prompts. When asked generically to *"Identify the main component"*, its vast latent space caused it to hallucinate highly specific, incorrect hardware names (e.g., `"Dell XPS 13 Gaming Computer"`, `"Solidity"`, `"Intel Pentium III Processors"`). It also appended raw model tokens like `<|im_end|>` to the UI.
* **The Fix:** Small models require severe domain grounding. We updated the vision model's internal prompt from *"Identify the object"* to strictly: *"What electronic component, PCB, or circuit board is this?"*. This anchored the model to the specific domain of electronic hardware. Additionally, we added a regex/string sanitization step (`.replaceAll('<|im_end|>', '')`) to ensure clean UI presentation.

### Challenge 6: Cloud API Rate Limiting (HTTP 429)

* **The Problem:** When the local app intentionally escalated to the cloud (or during fallback), rapid execution sometimes hit the Gemini API rate limits, resulting in a persistent HTTP 429 error and crashing the flow.
* **The Fix:** Implemented an exponential backoff-and-retry mechanism in `CloudService.dart`. The service now catches HTTP 429s, extracts the specific `retryDelay` required by the Gemini server from the JSON error payload, waits for that exact duration, and silently retries the request (up to 2 times) before surfacing an error to the user.
