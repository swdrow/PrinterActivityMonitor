import XCTest
import SwiftUI
@testable import PrinterActivityMonitor

final class PrinterStateTests: XCTestCase {

    // MARK: - PrinterState Initialization Tests

    func testPrinterStateInitializationWithAllProperties() {
        // Given
        let startDate = Date()
        let endDate = Date().addingTimeInterval(3600)

        // When
        let printerState = PrinterState(
            progress: 50,
            currentLayer: 100,
            totalLayers: 200,
            remainingMinutes: 120,
            status: .running,
            fileName: "test_model.3mf",
            printSpeed: 150,
            filamentUsed: 25.5,
            nozzleTemp: 220.0,
            nozzleTargetTemp: 220.0,
            bedTemp: 60.0,
            bedTargetTemp: 60.0,
            chamberTemp: 35.0,
            currentStage: "Printing",
            printWeight: 50.0,
            printLength: 100.0,
            bedType: "Cool Plate",
            startTime: startDate,
            endTime: endDate,
            auxFanSpeed: 50,
            chamberFanSpeed: 75,
            coolingFanSpeed: 100,
            isOnline: true,
            wifiSignal: -45,
            hmsErrors: "",
            coverImageURL: "https://example.com/image.png",
            printerModel: .x1c
        )

        // Then
        XCTAssertEqual(printerState.progress, 50)
        XCTAssertEqual(printerState.currentLayer, 100)
        XCTAssertEqual(printerState.totalLayers, 200)
        XCTAssertEqual(printerState.remainingMinutes, 120)
        XCTAssertEqual(printerState.status, .running)
        XCTAssertEqual(printerState.fileName, "test_model.3mf")
        XCTAssertEqual(printerState.printSpeed, 150)
        XCTAssertEqual(printerState.filamentUsed, 25.5)
        XCTAssertEqual(printerState.nozzleTemp, 220.0)
        XCTAssertEqual(printerState.nozzleTargetTemp, 220.0)
        XCTAssertEqual(printerState.bedTemp, 60.0)
        XCTAssertEqual(printerState.bedTargetTemp, 60.0)
        XCTAssertEqual(printerState.chamberTemp, 35.0)
        XCTAssertEqual(printerState.currentStage, "Printing")
        XCTAssertEqual(printerState.printWeight, 50.0)
        XCTAssertEqual(printerState.printLength, 100.0)
        XCTAssertEqual(printerState.bedType, "Cool Plate")
        XCTAssertEqual(printerState.startTime, startDate)
        XCTAssertEqual(printerState.endTime, endDate)
        XCTAssertEqual(printerState.auxFanSpeed, 50)
        XCTAssertEqual(printerState.chamberFanSpeed, 75)
        XCTAssertEqual(printerState.coolingFanSpeed, 100)
        XCTAssertTrue(printerState.isOnline)
        XCTAssertEqual(printerState.wifiSignal, -45)
        XCTAssertEqual(printerState.hmsErrors, "")
        XCTAssertEqual(printerState.coverImageURL, "https://example.com/image.png")
        XCTAssertEqual(printerState.printerModel, .x1c)
    }

    func testPrinterStatePlaceholder() {
        // When
        let placeholder = PrinterState.placeholder

        // Then
        XCTAssertEqual(placeholder.progress, 0)
        XCTAssertEqual(placeholder.currentLayer, 0)
        XCTAssertEqual(placeholder.totalLayers, 0)
        XCTAssertEqual(placeholder.remainingMinutes, 0)
        XCTAssertEqual(placeholder.status, .idle)
        XCTAssertEqual(placeholder.fileName, "No print")
        XCTAssertEqual(placeholder.printSpeed, 100)
        XCTAssertEqual(placeholder.filamentUsed, 0)
        XCTAssertEqual(placeholder.nozzleTemp, 0)
        XCTAssertEqual(placeholder.nozzleTargetTemp, 0)
        XCTAssertEqual(placeholder.bedTemp, 0)
        XCTAssertEqual(placeholder.bedTargetTemp, 0)
        XCTAssertEqual(placeholder.chamberTemp, 0)
        XCTAssertEqual(placeholder.currentStage, "")
        XCTAssertEqual(placeholder.printWeight, 0)
        XCTAssertEqual(placeholder.printLength, 0)
        XCTAssertEqual(placeholder.bedType, "")
        XCTAssertNil(placeholder.startTime)
        XCTAssertNil(placeholder.endTime)
        XCTAssertEqual(placeholder.auxFanSpeed, 0)
        XCTAssertEqual(placeholder.chamberFanSpeed, 0)
        XCTAssertEqual(placeholder.coolingFanSpeed, 0)
        XCTAssertFalse(placeholder.isOnline)
        XCTAssertEqual(placeholder.wifiSignal, 0)
        XCTAssertEqual(placeholder.hmsErrors, "")
        XCTAssertNil(placeholder.coverImageURL)
        XCTAssertEqual(placeholder.printerModel, .unknown)
    }

    // MARK: - PrintStatus Enum Tests

    func testPrintStatusRawValueParsing() {
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "idle"), .idle)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "running"), .running)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "pause"), .paused)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "finish"), .finish)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "failed"), .failed)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "prepare"), .prepare)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "slicing"), .slicing)
        XCTAssertEqual(PrinterState.PrintStatus(rawValue: "unknown"), .unknown)

        // Test invalid raw value returns nil
        XCTAssertNil(PrinterState.PrintStatus(rawValue: "invalid_status"))
        XCTAssertNil(PrinterState.PrintStatus(rawValue: ""))
    }

    func testPrintStatusDisplayName() {
        XCTAssertEqual(PrinterState.PrintStatus.idle.displayName, "Idle")
        XCTAssertEqual(PrinterState.PrintStatus.running.displayName, "Printing")
        XCTAssertEqual(PrinterState.PrintStatus.paused.displayName, "Paused")
        XCTAssertEqual(PrinterState.PrintStatus.finish.displayName, "Finished")
        XCTAssertEqual(PrinterState.PrintStatus.failed.displayName, "Failed")
        XCTAssertEqual(PrinterState.PrintStatus.prepare.displayName, "Preparing")
        XCTAssertEqual(PrinterState.PrintStatus.slicing.displayName, "Slicing")
        XCTAssertEqual(PrinterState.PrintStatus.unknown.displayName, "Unknown")
    }

    func testPrintStatusColor() {
        XCTAssertEqual(PrinterState.PrintStatus.idle.color, .gray)
        XCTAssertEqual(PrinterState.PrintStatus.running.color, .green)
        XCTAssertEqual(PrinterState.PrintStatus.paused.color, .orange)
        XCTAssertEqual(PrinterState.PrintStatus.finish.color, .blue)
        XCTAssertEqual(PrinterState.PrintStatus.failed.color, .red)
        XCTAssertEqual(PrinterState.PrintStatus.prepare.color, .yellow)
        XCTAssertEqual(PrinterState.PrintStatus.slicing.color, .purple)
        XCTAssertEqual(PrinterState.PrintStatus.unknown.color, .gray)
    }

    func testPrintStatusIcon() {
        XCTAssertEqual(PrinterState.PrintStatus.idle.icon, "moon.zzz.fill")
        XCTAssertEqual(PrinterState.PrintStatus.running.icon, "play.circle.fill")
        XCTAssertEqual(PrinterState.PrintStatus.paused.icon, "pause.circle.fill")
        XCTAssertEqual(PrinterState.PrintStatus.finish.icon, "checkmark.circle.fill")
        XCTAssertEqual(PrinterState.PrintStatus.failed.icon, "xmark.circle.fill")
        XCTAssertEqual(PrinterState.PrintStatus.prepare.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(PrinterState.PrintStatus.slicing.icon, "scissors")
        XCTAssertEqual(PrinterState.PrintStatus.unknown.icon, "questionmark.circle.fill")
    }

    // MARK: - PrinterModel Enum Tests

    func testPrinterModelRawValue() {
        XCTAssertEqual(PrinterState.PrinterModel.x1c.rawValue, "X1 Carbon")
        XCTAssertEqual(PrinterState.PrinterModel.x1e.rawValue, "X1E")
        XCTAssertEqual(PrinterState.PrinterModel.p1p.rawValue, "P1P")
        XCTAssertEqual(PrinterState.PrinterModel.p1s.rawValue, "P1S")
        XCTAssertEqual(PrinterState.PrinterModel.a1.rawValue, "A1")
        XCTAssertEqual(PrinterState.PrinterModel.a1mini.rawValue, "A1 Mini")
        XCTAssertEqual(PrinterState.PrinterModel.unknown.rawValue, "Unknown")
    }

    func testPrinterModelIcon() {
        XCTAssertEqual(PrinterState.PrinterModel.x1c.icon, "cube.fill")
        XCTAssertEqual(PrinterState.PrinterModel.x1e.icon, "cube.fill")
        XCTAssertEqual(PrinterState.PrinterModel.p1p.icon, "printer.fill")
        XCTAssertEqual(PrinterState.PrinterModel.p1s.icon, "printer.fill")
        XCTAssertEqual(PrinterState.PrinterModel.a1.icon, "printer.fill")
        XCTAssertEqual(PrinterState.PrinterModel.a1mini.icon, "printer.fill")
        XCTAssertEqual(PrinterState.PrinterModel.unknown.icon, "questionmark.circle.fill")
    }

    func testPrinterModelColor() {
        XCTAssertEqual(PrinterState.PrinterModel.x1c.color, .orange)
        XCTAssertEqual(PrinterState.PrinterModel.x1e.color, .purple)
        XCTAssertEqual(PrinterState.PrinterModel.p1p.color, .blue)
        XCTAssertEqual(PrinterState.PrinterModel.p1s.color, .cyan)
        XCTAssertEqual(PrinterState.PrinterModel.a1.color, .green)
        XCTAssertEqual(PrinterState.PrinterModel.a1mini.color, .mint)
        XCTAssertEqual(PrinterState.PrinterModel.unknown.color, .gray)
    }

    // MARK: - Computed Properties Tests

    func testFormattedTimeRemainingHoursAndMinutes() {
        // Given
        var printerState = PrinterState.placeholder

        // When: 2 hours 30 minutes
        printerState.remainingMinutes = 150

        // Then
        XCTAssertEqual(printerState.formattedTimeRemaining, "2h 30m")
    }

    func testFormattedTimeRemainingOnlyMinutes() {
        // Given
        var printerState = PrinterState.placeholder

        // When: 45 minutes
        printerState.remainingMinutes = 45

        // Then
        XCTAssertEqual(printerState.formattedTimeRemaining, "45m")
    }

    func testFormattedTimeRemainingExactHours() {
        // Given
        var printerState = PrinterState.placeholder

        // When: 3 hours exactly
        printerState.remainingMinutes = 180

        // Then
        XCTAssertEqual(printerState.formattedTimeRemaining, "3h 0m")
    }

    func testFormattedTimeRemainingZero() {
        // Given
        var printerState = PrinterState.placeholder

        // When: 0 minutes
        printerState.remainingMinutes = 0

        // Then
        XCTAssertEqual(printerState.formattedTimeRemaining, "0m")
    }

    func testFormattedTimeRemainingLargeValue() {
        // Given
        var printerState = PrinterState.placeholder

        // When: 24 hours 1 minute
        printerState.remainingMinutes = 1441

        // Then
        XCTAssertEqual(printerState.formattedTimeRemaining, "24h 1m")
    }

    func testLayerProgress() {
        // Given
        var printerState = PrinterState.placeholder

        // When
        printerState.currentLayer = 150
        printerState.totalLayers = 300

        // Then
        XCTAssertEqual(printerState.layerProgress, "150/300")
    }

    func testLayerProgressZeroLayers() {
        // Given
        var printerState = PrinterState.placeholder

        // When
        printerState.currentLayer = 0
        printerState.totalLayers = 0

        // Then
        XCTAssertEqual(printerState.layerProgress, "0/0")
    }

    func testFormattedNozzleTempWithTarget() {
        // Given
        var printerState = PrinterState.placeholder

        // When: Target temperature is set
        printerState.nozzleTemp = 219.8
        printerState.nozzleTargetTemp = 220.0

        // Then
        XCTAssertEqual(printerState.formattedNozzleTemp, "219°/220°")
    }

    func testFormattedNozzleTempWithoutTarget() {
        // Given
        var printerState = PrinterState.placeholder

        // When: No target temperature
        printerState.nozzleTemp = 25.3
        printerState.nozzleTargetTemp = 0

        // Then
        XCTAssertEqual(printerState.formattedNozzleTemp, "25°C")
    }

    func testFormattedNozzleTempRounding() {
        // Given
        var printerState = PrinterState.placeholder

        // When: Temperature with decimals
        printerState.nozzleTemp = 219.4
        printerState.nozzleTargetTemp = 220.7

        // Then: Should round down
        XCTAssertEqual(printerState.formattedNozzleTemp, "219°/220°")
    }

    func testFormattedBedTempWithTarget() {
        // Given
        var printerState = PrinterState.placeholder

        // When: Target temperature is set
        printerState.bedTemp = 59.8
        printerState.bedTargetTemp = 60.0

        // Then
        XCTAssertEqual(printerState.formattedBedTemp, "59°/60°")
    }

    func testFormattedBedTempWithoutTarget() {
        // Given
        var printerState = PrinterState.placeholder

        // When: No target temperature
        printerState.bedTemp = 23.5
        printerState.bedTargetTemp = 0

        // Then
        XCTAssertEqual(printerState.formattedBedTemp, "23°C")
    }

    func testFormattedChamberTemp() {
        // Given
        var printerState = PrinterState.placeholder

        // When
        printerState.chamberTemp = 35.7

        // Then
        XCTAssertEqual(printerState.formattedChamberTemp, "35°C")
    }

    func testFormattedChamberTempZero() {
        // Given
        var printerState = PrinterState.placeholder

        // When
        printerState.chamberTemp = 0.0

        // Then
        XCTAssertEqual(printerState.formattedChamberTemp, "0°C")
    }

    // MARK: - Codable Tests

    func testPrinterStateCodable() throws {
        // Given
        let originalState = PrinterState(
            progress: 75,
            currentLayer: 200,
            totalLayers: 250,
            remainingMinutes: 30,
            status: .running,
            fileName: "test.3mf",
            printSpeed: 120,
            filamentUsed: 15.5,
            nozzleTemp: 220.0,
            nozzleTargetTemp: 220.0,
            bedTemp: 60.0,
            bedTargetTemp: 60.0,
            chamberTemp: 35.0,
            currentStage: "Printing",
            printWeight: 30.0,
            printLength: 75.0,
            bedType: "Textured PEI",
            startTime: Date(timeIntervalSince1970: 1700000000),
            endTime: Date(timeIntervalSince1970: 1700003600),
            auxFanSpeed: 60,
            chamberFanSpeed: 80,
            coolingFanSpeed: 100,
            isOnline: true,
            wifiSignal: -50,
            hmsErrors: "",
            coverImageURL: "https://example.com/cover.png",
            printerModel: .p1s
        )

        // When: Encode and decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(PrinterState.self, from: data)

        // Then
        XCTAssertEqual(decodedState, originalState)
    }

    func testPrinterStateEquatable() {
        // Given
        let state1 = PrinterState.placeholder
        let state2 = PrinterState.placeholder

        // Then
        XCTAssertEqual(state1, state2)
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableWithInt() throws {
        // Given
        let intValue = AnyCodable(42)

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(intValue)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testAnyCodableWithDouble() throws {
        // Given
        let doubleValue = AnyCodable(3.14159)

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(doubleValue)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? Double, 3.14159)
    }

    func testAnyCodableWithString() throws {
        // Given
        let stringValue = AnyCodable("Hello World")

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(stringValue)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? String, "Hello World")
    }

    func testAnyCodableWithBool() throws {
        // Given
        let boolValue = AnyCodable(true)

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(boolValue)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testAnyCodableDecodesIntFromJSON() throws {
        // Given
        let json = "42"
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testAnyCodableDecodesDoubleFromJSON() throws {
        // Given
        let json = "3.14159"
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? Double, 3.14159)
    }

    func testAnyCodableDecodesStringFromJSON() throws {
        // Given
        let json = "\"Hello World\""
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? String, "Hello World")
    }

    func testAnyCodableDecodesBoolFromJSON() throws {
        // Given
        let json = "true"
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then
        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testAnyCodableHandlesInvalidType() throws {
        // Given: JSON array which is not supported
        let json = "[]"
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Then: Should fall back to empty string
        XCTAssertEqual(decoded.value as? String, "")
    }

    // MARK: - HAStateResponse Tests

    func testHAStateResponseDecoding() throws {
        // Given
        let json = """
        {
            "entity_id": "sensor.h2s_print_progress",
            "state": "75",
            "attributes": {
                "friendly_name": "Print Progress",
                "unit_of_measurement": "%"
            },
            "last_changed": "2024-01-12T10:30:00.000000+00:00",
            "last_updated": "2024-01-12T10:30:05.000000+00:00"
        }
        """
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let response = try decoder.decode(HAStateResponse.self, from: data)

        // Then
        XCTAssertEqual(response.entityId, "sensor.h2s_print_progress")
        XCTAssertEqual(response.state, "75")
        XCTAssertNotNil(response.attributes)
        XCTAssertEqual(response.lastChanged, "2024-01-12T10:30:00.000000+00:00")
        XCTAssertEqual(response.lastUpdated, "2024-01-12T10:30:05.000000+00:00")

        // Verify attributes
        let friendlyName = response.attributes?["friendly_name"]?.value as? String
        XCTAssertEqual(friendlyName, "Print Progress")

        let unit = response.attributes?["unit_of_measurement"]?.value as? String
        XCTAssertEqual(unit, "%")
    }

    func testHAStateResponseEncodingDecoding() throws {
        // Given
        let attributes: [String: AnyCodable] = [
            "temperature": AnyCodable(220.5),
            "enabled": AnyCodable(true),
            "count": AnyCodable(42),
            "name": AnyCodable("Test Sensor")
        ]

        let originalResponse = HAStateResponse(
            entityId: "sensor.test_entity",
            state: "active",
            attributes: attributes,
            lastChanged: "2024-01-12T10:00:00Z",
            lastUpdated: "2024-01-12T10:00:05Z"
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalResponse)
        let decoder = JSONDecoder()
        let decodedResponse = try decoder.decode(HAStateResponse.self, from: data)

        // Then
        XCTAssertEqual(decodedResponse.entityId, originalResponse.entityId)
        XCTAssertEqual(decodedResponse.state, originalResponse.state)
        XCTAssertEqual(decodedResponse.lastChanged, originalResponse.lastChanged)
        XCTAssertEqual(decodedResponse.lastUpdated, originalResponse.lastUpdated)

        // Verify attributes
        XCTAssertEqual(decodedResponse.attributes?["temperature"]?.value as? Double, 220.5)
        XCTAssertEqual(decodedResponse.attributes?["enabled"]?.value as? Bool, true)
        XCTAssertEqual(decodedResponse.attributes?["count"]?.value as? Int, 42)
        XCTAssertEqual(decodedResponse.attributes?["name"]?.value as? String, "Test Sensor")
    }

    func testHAStateResponseWithNullAttributes() throws {
        // Given
        let json = """
        {
            "entity_id": "sensor.test",
            "state": "on"
        }
        """
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let response = try decoder.decode(HAStateResponse.self, from: data)

        // Then
        XCTAssertEqual(response.entityId, "sensor.test")
        XCTAssertEqual(response.state, "on")
        XCTAssertNil(response.attributes)
        XCTAssertNil(response.lastChanged)
        XCTAssertNil(response.lastUpdated)
    }

    func testHAStateResponseCodingKeys() throws {
        // Given: JSON with snake_case keys
        let json = """
        {
            "entity_id": "sensor.printer",
            "state": "printing",
            "last_changed": "2024-01-12T10:00:00Z",
            "last_updated": "2024-01-12T10:00:05Z"
        }
        """
        let data = json.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let response = try decoder.decode(HAStateResponse.self, from: data)

        // Then: Should properly decode snake_case to camelCase
        XCTAssertEqual(response.entityId, "sensor.printer")
        XCTAssertEqual(response.lastChanged, "2024-01-12T10:00:00Z")
        XCTAssertEqual(response.lastUpdated, "2024-01-12T10:00:05Z")
    }

    // MARK: - Edge Cases and Integration Tests

    func testPrinterStateWithOptionalValues() {
        // Given: State with nil optional values
        var printerState = PrinterState.placeholder

        // Then
        XCTAssertNil(printerState.startTime)
        XCTAssertNil(printerState.endTime)
        XCTAssertNil(printerState.coverImageURL)
    }

    func testFormattedTemperaturesWithNegativeValues() {
        // Given
        var printerState = PrinterState.placeholder

        // When: Unlikely but possible negative values
        printerState.nozzleTemp = -5.0
        printerState.nozzleTargetTemp = 0

        // Then: Should handle gracefully
        XCTAssertEqual(printerState.formattedNozzleTemp, "-5°C")
    }

    func testLayerProgressWithLargeNumbers() {
        // Given
        var printerState = PrinterState.placeholder

        // When: Very large layer counts
        printerState.currentLayer = 9999
        printerState.totalLayers = 10000

        // Then
        XCTAssertEqual(printerState.layerProgress, "9999/10000")
    }

    func testPrintStatusEnumCodable() throws {
        // Given
        let statuses: [PrinterState.PrintStatus] = [
            .idle, .running, .paused, .finish, .failed, .prepare, .slicing, .unknown
        ]

        for status in statuses {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(status)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(PrinterState.PrintStatus.self, from: data)

            // Then
            XCTAssertEqual(decoded, status)
        }
    }

    func testPrinterModelEnumCodable() throws {
        // Given
        let models: [PrinterState.PrinterModel] = [
            .x1c, .x1e, .p1p, .p1s, .a1, .a1mini, .unknown
        ]

        for model in models {
            // When
            let encoder = JSONEncoder()
            let data = try encoder.encode(model)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(PrinterState.PrinterModel.self, from: data)

            // Then
            XCTAssertEqual(decoded, model)
        }
    }
}
