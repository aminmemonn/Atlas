import { tool } from "ai";
import { z } from "zod";
import { exec } from "node:child_process";
import { readFile } from "node:fs/promises";
import { promisify } from "node:util";
import { config } from "./config.js";
import { searchConfigured, webSearch } from "./search.js";

const execAsync = promisify(exec);

/** Context the session provides so tools can gate on approval and emit pills. */
export interface ToolContext {
  /** Emit a "tool started" pill in the app. */
  toolStarted(name: string): void;
  /** Emit a "tool finished" pill (success/failure) in the app. */
  toolFinished(name: string, success: boolean): void;
  /**
   * Requests approval for a sensitive action. Resolves true if approved in the
   * app, false if denied or the request expired.
   */
  requestApproval(input: {
    title: string;
    description: string;
    domain: string;
    parameters: Record<string, string>;
  }): Promise<boolean>;
}

const DENIED = "The user denied this action. Do not retry it.";

/** Wraps a tool body with start/finish lifecycle reporting. */
function lifecycle<T>(
  ctx: ToolContext,
  name: string,
  body: () => Promise<T & { error?: string }>,
): Promise<T & { error?: string }> {
  ctx.toolStarted(name);
  return body()
    .then((result) => {
      ctx.toolFinished(name, !(result && "error" in result && result.error));
      return result;
    })
    .catch((err) => {
      ctx.toolFinished(name, false);
      throw err;
    });
}

export function createTools(ctx: ToolContext) {
  const getTime = tool({
    description:
      "Get the current date and time. Use when the user asks about now, today, or the time.",
    parameters: z.object({
      timezone: z
        .string()
        .optional()
        .describe("IANA timezone, e.g. America/Chicago. Defaults to server time."),
    }),
    execute: ({ timezone }) =>
      lifecycle(ctx, "get_current_time", async () => {
        try {
          return {
            now: new Date().toLocaleString("en-US", { timeZone: timezone || undefined }),
            iso: new Date().toISOString(),
          };
        } catch {
          return { now: new Date().toString(), iso: new Date().toISOString() };
        }
      }),
  });

  const webSearchTool = tool({
    description:
      "Search the web for current information. Requires user approval before the request is made.",
    parameters: z.object({ query: z.string().describe("The search query.") }),
    execute: ({ query }) =>
      lifecycle(ctx, "web_search", async () => {
        const approved = await ctx.requestApproval({
          title: "Search the web",
          description: `Atlas wants to search for: ${query}`,
          domain: "network",
          parameters: { query },
        });
        if (!approved) return { error: DENIED };
        if (!searchConfigured()) {
          return {
            error:
              "Web search is not configured on this gateway. Add TAVILY_API_KEY or BRAVE_API_KEY to .env.",
          };
        }
        try {
          const { answer, results } = await webSearch(query);
          return { query, answer, results };
        } catch (err) {
          return { error: `Search failed: ${(err as Error).message}` };
        }
      }),
  });

  const readFileTool = tool({
    description:
      "Read the contents of a text file on the host machine. Requires user approval.",
    parameters: z.object({ path: z.string().describe("Path to the file.") }),
    execute: ({ path }) =>
      lifecycle(ctx, "read_file", async () => {
        const approved = await ctx.requestApproval({
          title: "Read a file",
          description: `Atlas wants to read ${path}`,
          domain: "filesystem",
          parameters: { path },
        });
        if (!approved) return { error: DENIED };
        try {
          const content = await readFile(path, "utf8");
          return { path, content: content.slice(0, 20_000) };
        } catch (err) {
          return { error: `Could not read file: ${(err as Error).message}` };
        }
      }),
  });

  const runCommand = tool({
    description:
      "Run a shell command on the host machine. HIGH RISK — always requires user approval.",
    parameters: z.object({ command: z.string().describe("The shell command to execute.") }),
    execute: ({ command }) =>
      lifecycle(ctx, "run_command", async () => {
        const approved = await ctx.requestApproval({
          title: "Run a command",
          description: `Atlas wants to run: ${command}`,
          domain: "shell",
          parameters: { command },
        });
        if (!approved) return { error: DENIED };
        try {
          const { stdout, stderr } = await execAsync(command, {
            timeout: 30_000,
            maxBuffer: 1_000_000,
          });
          return { stdout: stdout.slice(0, 20_000), stderr: stderr.slice(0, 4_000) };
        } catch (err) {
          return { error: `Command failed: ${(err as Error).message}` };
        }
      }),
  });

  return {
    get_current_time: getTime,
    web_search: webSearchTool,
    ...(config.enableFileTool ? { read_file: readFileTool } : {}),
    ...(config.enableShellTool ? { run_command: runCommand } : {}),
  };
}
