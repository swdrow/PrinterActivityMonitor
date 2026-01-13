import WebSocket from 'ws';
import { EventEmitter } from 'events';
import type {
  HAAuthMessage,
  HAMessage,
  HAEntityState,
  HAStateChangedEvent,
} from '../types/homeassistant.js';

export interface HomeAssistantConfig {
  url: string;
  token: string;
}

export interface StateChangeEvent {
  entityId: string;
  oldState: string | null;
  newState: string | null;
  attributes: Record<string, unknown>;
}

export class HomeAssistantService extends EventEmitter {
  private ws: WebSocket | null = null;
  private config: HomeAssistantConfig | null = null;
  private messageId = 1;
  private connected = false;
  private authenticated = false;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000;
  private pendingRequests: Map<number, {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
  }> = new Map();

  constructor() {
    super();
  }

  async connect(config: HomeAssistantConfig): Promise<void> {
    this.config = config;
    return this.establishConnection();
  }

  private async establishConnection(): Promise<void> {
    if (!this.config) {
      throw new Error('HomeAssistant not configured');
    }

    return new Promise((resolve, reject) => {
      const wsUrl = this.config!.url.replace(/^http/, 'ws') + '/api/websocket';

      console.log(`Connecting to Home Assistant at ${wsUrl}`);

      this.ws = new WebSocket(wsUrl);

      this.ws.on('open', () => {
        console.log('WebSocket connection opened');
        this.connected = true;
        this.reconnectAttempts = 0;
      });

      this.ws.on('message', (data) => {
        try {
          const message: HAMessage = JSON.parse(data.toString());
          this.handleMessage(message, resolve, reject);
        } catch (error) {
          console.error('Failed to parse message:', error);
        }
      });

      this.ws.on('close', () => {
        console.log('WebSocket connection closed');
        this.connected = false;
        this.authenticated = false;
        this.emit('disconnected');
        this.scheduleReconnect();
      });

      this.ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      });
    });
  }

  private handleMessage(
    message: HAMessage,
    connectResolve?: (value: void) => void,
    connectReject?: (error: Error) => void
  ): void {
    switch (message.type) {
      case 'auth_required':
        this.sendAuth();
        break;

      case 'auth_ok':
        console.log('Authenticated with Home Assistant');
        this.authenticated = true;
        this.emit('connected');
        connectResolve?.();
        break;

      case 'auth_invalid':
        console.error('Authentication failed:', (message as { message: string }).message);
        this.emit('auth_failed', (message as { message: string }).message);
        connectReject?.(new Error('Authentication failed'));
        break;

      case 'event':
        this.handleEvent(message as HAStateChangedEvent);
        break;

      case 'result':
        this.handleResult(message as { id: number; success: boolean; result: unknown; error?: { message: string } });
        break;
    }
  }

  private sendAuth(): void {
    if (!this.config || !this.ws) return;

    const authMessage: HAAuthMessage = {
      type: 'auth',
      access_token: this.config.token,
    };

    this.ws.send(JSON.stringify(authMessage));
  }

  private handleEvent(message: HAStateChangedEvent): void {
    const { entity_id, old_state, new_state } = message.event.data;

    const event: StateChangeEvent = {
      entityId: entity_id,
      oldState: old_state?.state ?? null,
      newState: new_state?.state ?? null,
      attributes: new_state?.attributes ?? {},
    };

    this.emit('state_changed', event);
  }

  private handleResult(message: { id: number; success: boolean; result: unknown; error?: { message: string } }): void {
    const pending = this.pendingRequests.get(message.id);
    if (pending) {
      this.pendingRequests.delete(message.id);
      if (message.success) {
        pending.resolve(message.result);
      } else {
        pending.reject(new Error(message.error?.message ?? 'Request failed'));
      }
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnect attempts reached');
      this.emit('max_reconnects');
      return;
    }

    const delay = Math.min(
      this.reconnectDelay * Math.pow(2, this.reconnectAttempts),
      60000
    );

    console.log(`Scheduling reconnect in ${delay}ms (attempt ${this.reconnectAttempts + 1})`);

    setTimeout(() => {
      this.reconnectAttempts++;
      this.establishConnection().catch((error) => {
        console.error('Reconnect failed:', error);
      });
    }, delay);
  }

  async subscribeToStateChanges(): Promise<void> {
    const id = this.messageId++;

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, {
        resolve: () => resolve(),
        reject,
      });

      this.ws?.send(JSON.stringify({
        id,
        type: 'subscribe_events',
        event_type: 'state_changed',
      }));
    });
  }

  async getStates(): Promise<HAEntityState[]> {
    const id = this.messageId++;

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, {
        resolve: (result) => resolve(result as HAEntityState[]),
        reject,
      });

      this.ws?.send(JSON.stringify({
        id,
        type: 'get_states',
      }));
    });
  }

  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.connected = false;
    this.authenticated = false;
  }

  isConnected(): boolean {
    return this.connected && this.authenticated;
  }
}
