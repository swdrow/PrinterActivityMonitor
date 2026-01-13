import XCTest
@testable import PrinterActivityMonitor

/// Unit tests for HAAPIService parsing and helper methods
@MainActor
final class HAAPIServiceTests: XCTestCase {

    // MARK: - parseRemainingTime Tests

    func testParseRemainingTime_PlainMinutes() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseRemainingTime("90"), 90)
        XCTAssertEqual(service.testParseRemainingTime("0"), 0)
        XCTAssertEqual(service.testParseRemainingTime("120"), 120)
        XCTAssertEqual(service.testParseRemainingTime("1"), 1)
    }

    func testParseRemainingTime_HoursAndMinutes() {
        let service = HAAPIService()

        // "1h 30m" format
        XCTAssertEqual(service.testParseRemainingTime("1h 30m"), 90)
        XCTAssertEqual(service.testParseRemainingTime("2h 15m"), 135)
        XCTAssertEqual(service.testParseRemainingTime("0h 45m"), 45)

        // "1h30m" format (no space)
        XCTAssertEqual(service.testParseRemainingTime("1h30m"), 90)
        XCTAssertEqual(service.testParseRemainingTime("2h15m"), 135)
        XCTAssertEqual(service.testParseRemainingTime("3h0m"), 180)
    }

    func testParseRemainingTime_HoursOnly() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseRemainingTime("2h"), 120)
        XCTAssertEqual(service.testParseRemainingTime("1h"), 60)
        XCTAssertEqual(service.testParseRemainingTime("5h"), 300)
    }

    func testParseRemainingTime_MinutesOnly() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseRemainingTime("45m"), 45)
        XCTAssertEqual(service.testParseRemainingTime("90m"), 90)
        XCTAssertEqual(service.testParseRemainingTime("5m"), 5)
    }

    func testParseRemainingTime_DecimalMinutes() {
        let service = HAAPIService()

        // Decimal values should be truncated to integer minutes
        XCTAssertEqual(service.testParseRemainingTime("1.5"), 1)
        XCTAssertEqual(service.testParseRemainingTime("2.9"), 2)
        XCTAssertEqual(service.testParseRemainingTime("0.5"), 0)
        XCTAssertEqual(service.testParseRemainingTime("45.7"), 45)
    }

    func testParseRemainingTime_EmptyString() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseRemainingTime(""), 0)
        XCTAssertEqual(service.testParseRemainingTime("   "), 0)
    }

    func testParseRemainingTime_InvalidInput() {
        let service = HAAPIService()

        // Invalid formats should return 0
        XCTAssertEqual(service.testParseRemainingTime("abc"), 0)
        XCTAssertEqual(service.testParseRemainingTime("unknown"), 0)
    }

    func testParseRemainingTime_CaseInsensitive() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseRemainingTime("1H 30M"), 90)
        XCTAssertEqual(service.testParseRemainingTime("2H"), 120)
        XCTAssertEqual(service.testParseRemainingTime("45M"), 45)
    }

    func testParseRemainingTime_ExtraWhitespace() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseRemainingTime("  1h  30m  "), 90)
        XCTAssertEqual(service.testParseRemainingTime("  2h  "), 120)
        XCTAssertEqual(service.testParseRemainingTime("  45  "), 45)
    }

    // MARK: - parseFilamentUsed Tests

    func testParseFilamentUsed_PlainNumber() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseFilamentUsed("100"), 100.0)
        XCTAssertEqual(service.testParseFilamentUsed("0"), 0.0)
        XCTAssertEqual(service.testParseFilamentUsed("50.5"), 50.5)
        XCTAssertEqual(service.testParseFilamentUsed("1234.56"), 1234.56)
    }

    func testParseFilamentUsed_WithGramsSuffix() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseFilamentUsed("100g"), 100.0)
        XCTAssertEqual(service.testParseFilamentUsed("100 grams"), 100.0)
        XCTAssertEqual(service.testParseFilamentUsed("50 gram"), 50.0)
        XCTAssertEqual(service.testParseFilamentUsed("75.5g"), 75.5)
    }

    func testParseFilamentUsed_MetersToGrams() {
        let service = HAAPIService()

        // 10m should convert to 29.6 grams (10 * 2.96)
        XCTAssertEqual(service.testParseFilamentUsed("10m"), 29.6, accuracy: 0.01)

        // 1m should convert to 2.96 grams
        XCTAssertEqual(service.testParseFilamentUsed("1m"), 2.96, accuracy: 0.01)

        // 100m should convert to 296 grams
        XCTAssertEqual(service.testParseFilamentUsed("100m"), 296.0, accuracy: 0.01)

        // 0m should be 0 grams
        XCTAssertEqual(service.testParseFilamentUsed("0m"), 0.0)
    }

    func testParseFilamentUsed_NotMillimeters() {
        let service = HAAPIService()

        // "mm" should be stripped but not treated as meters
        XCTAssertEqual(service.testParseFilamentUsed("100mm"), 100.0)
        XCTAssertEqual(service.testParseFilamentUsed("50mm"), 50.0)
    }

    func testParseFilamentUsed_EmptyString() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseFilamentUsed(""), 0.0)
        XCTAssertEqual(service.testParseFilamentUsed("   "), 0.0)
    }

    func testParseFilamentUsed_InvalidInput() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseFilamentUsed("abc"), 0.0)
        XCTAssertEqual(service.testParseFilamentUsed("unknown"), 0.0)
    }

    func testParseFilamentUsed_CaseInsensitive() {
        let service = HAAPIService()

        XCTAssertEqual(service.testParseFilamentUsed("100G"), 100.0)
        XCTAssertEqual(service.testParseFilamentUsed("100 GRAMS"), 100.0)
        XCTAssertEqual(service.testParseFilamentUsed("10M"), 29.6, accuracy: 0.01)
    }

    // MARK: - detectPrinterModel Tests

    func testDetectPrinterModel_X1C() {
        let service = HAAPIService()
        service.testSetEntityPrefix("x1c_printer")

        XCTAssertEqual(service.testDetectPrinterModel(), .x1c)
    }

    func testDetectPrinterModel_X1C_Variants() {
        let service = HAAPIService()

        service.testSetEntityPrefix("x1_c_test")
        XCTAssertEqual(service.testDetectPrinterModel(), .x1c)

        service.testSetEntityPrefix("x1carbon")
        XCTAssertEqual(service.testDetectPrinterModel(), .x1c)

        service.testSetEntityPrefix("X1C")
        XCTAssertEqual(service.testDetectPrinterModel(), .x1c)
    }

    func testDetectPrinterModel_X1E() {
        let service = HAAPIService()
        service.testSetEntityPrefix("x1e_printer")

        XCTAssertEqual(service.testDetectPrinterModel(), .x1e)
    }

    func testDetectPrinterModel_P1P() {
        let service = HAAPIService()
        service.testSetEntityPrefix("p1p_printer")

        XCTAssertEqual(service.testDetectPrinterModel(), .p1p)
    }

    func testDetectPrinterModel_P1S() {
        let service = HAAPIService()
        service.testSetEntityPrefix("bambu_p1s")

        XCTAssertEqual(service.testDetectPrinterModel(), .p1s)
    }

    func testDetectPrinterModel_A1() {
        let service = HAAPIService()
        service.testSetEntityPrefix("a1_printer")

        XCTAssertEqual(service.testDetectPrinterModel(), .a1)
    }

    func testDetectPrinterModel_A1Mini() {
        let service = HAAPIService()
        service.testSetEntityPrefix("a1mini_test")

        XCTAssertEqual(service.testDetectPrinterModel(), .a1mini)
    }

    func testDetectPrinterModel_A1Mini_Variants() {
        let service = HAAPIService()

        service.testSetEntityPrefix("a1_mini_printer")
        XCTAssertEqual(service.testDetectPrinterModel(), .a1mini)

        service.testSetEntityPrefix("A1MINI")
        XCTAssertEqual(service.testDetectPrinterModel(), .a1mini)
    }

    func testDetectPrinterModel_H2S_DefaultToX1C() {
        let service = HAAPIService()
        service.testSetEntityPrefix("h2s")

        // h2s is a common prefix that defaults to X1C
        XCTAssertEqual(service.testDetectPrinterModel(), .x1c)
    }

    func testDetectPrinterModel_Bambu_DefaultToX1C() {
        let service = HAAPIService()
        service.testSetEntityPrefix("bambu_printer")

        // Generic "bambu" prefix defaults to X1C
        XCTAssertEqual(service.testDetectPrinterModel(), .x1c)
    }

    func testDetectPrinterModel_Unknown() {
        let service = HAAPIService()
        service.testSetEntityPrefix("unknown_prefix")

        XCTAssertEqual(service.testDetectPrinterModel(), .unknown)
    }

    func testDetectPrinterModel_Empty() {
        let service = HAAPIService()
        service.testSetEntityPrefix("")

        XCTAssertEqual(service.testDetectPrinterModel(), .unknown)
    }

    // MARK: - HAAPIError Tests

    func testHAAPIError_InvalidURL() {
        let error = HAAPIError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid server URL")
    }

    func testHAAPIError_InvalidResponse() {
        let error = HAAPIError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Invalid response from server")
    }

    func testHAAPIError_Unauthorized() {
        let error = HAAPIError.unauthorized
        XCTAssertEqual(error.errorDescription, "Unauthorized - check your access token")
    }

    func testHAAPIError_HTTPError() {
        let error = HAAPIError.httpError(statusCode: 404)
        XCTAssertEqual(error.errorDescription, "HTTP Error: 404")

        let error500 = HAAPIError.httpError(statusCode: 500)
        XCTAssertEqual(error500.errorDescription, "HTTP Error: 500")
    }

    func testHAAPIError_DecodingError() {
        let error = HAAPIError.decodingError
        XCTAssertEqual(error.errorDescription, "Failed to parse server response")
    }

    func testHAAPIError_EntityNotFound() {
        let error = HAAPIError.entityNotFound("sensor.test_entity")
        XCTAssertEqual(error.errorDescription, "Entity not found: sensor.test_entity")
    }

    // MARK: - HAEntityData Helper Tests

    func testHAEntityData_StringAttribute() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "on",
            attributes: [
                "name": "Test Name",
                "description": "Test Description"
            ]
        )

        XCTAssertEqual(entity.stringAttribute("name"), "Test Name")
        XCTAssertEqual(entity.stringAttribute("description"), "Test Description")
        XCTAssertNil(entity.stringAttribute("nonexistent"))
    }

    func testHAEntityData_IntAttribute() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "100",
            attributes: [
                "int_value": 42,
                "double_value": 3.14,
                "string_value": "123"
            ]
        )

        XCTAssertEqual(entity.intAttribute("int_value"), 42)
        XCTAssertEqual(entity.intAttribute("double_value"), 3)
        XCTAssertEqual(entity.intAttribute("string_value"), 123)
        XCTAssertNil(entity.intAttribute("nonexistent"))
    }

    func testHAEntityData_IntAttribute_InvalidString() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "on",
            attributes: [
                "invalid": "abc"
            ]
        )

        XCTAssertNil(entity.intAttribute("invalid"))
    }

    func testHAEntityData_DoubleAttribute() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "100.5",
            attributes: [
                "double_value": 3.14,
                "int_value": 42,
                "string_value": "123.45"
            ]
        )

        XCTAssertEqual(entity.doubleAttribute("double_value"), 3.14)
        XCTAssertEqual(entity.doubleAttribute("int_value"), 42.0)
        XCTAssertEqual(entity.doubleAttribute("string_value"), 123.45)
        XCTAssertNil(entity.doubleAttribute("nonexistent"))
    }

    func testHAEntityData_DoubleAttribute_InvalidString() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "on",
            attributes: [
                "invalid": "abc"
            ]
        )

        XCTAssertNil(entity.doubleAttribute("invalid"))
    }

    func testHAEntityData_BoolAttribute() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "on",
            attributes: [
                "bool_true": true,
                "bool_false": false,
                "string_true": "true",
                "string_false": "false",
                "string_1": "1",
                "int_1": 1,
                "int_0": 0
            ]
        )

        XCTAssertEqual(entity.boolAttribute("bool_true"), true)
        XCTAssertEqual(entity.boolAttribute("bool_false"), false)
        XCTAssertEqual(entity.boolAttribute("string_true"), true)
        XCTAssertEqual(entity.boolAttribute("string_false"), false)
        XCTAssertEqual(entity.boolAttribute("string_1"), true)
        XCTAssertEqual(entity.boolAttribute("int_1"), true)
        XCTAssertEqual(entity.boolAttribute("int_0"), false)
        XCTAssertNil(entity.boolAttribute("nonexistent"))
    }

    func testHAEntityData_BoolAttribute_CaseInsensitive() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "on",
            attributes: [
                "upper": "TRUE",
                "mixed": "True"
            ]
        )

        XCTAssertEqual(entity.boolAttribute("upper"), true)
        XCTAssertEqual(entity.boolAttribute("mixed"), true)
    }

    func testHAEntityData_BoolAttribute_InvalidString() {
        let entity = HAEntityData(
            entityId: "test.entity",
            state: "on",
            attributes: [
                "invalid": "abc"
            ]
        )

        XCTAssertEqual(entity.boolAttribute("invalid"), false)
    }
}

// MARK: - Test Extension for HAAPIService

/// Extension to expose private methods for testing
extension HAAPIService {
    /// Test wrapper for parseRemainingTime
    func testParseRemainingTime(_ timeString: String) -> Int {
        return parseRemainingTime(timeString)
    }

    /// Test wrapper for parseFilamentUsed
    func testParseFilamentUsed(_ filamentString: String) -> Double {
        return parseFilamentUsed(filamentString)
    }

    /// Test wrapper for detectPrinterModel
    func testDetectPrinterModel() -> PrinterState.PrinterModel {
        return detectPrinterModel()
    }

    /// Test helper to set entity prefix
    func testSetEntityPrefix(_ prefix: String) {
        // Configure with mock settings that include the desired prefix
        let settings = AppSettings(
            haServerURL: "http://test.local",
            haAccessToken: "test_token",
            entityPrefix: prefix,
            refreshInterval: 30,
            accentColor: .cyan,
            showProgress: true,
            showLayers: true,
            showTimeRemaining: true,
            showNozzleTemp: true,
            showBedTemp: true,
            showPrintSpeed: false,
            showFilamentUsed: false,
            compactMode: false,
            notificationSettings: .default
        )
        configure(with: settings)
    }
}
