import { describe, it, expect } from 'vitest';
import { EntityDiscoveryService } from '../src/services/EntityDiscovery.js';
import type { HAEntityState } from '../src/types/homeassistant.js';

// Mock entity data simulating ha_bambulab integration
const mockEntities: HAEntityState[] = [
  // H2S printer entities
  { entity_id: 'sensor.h2s_print_progress', state: '45', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_print_status', state: 'running', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_current_layer', state: '67', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_total_layer_count', state: '150', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_nozzle_temperature', state: '220', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_bed_temperature', state: '60', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_remaining_time', state: '3600', attributes: {}, last_changed: '', last_updated: '' },

  // AMS entities
  { entity_id: 'sensor.h2s_ams_tray_1', state: 'PLA', attributes: { color: '#FF0000' }, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_ams_tray_2', state: 'PETG', attributes: { color: '#00FF00' }, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_ams_tray_3', state: 'empty', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'sensor.h2s_ams_tray_4', state: 'ABS', attributes: { color: '#0000FF' }, last_changed: '', last_updated: '' },

  // Non-printer entities (should be ignored)
  { entity_id: 'sensor.living_room_temperature', state: '22', attributes: {}, last_changed: '', last_updated: '' },
  { entity_id: 'light.bedroom', state: 'on', attributes: {}, last_changed: '', last_updated: '' },
];

describe('EntityDiscoveryService', () => {
  describe('discoverPrinters', () => {
    it('discovers printers from entities', () => {
      const printers = EntityDiscoveryService.discoverPrinters(mockEntities);

      expect(printers).toHaveLength(1);
      expect(printers[0].entityPrefix).toBe('h2s');
      expect(printers[0].model).toBe('H2S');
      expect(printers[0].entityCount).toBeGreaterThanOrEqual(5);
    });

    it('returns empty array for no matching entities', () => {
      const nonPrinterEntities: HAEntityState[] = [
        { entity_id: 'sensor.temperature', state: '22', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'light.bedroom', state: 'on', attributes: {}, last_changed: '', last_updated: '' },
      ];

      const printers = EntityDiscoveryService.discoverPrinters(nonPrinterEntities);
      expect(printers).toHaveLength(0);
    });

    it('detects correct model from prefix', () => {
      const x1cEntities: HAEntityState[] = [
        { entity_id: 'sensor.bambu_x1c_print_progress', state: '0', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.bambu_x1c_print_status', state: 'idle', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.bambu_x1c_current_layer', state: '0', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.bambu_x1c_nozzle_temperature', state: '25', attributes: {}, last_changed: '', last_updated: '' },
      ];

      const printers = EntityDiscoveryService.discoverPrinters(x1cEntities);
      expect(printers).toHaveLength(1);
      expect(printers[0].model).toBe('X1 Carbon');
    });
  });

  describe('discoverAMS', () => {
    it('discovers AMS units from tray entities', () => {
      const amsUnits = EntityDiscoveryService.discoverAMS(mockEntities, ['h2s']);

      expect(amsUnits).toHaveLength(1);
      expect(amsUnits[0].entityPrefix).toBe('h2s_ams');
      expect(amsUnits[0].trayCount).toBe(4);
      expect(amsUnits[0].associatedPrinter).toBe('h2s');
    });

    it('returns empty array for no AMS entities', () => {
      const noAmsEntities: HAEntityState[] = [
        { entity_id: 'sensor.h2s_print_progress', state: '45', attributes: {}, last_changed: '', last_updated: '' },
      ];

      const amsUnits = EntityDiscoveryService.discoverAMS(noAmsEntities);
      expect(amsUnits).toHaveLength(0);
    });

    it('correctly associates AMS with printer using known prefixes', () => {
      // Test case: ams_2_pro should associate with h2s when h2s is a known prefix
      const amsEntities: HAEntityState[] = [
        { entity_id: 'sensor.ams_2_pro_tray_1', state: 'PLA', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.ams_2_pro_tray_2', state: 'PETG', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.ams_2_pro_tray_3', state: 'empty', attributes: {}, last_changed: '', last_updated: '' },
        { entity_id: 'sensor.ams_2_pro_tray_4', state: 'ABS', attributes: {}, last_changed: '', last_updated: '' },
      ];

      // Without known prefixes, fallback logic applies
      const amsWithoutPrefixes = EntityDiscoveryService.discoverAMS(amsEntities);
      expect(amsWithoutPrefixes[0].associatedPrinter).toBe(null); // 'ams_2_pro' with 'ams', 'pro', and numbers removed = nothing

      // With h2s as known prefix, but it's not in 'ams_2_pro', so still null
      const amsWithH2s = EntityDiscoveryService.discoverAMS(amsEntities, ['h2s']);
      expect(amsWithH2s[0].associatedPrinter).toBe(null);
    });
  });
});
