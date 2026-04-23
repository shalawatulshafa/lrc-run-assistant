# Flutter Frontend Tutorial (Beginner Friendly)

This tutorial explains how your friend's Flutter frontend works, step by step, in simple language.

Goal: after reading this, you should understand:
- how the app starts
- how users move between screens
- how run data is stored and displayed
- where to edit code when you want to add features

---

## 1) What this project is

This app is a running assistant UI (`LRC Run Assistant`) with this flow:
1. User opens app
2. User logs in
3. User sees dashboard + history tabs
4. User taps `+` to connect to chest strap (simulated)
5. If data exists, user downloads run data
6. Data is saved locally and shown in dashboard/history

Important: many backend/BLE parts are still mock/simulated.

---

## 2) Project structure you should know

Main folders inside `lib/`:

- `main.dart` -> app entry point + route table
- `screen/` -> all UI pages
- `services/` -> API layer templates (real backend not wired yet)
- `models/` -> data model classes
- `helpers/` -> helper logic (example: auto run title)
- `utils/` -> reusable utility widgets/functions (example: Snackbar helper)

Most learning happens in `lib/screen/`.

---

## 3) Dependencies used (`pubspec.yaml`)

Main packages:

- `http` -> for REST API calls (prepared, not yet active in UI)
- `shared_preferences` -> local key-value storage (used heavily)

Also check this asset setup:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/runners_bg.jpg
```

Note: your folder appears as `assets/Images/` (capital `I`) in repository listing. On Windows this often works, but on Linux/macOS/build servers case mismatch can break asset loading. Keep path casing consistent.

---

## 4) App entry point (`lib/main.dart`)

The app starts from:

```dart
void main() {
  runApp(const MyApp());
}
```

`MyApp` returns `MaterialApp` with named routes:

```dart
initialRoute: '/',
routes: {
  '/': (context) => WelcomeScreen(),
  '/login': (context) => LoginScreen(),
  '/main': (context) => MainNavigation(),
  '/settings': (context) => SettingsScreen(),
},
```

Meaning:
- first screen: `WelcomeScreen`
- then app navigates by route names like `/login`, `/main`

---

## 5) Full screen flow walkthrough

## 5.1 Welcome screen (`welcome_screen.dart`)

Shows greeting and two buttons:
- `Login with Email` -> `Navigator.pushReplacementNamed(context, '/login')`
- `Register` -> currently only shows SnackBar "feature coming soon"

`pushReplacementNamed` means old screen is replaced, so back button behavior is cleaner.

## 5.2 Login screen (`login_screen.dart`)

This screen has:
- email + password `TextEditingController`
- loading state (`_isLoading`)
- password show/hide (`_obscurePassword`)

Login logic (`_login`):
1. validate non-empty input
2. wait 1 second (simulation)
3. save login/profile data to `SharedPreferences`
4. show success snackbar
5. navigate to `/main`

Core part:

```dart
await prefs.setBool('isLoggedIn', true);
await prefs.setString('userEmail', finalEmail);
await prefs.setString('userName', finalName);
Navigator.pushReplacementNamed(context, '/main');
```

So for now, login is local-only (no server auth yet).

## 5.3 Main navigation (`main_navigation.dart`)

This is the container after login. It controls:
- bottom tabs: `Dashboard` and `History`
- center floating `+` button for sync/connect flow
- state shared between tabs (`_deviceConnected`, `_hasNewData`)

Important pattern used here: `GlobalKey`

```dart
final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
final GlobalKey<DashboardRunnersState> _dashboardKey = GlobalKey<DashboardRunnersState>();
```

Why: parent screen can call child methods directly:
- history refresh
- dashboard refresh/reset

When user taps `+`, method `_onSyncPressed()` opens `ConnectingScreen`.

## 5.4 Connecting, success, failed screens

Files:
- `connecting_screen.dart`
- `success_screen.dart`
- `failed_screen.dart`

Current behavior:
- connection is simulated with delay
- connection success is hardcoded `true`
- app checks for new data via callback `onCheckData`
- success page appears for 2 seconds then returns
- if failure happens, failed screen offers retry/cancel

This gives a complete UX even before real BLE integration.

## 5.5 Dashboard screen (`dashboard_runners.dart`)

This is the most important screen.

What it does:
- shows connection status
- enables/disables "Unduh Data Lari" button
- shows latest run from local storage
- opens `SettingsScreen`

Key rule:

```dart
bool get canDownload => widget.isConnectedFromMain && _hasNewData;
```

So download button works only when:
- device connected
- chest strap has new data

Latest run data comes from `SharedPreferences` key `runHistory`.

## 5.6 Download data screen (`download_data_screen.dart`)

Simulates downloading with progress bar from 0% to 100%.

After progress completes:
1. create sample run data
2. generate title
3. save into `runHistory` (SharedPreferences)
4. go directly to `DetailLariScreen`

Storage format saved per run:

```dart
Map<String, dynamic> newRun = {
  'id': id,
  'title': title,
  'date': (runData['dateTime'] as DateTime).toIso8601String(),
  'distance': runData['distance'],
  'avgSpm': runData['avgSpm'],
  'compliance': runData['compliance'],
  'duration': runData['duration'],
};
```

So history is a list of JSON strings under key `runHistory`.

## 5.7 Run detail screen (`detail_lari_screen.dart`)

This screen can open in two modes:
- from fresh download (`runData` provided)
- from history (`runId` provided, load from storage)

Features:
- editable run title
- date formatting
- compliance color (green/orange/red)
- static chart painter (`CustomPainter`)
- detail rows: distance, duration, avg SPM, compliance

Edit title flow updates the saved item in `runHistory`.

## 5.8 History screen (`history_screen.dart`)

Loads `runHistory` from local storage, parses JSON, formats date, sorts newest first.

When user taps one history card:
- open `DetailLariScreen(runId: ...)`
- after returning, refresh list

Empty state is shown if no saved runs.

## 5.9 Settings screen (`settings_screen.dart`)

Handles:
- profile load/edit (`userName`, `userEmail`)
- delete all run history (`runHistory`)
- debug dialog to inspect stored data
- about/contact dialogs
- logout (`isLoggedIn = false`, then clear navigation stack)

Delete data also triggers callback to refresh dashboard/history UI immediately.

---

## 6) State management pattern used in this app

This app mainly uses basic Flutter state management:
- `StatefulWidget`
- local state variables
- `setState(...)`
- callbacks passed via constructors

Example callback pattern:

- Parent (`MainNavigation`) passes callback to child (`DashboardRunners`)
- Child calls callback after data changes
- Parent refreshes other tab/state

This is simple and beginner-friendly, but for larger apps you may later use Provider, Riverpod, or Bloc.

---

## 7) Local storage design (`SharedPreferences`)

Keys used now:
- `isLoggedIn` -> bool
- `userEmail` -> String
- `userName` -> String
- `runHistory` -> `List<String>` where each item is JSON of one run

Conceptually:

```text
runHistory = [
  "{...run1 json...}",
  "{...run2 json...}",
]
```

Then UI decodes each JSON string using `jsonDecode(...)`.

---

## 8) Services layer (prepared for backend)

### `lib/services/api_service.dart`
Contains endpoint method skeletons (`login`, `getRunHistory`, `syncRunData`, etc.) but all throw `UnimplementedError()`.

Meaning: real backend integration is not active yet.

### `lib/services/mock_api.dart`
Contains fake API methods and fake run data. Good for testing architecture without server.

Current screen code mostly uses local `SharedPreferences` directly instead of these services.

---

## 9) Helpers and utilities

### `lib/utils/snackbar_helper.dart`
Reusable snackbars for success/error/info/warning, so UI messages stay consistent.

### `lib/helpers/run_title_helper.dart`
Generates smarter run titles based on time of day, distance, avg SPM, and compliance.

Current `download_data_screen.dart` still uses a simpler manual title, but this helper can be plugged in later.

### `lib/models/chest_strap_data.dart`
Simple data model placeholder for chest strap sync metadata.

---

## 10) Beginner glossary (quick)

- `StatelessWidget`: UI with no changing local state.
- `StatefulWidget`: UI that changes over time (with `setState`).
- `Navigator.push(...)`: open new page.
- `Navigator.pop(...)`: close current page.
- `pushReplacement`: replace current page (user cannot go back to old one normally).
- `SharedPreferences`: local key-value storage for small app data.
- `async/await`: run async tasks (network, storage, delay) without blocking UI.

---

## 11) How to run and explore this project

From project root:

```bash
flutter pub get
flutter run
```

Good beginner testing checklist:
1. Welcome -> Login -> Main opens correctly
2. Tap `+` -> connect flow shows success
3. Dashboard download button becomes active when data is available
4. Download finishes and opens detail page
5. Back to history: new run appears
6. Edit title in detail, verify history title updates
7. Delete local data in settings, verify dashboard/history reset

---

## 12) What to improve next (learning roadmap)

1. Replace simulated login with real API call (`ApiService.login`).
2. Replace simulated BLE data check with real chest strap integration.
3. Move storage/network logic out of screens into repository/service classes.
4. Add unit/widget tests for login, history parsing, and detail title update.

---

## Summary

This frontend already has a solid beginner architecture:
- clear navigation
- complete user journey
- local persistence using `SharedPreferences`
- reusable helper utilities

The app currently behaves like a "working prototype": UI/flow is implemented, while backend and BLE are still mostly simulated. If you understand `main_navigation.dart`, `dashboard_runners.dart`, `download_data_screen.dart`, and `history_screen.dart`, you already understand most of this app's core logic.

When you are ready, the next big step is to swap simulation code with real `ApiService` + BLE implementation without changing the overall UI flow.
