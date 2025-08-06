# **FoodLens**

**Scan food labels. Get personalized safety insights. All on-device.**

> **Personalized food safety powered by on-device AI.**
---


## Important Links

- [Youtube](https://youtu.be/z1hHl7igdvk)
- [Kaggle](https://www.kaggle.com/competitions/google-gemma-3n-hackathon/writeups/food-len-ios-app)



## Overview

**FoodLens** is an iOS app that helps users instantly analyze food ingredients for compatibility with their allergies, health conditions, and dietary preferences. It uses **Vision-based OCR** to extract text from food packaging, and runs **Gemma-based LLMs locally** (via [MLX](https://github.com/ml-explore/mlx)) to provide intelligent food safety recommendations — completely offline and privacy-first.

---

## Features

* Capture photos of food ingredient labels
* On-device OCR using Apple Vision
* Run quantized LLMs (Gemma 3-1B / 3n) entirely offline
* Automatically tailor model options based on device RAM
* Cancel inference when app moves to background to avoid crashes
* Customizable dietary profile (allergies, conditions, preferences)
* Streamed, real-time LLM response formatted for clarity

---

## Architecture

```
[User] → [Camera Input] → [OCR via Vision] → [Text + Profile] 
      → [Prompt Generation] → [On-device LLM via MLX] 
      → [Streamed Result] → [AI Response UI]
```

* **OCR**: Apple Vision (`VNRecognizeTextRequest`)
* **LLM**: MLX-compatible, 4-bit quantized Gemma models
* **Model Selection**: RAM-aware filtering (e.g., Gemma 3n shown only on 7GB+ devices)
* **Inference Safety**: Graceful cancellation when app goes to background
* **UI**: SwiftUI with modular components for camera, text, response, settings

---

## 🛠️ Model Management

FoodLens supports multiple model options, such as:

| Model                     | Device RAM Size Required | Size     |
| ------------------------- | ------------ | -------- |
| `gemma-3-1b-it-qat-4bit`  | 2GB+         | \~0.75GB |
| `gemma-3n-E2B-it-lm-4bit` | 8GB+         | \~2.5GB  |

Only compatible models are shown on devices, based on:

```swift
static func getDeviceRAMInGB() -> Int {
    let ramBytes = ProcessInfo.processInfo.physicalMemory
    return Int(ramBytes / (1024 * 1024 * 1024))
}
```

Models are downloaded using MLX APIs, cached locally, and only loaded into memory when needed. Metal-based inference is isolated per session to avoid stale encoder reuse.

---

## 💡 Prompt Format

```text
You are FoodLens AI, a dietary safety assistant. Analyze the ingredients below based on the user's dietary profile.

USER DIETARY PROFILE:
[Allergies, Diet Types, Health Conditions...]

DETECTED INGREDIENTS:
[Sugar, Milk, Gluten...]

Return your answer in the following format:

🔍 SAFETY VERDICT: [SAFE ✅ / CAUTION ⚠️ / NOT SAFE ❌]

Reasons:
- ...
```

---

## LLM Execution & Inference Safety

FoodLens wraps MLX inference in a `SafeInferenceWrapper` that:

* Detects app backgrounding
* Cancels inference when unsafe
* Forces model unload/reload to avoid stale Metal encoders

This prevents crashes and memory leaks common in GPU-backed model execution.

---

## Example Workflow

1. Launch the app and configure your dietary profile (allergies, preferences).
2. In first time of launch, open the ModelSettingView tapping the gear button at top right corner
3. After downlaoded complete tap the green 'load the model' button.
4. Snap one or more photos of ingredient lists using the built-in camera.
5. The app extracts text and streams it to the selected LLM.
6. You get a personalized food safety verdict with explanations.
