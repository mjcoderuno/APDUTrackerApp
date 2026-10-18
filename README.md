# BioCard APDU Trace Inspector

A native Apple platform diagnostic tool designed to capture, inspect, and export low-level APDU communication traces between biometric smart cards (Match-on-Card, FIDO2/WebAuthn tokens, EMV bio cards) and Apple devices (**macOS**, **iOS**, **iPadOS**).

---

## Opening in Xcode

You can now open the project directly in Xcode using either the Xcode Project or Workspace file:

### Option A: Open `BioCard.xcodeproj`
Double-click `BioCard.xcodeproj` in Finder, or run from Terminal:
```bash
open /Users/mrityunjaykumar/Documents/POC/BioCard/BioCard.xcodeproj
```

### Option B: Open `BioCard.xcworkspace`
```bash
open /Users/mrityunjaykumar/Documents/POC/BioCard/BioCard.xcworkspace
```

Once opened in Xcode:
1. Select the **BioCard** scheme.
2. Select your target device from the run destination menu:
   - **My Mac** (Native macOS App)
   - **Any iPhone / iPhone Simulator** (iOS App)
   - **Any iPad / iPad Simulator** (iPadOS App)
3. Press **Cmd + R** to Build & Run!

---

## Running Outside Xcode (macOS Desktop)

### 1. Launch with One Click
```bash
/Users/mrityunjaykumar/Documents/POC/BioCard/run_app.sh
```
Or double-click `BioCard.app` directly in Finder.

### 2. Run Automated Tests
```bash
cd /Users/mrityunjaykumar/Documents/POC/BioCard
swift test
```

### 3. Run Command-Line Diagnostic Runner
```bash
swift run BioCardCLI
```

---

## Unmasking `<private>` Logs on Apple Devices

Apple's Unified Logging masks sensitive cryptographic payloads by default. To unmask 100% of raw hex bytes:

### On macOS:
Run this terminal command:
```bash
sudo log config --mode "private_data:on"
```

### On iOS / iPadOS:
AirDrop or email `Config/EnablePrivateLogging.mobileconfig` to your test device, then navigate to **Settings -> Profile Downloaded -> Install**.
