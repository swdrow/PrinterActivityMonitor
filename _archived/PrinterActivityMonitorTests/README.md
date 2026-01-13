# PrinterActivityMonitor Unit Tests

This directory contains unit tests for core models and services.

## Test Files

### PrinterStateTests.swift
Comprehensive tests for the PrinterState model and related types.

### HAAPIServiceTests.swift
Tests for HAAPIService parsing and helper methods.

## Test Coverage

### PrinterStateTests.swift

Tests for the `PrinterState` model, enums, and helper types:

1. **PrinterState Initialization**
   - Full initialization with all properties
   - Placeholder static property
   - Codable conformance
   - Equatable conformance

2. **PrintStatus Enum**
   - Raw value parsing: idle, running, pause, finish, failed, prepare, slicing, unknown
   - Display name computed property
   - Color computed property
   - Icon SF Symbol names
   - Codable roundtrip encoding/decoding

3. **PrinterModel Enum**
   - Raw values for all models (X1C, X1E, P1P, P1S, A1, A1 Mini, Unknown)
   - Icon SF Symbol names
   - Color associations
   - Codable conformance

4. **Computed Properties**
   - `formattedTimeRemaining` - Hours/minutes formatting, edge cases (0m, 24h+)
   - `layerProgress` - Current/total layer display
   - `formattedNozzleTemp` - With/without target temperature
   - `formattedBedTemp` - With/without target temperature
   - `formattedChamberTemp` - Simple Celsius display

5. **AnyCodable Helper**
   - Int encoding/decoding
   - Double encoding/decoding
   - String encoding/decoding
   - Bool encoding/decoding
   - Fallback behavior for unsupported types

6. **HAStateResponse**
   - Full JSON decoding from Home Assistant API
   - snake_case to camelCase key mapping (entity_id, last_changed, last_updated)
   - Attribute dictionary with AnyCodable values
   - Optional field handling
   - Encoding/decoding roundtrip

7. **Edge Cases**
   - Negative temperature values
   - Zero values and nil optionals
   - Large layer counts (9999/10000)
   - Invalid enum raw values
   - Temperature rounding behavior

**Total Test Methods:** 52

### HAAPIServiceTests.swift

The `HAAPIServiceTests.swift` file includes comprehensive tests for:

1. **parseRemainingTime()** - Tests parsing of various time formats:
   - Plain minutes: "90" → 90 minutes
   - Hours and minutes: "1h 30m" → 90 minutes
   - Compact format: "1h30m" → 90 minutes
   - Hours only: "2h" → 120 minutes
   - Minutes only: "45m" → 45 minutes
   - Decimal minutes: "1.5" → 1 minute (truncated)
   - Empty strings → 0
   - Case insensitivity and whitespace handling

2. **parseFilamentUsed()** - Tests parsing of filament usage:
   - Plain numbers: "100" → 100.0 grams
   - With "g" suffix: "100g" → 100.0 grams
   - With "grams": "100 grams" → 100.0 grams
   - Meters conversion: "10m" → 29.6 grams (using 2.96g/meter for 1.75mm PLA)
   - Millimeters: "100mm" → 100.0 (not converted)
   - Empty strings → 0.0
   - Invalid input handling

3. **detectPrinterModel()** - Tests printer model detection from entity prefix:
   - "x1c_printer" → .x1c
   - "bambu_p1s" → .p1s
   - "a1mini_test" → .a1mini
   - "h2s" → .x1c (default)
   - "unknown_prefix" → .unknown
   - Case insensitivity

4. **HAAPIError** - Tests error descriptions for all error cases:
   - invalidURL
   - invalidResponse
   - unauthorized
   - httpError (with status codes)
   - decodingError
   - entityNotFound

5. **HAEntityData Helper Methods** - Tests attribute parsing:
   - stringAttribute()
   - intAttribute() - handles Int, Double, and String values
   - doubleAttribute() - handles Double, Int, and String values
   - boolAttribute() - handles Bool, String ("true"/"false"/"1"), and Int values
   - Case insensitivity for bool strings

## Setting Up the Test Target

Since this is a new test suite, you need to add the test target to your Xcode project:

### Option 1: Add Test Target in Xcode (Recommended)

1. Open `PrinterActivityMonitor.xcodeproj` in Xcode
2. Click on the project in the Project Navigator
3. Click the "+" button at the bottom of the Targets list
4. Select "iOS Unit Testing Bundle"
5. Name it "PrinterActivityMonitorTests"
6. Set the Bundle Identifier to "com.samduncan.PrinterActivityMonitorTests"
7. Make sure "Target to be Tested" is set to "PrinterActivityMonitor"
8. Click "Finish"

9. Add the test file to the target:
   - In Project Navigator, select `PrinterActivityMonitorTests/HAAPIServiceTests.swift`
   - In the File Inspector (right panel), check the box next to "PrinterActivityMonitorTests" in Target Membership

10. Configure the scheme for testing:
    - Go to Product → Scheme → Edit Scheme
    - Select "Test" in the left sidebar
    - Click the "+" button under Test section
    - Add "PrinterActivityMonitorTests" to the list
    - Click "Close"

### Option 2: Manual Project File Editing (Advanced)

If you prefer command-line setup, you'll need to manually edit the `project.pbxproj` file to add:
- Test target configuration
- File references
- Build phases
- Scheme configuration

This is complex and error-prone. Option 1 is strongly recommended.

## Running the Tests

### In Xcode
1. Select the test target or scheme
2. Press Cmd+U to run all tests
3. Or click the diamond icon next to individual test methods to run them

### From Command Line
```bash
xcodebuild test \
  -project PrinterActivityMonitor.xcodeproj \
  -scheme PrinterActivityMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Test Implementation Details

The tests use a test extension on `HAAPIService` to expose private methods for testing:

```swift
extension HAAPIService {
    func testParseRemainingTime(_ timeString: String) -> Int
    func testParseFilamentUsed(_ filamentString: String) -> Double
    func testDetectPrinterModel() -> PrinterState.PrinterModel
    func testSetEntityPrefix(_ prefix: String)
}
```

This approach:
- Keeps the original methods private in production code
- Provides clean test access without modifying the main implementation
- Uses @MainActor to match the HAAPIService actor context

## Notes

- Tests are marked `@MainActor` because `HAAPIService` is a `@MainActor` class
- Tests focus on parsing logic that can be unit tested in isolation
- Network-dependent methods are intentionally excluded (require integration tests)
- All tests use XCTest assertions with appropriate accuracy parameters for floating-point comparisons
