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
// the file the hook in fableplan.settings.json keeps current, keyed by this
// process's pid.
const fs = require("fs");

// Full model ids only; the API does not take the fable/opus tracking aliases.
const PLAN_MODEL = "claude-fable-5-1";
const BUILD_MODEL = "claude-opus-5";
const ROW_ID = "fableplan";

const runtimeDir = process.env.XDG_RUNTIME_DIR || process.env.TMPDIR || "/tmp";
const modeFile = `${runtimeDir}/claude-mode.${process.pid}`;

function currentMode() {
  try {
    return fs.readFileSync(modeFile, "utf8").trim();
  } catch {
    return "";
  }
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
