import { getDatabase } from '../config/database.js';
import { apnsService } from './APNsService.js';
import type { PrinterNotificationPayload } from '../types/apns.js';

interface DeviceWithSettings {
  id: string;
  apnsToken: string;
  printerName: string | null;
  onStart: boolean;
  onComplete: boolean;
  onFailed: boolean;
  onPaused: boolean;
  onMilestone: boolean;
}

export class NotificationTrigger {
  private lastProgress: Map<string, number> = new Map();
  private milestones = [25, 50, 75];

  async handleStatusChange(
    printerPrefix: string,
    oldStatus: string,
    newStatus: string,
    filename?: string
  ): Promise<void> {
    const devices = this.getDevicesForPrinter(printerPrefix);
    if (devices.length === 0) return;

    let notificationType: PrinterNotificationPayload['type'] | null = null;
    let filterKey: 'onStart' | 'onComplete' | 'onFailed' | 'onPaused' | null = null;

    // Determine notification type based on status transition
    if (oldStatus !== 'running' && newStatus === 'running') {
      notificationType = 'print_started';
      filterKey = 'onStart';
    } else if (oldStatus === 'running' && newStatus === 'complete') {
      notificationType = 'print_complete';
      filterKey = 'onComplete';
    } else if (oldStatus === 'running' && newStatus === 'failed') {
      notificationType = 'print_failed';
      filterKey = 'onFailed';
    } else if (oldStatus === 'running' && newStatus === 'paused') {
      notificationType = 'print_paused';
      filterKey = 'onPaused';
    }

    if (!notificationType || !filterKey) return;

    // Filter devices by notification preference
    const eligibleDevices = devices.filter(d => d[filterKey]);
    if (eligibleDevices.length === 0) return;

    const payload: PrinterNotificationPayload = {
      type: notificationType,
      printerPrefix,
      printerName: eligibleDevices[0].printerName || printerPrefix,
      filename,
    };

    const tokens = eligibleDevices.map(d => d.apnsToken);
    await apnsService.sendToMultiple(tokens, payload);

    console.log(`Sent ${notificationType} notification to ${tokens.length} devices`);
  }

  async handleProgressChange(
    printerPrefix: string,
    progress: number,
    filename?: string
  ): Promise<void> {
    const lastProg = this.lastProgress.get(printerPrefix) ?? 0;
    this.lastProgress.set(printerPrefix, progress);

    // Check if we crossed a milestone
    const crossedMilestone = this.milestones.find(
      m => lastProg < m && progress >= m
    );

    if (!crossedMilestone) return;

    const devices = this.getDevicesForPrinter(printerPrefix);
    const eligibleDevices = devices.filter(d => d.onMilestone);
    if (eligibleDevices.length === 0) return;

    const payload: PrinterNotificationPayload = {
      type: 'progress_milestone',
      printerPrefix,
      printerName: eligibleDevices[0].printerName || printerPrefix,
      filename,
      progress: crossedMilestone,
    };

    const tokens = eligibleDevices.map(d => d.apnsToken);
    await apnsService.sendToMultiple(tokens, payload);

    console.log(`Sent ${crossedMilestone}% milestone notification to ${tokens.length} devices`);
  }

  resetProgress(printerPrefix: string): void {
    this.lastProgress.delete(printerPrefix);
  }

  private getDevicesForPrinter(printerPrefix: string): DeviceWithSettings[] {
    const db = getDatabase();

    return db.devices
      .filter(d => d.entityPrefix === printerPrefix && d.notificationsEnabled && d.apnsToken)
      .map(d => {
        const settings = db.notificationSettings.find(s => s.deviceId === d.id) || {
          onStart: true,
          onComplete: true,
          onFailed: true,
          onPaused: true,
          onMilestone: true,
        };

        return {
          id: d.id,
          apnsToken: d.apnsToken!,
          printerName: d.printerName,
          ...settings,
        };
      });
  }
}

export const notificationTrigger = new NotificationTrigger();
