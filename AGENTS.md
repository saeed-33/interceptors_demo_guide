# Agent Guide — Interceptors Demo

> This file is for AI coding agents. It describes the project as it actually exists today. Do not assume production-grade defaults — this is a demo/presentation project.

## 1. Project Overview

This repository is a companion demo for a presentation about HTTP interceptor patterns in Flutter. It contains two independent sub-projects:

- **`backend/`** — A small Node.js/Express API that mirrors the interceptor behaviors implemented on the client.
- **`mobile/`** — A Flutter app that demonstrates a Dio interceptor chain (network, auth, cache, encryption, logging, etc.) through a dark-themed UI.

The codebase is intentionally educational. All demo pages make real HTTP calls through the wired Dio client; the backend mirrors the interceptor behaviors so you can observe the full chain in the terminal and in the UI.

## 2. Repository Layout

```text
.
├── backend/                 # Node.js/Express API
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── index.js
│       ├── middleware/      # Express middleware implementations
│       └── routes/          # Auth and post routes
├── mobile/                  # Flutter application
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── android/             # Android platform files
│   ├── web/                 # Web platform files
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── dependencies/   # Singleton Dio + NetworkCubit
│       │   ├── history/        # In-memory request history
│       │   ├── interceptors/   # Dio interceptors
│       │   ├── logs/           # In-memory interceptor log store
│       │   ├── navigation/     # GoRouter configuration
│       │   ├── network/        # DioClient factory
│       │   ├── security/       # Root & biometric guards
│       │   └── storage/        # Web-compatible token storage
│       ├── features/
│       │   └── */presentation/pages/   # Splash, login, posts, dashboard, settings, logs
│       └── shared/
│           ├── theme/
│           └── widgets/
├── README.md
├── interceptors.pptx        # Presentation deck
└── AGENTS.md                # This file
```

## 3. Technology Stack

### Backend
- **Runtime:** Node.js
- **Framework:** Express 4.x
- **Key packages:** `jsonwebtoken`, `bcryptjs`, `cors`, `helmet`, `express-rate-limit`, `morgan`, `uuid`, `node-cache`
- **Dev tool:** `nodemon`
- **Data store:** In-memory `Map` objects (no database)

### Mobile
- **Framework:** Flutter / Dart
- **Dart SDK:** `>=3.0.0 <4.0.0`
- **Networking:** `dio: ^5.4.0`, `connectivity_plus: ^5.0.2`
- **State management:** `flutter_bloc`, `equatable`
- **Navigation:** `go_router: ^13.0.0`
- **Local storage / cache:** `hive`, `hive_flutter`, `shared_preferences`, `flutter_cache_manager`
- **Security:** `flutter_secure_storage`, `local_auth`, `root_check`
- **Encryption:** `encrypt`, `crypto`
- **Logging:** `logger`, `pretty_dio_logger`
- **Other declared deps:** `dartz`, `formz`, `get_it`, `injectable`, `intl`, `uuid`, `package_info_plus`
- **Code generation:** `build_runner`, `injectable_generator`, `hive_generator`
- **Linting:** Default analyzer rules only. `analysis_options.yaml` no longer references `package:flutter_lints` because `flutter_lints` is not a declared dependency.

Note: Several packages (`dartz`, `formz`, `get_it`, `injectable`, `intl`) are declared but not currently used in the source code. They are available for future refactoring.

## 4. Backend Architecture

### Entry Point
`backend/src/index.js` bootstraps Express and applies middleware in this order:

1. `helmet()` — security headers
2. `cors(...)` — dynamic origin reflection for localhost and any other host
3. Rate limiting (100 req/15 min for `/api/`, 10 req/15 min for `/api/auth/`)
4. `express.json({ limit: '1mb' })`
5. `morgan('dev')` + custom `logMiddleware`
6. `rootDeviceMiddleware`
7. `decryptMiddleware`
8. `versionMiddleware`
9. `softDeleteMiddleware`
10. `encryptResponse` — wraps `res.json()` so encrypted requests get encrypted responses
11. Routes: `/api/auth`, `/api/posts`
12. Health check (`/health`)
13. 404 + global error handlers

### Routes

| Route | Purpose |
|-------|---------|
| `POST /api/auth/register` | Register a new user, issue JWTs |
| `POST /api/auth/login` | Authenticate, issue JWTs |
| `POST /api/auth/refresh` | Rotate refresh token |
| `POST /api/auth/logout` | Revoke refresh token |
| `POST /api/auth/profile/delete` | Bio-auth protected demo endpoint |
| `GET /api/posts` | List posts (excludes soft-deleted) |
| `GET /api/posts/:id` | Get a single post |
| `POST /api/posts` | Create a post (auth required) |
| `PATCH /api/posts/:id` | Update or soft-delete a post |
| `DELETE /api/posts/:id` | Hard delete a post (auth required) |
| `GET /health` | Health check |

### Middleware Details
- **`validator.middleware.js`** — Path-based schema validation for `login`, `register`, and `POST /posts`.
- **`auth.routes.js`** — Issues 15-minute access tokens and 7-day refresh tokens. Refresh tokens are rotated.
- **`encrypt.middleware.js` / `decrypt.middleware.js`** — AES-256-CBC body encryption when `X-Encrypted: true` is present. Response encryption wraps `res.json()` before routes run so it can encrypt on the way out.
- **`softDelete.middleware.js`** — Detects `X-Soft-Delete: true` header on PATCH and sets `deleted_at`.
- **`version.middleware.js`** — Adds `X-App-Min-Version` and `X-App-Latest-Version` headers.
- **`rootDevice.middleware.js`** — Logs requests from rooted devices.
- **`log.middleware.js`** — Structured JSON request logs using `req.originalUrl`.

### Environment Variables
| Variable | Default (demo) | Purpose |
|----------|----------------|---------|
| `PORT` | `3000` | Server port |
| `JWT_SECRET` | `demo-jwt-secret-change-in-prod` | Access token signing |
| `JWT_REFRESH_SECRET` | `demo-refresh-secret` | Refresh token signing |
| `ENCRYPTION_KEY` | `demo-secret-key-32-bytes-exactly!!` | AES key (first 32 bytes used) |

## 5. Mobile App Architecture

### App Startup
`mobile/lib/main.dart`:
- Ensures Flutter binding
- Initializes Hive (`Hive.initFlutter()`)
- Calls `AppDependencies.initialize()` (creates the single Dio client + NetworkCubit and runs root detection)
- Provides `NetworkCubit` via `BlocProvider.value`
- Runs `MaterialApp.router` with `AppTheme.dark` and `AppRouter.router`

### Navigation
- Declarative routing via `go_router`.
- `AppRouter.navigatorKey` is a `GlobalKey<NavigatorState>` used by interceptors to navigate without a `BuildContext`.
- Routes: `/splash` → `/login` → `/posts`, `/dashboard`, `/settings`, `/logs`.

### Theming
- Single dark theme defined in `shared/theme/app_theme.dart`.
- Color palette (`AppColors`) uses GitHub-dark-inspired navy surfaces and an electric-blue accent.
- Global widgets live in `shared/widgets/shared_widgets.dart`.

### Storage
- **`TokenStorage`** (`core/storage/token_storage.dart`) — Web-compatible token abstraction.
  - Native: `FlutterSecureStorage`
  - Web: `SharedPreferences` (localStorage fallback for demo only)
  - Stores `access_token`, `refresh_token`, plus encryption key/IV used by `EncryptInterceptor`.
- **`RequestHistory`** (`core/history/request_history.dart`) — In-memory request history used by the Dashboard.
- **`LogStore`** (`core/logs/log_store.dart`) — In-memory interceptor log buffer used by the Logs screen.

### Dio Client & Interceptor Chain
`core/network/dio_client.dart` exposes a factory:

```dart
final dio = DioClient.create(networkCubit: myNetworkCubit);
```

Default `baseUrl` is `http://localhost:3000/api`.

Interceptors are registered in this request order. **Order matters**: they run top-to-bottom on request and bottom-to-top on response/error.

| Order | Interceptor | Responsibility |
|-------|-------------|----------------|
| 1 | `NetworkInterceptor` | Abort if offline using `connectivity_plus` |
| 2 | `RootDetectionDioInterceptor` | Add `X-Device-Rooted` header; optionally block rooted devices |
| 3 | `BioAuthDioInterceptor` | Require biometric auth for configured sensitive endpoints |
| 4 | `ValidatorInterceptor` | Client-side request/response schema validation |
| 5 | `CacheInterceptor` | Serve GET responses from Hive cache, respect `Cache-Control` |
| 6 | `AuthInterceptor` | Attach Bearer token, queue requests, auto-refresh on 401. Never sends tokens to `/auth/login`, `/auth/register`, `/auth/refresh`, or `/auth/logout`. |
| 7 | `EncryptInterceptor` | AES-256-CBC encrypt bodies for endpoints marked `extra['encrypt'] = true` |
| 8 | `NavigationInterceptor` | Attach current route as `X-Screen-Origin` header and log it |
| 9 | `SoftDeleteInterceptor` | Transform `DELETE` → `PATCH {deleted_at: now}` |
| 10 | `StateInterceptor` | Emit `NetworkLoading/Success/Error` via a `NetworkCubit` |
| 11 | `PerformanceInterceptor` | Measure request duration and warn on slow calls |
| 12 | `ErrorInterceptor` | Map Dio exceptions to typed `AppException` subclasses |
| 13 | `UpdateCheckInterceptor` | Read version headers and show force/soft update dialogs |
| 14 | `AppLogInterceptor` | Pretty-print requests/responses/errors, sanitize headers |

### Security Interceptors
- `RootDetectionInterceptor` — Singleton, checks `RootCheck.isRooted` at startup. Called from `AppDependencies.initialize()`. On web the check is skipped and the Dio interceptor still adds `X-Device-Rooted: false`.
- `BioAuthInterceptor` — Singleton for local biometric auth. The Dio variant protects `/auth/profile/delete`. On web the prompt is skipped and the request is allowed through.
- **No screenshot protection interceptor is present.** The `screen_protector` package was removed because it does not support web and was never wired into the app lifecycle.

### Pages
- **`SplashPage`** — Animated boot sequence, then routes to `/login`.
- **`LoginPage`** — Real login/register against `/api/auth/login` and `/api/auth/register`. Stores tokens and navigates to `/posts`. The right panel shows a live chain summary.
- **`PostsPage`** — Loads real posts from `/api/posts` with cache hit detection, creates encrypted posts (`extra['encrypt'] = true`), and soft-deletes via the `SoftDeleteInterceptor`.
- **`DashboardPage`** — Real request history from `RequestHistory`, interceptor status grid (no toggles), bio-auth demo button, and logout.
- **`SettingsPage`** — Interceptor documentation (no toggles), app config readout, and danger-zone actions.
- **`LogsPage`** — Live interceptor log output grouped by individual request invocation. Every interceptor writes here via `LogStore` in addition to `print()`.

### Typical Request Flows
- **Login/Register** → `Network`, `RootDetection`, `BioAuth` (no-op unless sensitive), `Validator`, `State`, `Performance`, `Error`, `UpdateCheck`, `AppLog`.
- **Load Posts** → `Network`, `RootDetection`, `Cache` (MISS/HIT), `Auth`, `Navigation`, `State`, `Performance`, `UpdateCheck`, `AppLog`.
- **Create Post** → `Validator`, `Auth`, `Encrypt` (AES-256-CBC request + encrypted response), `Navigation`, `State`, `Performance`, `AppLog`.
- **Soft Delete** → `SoftDeleteInterceptor` transforms `DELETE /posts/:id` into `PATCH` with `X-Soft-Delete: true`.
- **Bio-Auth Request** → `BioAuthDioInterceptor` protects `/auth/profile/delete` (auto-allowed on web, prompts biometrics on native).

## 6. Build & Run Commands

### Backend
```bash
cd backend
npm install
npm start        # node src/index.js
npm run dev      # nodemon src/index.js
```

The backend listens on `http://localhost:3000` by default.

### Mobile
```bash
cd mobile
flutter pub get
flutter analyze
flutter run -d chrome      # web
flutter run                # default device
flutter build apk          # Android
flutter build web          # Web
```

If code generation is needed later:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Restarting after backend changes
Any change under `backend/src/` requires a restart of the Node process for it to take effect.

### Port already in use
If you see `EADDRINUSE: 3000`, kill the stale process and restart:
```bash
npx kill-port 3000
```

## 7. Code Style Guidelines

- **Dart:** Files are `snake_case`, classes `PascalCase`, constants `camelCase`/`kConstant` style as seen in the project.
- **JavaScript:** 2-space indentation, CommonJS `require`/`module.exports`, semi-colons used.
- **Comments:** Heavy use of ASCII section banners (`// ─── Section ───`) and emoji labels per interceptor. Maintain this style for consistency.
- **Imports:** Dart files use full package imports (`package:interceptors_demo/...`). Avoid relative imports unless local to a feature.
- **State:** Demo pages keep state in `StatefulWidget`s. The wired network layer uses a `NetworkCubit`.
- **Demo logging:** Every interceptor now prints a `==== <name> interceptor : …` line to the terminal AND writes the same line — along with an `api` tag (request path or logical group) and a per-request `requestId` — to `LogStore`. The first interceptor (`NetworkInterceptor`) generates the `requestId`, and every downstream interceptor reuses it so the `LogsPage` can group all logs for a single API invocation together. Repeated calls to the same endpoint appear as separate groups. In production these should be replaced with a real logging backend.

## 8. Testing Strategy

There are **no automated tests** in this repository at the moment.

- No `test/` or `integration_test/` directories exist in `mobile/`.
- The backend has no test runner configured.

Recommended additions:
- `mobile/test/core/interceptors/` — unit tests for each interceptor using a mocked `Dio` adapter.
- `mobile/integration_test/` — end-to-end flows for login/posts.
- `backend/tests/` — Jest or Node test runner for route and middleware behavior.

Run existing Flutter test harness with:
```bash
cd mobile
flutter test
```
It will report zero tests unless new ones are added.

## 9. Security Considerations

This is a demo project and is **not production-ready**.

- Hard-coded secrets (`JWT_SECRET`, `ENCRYPTION_KEY`, etc.) must be rotated and sourced from environment variables/secrets managers.
- The backend uses in-memory data stores; data is lost on restart.
- CORS configuration reflects any request origin for local demo convenience.
- No HTTPS/TLS enforcement.
- Rooted-device and biometric checks are present but the biometric prompt is skipped on web.
- Encryption IVs are random per request (good), but the key is derived from a fixed demo string.
- Rate limiting is basic and per-process only.
- Tokens are stored in `FlutterSecureStorage` on native; on web they fall back to plain `SharedPreferences`, which is insecure and for demo only.

## 10. Deployment Notes

### Backend
- The Express app can be containerized with a standard Node.js image.
- Use environment variables for all secrets before deploying.
- Replace in-memory stores with a real database before any real usage.

### Mobile
- Android (`mobile/android/`) and web (`mobile/web/`) platform directories are present.
- Default backend URL is `http://localhost:3000/api`; update it for physical devices or production.
- Web builds use `SharedPreferences` as a fallback for secure storage; this is not secure and is for demo only.
- Release builds use the debug signing config (see `mobile/android/app/build.gradle.kts`). Replace before distributing.

## 11. Known Caveats & Things to Check

- `backend/package.json` defines an `npm run seed` script, but `backend/src/seed.js` does not exist. Posts are seeded inline in `post.routes.js` instead.
- `DioClient.create()` is invoked once at startup by `AppDependencies` and shared across pages.
- `RootDetectionInterceptor.check()` is called from `AppDependencies.initialize()`.
- The `assets/` folder exists but is empty.
- Several declared dependencies (`dartz`, `formz`, `get_it`, `injectable`, `intl`) are not currently imported in source files.
- `flutter analyze` reports `withOpacity` deprecation infos across the UI files. These are pre-existing and non-blocking.
- `analysis_options.yaml` does not include `flutter_lints` because the package is not declared as a dependency; this avoids the previous `include_file_not_found` warning.
