# 🗣️ Unmute – Your Voice, Your Power

## 🚀 Inspiration

Many people with disabilities — especially those with visual impairments — face daily challenges that limit their independence and leave them feeling disconnected from their communities. We were inspired to build **Unmute** to give them a powerful way to be heard, stay connected, and take control of their day-to-day lives using nothing but their voice.

---

## 💡 What It Does

**Unmute** is a voice-powered assistant designed for accessibility. It allows users to:

- 🗓️ Add tasks and set reminders using speech only
- 🔊 Get audio feedback and prompts via text-to-speech
- 📞 Call loved ones like mom, dad, or a doctor by simply saying their name
- 🚨 Instantly call for help in emergencies with voice triggers
- 👂 Interact fully hands-free — no screen needed

---

## 🛠️ How We Built It

We used **Flutter** for cross-platform development and integrated:

- `speech_to_text` for speech recognition  
- `flutter_tts` for natural audio responses  
- `contacts_service` for contact access and calling (with fallback logic)  
- Custom logic to handle misheard words (e.g., “tenty to” ➝ “22”)  
- AI-inspired parser to extract valid date/time from vague inputs  
- Smart phrase triggers like `"call help"` or `"call mom"`  

---

## 🧱 Challenges We Ran Into

- Handling inaccurate speech recognition (especially with accents or noise)
- Parsing natural language into dates reliably
- Android permissions and plugin compatibility (`contacts_service` namespace issues)
- Creating a truly voice-first, screen-free UX that still felt smooth and responsive

---

## 🏆 Accomplishments We're Proud Of

- ✅ Fully functional voice assistant built in under 48 hours
- ✅ Core features accessible with **zero visual interaction**
- ✅ Intelligent fallback logic to ensure no command “fails”
- ✅ Created something that can truly improve lives

---

## 📚 What We Learned

- How to build robust voice-based apps with Flutter
- The importance of **accessibility-first** design
- Building fallback experiences that always support the user
- Rapid development under pressure and prioritizing key features

---

## 🔮 What’s Next for Unmute
Collaborate with the OS to enable continuous background listening, allowing the AI to remain always attentive and ready to assist users at any time.

Implement an enhanced and accessible design to provide a more intuitive experience tailored to users with various disabilities.

Enable direct calling and messaging immediately after speech commands (pending appropriate OS permissions), ensuring faster and more reliable communication.

Expand support beyond visual and motor impairments: While Unmute is currently focused on aiding blind users and individuals with hand movement limitations (e.g., reduced fingers, Parkinson’s disease), we aim to broaden its functionality to support a wider range of disabilities — including cognitive and auditory challenges
---

## what make us diferant from the other compititor 
Our only real competitor is Siri, which is exclusive to iPhones and designed for general-purpose use. With Unmute, we aim to build an inclusive alternative — one that is tailored specifically to the needs of people with disabilities, offering deeper accessibility and broader availability across platforms.

> 🎤 *Unmute is more than an app. It’s a chance for every voice to be heard — clearly, simply, and powerfully.*

