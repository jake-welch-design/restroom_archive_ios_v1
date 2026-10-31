# The Restroom Archive — Native iOS App (v1)

Native iOS & iPadOS application for **[The Restroom Archive](https://restroomarchive.com)** (`restroom_archive_v2`), built with a 100% native SwiftUI "Ink & Paper" archival shell (`HelveticaNeue`, crisp `1pt` square borders, `#000`/`#fff`) paired with a persistent bundled Three.js WebGL 3D stage (`WKWebView` + `WKURLSchemeHandler`) for zero-compromise Draco `.glb` decompression, unlit vertex/texture rendering, non-destructive multi-box cropping, and floor-levelling shaders.

---

## Architecture Overview

```text
restroom_archive_ios_v1/
├── project.yml                     # XcodeGen specification -> RestroomArchive.xcodeproj
├── Packages/
│   └── ArchiveCore/                # Swift 6 SPM package (Models, APIClient, Regions, Storage, Tests)
├── Stage/                          # Local TypeScript + Three.js WebGL stage source & esbuild bundler
├── RestroomArchive/                # Native SwiftUI iOS/iPadOS application target
│   ├── App/                        # AppState, LocationService, ArchiveShellView (bottom sheet + split view)
│   ├── DesignSystem/               # ArchiveTheme ("Ink & Paper" tokens), AsyncCachedImage
│   ├── Stage/                      # ArchiveSchemeHandler (archive-stage:// + LRU cache), StageController
│   ├── Features/
│   │   ├── Viewer/                 # ViewerControlsOverlay (POV/Orbit, annotations, Admin Crop/Level gizmo)
│   │   ├── Catalog/                # List, Grid, Map (CARTO Positron & Esri tiles), Search/Tag/Date/Near Me
│   │   ├── Submit/                 # 4-step .GLB wizard, 1-tap GPS/POI autofill, offline Drafts
│   │   ├── Account/                # Email/Password Auth, Profile, Submissions, Annotations, Blocklist, Delete
│   │   ├── Admin/                  # 2-tier Admin Console (Pending, Archive, Rejected, Removals, Users, Log)
│   │   └── Info/                   # About, live Stats, 6-step Submission Guide, Contact, Privacy & Terms
│   └── Resources/                  # Info.plist, Assets.xcassets, bundled StageDist/ (stage.js + Draco WASM)
└── RestroomShareExtension/         # iOS Share Sheet extension for importing .GLB files from Scaniverse/Files
```

---

## Quick Start

### 1. Prerequisites
- **Xcode 16+** (install from the Mac App Store or Apple Developer Downloads, then run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`)
- **XcodeGen** (`brew install xcodegen`)
- **Node.js 20+** (only needed when modifying `Stage/src/`)

### 2. Generate the Xcode Project & Run
`RestroomArchive/Resources/StageDist/` is already pre-built and ready. Generate the `.xcodeproj` and open it in Xcode:

```bash
cd /Users/jakewelch/Desktop/Projects/Personal/Websites/restroom_archive_ios_v1
xcodegen generate
open RestroomArchive.xcodeproj
```

In Xcode:
1. Select the **RestroomArchive** project in the navigator -> **Signing & Capabilities**.
2. Choose your **Apple Developer Team** on both `RestroomArchive` and `RestroomShareExtension`.
3. Register the App Group `group.com.restroomarchive.shared` (and update `TEAM_ID_HERE` in `restroom_archive_v2/public/.well-known/apple-app-site-association` with your 10-character Apple Team ID for Universal Links).
4. Select an iPhone or iPad Simulator (or physical device) and press **Cmd + R**.

### 3. Rebuilding the Local 3D WebGL Stage (Optional)
If you edit `Stage/src/main.ts` or `Stage/src/cropController.ts`:

```bash
npm --prefix Stage run typecheck
npm --prefix Stage run build
```

### 4. Running `ArchiveCore` Package Tests
In Xcode, press **Cmd + U** (`ArchiveCoreTests`), or run the CLI verification suite directly:

```bash
swift run --package-path Packages/ArchiveCore ArchiveCoreVerify
```

---

## Companion Backend Changes (`restroom_archive_v2`)

The companion mobile additions in `/Users/jakewelch/Desktop/Projects/Personal/Websites/restroom_archive_v2` are strictly additive and leave all existing browser cookie/Turnstile flows untouched:
- Migration `server/db/migrations/0030_mobile_auth_and_ugc_safety.sql` (`api_tokens`, `user_blocks`, `restroom_reports`)
- Bearer token fallback in `server/middleware/auth.ts`
- Native endpoints under `/api/auth/mobile/*`, `/api/me/session`, `/api/me/blocks`, `/api/restrooms/[slug]/report`, and `/api/contact/mobile`
- Universal Links manifest at `public/.well-known/apple-app-site-association`

When ready to deploy the backend changes to production (`restroomarchive.com`), run the D1 migration and deploy from `restroom_archive_v2`:

```bash
cd /Users/jakewelch/Desktop/Projects/Personal/Websites/restroom_archive_v2
npm run db:migrate:local
# When ready for production:
# npm run db:migrate:remote
# npm run deploy
```

