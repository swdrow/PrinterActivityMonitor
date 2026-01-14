export interface LiveActivityContentState {
  progress: number;
  currentLayer: number;
  totalLayers: number;
  remainingSeconds: number;
  status: string;
  nozzleTemp: number;
  bedTemp: number;
}

export interface ActivityTokenRegistration {
  deviceId: string;
  activityToken: string;
  printerPrefix: string;
  createdAt: Date;
}
