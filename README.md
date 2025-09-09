# 📌 Roleplaying Advisor App - Development Checkpoints

A Flutter-based app where users can chat with fictional and non-fictional characters (e.g., Robert Greene, Harry Potter) and receive advice in their unique perspective.  
Powered by **Groq API**, **Firebase Authentication**, **Firebase Storage**, and **Supabase** for character assets.

---

## ✅ Phase 1: Project Setup
- [ ] Create Flutter project (`flutter create roleplay_advisor`).
- [ ] Setup GitHub repo & enable version control.
- [ ] Configure environment files for API keys (`.env` with `flutter_dotenv`).
- [ ] Add required dependencies in `pubspec.yaml`:
  - `firebase_core`, `firebase_auth`, `google_sign_in`
  - `firebase_storage`
  - `supabase_flutter`
  - `http`, `dio`
  - `provider` or `riverpod` (state management)
  - `flutter_dotenv` (env variables)
  - `flutter_hooks` (optional, for cleaner UI state)
- [ ] Initialize Firebase in project (`firebase init` + connect with Android/iOS).
- [ ] Setup Supabase project & link to app.

---

## ✅ Phase 2: Authentication
- [ ] Implement **Google Sign-In** with Firebase.
- [ ] Add **Email/Password authentication** as fallback.
- [ ] Store user profile info in Firestore:
  - UID
  - Display name
  - Email
  - Profile picture
- [ ] Build UI:
  - Login Page
  - Sign-Up Page
  - Forgot Password flow
- [ ] Add **auth guard** to protect character/chat pages.

---

## ✅ Phase 3: Character System
- [ ] Setup Supabase bucket for **character images**.
- [ ] Create `characters` table in Supabase:
  - `id`
  - `name`
  - `category` (fictional, non-fictional, author, historical, etc.)
  - `image_url`
  - `description`
  - `prompt_style` (base prompt for personality)
- [ ] Build UI for:
  - **Character Grid/List**
  - **Search & Filter (fictional/non-fictional, authors, etc.)**
- [ ] Connect Supabase API to fetch character list dynamically.

---

## ✅ Phase 4: Chat System
- [ ] Create Chat UI (similar to WhatsApp/Telegram layout).
- [ ] Integrate **Groq API** for AI character responses.
- [ ] Build **character-specific prompts**:
  - Example: “Answer as Robert Greene, author of The 48 Laws of Power, in a strategic and philosophical tone.”
- [ ] Store conversation history in Firestore:
  - `user_id`
  - `character_id`
  - `messages[]` (role: user/ai, content, timestamp)
- [ ] Enable **real-time updates** for chat messages.
- [ ] Implement **message persistence** (users see past conversations).

---

## ✅ Phase 5: Enhancements
- [ ] Add **Favorites system** (users can pin favorite characters).
- [ ] Allow **multi-character chat** (switch between characters).
- [ ] Add **user profile page** (update name, profile picture).
- [ ] Save **chat summaries** per session (optional, using Groq API summarization).
- [ ] Add **dark mode / light mode toggle**.
- [ ] Push Notifications for:
  - Daily character “advice of the day”.
  - Chat reminders.

---

## ✅ Phase 6: Deployment
- [ ] Setup Firebase Hosting (if using web).
- [ ] Configure iOS & Android builds.
- [ ] Setup **Crashlytics & Analytics**.
- [ ] Test with real users (Beta via Firebase App Distribution).
- [ ] Publish to **Google Play Store** & **Apple App Store**.

---

## ✅ Phase 7: Future Expansion (Optional)
- [ ] Add **voice-based character conversations** (Speech-to-Text + Text-to-Speech).
- [ ] Allow **custom user-created characters** with prompts + images.
- [ ] Add **community marketplace** for character packs.
- [ ] Integrate **subscription model**:
  - Free tier → limited characters & chat length.
  - Premium tier → all characters, unlimited chats, voice mode.
- [ ] Enable **multi-language support**.

---

# 🔑 Key Notes
- **Firebase** → Authentication, user management, chat storage.
- **Supabase** → Character images & metadata storage.
- **Groq API** → Chat responses with character-specific personality prompts.
- **Scalability** → Ensure modular state management (Provider/Riverpod).
- **Security** → Store API keys safely with `.env` + do not hardcode secrets.

---
