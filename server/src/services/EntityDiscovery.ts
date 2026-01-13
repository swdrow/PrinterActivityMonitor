import type { HAEntityState } from '../types/homeassistant.js';

export interface DiscoveredPrinter {
  entityPrefix: string;
  displayName: string;
  model: string;
  entityCount: number;
  entities: string[];
}

export interface DiscoveredAMS {
  entityPrefix: string;
  displayName: string;
  trayCount: number;
  associatedPrinter: string | null;
}

// Known printer sensor suffixes from ha_bambulab integration
const PRINTER_SUFFIXES = [
  '_print_progress',
  '_print_status',
  '_current_layer',
  '_total_layer_count',
  '_nozzle_temperature',
  '_bed_temperature',
  '_remaining_time',
  '_subtask_name',
  '_speed_profile',
  '_stage',
];

// Model detection patterns
const MODEL_PATTERNS: Record<string, string> = {
  x1c: 'X1 Carbon',
  x1: 'X1',
  p1s: 'P1S',
  p1p: 'P1P',
  a1: 'A1',
  a1m: 'A1 Mini',
  h2s: 'H2S',
  h2d: 'H2D',
};

export class EntityDiscoveryService {
  /**
   * Discover printers from Home Assistant entities
   */
  static discoverPrinters(entities: HAEntityState[]): DiscoveredPrinter[] {
    const prefixMap = new Map<string, Set<string>>();

    // Find all sensor entities matching printer suffixes
    for (const entity of entities) {
      if (!entity.entity_id.startsWith('sensor.')) continue;

      for (const suffix of PRINTER_SUFFIXES) {
        if (entity.entity_id.endsWith(suffix)) {
          const prefix = entity.entity_id
            .replace('sensor.', '')
            .replace(suffix, '');

          if (!prefixMap.has(prefix)) {
            prefixMap.set(prefix, new Set());
          }
          prefixMap.get(prefix)!.add(entity.entity_id);
          break;
        }
      }
    }

    // Convert to DiscoveredPrinter array
    const printers: DiscoveredPrinter[] = [];

    for (const [prefix, entitySet] of prefixMap) {
      // Only consider prefixes with at least 3 matching entities
      if (entitySet.size < 3) continue;

      const model = this.detectModel(prefix);

      printers.push({
        entityPrefix: prefix,
        displayName: this.formatDisplayName(prefix, model),
        model,
        entityCount: entitySet.size,
        entities: Array.from(entitySet),
      });
    }

    // Sort by entity count (most complete first)
    return printers.sort((a, b) => b.entityCount - a.entityCount);
  }

  /**
   * Discover AMS units from Home Assistant entities
   * @param entities - All HA entities
   * @param knownPrinterPrefixes - Prefixes of discovered printers for better association
   */
  static discoverAMS(
    entities: HAEntityState[],
    knownPrinterPrefixes: string[] = []
  ): DiscoveredAMS[] {
    const amsMap = new Map<string, Set<number>>();

    // Find AMS tray entities (pattern: sensor.{prefix}_tray_{1-4})
    const trayPattern = /^sensor\.(.+)_tray_(\d+)$/;

    for (const entity of entities) {
      const match = entity.entity_id.match(trayPattern);
      if (match) {
        const prefix = match[1];
        const trayNum = parseInt(match[2], 10);

        if (!amsMap.has(prefix)) {
          amsMap.set(prefix, new Set());
        }
        amsMap.get(prefix)!.add(trayNum);
      }
    }

    // Convert to DiscoveredAMS array
    const amsUnits: DiscoveredAMS[] = [];

    for (const [prefix, trays] of amsMap) {
      amsUnits.push({
        entityPrefix: prefix,
        displayName: this.formatAMSName(prefix),
        trayCount: trays.size,
        associatedPrinter: this.findAssociatedPrinter(prefix, knownPrinterPrefixes),
      });
    }

    return amsUnits;
  }

  /**
   * Detect printer model from prefix
   */
  private static detectModel(prefix: string): string {
    const lowerPrefix = prefix.toLowerCase();

    for (const [pattern, model] of Object.entries(MODEL_PATTERNS)) {
      if (lowerPrefix.includes(pattern)) {
        return model;
      }
    }

    return 'Unknown';
  }

  /**
   * Format a human-readable display name
   */
  private static formatDisplayName(prefix: string, model: string): string {
    if (model !== 'Unknown') {
      return `Bambu Lab ${model}`;
    }
    // Capitalize and replace underscores with spaces
    return prefix
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  /**
   * Format AMS display name
   */
  private static formatAMSName(prefix: string): string {
    // Check if prefix contains ams identifier
    if (prefix.toLowerCase().includes('ams')) {
      return prefix
        .split('_')
        .map(word => word.toUpperCase() === 'AMS' ? 'AMS' : word.charAt(0).toUpperCase() + word.slice(1))
        .join(' ');
    }
    return `AMS (${prefix})`;
  }

  /**
   * Try to find associated printer for an AMS unit
   * @param amsPrefix - The AMS entity prefix
   * @param knownPrinterPrefixes - Known printer prefixes for smarter matching
   */
  private static findAssociatedPrinter(
    amsPrefix: string,
    knownPrinterPrefixes: string[] = []
  ): string | null {
    // First try: check if any known printer prefix is contained in the AMS prefix
    for (const printerPrefix of knownPrinterPrefixes) {
      if (amsPrefix.toLowerCase().includes(printerPrefix.toLowerCase())) {
        return printerPrefix;
      }
    }

    // Fallback: original logic - remove 'ams', 'pro', and numbers
    const parts = amsPrefix.split('_');
    const filtered = parts.filter(p =>
      p.toLowerCase() !== 'ams' &&
      p.toLowerCase() !== 'pro' &&
      !/^\d+$/.test(p)
    );

    return filtered.length > 0 ? filtered.join('_') : null;
  }
}
