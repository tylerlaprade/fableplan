// fableplan — Fable plans, Opus executes.
// Mechanism and caveats: see README.md in this directory.
//
// Loaded into the claude binary through BUN_OPTIONS=--preload, before the
// bundle runs. Claude Code's only mode-dependent model is opusplan, and its
// split (opus tier in plan mode, sonnet tier otherwise) is fixed in the
// binary. The picker row in fableplan.settings.json uses the made-up id
// "fableplan", which reaches every Messages API request unchanged. This file
// wraps fetch and swaps that id for the plan model while the session is in
// plan mode and for the build model otherwise. The permission mode comes from
// the file fableplan-hook.sh keeps current. The hook names it after
// CLAUDE_PID, which Claude Code sets to its own pid when it runs a hook, so
// process.pid here is the same number.
const fs = require("fs");

// Full model ids only; the API does not take the fable/opus tracking aliases.
const PLAN_MODEL = "claude-fable-5-1";
const BUILD_MODEL = "claude-opus-5";
const ROW_ID = "fableplan";

// Every value Claude Code reports as permission_mode. Anything else means the
// hook did not run or wrote garbage, and is reported instead of trusted.
const MODES = new Set(["plan", "default", "acceptEdits", "auto", "bypassPermissions", "dontAsk"]);

const runtimeDir = process.env.XDG_RUNTIME_DIR || process.env.TMPDIR || "/tmp";
const modeFile = `${runtimeDir}/fableplan-${process.getuid()}/claude-mode.${process.pid}`;

// A session that was killed leaves its file behind. If this pid was reused,
// that file is not ours: remove it before the first hook of this session
// writes a fresh one.
try {
  fs.unlinkSync(modeFile);
} catch {}

let lastMode = "";
let warned = false;

function currentMode() {
  let mode;
  try {
    mode = fs.readFileSync(modeFile, "utf8").trim();
  } catch {
    mode = "";
  }
  if (MODES.has(mode)) {
    lastMode = mode;
    return mode;
  }
  if (!warned) {
    warned = true;
    console.error(
      `fableplan: no usable permission mode in ${modeFile} (got ${JSON.stringify(mode)}); ` +
        `is fableplan-hook.sh running? Using ${lastMode || `${BUILD_MODEL} until it does`}.`,
    );
  }
  return lastMode;
}

const realFetch = globalThis.fetch;
globalThis.fetch = function (input, init) {
  const url = typeof input === "string" ? input : input?.url;
  if (url?.includes("/v1/messages") && typeof init?.body === "string") {
    try {
      const body = JSON.parse(init.body);
      if (body.model === ROW_ID) {
        body.model = currentMode() === "plan" ? PLAN_MODEL : BUILD_MODEL;
        init = { ...init, body: JSON.stringify(body) };
      }
    } catch {
      // Not JSON, or a shape without a model: send unchanged.
    }
  }
  return realFetch.call(this, input, init);
};

process.on("exit", () => {
  try {
    fs.unlinkSync(modeFile);
  } catch {}
});
