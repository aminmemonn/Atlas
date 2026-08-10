import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

export interface StoredAutomation {
  id: string;
  title: string;
  prompt: string;
  scheduleDescription: string;
  cron: string | null;
  status: "idle" | "running" | "completed" | "failed";
  createdAt: string;
  lastRunAt: string | null;
  nextRunAt: string | null;
  enabled: boolean;
}

interface StoreShape {
  automations: StoredAutomation[];
}

const STORE_FILE = join(process.cwd(), ".atlas-store.json");

function read(): StoreShape {
  if (existsSync(STORE_FILE)) {
    try {
      return JSON.parse(readFileSync(STORE_FILE, "utf8")) as StoreShape;
    } catch {
      // fall through
    }
  }
  return { automations: [] };
}

function write(data: StoreShape): void {
  writeFileSync(STORE_FILE, JSON.stringify(data, null, 2));
}

export const store = {
  listAutomations(): StoredAutomation[] {
    return read().automations;
  },
  upsertAutomation(a: StoredAutomation): void {
    const data = read();
    const idx = data.automations.findIndex((x) => x.id === a.id);
    if (idx >= 0) data.automations[idx] = a;
    else data.automations.push(a);
    write(data);
  },
  updateAutomation(id: string, patch: Partial<StoredAutomation>): StoredAutomation | null {
    const data = read();
    const idx = data.automations.findIndex((x) => x.id === id);
    if (idx < 0) return null;
    const updated = { ...data.automations[idx]!, ...patch };
    data.automations[idx] = updated;
    write(data);
    return updated;
  },
  removeAutomation(id: string): void {
    const data = read();
    data.automations = data.automations.filter((x) => x.id !== id);
    write(data);
  },
};
