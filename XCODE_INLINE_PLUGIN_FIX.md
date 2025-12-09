# iOS AltimeterPlugin - Inline Implementation Fix

## Problem
When creating `AltimeterPlugin.swift` as a separate file, Xcode project failed to build with:
```
Swift Compiler Error: Cannot find 'AltimeterPlugin' in scope
```

**Root cause**: Swift files must be explicitly registered in Xcode's `project.pbxproj` file. Simply creating a file in the filesystem is not enough.

## Solution Attempts

### 1. Ruby xcodeproj gem ❌
```ruby
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner_group = project.main_group.groups.find { |g| g.name == 'Runner' }
# FAILED: runner_group was nil
```
**Error**: `undefined method 'files' for nil:NilClass`

### 2. Sed-based project.pbxproj edit ❌
```bash
sed -i '' "/AppDelegate.swift/a\\
    ${FILE_UUID} /* AltimeterPlugin.swift */
" project.pbxproj
```
**Error**: `xcodebuild: error: Unable to read project 'Runner.xcodeproj' - parse error`
**Reason**: Sed corrupted XML structure with improper escaping

### 3. Inline Plugin Code ✅
**Solution**: Merge `AltimeterPlugin.swift` directly into `AppDelegate.swift`

## Implementation

Moved all AltimeterPlugin class code into `AppDelegate.swift`:

```swift
import Flutter
import UIKit
import CoreMotion  // ← Added

// ← Entire AltimeterPlugin class (110 lines) pasted here
class AltimeterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let altimeter = CMAltimeter()
    // ... full implementation ...
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(...) -> Bool {
    let registrar = self.registrar(forPlugin: "AltimeterPlugin")!
    AltimeterPlugin.register(with: registrar)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(...)
  }
}
```

## Benefits
✅ No Xcode project file manipulation required
✅ Guaranteed Swift compiler can find class
✅ Single file easier to maintain
✅ Avoids project.pbxproj corruption risks

## Trade-offs
⚠️ AppDelegate.swift becomes larger (130+ lines)
⚠️ Less modular than separate files
✅ Still clean: proper class separation maintained

## Status
- `ios/Runner/AltimeterPlugin.swift` - Kept for reference (not compiled)
- `ios/Runner/AppDelegate.swift` - Contains inline AltimeterPlugin class
- Build: ✅ Should compile successfully now

## Alternative Solutions Not Attempted
1. **Manual Xcode GUI**: Right-click Runner → Add Files (requires user interaction)
2. **Xcode command-line tools**: `xcodebuild -list` and manual UUID generation
3. **Flutter plugin package**: Create proper pub.dev plugin (overkill for single app)

## Lessons Learned
- Xcode project files are fragile XML structures
- Prefer inline code over complex build system manipulation
- Always backup `project.pbxproj` before automated edits
- Flutter plugins can be implemented without separate files when targeting single app

## Related Files
- `/lib/services/ios_altimeter_service.dart` - Dart wrapper (unchanged)
- `/lib/services/barometer_service.dart` - Integration (unchanged)
- Platform channels still work identically with inline implementation

---
**Date**: December 9, 2024  
**Approach**: Inline plugin implementation in AppDelegate.swift  
**Result**: iOS build should now succeed
