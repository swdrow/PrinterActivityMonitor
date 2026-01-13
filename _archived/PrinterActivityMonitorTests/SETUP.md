# Quick Setup Guide for Unit Tests

## Step-by-Step: Adding Test Target in Xcode

Follow these steps to configure the test target and run the unit tests:

### 1. Open Project in Xcode
```bash
open PrinterActivityMonitor.xcodeproj
```

### 2. Add Test Target

1. In Xcode, select the **PrinterActivityMonitor** project in the Project Navigator (top of the left sidebar)
2. In the editor area, you'll see the project settings with a list of targets
3. Click the **"+"** button at the bottom of the TARGETS list
4. In the dialog that appears:
   - Under **iOS**, select **"Unit Testing Bundle"**
   - Click **Next**
5. Configure the test target:
   - **Product Name:** `PrinterActivityMonitorTests` (should be pre-filled)
   - **Team:** Select your development team
   - **Organization Identifier:** Use the same as your main app (e.g., `com.yourname`)
   - **Bundle Identifier:** Should auto-populate as `com.yourname.PrinterActivityMonitorTests`
   - **Project:** PrinterActivityMonitor
   - **Target to be Tested:** PrinterActivityMonitor
6. Click **Finish**

### 3. Remove Default Test File

Xcode will create a default test file. Delete it:

1. In the Project Navigator, expand the **PrinterActivityMonitorTests** folder
2. Find the auto-generated test file (usually `PrinterActivityMonitorTests.swift`)
3. Right-click it and select **Delete**
4. Choose **Move to Trash** (not just "Remove Reference")

### 4. Add Existing Test Files to Target

The test files already exist in the `PrinterActivityMonitorTests` directory. Add them to the target:

1. In Project Navigator, select **PrinterStateTests.swift**
2. Open the **File Inspector** in the right sidebar (press Cmd+Option+1 if hidden)
3. Under **Target Membership**, check the box next to **PrinterActivityMonitorTests**
4. Repeat for any other test files (e.g., `HAAPIServiceTests.swift` if it exists)

### 5. Configure Test Scheme

1. In the toolbar, click the scheme selector (next to the play/stop buttons)
2. Select **Edit Scheme...**
3. In the left sidebar, select **Test**
4. If `PrinterActivityMonitorTests` isn't listed, click the **"+"** button
5. Select **PrinterActivityMonitorTests** from the list
6. Make sure the checkbox next to it is **checked**
7. Click **Close**

### 6. Run Tests

You're ready to run tests! Choose one:

- **Run all tests:** Press `Cmd + U`
- **Run tests for current file:** Click the diamond icon in the gutter next to the class name
- **Run single test:** Click the diamond icon next to any test method
- **View results:** Open Test Navigator with `Cmd + 6`

## Command Line Testing

Once the test target is configured in Xcode, you can also run tests from the command line:

```bash
# Run all tests
xcodebuild test \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run with code coverage
xcodebuild test \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -enableCodeCoverage YES

# Run specific test class
xcodebuild test \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:PrinterActivityMonitorTests/PrinterStateTests

# Run specific test method
xcodebuild test \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:PrinterActivityMonitorTests/PrinterStateTests/testPrinterStatePlaceholder
```

## Troubleshooting

### "No such module 'PrinterActivityMonitor'"

This means the test target can't find the app module. Fix:

1. Select the test target in Project Navigator
2. Go to **Build Settings**
3. Search for "Test Host"
4. Verify `BUNDLE_LOADER` is set to `$(TEST_HOST)`
5. Verify `TEST_HOST` points to: `$(BUILT_PRODUCTS_DIR)/PrinterActivityMonitor.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PrinterActivityMonitor`

### "ld: framework not found XCTest"

The SDK or deployment target is misconfigured:

1. Select the test target
2. Go to **Build Settings**
3. Verify **Base SDK** is set to "iOS"
4. Verify **iOS Deployment Target** matches the app target (iOS 17.0)

### Tests Don't Appear in Test Navigator

1. Clean the build folder: `Cmd + Shift + K`
2. Rebuild: `Cmd + B`
3. Close and reopen Xcode
4. Check that test files are added to the test target (see Step 4 above)

### Simulator Not Found

Update the destination to match available simulators:

```bash
# List available simulators
xcrun simctl list devices available

# Use a different device
xcodebuild test \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Next Steps

Once tests are running successfully:

1. **Check Coverage:** In Xcode, go to Report Navigator (Cmd+9), select the test report, click Coverage tab
2. **Add CI/CD:** Integrate tests into GitHub Actions or other CI systems
3. **Write More Tests:** Add tests for other components like HAAPIService, ActivityManager, etc.

## Questions?

See the main [README.md](./README.md) for detailed test coverage information and implementation notes.
