# PawPlan Mobile

Flutter MVP client for the PawPlan capstone stack.

## Prerequisites

- Flutter SDK: `H:\tools\flutter`
- Backend API running on `http://localhost:4000`
- PostgreSQL running through the root `docker-compose.yml`

## Run

```powershell
cd H:\programming\jonsulpu\mobile
flutter pub get
flutter run -d chrome
```

Android emulator uses the default API base URL `http://10.0.2.2:4000/api/v1`.
Web and Windows use `http://localhost:4000/api/v1`.

If Android login shows a socket error for `10.0.2.2:4000`, verify that the backend is running and bound to `0.0.0.0`.

```powershell
Invoke-RestMethod http://localhost:4000/health
Get-NetTCPConnection -LocalPort 4000
```

`10.0.2.2` is for Android emulators. For a physical Android device, use a LAN IP API URL or run `adb reverse tcp:4000 tcp:4000` and build/run with `API_BASE_URL=http://127.0.0.1:4000/api/v1`.

Override it when needed:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api/v1
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

## Android

Installed local SDK paths:

- Flutter SDK: `H:\tools\flutter`
- Android SDK: `H:\Android\Sdk`
- AVD: `PawPlan_API36`

Useful commands:

```powershell
flutter doctor -v
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
flutter emulators --launch PawPlan_API36
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

## UI Integration Test

Run the backend, PostgreSQL, and demo seed first.

```powershell
cd H:\programming\jonsulpu
docker compose up -d postgres

cd H:\programming\jonsulpu\backend
npm run dev
npm run seed:demo
```

Then run the Android UI flow test.

```powershell
cd H:\programming\jonsulpu\mobile
flutter emulators --launch PawPlan_API36
flutter test integration_test\app_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

Covered screens:

- Login with the seeded demo account
- Today dashboard
- Records tab with unified timeline filters
- Reports tab
- Forecast recalculation and forecast history
- Health log create, edit, delete
- Expense create, edit, delete
- Medical visit create, edit, delete
- Medical visit attachment list, upload, delete
- Dog profile edit
- Care schedule create, edit, skip

## Current MVP Flow

- Register/login against Express API
- Use seeded demo account `demo@pawplan.kr` / `password123` after running backend `npm run seed:demo`
- Restore mobile sessions from secure device storage
- Register first dog through onboarding
- Switch between registered dogs
- Edit or delete the selected dog profile; deletion shows linked record counts and requires typing the dog name
- Manage family sharing from the selected dog header: view members, add an existing user by email, change roles, or remove access
- View dashboard, pending care schedules, latest forecast, and recent logs
- Browse health logs, medical visits, and expenses together in the Records tab timeline
- Filter the Records tab timeline by all, health, hospital, or expense items
- Edit or delete health logs, medical visits, and expenses from the Records tab
- Browse, add, edit, and delete dog conditions and medications in the Info tab
- Complete or skip care schedules; recurring schedules continue with the next occurrence
- Add quick health logs and expenses
- Add hospital visit records with optional linked expense
- Attach receipt, prescription, or test-result images to hospital visits
- Generate and view hospital visit report history in the Reports tab
- Recalculate cost forecasts and review recent forecast history in the Reports tab
- Sync enabled pending care reminders into device-local notifications on supported mobile platforms
