import { getDatabase } from '../config/database.js';
import { apnsService } from './APNsService.js';
import { liveActivityService } from './LiveActivityService.js';
import { printHistoryService } from './PrintHistoryService.js';
import type { PrinterNotificationPayload } from '../types/apns.js';
import type { LiveActivityContentState } from '../types/live-activity.js';

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

    // Record print job history
    if (newStatus === 'running' && devices.length > 0) {
      // Start a new print job
      const device = devices[0];
      await printHistoryService.startJob({
        deviceId: device.id,
        printerPrefix,
        filename: filename ?? 'Unknown',
      });
    }

    // Handle Live Activity end and complete print job for terminal states
    if (newStatus === 'complete' || newStatus === 'failed' || newStatus === 'cancelled') {
      // Complete the print job in history
      await printHistoryService.completeJob(printerPrefix, {
        status: newStatus === 'complete' ? 'completed' : newStatus as 'failed' | 'cancelled',
      });

      // End Live Activity
      const finalState: LiveActivityContentState = {
        progress: newStatus === 'complete' ? 100 : 0,
        currentLayer: 0,
        totalLayers: 0,
        remainingSeconds: 0,
        status: newStatus,
        nozzleTemp: 0,
        bedTemp: 0,
      };
      await liveActivityService.endActivity(printerPrefix, finalState);
    }
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

  async handleStateUpdate(
    printerPrefix: string,
    state: {
      progress: number;
      currentLayer: number;
      totalLayers: number;
      remainingSeconds: number;
      status: string;
      nozzleTemp: number;
      bedTemp: number;
    }
  ): Promise<void> {
    // Only send updates while running or paused
    if (state.status !== 'running' && state.status !== 'paused') {
      return;
    }

    // Only send if there's an active Live Activity for this printer
    if (!liveActivityService.hasActivityToken(printerPrefix)) {
      return;
    }

    const liveActivityState: LiveActivityContentState = {
      progress: state.progress,
      currentLayer: state.currentLayer,
      totalLayers: state.totalLayers,
      remainingSeconds: state.remainingSeconds,
      status: state.status,
      nozzleTemp: state.nozzleTemp,
      bedTemp: state.bedTemp,
    };

    await liveActivityService.sendUpdate(printerPrefix, liveActivityState);
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
