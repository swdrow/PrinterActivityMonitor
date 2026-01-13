import { EventEmitter } from 'events';
import { HomeAssistantService, StateChangeEvent } from './HomeAssistant.js';
import type { HAEntityState } from '../types/homeassistant.js';

export interface PrinterStateCache {
  entityPrefix: string;
  progress: number;
  currentLayer: number;
  totalLayers: number;
  remainingSeconds: number;
  status: string;
  nozzleTemp: number;
  bedTemp: number;
  subtaskName: string | null;
  speedProfile: string | null;
  lastUpdated: Date;
  isOnline: boolean;
}

export interface PrinterMonitorConfig {
  haUrl: string;
  haToken: string;
  printerPrefixes: string[];
}

export class PrinterMonitor extends EventEmitter {
  private ha: HomeAssistantService;
  private config: PrinterMonitorConfig | null = null;
  private stateCache: Map<string, PrinterStateCache> = new Map();
  private isRunning = false;

  constructor() {
    super();
    this.ha = new HomeAssistantService();
  }

  async start(config: PrinterMonitorConfig): Promise<void> {
    this.config = config;

    try {
      // Connect to Home Assistant
      await this.ha.connect({ url: config.haUrl, token: config.haToken });

      // Get initial state
      const states = await this.ha.getStates();
      this.initializeCache(states, config.printerPrefixes);

      // Subscribe to state changes
      await this.ha.subscribeToStateChanges();

      // Handle state change events
      this.ha.on('state_changed', (event: StateChangeEvent) => {
        this.handleStateChange(event);
      });

      this.ha.on('disconnected', () => {
        this.emit('disconnected');
      });

      this.isRunning = true;
      this.emit('started');

      console.log(`PrinterMonitor started for prefixes: ${config.printerPrefixes.join(', ')}`);
    } catch (error) {
      console.error('Failed to start PrinterMonitor:', error);
      throw error;
    }
  }

  stop(): void {
    this.ha.disconnect();
    this.stateCache.clear();
    this.isRunning = false;
    this.emit('stopped');
  }

  getState(entityPrefix: string): PrinterStateCache | null {
    return this.stateCache.get(entityPrefix) ?? null;
  }

  getAllStates(): PrinterStateCache[] {
    return Array.from(this.stateCache.values());
  }

  isConnected(): boolean {
    return this.isRunning && this.ha.isConnected();
  }

  private initializeCache(states: HAEntityState[], prefixes: string[]): void {
    for (const prefix of prefixes) {
      const cache = this.buildCacheFromStates(prefix, states);
      if (cache) {
        this.stateCache.set(prefix, cache);
      }
    }
  }

  private buildCacheFromStates(prefix: string, states: HAEntityState[]): PrinterStateCache | null {
    const find = (suffix: string): HAEntityState | undefined =>
      states.find(s => s.entity_id === `sensor.${prefix}${suffix}`);

    const progressEntity = find('_print_progress');
    if (!progressEntity) {
      return null; // Not a valid printer prefix
    }

    return {
      entityPrefix: prefix,
      progress: this.parseNumber(find('_print_progress')?.state, 0),
      currentLayer: this.parseNumber(find('_current_layer')?.state, 0),
      totalLayers: this.parseNumber(find('_total_layer_count')?.state, 0),
      remainingSeconds: this.parseNumber(find('_remaining_time')?.state, 0),
      status: find('_print_status')?.state ?? 'unknown',
      nozzleTemp: this.parseNumber(find('_nozzle_temperature')?.state, 0),
      bedTemp: this.parseNumber(find('_bed_temperature')?.state, 0),
      subtaskName: find('_subtask_name')?.state ?? null,
      speedProfile: find('_speed_profile')?.state ?? null,
      lastUpdated: new Date(),
      isOnline: true,
    };
  }

  private handleStateChange(event: StateChangeEvent): void {
    const { entityId, newState, attributes } = event;

    // Check if this entity belongs to a monitored printer
    for (const prefix of this.config?.printerPrefixes ?? []) {
      if (entityId.startsWith(`sensor.${prefix}_`)) {
        this.updateCacheFromEvent(prefix, entityId, newState, attributes);
        break;
      }
    }
  }

  private updateCacheFromEvent(
    prefix: string,
    entityId: string,
    newState: string | null,
    _attributes: Record<string, unknown>
  ): void {
    let cache = this.stateCache.get(prefix);
    if (!cache) {
      cache = this.createEmptyCache(prefix);
      this.stateCache.set(prefix, cache);
    }

    const suffix = entityId.replace(`sensor.${prefix}`, '');
    const value = newState ?? '';

    switch (suffix) {
      case '_print_progress':
        cache.progress = this.parseNumber(value, cache.progress);
        break;
      case '_current_layer':
        cache.currentLayer = this.parseNumber(value, cache.currentLayer);
        break;
      case '_total_layer_count':
        cache.totalLayers = this.parseNumber(value, cache.totalLayers);
        break;
      case '_remaining_time':
        cache.remainingSeconds = this.parseNumber(value, cache.remainingSeconds);
        break;
      case '_print_status':
        const oldStatus = cache.status;
        cache.status = value;
        if (oldStatus !== value) {
          this.emit('status_changed', { prefix, oldStatus, newStatus: value });
        }
        break;
      case '_nozzle_temperature':
        cache.nozzleTemp = this.parseNumber(value, cache.nozzleTemp);
        break;
      case '_bed_temperature':
        cache.bedTemp = this.parseNumber(value, cache.bedTemp);
        break;
      case '_subtask_name':
        cache.subtaskName = value || null;
        break;
      case '_speed_profile':
        cache.speedProfile = value || null;
        break;
    }

    cache.lastUpdated = new Date();
    this.emit('state_updated', { prefix, state: cache });
  }

  private createEmptyCache(prefix: string): PrinterStateCache {
    return {
      entityPrefix: prefix,
      progress: 0,
      currentLayer: 0,
      totalLayers: 0,
      remainingSeconds: 0,
      status: 'unknown',
      nozzleTemp: 0,
      bedTemp: 0,
      subtaskName: null,
      speedProfile: null,
      lastUpdated: new Date(),
      isOnline: true,
    };
  }

  private parseNumber(value: string | undefined | null, fallback: number): number {
    if (!value || value === 'unknown' || value === 'unavailable') {
      return fallback;
    }
    const num = parseFloat(value);
    return isNaN(num) ? fallback : Math.round(num);
  }
}
