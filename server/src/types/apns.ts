export interface APNsConfig {
  teamId: string;
  keyId: string;
  keyPath: string;  // Path to .p8 file
  bundleId: string;
  production: boolean;
}

export interface PrinterNotificationPayload {
  type: 'print_started' | 'print_complete' | 'print_failed' | 'print_paused' | 'progress_milestone';
  printerPrefix: string;
  printerName: string;
  filename?: string;
  progress?: number;
  status?: string;
}

export interface NotificationResult {
  success: boolean;
  deviceToken: string;
  error?: string;
}
