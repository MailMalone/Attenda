<p align="center">
  <img src="assets/readme.png" width="120" alt="Attenda Logo" />
</p>

<h1 align="center">Attenda</h1>

<p align="center">
  <strong>A privacy-first student portal companion for tracking attendance, marks, timetables, and study notes.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/License-Educational-blue" alt="License" />
</p>

---

## 🧐 What is Attenda?

Attenda is a **mobile app** that scrapes your university student portal **locally on your device** — your credentials never leave your phone. It gives you a clean, modern dashboard to monitor attendance, internal marks, class schedules, and even download study notes — all without relying on a third-party server.

> **Privacy guarantee:** All portal scraping happens on-device. No backend. No data collection. Your credentials are stored locally in shared preferences and are never transmitted to any server other than your university's own portal.

---

## ✨ Features

### 📊 Attendance Tracker
- Live attendance percentages scraped directly from the student portal.
- Color-coded progress bars — green (≥85%), orange (75–84%), violet (<75%).
- Per-subject bunk headroom: see exactly how many classes you can safely skip.
- "At Risk" summary banner with witty messages.

### 📝 IA Marks
- Internal Assessment marks displayed in clean, expandable subject cards.
- Score-based color coding: green for high scores, violet for danger zone.
- First-time setup wizard to configure CBT subjects.

### 📅 Timetable
- **Auto-load** your timetable from a centralized GitHub repository by entering your semester and section.
- Manual timetable editing with subject code, alias, and period type (Theory / Practical / SL).
- **Live progress indicators** — highlights your current and upcoming class.
- Supports free periods, self-learning (SL) slots, and practical labs.

### 🧮 Bunk Calculator
- **By Day mode:** Select one or more weekdays and instantly see the attendance impact of bunking the entire day.
- **By Subject mode:** Enter a number of classes to skip for any subject and get a detailed recovery plan.
- SL (Self-Learning) period scenario analysis — shows best-case and worst-case attendance impact.
- Before/after percentage comparison with visual progress bars.

### 📚 Study Hub
- Cloud-hosted PDF notes fetched from a GitHub repository via a JSON manifest (`notes_index.json`).
- Automatic subject matching — maps your enrolled subjects to available notes.
- Download notes for offline access with a configurable save directory.
- Open downloaded PDFs directly with your device's default viewer.

---

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── theme.dart                   # VergeTheme design system (dark mode, typography)
├── api_service.dart             # Student portal scraper (login, attendance, IA marks)
├── cache_service.dart           # Local data caching via SharedPreferences
├── cloud_storage_service.dart   # GitHub-based notes manifest fetching
├── local_storage_service.dart   # File download & offline storage management
├── timetable_service.dart       # Timetable persistence (local JSON)
├── timetable_loader_service.dart# Remote timetable fetching & parsing
├── subject_alias_service.dart   # Subject display name mapping
├── models/
│   └── student_data.dart        # StudentData model (name, attendance, IA marks)
├── screens/
│   ├── login_screen.dart        # Login with auto-login & credential caching
│   ├── dashboard_screen.dart    # Main shell with bottom navigation (5 tabs)
│   ├── attendance_tab.dart      # Attendance overview
│   ├── ia_marks_tab.dart        # Internal marks with CBT toggle
│   ├── timetable_tab.dart       # Timetable viewer & editor
│   ├── bunk_tab.dart            # Bunk calculator (day & subject modes)
│   └── study_tab.dart           # Cloud study notes browser
└── widgets/
    └── scrolling_text.dart      # Marquee-style text widget
```

### Data Flow

```
┌─────────────────┐     HTTPS (on-device)      ┌──────────────────┐
│  Student Portal │ ◄────────────────────────  │   ApiService     │
│  (University)   │                            │   (scraper)      │
└─────────────────┘                            └────────┬─────────┘
                                                        │
                                                        ▼
                                               ┌──────────────────┐
                                               │  CacheService    │
                                               │  (local storage) │
                                               └────────┬─────────┘
                                                        │
                                                        ▼
                                               ┌──────────────────┐
                                               │  Dashboard UI    │
                                               │  (5 tabs)        │
                                               └──────────────────┘

┌─────────────────┐     raw.githubusercontent  ┌──────────────────┐
│  GitHub Repo    │ ◄───────────────────────── │ CloudStorageServ │
│  (Notes + TT)   │                            │ TimetableLoader  │
└─────────────────┘                            └──────────────────┘
```

---


## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) `≥ 3.11.0`
- Android SDK with min API level 21
- A valid student portal account (University Solutions portal)

### Setup

```bash
# Clone the repository
git clone https://github.com/MailMalone/Attenda.git
cd Attenda

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Build APK

```bash
flutter build apk --release
```

The built APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📦 Key Dependencies

| Package               | Purpose                              |
|------------------------|--------------------------------------|
| `http`                | Network requests (portal scraping)   |
| `html`                | HTML parsing (IA marks table)        |
| `shared_preferences`  | Local credential & preference storage|
| `path_provider`       | File system paths                    |
| `open_filex`          | Open PDFs with system viewer         |
| `google_fonts`        | Oswald, Space Grotesk, Space Mono    |
| `animations`          | Shared axis transitions (Study tab)  |
| `permission_handler`  | Storage permission management        |

---

## 🔒 Privacy & Security

- **Zero server architecture** — no backend, no analytics, no telemetry.
- Portal credentials are stored **only** in the device's local SharedPreferences.
- All HTTP requests go directly from your device to the university portal — no proxy, no middleman.
- Study notes are fetched from public GitHub raw URLs (no API key required).

---

## 📄 License

This project is for **educational and personal use** only. All university portal scraping logic is designed exclusively for private use by students accessing their own academic data.
