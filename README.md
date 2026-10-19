# APDU Trace Inspector

A native Apple platform diagnostic tool designed to capture, inspect, and export low-level APDU communication traces Apple devices (**macOS**, **iOS**, **iPadOS**). 

---

## Opening in Xcode 26.2

You can now open the project directly in Xcode using either the Xcode Project or Workspace file:

### Option A: Open `APDUTracker.xcodeproj`
Double-click `APDUTracker.xcodeproj` in Finder, or run from Terminal:
```bash
open {project_path}/APDUTracker.xcodeproj
```

### Option B: Open `APDUTracker.xcworkspace`
```bash
open {project_path}/APDUTracker.xcworkspace
```

Once opened in Xcode:
1. Select the **APDUTracker** scheme.
2. Select your target device from the run destination menu:
   - **My Mac** (Native macOS App)
   - **Any iPhone / iPhone Simulator** (iOS App)
   - **Any iPad / iPad Simulator** (iPadOS App)
3. Press **Cmd + R** to Build & Run!

---

## Running Outside Xcode (macOS Desktop)

### 1. Launch with One Click
```bash
{project_path}/run_app.sh
```
Or double-click `APDUTracker.app` directly in Finder.

### 2. Run Automated Tests
```bash
cd {project_path}
swift test
```

### 3. Run Command-Line Diagnostic Runner
```bash
swift run APDUTrackerCLI
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
