import { ApnsClient, Notification, Priority, PushType } from 'apns2';
import { env } from '../config/index.js';
import { readFileSync } from 'fs';
import type { LiveActivityContentState } from '../types/live-activity.js';

export class LiveActivityService {
  private client: ApnsClient | null = null;
  private isConfigured = false;

  // Map of printerPrefix -> activityToken
  private activityTokens: Map<string, string> = new Map();

  configure(): void {
    if (!env.APNS_TEAM_ID || !env.APNS_KEY_ID || !env.APNS_KEY_PATH) {
      console.log('APNs not configured - Live Activity updates disabled');
      return;
    }

    try {
      const signingKey = readFileSync(env.APNS_KEY_PATH, 'utf8');

      this.client = new ApnsClient({
        team: env.APNS_TEAM_ID,
        keyId: env.APNS_KEY_ID,
        signingKey,
        defaultTopic: `${env.APNS_BUNDLE_ID}.push-type.liveactivity`,
        host: env.APNS_PRODUCTION === 'true'
          ? 'api.push.apple.com'
          : 'api.sandbox.push.apple.com',
      });

      this.isConfigured = true;
      console.log('LiveActivityService configured');
    } catch (error) {
      console.error('Failed to configure LiveActivityService:', error);
    }
  }

  registerActivityToken(printerPrefix: string, token: string): void {
    this.activityTokens.set(printerPrefix, token);
    console.log(`Registered activity token for ${printerPrefix}`);
  }

  removeActivityToken(printerPrefix: string): void {
    this.activityTokens.delete(printerPrefix);
  }

  hasActivityToken(printerPrefix: string): boolean {
    return this.activityTokens.has(printerPrefix);
  }

  async sendUpdate(
    printerPrefix: string,
    state: LiveActivityContentState
  ): Promise<boolean> {
    if (!this.client || !this.isConfigured) {
      return false;
    }

    const token = this.activityTokens.get(printerPrefix);
    if (!token) {
      return false;
    }

    const notification = new Notification(token, {
      type: PushType.liveactivity,
      priority: Priority.immediate,
      aps: {
        timestamp: Math.floor(Date.now() / 1000),
        event: 'update',
        'content-state': state,
      },
    });

    try {
      await this.client.send(notification);
      console.log(`Live Activity update sent for ${printerPrefix}`);
      return true;
    } catch (error) {
      console.error(`Live Activity update failed for ${printerPrefix}:`, error);
      // Token might be invalid, remove it
      this.activityTokens.delete(printerPrefix);
      return false;
    }
  }

  async endActivity(
    printerPrefix: string,
    finalState: LiveActivityContentState
  ): Promise<boolean> {
    if (!this.client || !this.isConfigured) {
      return false;
    }

    const token = this.activityTokens.get(printerPrefix);
    if (!token) {
      return false;
    }

    const notification = new Notification(token, {
      type: PushType.liveactivity,
      priority: Priority.immediate,
      aps: {
        timestamp: Math.floor(Date.now() / 1000),
        event: 'end',
        'content-state': finalState,
        'dismissal-date': Math.floor(Date.now() / 1000) + 3600, // Dismiss after 1 hour
      },
    });

    try {
      await this.client.send(notification);
      console.log(`Live Activity ended for ${printerPrefix}`);
      this.activityTokens.delete(printerPrefix);
      return true;
    } catch (error) {
      console.error(`Live Activity end failed for ${printerPrefix}:`, error);
      this.activityTokens.delete(printerPrefix);
      return false;
    }
  }

  isReady(): boolean {
    return this.isConfigured;
  }
}

export const liveActivityService = new LiveActivityService();
