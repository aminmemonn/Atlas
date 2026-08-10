// Lightweight natural-language → cron parser for automations. Handles the
// common phrasings; returns cron=null (manual) when it can't confidently map
// the request, so nothing runs on a wrong schedule.

export interface ParsedSchedule {
  cron: string | null;
  description: string;
}

const DOW: Record<string, number> = {
  sunday: 0,
  monday: 1,
  tuesday: 2,
  wednesday: 3,
  thursday: 4,
  friday: 5,
  saturday: 6,
};

/** Extracts an "at HH(:MM) am/pm" time; defaults to 09:00. */
function extractTime(text: string): { hour: number; minute: number } {
  const m = text.match(/\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b/i);
  if (!m) return { hour: 9, minute: 0 };
  let hour = parseInt(m[1]!, 10);
  const minute = m[2] ? parseInt(m[2], 10) : 0;
  const period = m[3]?.toLowerCase();
  if (period === "pm" && hour < 12) hour += 12;
  if (period === "am" && hour === 12) hour = 0;
  if (hour > 23) hour = 9;
  return { hour, minute };
}

function timeLabel(hour: number, minute: number): string {
  const period = hour >= 12 ? "PM" : "AM";
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  const mm = minute.toString().padStart(2, "0");
  return `${h12}:${mm} ${period}`;
}

export function parseSchedule(prompt: string): ParsedSchedule {
  const text = prompt.toLowerCase();

  // every N minutes
  const everyMinutes = text.match(/every\s+(\d+)\s+minutes?/);
  if (everyMinutes) {
    const n = Math.max(1, Math.min(59, parseInt(everyMinutes[1]!, 10)));
    return { cron: `*/${n} * * * *`, description: `Every ${n} minutes` };
  }

  // every N hours
  const everyHours = text.match(/every\s+(\d+)\s+hours?/);
  if (everyHours) {
    const n = Math.max(1, Math.min(23, parseInt(everyHours[1]!, 10)));
    return { cron: `0 */${n} * * *`, description: `Every ${n} hours` };
  }

  if (/every\s+hour|hourly/.test(text)) {
    return { cron: "0 * * * *", description: "Every hour" };
  }

  const { hour, minute } = extractTime(text);

  // specific weekday
  for (const [name, dow] of Object.entries(DOW)) {
    if (text.includes(name)) {
      return {
        cron: `${minute} ${hour} * * ${dow}`,
        description: `Every ${cap(name)} at ${timeLabel(hour, minute)}`,
      };
    }
  }

  // weekdays
  if (/weekday|every\s+week\s*day|mon(day)?\s*(-|to|through)\s*fri(day)?/.test(text)) {
    return {
      cron: `${minute} ${hour} * * 1-5`,
      description: `Every weekday at ${timeLabel(hour, minute)}`,
    };
  }

  // weekly
  if (/every\s+week|weekly/.test(text)) {
    return {
      cron: `${minute} ${hour} * * 1`,
      description: `Every Monday at ${timeLabel(hour, minute)}`,
    };
  }

  // daily (explicit or implied by a time)
  if (/every\s+day|daily|each\s+day/.test(text) || /\bat\s+\d/.test(text)) {
    return {
      cron: `${minute} ${hour} * * *`,
      description: `Every day at ${timeLabel(hour, minute)}`,
    };
  }

  return { cron: null, description: "Runs manually (no schedule detected)" };
}

function cap(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
