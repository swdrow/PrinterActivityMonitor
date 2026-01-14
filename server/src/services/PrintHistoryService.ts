import { v4 as uuidv4 } from 'uuid';
import { getDatabase, saveDatabase, type PrintJob } from '../config/database.js';

export interface PrintJobCreate {
  deviceId: string;
  printerPrefix: string;
  filename: string;
  totalLayers?: number;
}

export interface PrintJobComplete {
  status: 'completed' | 'failed' | 'cancelled';
  finalLayer?: number;
  filamentUsedMm?: number;
}

class PrintHistoryService {
  // Track active print jobs by printer prefix
  private activeJobs: Map<string, string> = new Map(); // prefix -> jobId

  async startJob(data: PrintJobCreate): Promise<PrintJob> {
    // End any existing job for this printer
    const existingJobId = this.activeJobs.get(data.printerPrefix);
    if (existingJobId) {
      await this.completeJob(data.printerPrefix, { status: 'cancelled' });
    }

    const job: PrintJob = {
      id: uuidv4(),
      deviceId: data.deviceId,
      printerPrefix: data.printerPrefix,
      filename: data.filename,
      startedAt: new Date().toISOString(),
      completedAt: null,
      durationSeconds: null,
      status: 'running',
      totalLayers: data.totalLayers ?? null,
      finalLayer: null,
      filamentUsedMm: null,
    };

    const db = getDatabase();
    db.printJobs.push(job);
    saveDatabase();

    this.activeJobs.set(data.printerPrefix, job.id);

    console.log(`[PrintHistory] Started job ${job.id}: ${job.filename}`);
    return job;
  }

  async completeJob(printerPrefix: string, data: PrintJobComplete): Promise<PrintJob | null> {
    const jobId = this.activeJobs.get(printerPrefix);
    if (!jobId) {
      console.log(`[PrintHistory] No active job for ${printerPrefix}`);
      return null;
    }

    const db = getDatabase();
    const jobIndex = db.printJobs.findIndex(j => j.id === jobId);
    if (jobIndex < 0) {
      this.activeJobs.delete(printerPrefix);
      return null;
    }

    const job = db.printJobs[jobIndex];
    const completedAt = new Date();
    const startedAt = job.startedAt ? new Date(job.startedAt) : new Date();
    const durationSeconds = Math.floor(
      (completedAt.getTime() - startedAt.getTime()) / 1000
    );

    const updatedJob: PrintJob = {
      ...job,
      completedAt: completedAt.toISOString(),
      durationSeconds,
      status: data.status,
      finalLayer: data.finalLayer ?? job.totalLayers,
      filamentUsedMm: data.filamentUsedMm ?? null,
    };

    db.printJobs[jobIndex] = updatedJob;
    saveDatabase();

    this.activeJobs.delete(printerPrefix);

    console.log(`[PrintHistory] Completed job ${job.id}: ${data.status}`);
    return updatedJob;
  }

  getActiveJob(printerPrefix: string): PrintJob | null {
    const jobId = this.activeJobs.get(printerPrefix);
    if (!jobId) return null;

    const db = getDatabase();
    return db.printJobs.find(j => j.id === jobId) ?? null;
  }

  getHistory(deviceId: string, limit = 50): PrintJob[] {
    const db = getDatabase();
    return db.printJobs
      .filter(j => j.deviceId === deviceId)
      .sort((a, b) => {
        const aTime = a.startedAt ? new Date(a.startedAt).getTime() : 0;
        const bTime = b.startedAt ? new Date(b.startedAt).getTime() : 0;
        return bTime - aTime;
      })
      .slice(0, limit);
  }

  getAllHistory(limit = 1000): PrintJob[] {
    const db = getDatabase();
    return db.printJobs
      .sort((a, b) => {
        const aTime = a.startedAt ? new Date(a.startedAt).getTime() : 0;
        const bTime = b.startedAt ? new Date(b.startedAt).getTime() : 0;
        return bTime - aTime;
      })
      .slice(0, limit);
  }

  getStats(deviceId: string): {
    totalJobs: number;
    completedJobs: number;
    failedJobs: number;
    totalPrintTimeSeconds: number;
    successRate: number;
  } {
    const jobs = this.getHistory(deviceId, 1000);

    const completedJobs = jobs.filter(j => j.status === 'completed').length;
    const failedJobs = jobs.filter(j => j.status === 'failed').length;
    const totalPrintTimeSeconds = jobs
      .filter(j => j.durationSeconds !== null)
      .reduce((sum, j) => sum + (j.durationSeconds ?? 0), 0);

    return {
      totalJobs: jobs.length,
      completedJobs,
      failedJobs,
      totalPrintTimeSeconds,
      successRate: jobs.length > 0 ? completedJobs / jobs.length : 0,
    };
  }
}

export const printHistoryService = new PrintHistoryService();
