import XCTest
@testable import PrinterActivityMonitor

final class EntityDiscoveryServiceTests: XCTestCase {

    // MARK: - Test Data Helpers

    /// Create a mock entity dictionary
    private func makeEntity(
        id: String,
        state: String = "unknown",
        friendlyName: String? = nil
    ) -> [String: Any] {
        var entity: [String: Any] = [
            "entity_id": id,
            "state": state,
            "last_changed": "2024-01-10T12:00:00.000000+00:00",
            "last_updated": "2024-01-10T12:00:00.000000+00:00"
        ]

        if let name = friendlyName {
            entity["attributes"] = ["friendly_name": name]
        }

        return entity
    }

    // MARK: - Basic Discovery Tests

    func testDiscoverDevices_withEmptyEntityList_returnsEmptyResults() {
        // Given
        let emptyEntities: [[String: Any]] = []

        // When
        let result = EntityDiscoveryService.discoverDevices(from: emptyEntities)

        // Then
        XCTAssertTrue(result.printers.isEmpty, "Should find no printers in empty entity list")
        XCTAssertTrue(result.amsUnits.isEmpty, "Should find no AMS units in empty entity list")
    }

    func testDiscoverDevices_withNoMatchingEntities_returnsEmptyResults() {
        // Given
        let unrelatedEntities = [
            makeEntity(id: "light.bedroom_light"),
            makeEntity(id: "switch.kitchen_switch"),
            makeEntity(id: "sensor.temperature"),
            makeEntity(id: "binary_sensor.motion")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: unrelatedEntities)

        // Then
        XCTAssertTrue(result.printers.isEmpty, "Should find no printers in unrelated entities")
        XCTAssertTrue(result.amsUnits.isEmpty, "Should find no AMS units in unrelated entities")
    }

    // MARK: - Printer Discovery Tests

    func testDiscoverDevices_withSinglePrinter_discoversCorrectly() {
        // Given
        let entities = [
            makeEntity(id: "sensor.h2s_print_progress", state: "50", friendlyName: "H2S Print progress"),
            makeEntity(id: "sensor.h2s_print_status", state: "printing", friendlyName: "H2S Print status"),
            makeEntity(id: "sensor.h2s_current_layer", state: "100"),
            makeEntity(id: "sensor.h2s_total_layer_count", state: "200"),
            makeEntity(id: "sensor.h2s_remaining_time", state: "120"),
            makeEntity(id: "sensor.h2s_nozzle_temperature", state: "220"),
            makeEntity(id: "sensor.h2s_bed_temperature", state: "60")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1, "Should discover exactly one printer")

        let printer = result.printers[0]
        XCTAssertEqual(printer.prefix, "h2s", "Should extract correct prefix")
        XCTAssertEqual(printer.name, "H2S", "Should extract friendly name from print_status entity")
        XCTAssertEqual(printer.entityCount, 7, "Should count all matching entities")
    }

    func testDiscoverDevices_withMultiplePrinters_discoversAll() {
        // Given
        let entities = [
            // Printer 1: h2s
            makeEntity(id: "sensor.h2s_print_progress", state: "50", friendlyName: "H2S Print progress"),
            makeEntity(id: "sensor.h2s_print_status", state: "printing", friendlyName: "H2S Print status"),
            makeEntity(id: "sensor.h2s_current_layer", state: "100"),

            // Printer 2: bambu_x1c
            makeEntity(id: "sensor.bambu_x1c_print_progress", state: "75"),
            makeEntity(id: "sensor.bambu_x1c_print_status", state: "idle", friendlyName: "Bambu X1C Print status"),
            makeEntity(id: "sensor.bambu_x1c_nozzle_temperature", state: "220"),
            makeEntity(id: "sensor.bambu_x1c_bed_temperature", state: "60"),

            // Printer 3: p1s_garage
            makeEntity(id: "sensor.p1s_garage_print_progress", state: "0"),
            makeEntity(id: "sensor.p1s_garage_print_status", state: "idle")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 3, "Should discover all three printers")

        let prefixes = Set(result.printers.map { $0.prefix })
        XCTAssertTrue(prefixes.contains("h2s"))
        XCTAssertTrue(prefixes.contains("bambu_x1c"))
        XCTAssertTrue(prefixes.contains("p1s_garage"))
    }

    func testDiscoverDevices_sortsLargestEntityCountFirst() {
        // Given
        let entities = [
            // Printer 1 with 2 entities
            makeEntity(id: "sensor.minimal_printer_print_progress"),
            makeEntity(id: "sensor.minimal_printer_print_status"),

            // Printer 2 with 5 entities
            makeEntity(id: "sensor.full_printer_print_progress"),
            makeEntity(id: "sensor.full_printer_print_status"),
            makeEntity(id: "sensor.full_printer_current_layer"),
            makeEntity(id: "sensor.full_printer_nozzle_temperature"),
            makeEntity(id: "sensor.full_printer_bed_temperature")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 2)
        XCTAssertEqual(result.printers[0].prefix, "full_printer", "Printer with most entities should be first")
        XCTAssertEqual(result.printers[0].entityCount, 5)
        XCTAssertEqual(result.printers[1].prefix, "minimal_printer")
        XCTAssertEqual(result.printers[1].entityCount, 2)
    }

    func testDiscoverDevices_countsAllEntityDomains() {
        // Given
        let entities = [
            makeEntity(id: "sensor.multi_domain_print_progress"),
            makeEntity(id: "sensor.multi_domain_print_status"),
            makeEntity(id: "button.multi_domain_pause"),
            makeEntity(id: "button.multi_domain_resume"),
            makeEntity(id: "light.multi_domain_chamber_light"),
            makeEntity(id: "switch.multi_domain_power"),
            makeEntity(id: "number.multi_domain_speed_factor"),
            makeEntity(id: "image.multi_domain_camera")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1)
        XCTAssertEqual(result.printers[0].entityCount, 8, "Should count entities across all domains")
    }

    // MARK: - Printer Prefix Extraction Tests

    func testPrefixExtraction_withSimplePrefix() {
        // Given
        let entities = [
            makeEntity(id: "sensor.h2s_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].prefix, "h2s")
    }

    func testPrefixExtraction_withUnderscoresInPrefix() {
        // Given
        let entities = [
            makeEntity(id: "sensor.bambu_x1c_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].prefix, "bambu_x1c")
    }

    func testPrefixExtraction_withMultipleUnderscores() {
        // Given
        let entities = [
            makeEntity(id: "sensor.my_custom_printer_name_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].prefix, "my_custom_printer_name")
    }

    func testPrefixExtraction_ignoresNonSensorDomains() {
        // Given
        let entities = [
            makeEntity(id: "light.h2s_print_progress"), // Wrong domain, should be ignored
            makeEntity(id: "sensor.h2s_print_status") // Correct one
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1)
        XCTAssertEqual(result.printers[0].prefix, "h2s")
    }

    // MARK: - Model Detection Tests

    func testModelDetection_X1Carbon_variants() {
        // Given
        let entities = [
            makeEntity(id: "sensor.x1c_printer_print_progress"),
            makeEntity(id: "sensor.my_x1_c_print_status"),
            makeEntity(id: "sensor.x1carbon_test_current_layer")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 3)
        for printer in result.printers {
            XCTAssertEqual(printer.model, "X1 Carbon", "Should detect X1 Carbon model for prefix: \(printer.prefix)")
        }
    }

    func testModelDetection_P1S() {
        // Given
        let entities = [
            makeEntity(id: "sensor.p1s_basement_print_progress"),
            makeEntity(id: "sensor.my_p1s_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 2)
        for printer in result.printers {
            XCTAssertEqual(printer.model, "P1S", "Should detect P1S model")
        }
    }

    func testModelDetection_P1P() {
        // Given
        let entities = [
            makeEntity(id: "sensor.p1p_garage_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].model, "P1P")
    }

    func testModelDetection_A1Mini_variants() {
        // Given
        let entities = [
            makeEntity(id: "sensor.a1mini_desk_print_progress"),
            makeEntity(id: "sensor.my_a1_mini_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 2)
        for printer in result.printers {
            XCTAssertEqual(printer.model, "A1 Mini", "Should detect A1 Mini model")
        }
    }

    func testModelDetection_A1_withoutMini() {
        // Given
        let entities = [
            makeEntity(id: "sensor.a1_office_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].model, "A1")
    }

    func testModelDetection_A1_notAMS() {
        // Given - A1 AMS should not be detected as A1 printer model
        let entities = [
            makeEntity(id: "sensor.a1_ams_tray_1") // Should be AMS, not A1 printer
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertTrue(result.printers.isEmpty, "AMS prefix should not be detected as A1 printer")
        XCTAssertEqual(result.amsUnits.count, 1)
    }

    func testModelDetection_X1E() {
        // Given
        let entities = [
            makeEntity(id: "sensor.x1e_lab_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].model, "X1E")
    }

    func testModelDetection_H2S() {
        // Given
        let entities = [
            makeEntity(id: "sensor.h2s_print_progress"),
            makeEntity(id: "sensor.h2d_workshop_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 2)
        for printer in result.printers {
            XCTAssertEqual(printer.model, "H2S/H2D")
        }
    }

    func testModelDetection_unknownModel_returnsNil() {
        // Given
        let entities = [
            makeEntity(id: "sensor.custom_printer_123_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertNil(result.printers[0].model, "Unknown printer prefix should return nil model")
    }

    func testModelDetection_caseInsensitive() {
        // Given
        let entities = [
            makeEntity(id: "sensor.X1C_UPPERCASE_print_progress"),
            makeEntity(id: "sensor.P1s_MixedCase_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].model, "X1 Carbon", "Detection should be case insensitive")
        XCTAssertEqual(result.printers[1].model, "P1S", "Detection should be case insensitive")
    }

    // MARK: - AMS Discovery Tests

    func testDiscoverDevices_withSingleAMS_discoversCorrectly() {
        // Given
        let entities = [
            makeEntity(id: "sensor.h2s_ams_1_tray_1", friendlyName: "H2S AMS 1 Tray 1"),
            makeEntity(id: "sensor.h2s_ams_1_tray_2"),
            makeEntity(id: "sensor.h2s_ams_1_tray_3"),
            makeEntity(id: "sensor.h2s_ams_1_tray_4"),
            makeEntity(id: "sensor.h2s_ams_1_humidity"),
            makeEntity(id: "sensor.h2s_ams_1_temperature")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits.count, 1, "Should discover exactly one AMS unit")

        let ams = result.amsUnits[0]
        XCTAssertEqual(ams.prefix, "h2s_ams_1")
        XCTAssertEqual(ams.name, "H2S AMS 1", "Should extract friendly name from tray entity")
        XCTAssertEqual(ams.trayCount, 4, "Should find all 4 trays")
        XCTAssertEqual(ams.trayEntities.count, 4)
        XCTAssertEqual(ams.humidityEntity, "sensor.h2s_ams_1_humidity")
        XCTAssertEqual(ams.temperatureEntity, "sensor.h2s_ams_1_temperature")
    }

    func testDiscoverDevices_withMultipleAMSUnits_discoversAll() {
        // Given
        let entities = [
            // AMS 1
            makeEntity(id: "sensor.ams_1_tray_1"),
            makeEntity(id: "sensor.ams_1_tray_2"),
            makeEntity(id: "sensor.ams_1_tray_3"),
            makeEntity(id: "sensor.ams_1_tray_4"),

            // AMS 2 Pro
            makeEntity(id: "sensor.ams_2_pro_tray_1", friendlyName: "AMS 2 Pro Tray 1"),
            makeEntity(id: "sensor.ams_2_pro_tray_2"),
            makeEntity(id: "sensor.ams_2_pro_tray_3"),
            makeEntity(id: "sensor.ams_2_pro_tray_4"),

            // Bambu X1C AMS
            makeEntity(id: "sensor.bambu_x1c_ams_1_tray_1"),
            makeEntity(id: "sensor.bambu_x1c_ams_1_tray_2")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits.count, 3, "Should discover all three AMS units")

        let prefixes = Set(result.amsUnits.map { $0.prefix })
        XCTAssertTrue(prefixes.contains("ams_1"))
        XCTAssertTrue(prefixes.contains("ams_2_pro"))
        XCTAssertTrue(prefixes.contains("bambu_x1c_ams_1"))
    }

    func testDiscoverDevices_AMS_withPartialTrays() {
        // Given - AMS with only 2 trays
        let entities = [
            makeEntity(id: "sensor.partial_ams_tray_1"),
            makeEntity(id: "sensor.partial_ams_tray_2")
            // No tray_3 or tray_4
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits.count, 1)
        XCTAssertEqual(result.amsUnits[0].trayCount, 2, "Should only count existing trays")
        XCTAssertEqual(result.amsUnits[0].trayEntities.count, 2)
    }

    func testDiscoverDevices_AMS_withoutHumidityOrTemperature() {
        // Given
        let entities = [
            makeEntity(id: "sensor.basic_ams_tray_1"),
            makeEntity(id: "sensor.basic_ams_tray_2"),
            makeEntity(id: "sensor.basic_ams_tray_3"),
            makeEntity(id: "sensor.basic_ams_tray_4")
            // No humidity or temperature entities
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits.count, 1)
        XCTAssertNil(result.amsUnits[0].humidityEntity)
        XCTAssertNil(result.amsUnits[0].temperatureEntity)
    }

    func testDiscoverDevices_AMS_alternativeHumidityPattern() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_test_tray_1"),
            makeEntity(id: "sensor.ams_test_humidity_index") // Alternative humidity pattern
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].humidityEntity, "sensor.ams_test_humidity_index")
    }

    func testDiscoverDevices_AMS_alternativeTemperaturePattern() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_test_tray_1"),
            makeEntity(id: "sensor.ams_test_ams_temperature") // Alternative temperature pattern
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].temperatureEntity, "sensor.ams_test_ams_temperature")
    }

    func testDiscoverDevices_AMS_sortsLargestTrayCountFirst() {
        // Given
        let entities = [
            // AMS with 2 trays
            makeEntity(id: "sensor.partial_ams_tray_1"),
            makeEntity(id: "sensor.partial_ams_tray_2"),

            // AMS with 4 trays
            makeEntity(id: "sensor.full_ams_tray_1"),
            makeEntity(id: "sensor.full_ams_tray_2"),
            makeEntity(id: "sensor.full_ams_tray_3"),
            makeEntity(id: "sensor.full_ams_tray_4")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits.count, 2)
        XCTAssertEqual(result.amsUnits[0].prefix, "full_ams", "AMS with most trays should be first")
        XCTAssertEqual(result.amsUnits[0].trayCount, 4)
        XCTAssertEqual(result.amsUnits[1].prefix, "partial_ams")
        XCTAssertEqual(result.amsUnits[1].trayCount, 2)
    }

    // MARK: - AMS Prefix Extraction Tests

    func testAMSPrefixExtraction_simplePattern() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_tray_1")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].prefix, "ams")
    }

    func testAMSPrefixExtraction_withNumber() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_2_tray_1")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].prefix, "ams_2")
    }

    func testAMSPrefixExtraction_withDescription() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_2_pro_tray_1")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].prefix, "ams_2_pro")
    }

    func testAMSPrefixExtraction_complexPrefix() {
        // Given
        let entities = [
            makeEntity(id: "sensor.bambu_x1c_ams_1_tray_1")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].prefix, "bambu_x1c_ams_1")
    }

    func testAMSPrefixExtraction_requiresTraySuffix() {
        // Given - Entity with "tray" in name but not in pattern
        let entities = [
            makeEntity(id: "sensor.my_tray_holder_status") // Not a tray entity
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertTrue(result.amsUnits.isEmpty, "Should not detect AMS without proper tray pattern")
    }

    // MARK: - Edge Cases and Malformed Data Tests

    func testDiscoverDevices_withMissingEntityId_ignoresEntry() {
        // Given
        let entities: [[String: Any]] = [
            ["state": "unknown"], // Missing entity_id
            makeEntity(id: "sensor.h2s_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1, "Should ignore entries without entity_id")
    }

    func testDiscoverDevices_withEmptyEntityId_ignoresEntry() {
        // Given
        let entities = [
            makeEntity(id: ""),
            makeEntity(id: "sensor.h2s_print_progress")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1)
    }

    func testDiscoverDevices_withMalformedEntityId_ignoresEntry() {
        // Given
        let entities = [
            makeEntity(id: "notasensor"), // No domain separator
            makeEntity(id: ".no_domain"),
            makeEntity(id: "sensor."), // No entity name
            makeEntity(id: "sensor.h2s_print_progress") // Valid one
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1, "Should only process valid entities")
    }

    func testDiscoverDevices_withOnlyPartialSensorSuffix_doesNotMatch() {
        // Given - "progress" is part of "print_progress" but shouldn't match alone
        let entities = [
            makeEntity(id: "sensor.test_progress") // Not "print_progress"
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertTrue(result.printers.isEmpty, "Should require exact suffix match")
    }

    func testDiscoverDevices_withSimilarButDifferentSuffix_doesNotMatch() {
        // Given
        let entities = [
            makeEntity(id: "sensor.test_print_progress_2"), // Extra suffix
            makeEntity(id: "sensor.test2_custom_print_progress") // Custom prefix before known suffix
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertTrue(result.printers.isEmpty, "Should not match modified suffixes")
    }

    func testDiscoverDevices_withTrayNumberHigherThan4_stillDetected() {
        // Given - In case future AMS units have more trays
        let entities = [
            makeEntity(id: "sensor.future_ams_tray_5"),
            makeEntity(id: "sensor.future_ams_tray_6")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits.count, 1, "Should detect AMS even with non-standard tray numbers")
        XCTAssertEqual(result.amsUnits[0].prefix, "future_ams")
        // Note: trayCount will be 0 because the code only looks for trays 1-4
    }

    func testDiscoverDevices_withMixedPrintersAndAMS_discoversIndependently() {
        // Given
        let entities = [
            // Printer sensors
            makeEntity(id: "sensor.h2s_print_progress"),
            makeEntity(id: "sensor.h2s_print_status", friendlyName: "H2S Print status"),

            // AMS sensors with same base prefix
            makeEntity(id: "sensor.h2s_ams_1_tray_1", friendlyName: "H2S AMS 1 Tray 1"),
            makeEntity(id: "sensor.h2s_ams_1_tray_2"),
            makeEntity(id: "sensor.h2s_ams_1_tray_3"),
            makeEntity(id: "sensor.h2s_ams_1_tray_4"),

            // Different printer
            makeEntity(id: "sensor.p1s_print_progress"),
            makeEntity(id: "sensor.p1s_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 2, "Should find both printers")
        XCTAssertEqual(result.amsUnits.count, 1, "Should find AMS unit")

        let printerPrefixes = Set(result.printers.map { $0.prefix })
        XCTAssertTrue(printerPrefixes.contains("h2s"))
        XCTAssertTrue(printerPrefixes.contains("p1s"))
        XCTAssertEqual(result.amsUnits[0].prefix, "h2s_ams_1")
    }

    func testDiscoverDevices_withNoFriendlyName_usesPrefixAsFallback() {
        // Given
        let entities = [
            makeEntity(id: "sensor.custom_xyz_print_progress"),
            makeEntity(id: "sensor.custom_xyz_print_status") // No friendly name
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1)
        XCTAssertEqual(result.printers[0].name, "Custom Xyz", "Should capitalize prefix as fallback")
    }

    func testDiscoverDevices_withDuplicateEntities_handlesGracefully() {
        // Given
        let entities = [
            makeEntity(id: "sensor.h2s_print_progress"),
            makeEntity(id: "sensor.h2s_print_progress"), // Duplicate
            makeEntity(id: "sensor.h2s_print_status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 1, "Should deduplicate prefixes")
        // Entity count will only count unique entity IDs due to dictionary structure
    }

    // MARK: - Friendly Name Extraction Tests

    func testFriendlyNameExtraction_printer_removesPrintStatus() {
        // Given
        let entities = [
            makeEntity(id: "sensor.h2s_print_status", friendlyName: "H2S Print status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].name, "H2S")
    }

    func testFriendlyNameExtraction_printer_caseInsensitive() {
        // Given
        let entities = [
            makeEntity(id: "sensor.test_print_status", friendlyName: "Test print status")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers[0].name, "Test")
    }

    func testFriendlyNameExtraction_AMS_removesTray1() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_2_pro_tray_1", friendlyName: "AMS 2 Pro Tray 1")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].name, "AMS 2 Pro")
    }

    func testFriendlyNameExtraction_AMS_caseInsensitive() {
        // Given
        let entities = [
            makeEntity(id: "sensor.ams_test_tray_1", friendlyName: "AMS Test tray 1")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].name, "AMS Test")
    }

    func testFriendlyNameExtraction_AMS_fallbackUppercased() {
        // Given
        let entities = [
            makeEntity(id: "sensor.my_ams_unit_tray_1") // No friendly name
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.amsUnits[0].name, "MY AMS UNIT", "Should uppercase prefix as fallback")
    }

    // MARK: - Integration Tests

    func testDiscoverDevices_realWorldScenario() {
        // Given - Realistic Home Assistant setup with 2 printers and 1 AMS
        let entities = [
            // Main X1C Printer with full sensor suite
            makeEntity(id: "sensor.x1c_main_print_progress", state: "45"),
            makeEntity(id: "sensor.x1c_main_print_status", state: "printing", friendlyName: "X1C Main Print status"),
            makeEntity(id: "sensor.x1c_main_current_layer", state: "150"),
            makeEntity(id: "sensor.x1c_main_total_layer_count", state: "300"),
            makeEntity(id: "sensor.x1c_main_remaining_time", state: "2400"),
            makeEntity(id: "sensor.x1c_main_subtask_name", state: "Printing"),
            makeEntity(id: "sensor.x1c_main_nozzle_temperature", state: "220"),
            makeEntity(id: "sensor.x1c_main_bed_temperature", state: "60"),
            makeEntity(id: "sensor.x1c_main_current_stage", state: "printing"),
            makeEntity(id: "button.x1c_main_pause"),
            makeEntity(id: "button.x1c_main_resume"),
            makeEntity(id: "button.x1c_main_stop"),
            makeEntity(id: "light.x1c_main_chamber_light"),

            // X1C's AMS
            makeEntity(id: "sensor.x1c_main_ams_1_tray_1", friendlyName: "X1C Main AMS 1 Tray 1"),
            makeEntity(id: "sensor.x1c_main_ams_1_tray_2"),
            makeEntity(id: "sensor.x1c_main_ams_1_tray_3"),
            makeEntity(id: "sensor.x1c_main_ams_1_tray_4"),
            makeEntity(id: "sensor.x1c_main_ams_1_humidity"),

            // P1S Printer with fewer sensors
            makeEntity(id: "sensor.p1s_garage_print_progress", state: "0"),
            makeEntity(id: "sensor.p1s_garage_print_status", state: "idle", friendlyName: "P1S Garage Print status"),
            makeEntity(id: "sensor.p1s_garage_nozzle_temperature", state: "25"),

            // Some unrelated entities
            makeEntity(id: "light.workshop_overhead"),
            makeEntity(id: "sensor.room_temperature")
        ]

        // When
        let result = EntityDiscoveryService.discoverDevices(from: entities)

        // Then
        XCTAssertEqual(result.printers.count, 2, "Should find both printers")
        XCTAssertEqual(result.amsUnits.count, 1, "Should find one AMS unit")

        // Verify X1C printer (should be first due to more entities)
        let x1cPrinter = result.printers.first { $0.prefix == "x1c_main" }
        XCTAssertNotNil(x1cPrinter)
        XCTAssertEqual(x1cPrinter?.name, "X1C Main")
        XCTAssertEqual(x1cPrinter?.model, "X1 Carbon")
        XCTAssertEqual(x1cPrinter?.entityCount, 13, "Should count all sensor, button, and light entities")

        // Verify P1S printer
        let p1sPrinter = result.printers.first { $0.prefix == "p1s_garage" }
        XCTAssertNotNil(p1sPrinter)
        XCTAssertEqual(p1sPrinter?.name, "P1S Garage")
        XCTAssertEqual(p1sPrinter?.model, "P1S")
        XCTAssertEqual(p1sPrinter?.entityCount, 3)

        // Verify AMS
        let ams = result.amsUnits[0]
        XCTAssertEqual(ams.prefix, "x1c_main_ams_1")
        XCTAssertEqual(ams.name, "X1C Main AMS 1")
        XCTAssertEqual(ams.trayCount, 4)
        XCTAssertNotNil(ams.humidityEntity)
        XCTAssertNil(ams.temperatureEntity)
    }
}
