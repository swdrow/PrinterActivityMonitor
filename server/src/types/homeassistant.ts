// Home Assistant WebSocket API types

export interface HAAuthMessage {
  type: 'auth';
  access_token: string;
}

export interface HAAuthOkMessage {
  type: 'auth_ok';
  ha_version: string;
}

export interface HAAuthInvalidMessage {
  type: 'auth_invalid';
  message: string;
}

export interface HASubscribeEventsMessage {
  id: number;
  type: 'subscribe_events';
  event_type: string;
}

export interface HAStateChangedEvent {
  id: number;
  type: 'event';
  event: {
    event_type: 'state_changed';
    data: {
      entity_id: string;
      old_state: HAEntityState | null;
      new_state: HAEntityState | null;
    };
    origin: string;
    time_fired: string;
  };
}

export interface HAEntityState {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
  last_changed: string;
  last_updated: string;
}

export interface HAGetStatesMessage {
  id: number;
  type: 'get_states';
}

export interface HAResultMessage {
  id: number;
  type: 'result';
  success: boolean;
  result: HAEntityState[] | null;
  error?: {
    code: string;
    message: string;
  };
}

export type HAMessage =
  | HAAuthOkMessage
  | HAAuthInvalidMessage
  | HAStateChangedEvent
  | HAResultMessage
  | { type: string; [key: string]: unknown };
