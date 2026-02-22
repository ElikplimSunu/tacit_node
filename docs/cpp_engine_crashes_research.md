# Llama.cpp Mobile Engine Crashes (0 Tokens / Success=False)

## 1. What is the KV Cache and why does it crash the engine?

When an LLM generates text, it uses an optimization called the **Key-Value (KV) Cache**. Instead of recalculating the entire mathematical state of the prompt for every single new word it generates, it stores the calculated states of *previous* words in RAM.

* As the conversation gets longer (or if the chat history isn't completely wiped from RAM), the KV Cache grows linearly.
* Mobile devices have unified, highly constrained RAM (usually 6GB-12GB total, but the OS limits a single app to much less).
* When the KV Cache tries to allocate memory beyond what Android allows, the OS memory manager violently kills the thread, resulting in a `success=false, 0 tokens` silent crash.

## 2. Is it the Context Window?

**Yes.** The Context Window dictates the *theoretical maximum size* of the KV Cache.
If the `Cactus` SDK defaults the `gemma3-270m` context window to 4096 or 8192 tokens, the C++ engine might try to pre-allocate massive memory buffers for the KV cache the moment inference starts. If the Android GPU/CPU can't provide a contiguous block of memory that large, it instantly fails to generate token 1.

Furthermore, even though we call `_lm.reset()`, the underlying C++ wrapper might be suffering from **memory fragmentation** or failing to aggressively garbage collect the old KV cache before allocating the new one upon rapid successive tests.

## 3. Do we need to store to a DB or apply caching?

* **Database (SQLite/Drift):** Storing chat history to a database is great for long-term user experience, but it **will not fix the crash**. In fact, if you retrieve long chat history from a database and continually feed it into the LLM's prompt, the engine will crash *faster* because you are intentionally inflating the KV Cache.
* **Semantic Response Caching:** *This* would help. If the user asks *"What do you see?"* 5 times in a row, we could cache the fact that *"What do you see?"* equates to `validate_routine_step` and skip the `gemma` model entirely for exact-match questions, avoiding the C++ engine invocation completely.

## 4. How to perfectly fix the crashes

Based on web research into `llama.cpp` mobile optimization, here is the perfect fix strategy for TacitNode:

### A. Drastically Constrain the Context Window

Since FunctionGemma is *only* making routing decisions based on a single sentence and a highly optimized system prompt, it doesn't need a 4000+ token context window. We should limit it to exactly what it needs.

* **Fix Action:** When initializing `Cactus`, explicitly pass a small `contextSize` parameter (e.g., `512` or `1024` max). This physically prevents the C++ engine from pre-allocating massive RAM buffers.

### B. Enable KV Cache Quantization (if supported)

To save RAM, advanced engines allow you to convert the KV cache from 32-bit floating point numbers to 8-bit or 4-bit integers.

* **Fix Action:** Check the `Cactus` initialization parameters for flags like `useKVCacheQuantization: true` or specific `ggmlVulkan` optimization flags.

### C. Throttle the GPU/Vulkan Threads

Mobile GPUs share memory bandwidth with the CPU. Prompt processing is heavily memory-bandwidth bound. If the engine tries to parallelize too many threads on a mobile GPU during prompt evaluation, it crashes.

* **Fix Action:** Decrease the `threads` count or limit the `batchSize` during the `CactusLM` initialization.

### D. The Ultimate "Small-Model Agent" Strategy: Pure Statelessness

The best way to handle small models on mobile is **Statelessness**.
Right now, you are passing chat messages via a `List`. The engine sees `System Prompt -> User Message`. To ensure absolutely zero memory drift, we should completely ignore chat history for the routing model. The routing model should *only* ever see the current system prompt and the current single user query. If the user needs conversation history, only pass the very last interaction, never the whole chat log.
