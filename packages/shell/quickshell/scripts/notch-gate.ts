// notch-gate.ts — Pi extension for the notch's Pi backend (scripts/ask.py --backend pi).
// Reads always run; anything else is blocked unless the question was asked in Act
// mode (ask.py writes "1" to $NOTCH_PI_ACT), and then Ever approves each call in the notch.
import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SAFE = new Set(["read", "grep", "find", "ls", "optchat_memory"]);

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (SAFE.has(event.toolName)) return undefined;
		let act = false;
		try { act = readFileSync(process.env.NOTCH_PI_ACT ?? "", "utf8").trim() === "1"; } catch {}
		if (!act) return { block: true, reason: `Skipped: Act is off, so ${event.toolName} did not run. Tell Ever in one line; do not retry.` };
		const input = event.input as Record<string, unknown>;
		const detail = String(input.command ?? input.path ?? JSON.stringify(input)).slice(0, 300);
		if (!(await ctx.ui.confirm(event.toolName, detail))) {
			return { block: true, reason: `Skipped: Ever denied ${event.toolName} (${detail.slice(0, 80)}). Say so in one line and stop; do not retry it.` };
		}
		return undefined;
	});
}
