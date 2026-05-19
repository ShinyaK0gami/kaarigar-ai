# 🚀 Kaarigar AI (Antigravity Service Orchestrator)

**Kaarigar AI** is an intelligent, agentic mobile application built to orchestrate the informal service economy in Pakistan (starting with Karachi). Instead of browsing complex menus or lists, users simply chat with the AI in English, Urdu, or Roman Urdu (e.g., *"Mujhe aaj shaam Gulshan-e-Iqbal mein ek AC wala chahiye"*). The AI parses the intent, finds the best local professionals, calculates dynamic price quotes, and manages the entire booking lifecycle.

---

## 🏗️ Overall Design of the Solution

Kaarigar AI is designed as a **Service Orchestrator**, acting as intelligent middleware between informal workers and users seeking services. Instead of a traditional form-based or directory UI, the solution is built entirely around a conversational interface. The user provides unstructured text; the system intelligently extracts the structured data needed (service type, location, schedule) using an LLM, matches it against a dataset of available workers, and facilitates a seamless booking transaction entirely via chat.

## 📐 Brief Overview of Architecture

The architecture follows a Client-Serverless paradigm:
1. **Presentation Layer (Flutter):** A cross-platform mobile frontend handling the aesthetic chat interface, local user input validations (e.g., strict Pakistani phone number enforcement), and active state memory management.
2. **Agentic Orchestration Layer (Dart/Gemini):** A custom, on-device intelligence layer (`antigravity_engine.dart`) that constructs complex prompts, invokes the LLM, parses JSON outputs, and applies offline fallback matching for geographic locations.
3. **Data & Persistence Layer (Firebase):** Google Firebase acts as the backend-as-a-service, handling secure user authentication and the NoSQL persistence of booking records and histories.

## 🤖 Agents Developed

### The Antigravity Orchestrator Agent
We developed a primary, multi-faceted agent responsible for managing the complete lifecycle of a booking request. Its key capabilities include:
- **Multilingual Intent Extraction:** Uses a highly specialized prompt to process mixed English, Urdu, and Roman Urdu (e.g., mapping *"bijli wala"* to "Electrician" and understanding temporal context like *"kal subha"*).
- **Smart Location Resolution (3-Tier Failsafe):** 
  - *Tier 1:* Exact/substring match against an offline local database of known Karachi sectors.
  - *Tier 2:* Contextual mapping via the LLM for neighborhood variations or specific landmarks.
  - *Tier 3:* Offline regex and fuzzy-matching engine to ensure zero downtime even if the API fails.
- **Active Memory State Machine:** Maintains conversational context. If a user rejects a suggested professional, the agent recalls the location, required service, and time to instantly suggest the next best match without re-prompting the user.

## 🔌 Mock / Real APIs Used

### Real APIs
- **Google Generative AI API (`gemini-2.5-flash`):** Used extensively as the brain of the agent to parse unstructured text into strict JSON-formatted booking intents.
- **Firebase Authentication API:** Utilized to manage frictionless Anonymous Guest sessions as well as Google OAuth Sign-in.
- **Cloud Firestore API:** Used for the real-time creation and retrieval of user profiles, chat histories, and booking records.

### Mock APIs
- **Mock Worker Generation API:** Since there is no live worker marketplace attached yet, `lib/models/worker.dart` acts as a mocked internal API. It dynamically generates realistic worker profiles on-the-fly (assigning realistic Pakistani names, local Karachi sectors, random ratings, and dynamic price quotes) to simulate a rich marketplace response for the agent to orchestrate.

## 🔗 Integrations Implemented

- **Google Generative AI SDK (`google_generative_ai`):** Deeply integrated into the Dart service layer for direct interaction with the Gemini API natively, eliminating the need for a proxy server.
- **Firebase Core, Auth, & Cloud Firestore:** Seamless integrations for frictionless onboarding and cloud data synchronization.
- **Google Fonts:** Integrated for dynamic, aesthetic typography (`GoogleFonts.inter`, `GoogleFonts.outfit`) matching modern UI/UX standards.

---

## 🛠️ Tech Stack & File Structure

- **Frontend Environment**: Flutter (Cross-platform for Android, iOS, and Web).
- **Conversational UI (`lib/ui/dashboard_screen.dart`)**: A seamless, terminal-like chat interface that handles the active state machine and direct user validations.
- **AI Brain (`lib/services/antigravity_engine.dart`)**: Connects to the Gemini API and manages the intent orchestration.
- **Backend & Database (`lib/services/firebase_service.dart`)**: Firebase Firestore for real-time syncing of booking data and worker profiles.

