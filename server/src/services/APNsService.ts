import { ApnsClient, Notification, Priority, PushType } from 'apns2';
import type { APNsConfig, PrinterNotificationPayload, NotificationResult } from '../types/apns.js';
import { readFileSync } from 'fs';

export class APNsService {
  private client: ApnsClient | null = null;
  private config: APNsConfig | null = null;
  private isConfigured = false;

  configure(config: APNsConfig): void {
    try {
      const signingKey = readFileSync(config.keyPath, 'utf8');

      this.client = new ApnsClient({
        team: config.teamId,
        keyId: config.keyId,
        signingKey,
        defaultTopic: config.bundleId,
        host: config.production
          ? 'api.push.apple.com'
          : 'api.sandbox.push.apple.com',
      });

      this.config = config;
      this.isConfigured = true;
      console.log('APNs service configured successfully');
    } catch (error) {
      console.error('Failed to configure APNs:', error);
      this.isConfigured = false;
    }
  }

  async sendNotification(
    deviceToken: string,
    payload: PrinterNotificationPayload
  ): Promise<NotificationResult> {
    if (!this.client || !this.isConfigured) {
      return {
        success: false,
        deviceToken,
        error: 'APNs not configured',
      };
    }

    const { title, body } = this.formatNotification(payload);

    const notification = new Notification(deviceToken, {
      type: PushType.alert,
      priority: Priority.immediate,
      alert: { title, subtitle: '', body },
      sound: 'default',
      threadId: payload.printerPrefix,
      data: {
        printerState: {
          type: payload.type,
          prefix: payload.printerPrefix,
          progress: payload.progress,
          status: payload.status,
          filename: payload.filename,
        },
      },
    });

    try {
      await this.client.send(notification);
      return { success: true, deviceToken };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`APNs send failed for ${deviceToken}:`, message);
      return { success: false, deviceToken, error: message };
    }
  }

  async sendToMultiple(
    deviceTokens: string[],
    payload: PrinterNotificationPayload
  ): Promise<NotificationResult[]> {
    const results = await Promise.all(
      deviceTokens.map(token => this.sendNotification(token, payload))
    );
    return results;
  }

  private formatNotification(payload: PrinterNotificationPayload): { title: string; body: string } {
    const printer = payload.printerName || payload.printerPrefix;

    switch (payload.type) {
      case 'print_started':
        return {
          title: 'Print Started',
          body: `${payload.filename || 'Print'} started on ${printer}`,
        };
      case 'print_complete':
        return {
          title: 'Print Complete!',
          body: `${payload.filename || 'Print'} finished on ${printer}`,
        };
      case 'print_failed':
        return {
          title: 'Print Failed',
          body: `${payload.filename || 'Print'} failed on ${printer}`,
        };
      case 'print_paused':
        return {
          title: 'Print Paused',
          body: `${payload.filename || 'Print'} paused on ${printer}`,
        };
      case 'progress_milestone':
        return {
          title: `${payload.progress}% Complete`,
          body: `${payload.filename || 'Print'} on ${printer}`,
        };
      default:
        return {
          title: 'Printer Update',
          body: `Update from ${printer}`,
        };
    }
  }

  isReady(): boolean {
    return this.isConfigured;
  }
}

// Singleton instance
export const apnsService = new APNsService();
