import QRCode from "qrcode";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { config, resolveEndpoint } from "./config.js";

/** The exact JSON shape the iOS app decodes from the QR / manual code. */
export interface PairingPayload {
  name: string;
  endpoint: string;
  token: string;
}

export function buildPairingPayload(): PairingPayload {
  const { url } = resolveEndpoint();
  return {
    name: config.gatewayName,
    endpoint: url,
    token: config.token,
  };
}

/** Prints the pairing QR to the terminal and writes a PNG next to the process. */
export async function printPairing(): Promise<void> {
  const payload = buildPairingPayload();
  const json = JSON.stringify(payload);
  const { url, secure, note } = resolveEndpoint();

  const terminalQR = await QRCode.toString(json, {
    type: "terminal",
    small: true,
  });

  const pngPath = join(process.cwd(), "atlas-pairing.png");
  await QRCode.toFile(pngPath, json, { width: 512, margin: 2 });

  const line = "─".repeat(60);
  console.log(`\n${line}`);
  console.log("  Atlas Gateway — scan to pair");
  console.log(line);
  console.log(terminalQR);
  console.log(`  Gateway : ${payload.name}`);
  console.log(`  Endpoint: ${url}`);
  console.log(`  QR image: ${pngPath}`);
  if (!secure) {
    console.log(
      "\n  ⚠  " +
        (note ??
          "This endpoint is not wss:// — the iOS app requires a secure connection."),
    );
  }
  console.log(
    "\n  Manual setup code (paste into the app's manual entry):\n",
  );
  console.log("  " + json);
  console.log(`${line}\n`);
}

/** For debugging: also emit the manual code to a file if requested. */
export function writePairingJSON(): string {
  const json = JSON.stringify(buildPairingPayload(), null, 2);
  writeFileSync(join(process.cwd(), "atlas-pairing.json"), json);
  return json;
}
