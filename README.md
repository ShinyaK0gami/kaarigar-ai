# 🚀 Kaarigar AI (Antigravity Service Orchestrator)

**Kaarigar AI** is an intelligent, agentic mobile application built to orchestrate the informal service economy in Pakistan (starting with Karachi). Instead of browsing complex menus or lists, users simply chat with the AI in English, Urdu, or Roman Urdu (e.g., *"Mujhe aaj shaam Gulshan-e-Iqbal mein ek AC wala chahiye"*). The AI parses the intent, finds the best local professionals, calculates dynamic price quotes, and manages the entire booking lifecycle.

---

## 🧠 Technical Architecture & "The Antigravity Engine"

At the core of Kaarigar AI sits the **Antigravity Service Orchestrator**. This is a custom agentic layer that handles unstructured human inputs, maintains conversational context, and executes complex business logic.

### 1. Multilingual Intent Extraction
Powered by Google's Gemini Generative AI (`gemini-2.5-flash`), the orchestrator processes user inputs in real-time. It uses a highly specialized prompt structure to understand Roman Urdu colloquialisms. For example, it maps raw terms like *"bijli wala"* to "Electrician", and contextual temporal phrases like *"aaj raat"* to standard dates and times. 

### 2. Smart Location Resolution (3-Tier Failsafe)
Given the unstructured nature of Karachi neighborhood names, the app features a robust location resolution system:
* **Tier 1:** Attempts an exact or substring match against an offline local database of known Karachi sectors.
* **Tier 2:** Consults the LLM to contextually map variations or landmarks to the closest valid sector.
* **Tier 3 (Offline Fallback):** If the API fails, a strict offline regex and fuzzy-matching engine takes over to ensure zero downtime.

### 3. Active Memory State Machine
The app features a custom state machine built inside the `dashboard_screen.dart` to manage the conversational flow. It holds context in its `_activeMemory` dictionary. If a user rejects a suggested professional, the system instantly recalls the user's location, required service, and time, instantly suggesting the next best match without requiring the user to type out their details again.

### 4. Smart Matching Algorithm & ETAs
The engine dynamically matches users with mocked verified professionals stored in Firebase Firestore. It calculates logical Estimated Time of Arrivals (ETAs) and price quotes based on the user's location, the requested time block, and the worker's simulated current distance. 

### 5. Strict Failsafe Validations
To secure a booking, the Orchestrator strictly validates data formats natively before finalizing transactions. For example, it intercepts user messages to extract and strictly validate Pakistani mobile numbers (`03...`, `+92...`) using localized Regex patterns.

---

## 🛠️ Tech Stack & File Structure

- **Frontend Environment**: Flutter (Cross-platform for Android, iOS, and Web).
- **Conversational UI (`lib/ui/dashboard_screen.dart`)**: A seamless, terminal-like chat interface that handles the active state machine and direct user validations.
- **AI Brain (`lib/services/antigravity_engine.dart`)**: Connects to the Gemini API and manages the intent orchestration.
- **Backend & Database (`lib/services/firebase_service.dart`)**: Firebase Firestore for real-time syncing of booking data and worker profiles.
- **Authentication**: Firebase Auth (Allows seamless Anonymous Guest sessions natively, or full Google Sign-In support).

