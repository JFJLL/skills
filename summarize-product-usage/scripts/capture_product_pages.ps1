[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Manifest,

    [Alias("OutputDir")]
    [string]$OutputRoot,

    [string]$NodeExecutable,

    [ValidateSet("auto", "chrome", "edge")]
    [string]$Browser = "auto",

    [string]$BrowserExecutable,

    [switch]$ValidateOnly,
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Headed
)

$ErrorActionPreference = "Stop"

function Resolve-BrowserExecutable {
    param([string]$RequestedBrowser, [string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
            throw "Browser executable does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $chromeCandidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    $edgeCandidates = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )

    $candidates = switch ($RequestedBrowser) {
        "chrome" { $chromeCandidates }
        "edge" { $edgeCandidates }
        default { @($chromeCandidates) + @($edgeCandidates) }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $commands = switch ($RequestedBrowser) {
        "chrome" { @("chrome.exe", "chrome") }
        "edge" { @("msedge.exe", "msedge") }
        default { @("chrome.exe", "chrome", "msedge.exe", "msedge") }
    }
    foreach ($commandName in $commands) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }

    throw "No supported Chromium browser found. Install Chrome/Edge or pass -BrowserExecutable."
}

$manifestPath = (Resolve-Path -LiteralPath $Manifest).Path
$nodeCommand = if ($NodeExecutable) {
    if (-not (Test-Path -LiteralPath $NodeExecutable -PathType Leaf)) {
        throw "Node executable does not exist: $NodeExecutable"
    }
    [pscustomobject]@{ Source = (Resolve-Path -LiteralPath $NodeExecutable).Path }
} else {
    Get-Command node -ErrorAction SilentlyContinue
}
if (-not $nodeCommand) {
    throw "Node.js 22 or newer is required for the built-in DevTools screenshot provider."
}

$cacheBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [IO.Path]::GetTempPath() }
$helperDirectory = Join-Path $cacheBase "Codex\summarize-product-usage\runtime"
New-Item -ItemType Directory -Force -Path $helperDirectory | Out-Null
$helperPath = Join-Path $helperDirectory ("capture_product_pages.{0}.{1}.cdp.mjs" -f $PID, [guid]::NewGuid().ToString("N"))

$helperSource = @'
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawn } from "node:child_process";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i], process.argv[i + 1] ?? "true");
}

const mode = args.get("--mode") ?? "capture";
const manifestPath = path.resolve(args.get("--manifest") ?? "");
const explicitOutputRoot = args.get("--output-root");
const browserExecutable = args.get("--browser-executable");
const force = args.get("--force") === "true";
const forceHeaded = args.get("--headed") === "true";

function fail(message, details = []) {
  console.error(`ERROR: ${message}`);
  for (const detail of details) console.error(`  - ${detail}`);
  process.exitCode = 2;
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function slug(value, fallback) {
  const result = String(value ?? "").trim().replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
  return result || fallback;
}

function stableSlug(value, fallback) {
  const original = String(value ?? "");
  return `${slug(original, fallback)}-${sha256(original).slice(0, 8)}`;
}

function canonicalWindowsRelativeFile(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  const candidate = value.trim();
  if (
    path.isAbsolute(candidate) ||
    path.win32.isAbsolute(candidate) ||
    /^[a-zA-Z]:/.test(candidate) ||
    candidate.startsWith("\\\\") ||
    candidate.startsWith("//")
  ) return null;
  const parts = candidate.split(/[\\/]+/);
  if (parts.some(part => part === ".." || part === "." || part === "")) return null;
  return path.win32.normalize(candidate).toLowerCase();
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function validateReady(ready, location, errors, required = true) {
  if (!isObject(ready)) {
    if (required) errors.push(`${location}.ready must be an object`);
    return;
  }
  const hasStrategy =
    (typeof ready.selector === "string" && ready.selector.trim()) ||
    (typeof ready.text === "string" && ready.text.trim()) ||
    Number.isFinite(ready.wait_ms) ||
    Number.isFinite(ready.network_idle_ms);
  if (!hasStrategy) errors.push(`${location}.ready needs selector, text, wait_ms, or network_idle_ms`);
  for (const key of ["wait_ms", "network_idle_ms", "timeout_ms"]) {
    if (ready[key] !== undefined && (!Number.isFinite(ready[key]) || ready[key] < 0)) {
      errors.push(`${location}.ready.${key} must be a non-negative number`);
    }
  }
}

const actionTypes = new Set(["click", "fill", "select", "press", "wait", "wait_selector", "goto", "evaluate"]);
function validateActions(actions, location, errors) {
  if (actions === undefined) return;
  if (!Array.isArray(actions)) {
    errors.push(`${location}.actions must be an array`);
    return;
  }
  actions.forEach((action, index) => {
    const here = `${location}.actions[${index}]`;
    if (!isObject(action) || !actionTypes.has(action.type)) {
      errors.push(`${here}.type must be one of: ${[...actionTypes].join(", ")}`);
      return;
    }
    if (["click", "fill", "select", "press", "wait_selector"].includes(action.type) &&
        (typeof action.selector !== "string" || !action.selector.trim())) {
      errors.push(`${here}.selector is required for ${action.type}`);
    }
    if (action.type === "fill") {
      const values = [action.value !== undefined, typeof action.value_env === "string" && action.value_env.trim()].filter(Boolean).length;
      if (values !== 1) errors.push(`${here} needs exactly one of value or value_env`);
      if (action.value !== undefined && /password|passwd|pwd/i.test(action.selector ?? "")) {
        errors.push(`${here} looks like a password field; use value_env instead of storing the secret in the manifest`);
      }
    }
    if (action.type === "select" && action.value === undefined && !action.value_env) {
      errors.push(`${here} needs value or value_env`);
    }
    if (action.type === "press" && (typeof action.key !== "string" || !action.key)) {
      errors.push(`${here}.key is required for press`);
    }
    if (action.type === "wait" && (!Number.isFinite(action.wait_ms) || action.wait_ms < 0)) {
      errors.push(`${here}.wait_ms must be a non-negative number`);
    }
    if (action.type === "goto" && (typeof action.url !== "string" || !action.url.trim())) {
      errors.push(`${here}.url is required for goto`);
    }
    if (action.type === "evaluate" && (typeof action.script !== "string" || !action.script.trim())) {
      errors.push(`${here}.script is required for evaluate`);
    }
  });
}

function validateManifest(manifest) {
  const errors = [];
  if (!isObject(manifest)) return ["manifest root must be a JSON object"];
  if (manifest.schema_version !== 1) errors.push("schema_version must be 1");
  if (typeof manifest.source_revision !== "string" || !manifest.source_revision.trim()) {
    errors.push("source_revision is required and must identify the source version being documented");
  }
  if (typeof manifest.base_url !== "string" || !/^https?:\/\//i.test(manifest.base_url)) {
    errors.push("base_url must be an absolute http(s) URL");
  } else {
    try { new URL(manifest.base_url); } catch { errors.push("base_url is not a valid URL"); }
  }
  if (!Array.isArray(manifest.roles) || manifest.roles.length === 0) {
    errors.push("roles must contain at least one role");
    return errors;
  }
  const roleNames = new Set();
  manifest.roles.forEach((role, roleIndex) => {
    const here = `roles[${roleIndex}]`;
    if (!isObject(role)) { errors.push(`${here} must be an object`); return; }
    if (typeof role.name !== "string" || !role.name.trim()) errors.push(`${here}.name is required`);
    else if (roleNames.has(role.name)) errors.push(`${here}.name is duplicated: ${role.name}`);
    else roleNames.add(role.name);

    if (role.login !== undefined) {
      if (!isObject(role.login)) errors.push(`${here}.login must be an object`);
      else {
        const loginMode = role.login.mode ?? "actions";
        if (!["actions", "manual", "session"].includes(loginMode)) {
          errors.push(`${here}.login.mode must be actions, manual, or session`);
        }
        if (typeof role.login.url !== "string" || !role.login.url.trim()) errors.push(`${here}.login.url is required`);
        validateActions(role.login.actions, `${here}.login`, errors);
        validateReady(role.login.ready, `${here}.login`, errors, loginMode !== "session");
      }
    }

    if (!Array.isArray(role.pages) || role.pages.length === 0) {
      errors.push(`${here}.pages must contain at least one page`);
      return;
    }
    const pageNames = new Set();
    const pageFiles = new Set();
    role.pages.forEach((page, pageIndex) => {
      const pageHere = `${here}.pages[${pageIndex}]`;
      if (!isObject(page)) { errors.push(`${pageHere} must be an object`); return; }
      if (typeof page.name !== "string" || !page.name.trim()) errors.push(`${pageHere}.name is required`);
      else if (pageNames.has(page.name)) errors.push(`${pageHere}.name is duplicated: ${page.name}`);
      else pageNames.add(page.name);
      if (typeof page.url !== "string" || !page.url.trim()) errors.push(`${pageHere}.url is required`);
      validateReady(page.ready, pageHere, errors, true);
      validateActions(page.actions, pageHere, errors);
      const file = page.file ?? `${slug(page.name, `page-${pageIndex + 1}`)}.png`;
      if (typeof file !== "string" || !/\.png$/i.test(file)) errors.push(`${pageHere}.file must end in .png`);
      const canonicalFile = canonicalWindowsRelativeFile(file);
      if (!canonicalFile) errors.push(`${pageHere}.file must be a safe relative path inside its role output directory`);
      if (canonicalFile && pageFiles.has(canonicalFile)) errors.push(`${pageHere}.file is duplicated on Windows: ${file}`);
      if (canonicalFile) pageFiles.add(canonicalFile);
    });
  });
  return errors;
}

function readPng(filePath) {
  try {
    const stat = fs.statSync(filePath);
    if (!stat.isFile() || stat.size < 100) return { valid: false, reason: "file is empty or too small" };
    const header = Buffer.alloc(24);
    const fd = fs.openSync(filePath, "r");
    try { fs.readSync(fd, header, 0, 24, 0); } finally { fs.closeSync(fd); }
    if (!header.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
      return { valid: false, reason: "file does not have a PNG signature" };
    }
    const width = header.readUInt32BE(16);
    const height = header.readUInt32BE(20);
    if (width < 1 || height < 1) return { valid: false, reason: "PNG dimensions are invalid" };
    return { valid: true, width, height, bytes: stat.size };
  } catch (error) {
    return { valid: false, reason: error.message };
  }
}

function readJsonIfExists(filePath, fallback) {
  try { return JSON.parse(fs.readFileSync(filePath, "utf8")); } catch { return fallback; }
}

function writeJsonAtomic(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const temporary = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  fs.renameSync(temporary, filePath);
}

let rawManifest;
let manifest;
try {
  rawManifest = fs.readFileSync(manifestPath, "utf8");
  manifest = JSON.parse(rawManifest);
} catch (error) {
  fail(`Cannot read manifest: ${error.message}`);
  process.exit();
}

const validationErrors = validateManifest(manifest);
if (validationErrors.length) {
  fail(`Manifest validation failed (${validationErrors.length} issue${validationErrors.length === 1 ? "" : "s"})`, validationErrors);
  process.exit();
}

const manifestHash = sha256(rawManifest);
const cacheBase = process.env.LOCALAPPDATA || os.tmpdir();
const documentId = stableSlug(manifest.id ?? path.basename(manifestPath, path.extname(manifestPath)), "product");
const revisionId = stableSlug(manifest.source_revision, "revision");
const outputRoot = path.resolve(explicitOutputRoot || path.join(cacheBase, "Codex", "summarize-product-usage", "captures", documentId, revisionId));
const metadataPath = path.join(outputRoot, ".capture-index.json");
const reportPath = path.join(outputRoot, "capture-report.json");
const metadata = readJsonIfExists(metadataPath, { schema_version: 1, captures: {} });

function capturePath(role, page, pageIndex) {
  const roleDirectory = stableSlug(role.name, "role");
  const file = page.file ?? `${slug(page.name, `page-${pageIndex + 1}`)}.png`;
  const roleRoot = path.resolve(outputRoot, roleDirectory);
  const resolved = path.resolve(roleRoot, file);
  const relative = path.relative(roleRoot, resolved);
  if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error(`Unsafe screenshot path escaped role output directory: ${file}`);
  }
  return resolved;
}

function reuseState(role, page, pageIndex) {
  const key = `${role.name}/${page.name}`;
  const filePath = capturePath(role, page, pageIndex);
  const item = metadata.captures?.[key];
  const png = readPng(filePath);
  const valid = !force && png.valid && item &&
    item.source_revision === manifest.source_revision &&
    item.manifest_hash === manifestHash &&
    path.resolve(item.path) === filePath;
  return { key, filePath, item, png, reusable: Boolean(valid) };
}

console.log(`Manifest: ${manifestPath}`);
console.log(`Source revision: ${manifest.source_revision}`);
console.log(`Output root: ${outputRoot}`);
console.log(`Manifest SHA-256: ${manifestHash}`);

if (mode === "validate") {
  const pageCount = manifest.roles.reduce((sum, role) => sum + role.pages.length, 0);
  console.log(`VALID: ${manifest.roles.length} role(s), ${pageCount} page(s)`);
  process.exit(0);
}

if (mode === "dry-run") {
  let reusable = 0;
  let planned = 0;
  for (const role of manifest.roles) {
    console.log(`ROLE ${role.name}: login=${role.login?.mode ?? "none"}`);
    role.pages.forEach((page, pageIndex) => {
      const state = reuseState(role, page, pageIndex);
      if (state.reusable) reusable += 1; else planned += 1;
      console.log(`  ${state.reusable ? "REUSE" : "CAPTURE"} ${page.name} -> ${state.filePath}`);
    });
  }
  console.log(`DRY RUN: ${reusable} reusable, ${planned} capture(s) needed; browser was not started`);
  process.exit(0);
}

if (!browserExecutable || !fs.existsSync(browserExecutable)) {
  fail("Capture mode needs a valid Chrome/Edge executable");
  process.exit();
}
if (typeof globalThis.WebSocket !== "function") {
  fail("This capture provider needs Node.js 22 or newer (global WebSocket is unavailable)");
  process.exit();
}

class CDP {
  constructor(url) {
    this.url = url;
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
  }
  async connect() {
    this.socket = new WebSocket(this.url);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("Timed out connecting to DevTools")), 10000);
      this.socket.addEventListener("open", () => { clearTimeout(timer); resolve(); }, { once: true });
      this.socket.addEventListener("error", () => { clearTimeout(timer); reject(new Error("DevTools WebSocket connection failed")); }, { once: true });
    });
    this.socket.addEventListener("message", event => {
      const message = JSON.parse(String(event.data));
      if (message.id) {
        const pending = this.pending.get(message.id);
        if (!pending) return;
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(`${pending.method}: ${message.error.message}`));
        else pending.resolve(message.result ?? {});
        return;
      }
      const callbacks = this.listeners.get(message.method) ?? [];
      for (const callback of callbacks) callback(message.params ?? {});
    });
    this.socket.addEventListener("close", () => {
      for (const pending of this.pending.values()) pending.reject(new Error("DevTools connection closed"));
      this.pending.clear();
    });
  }
  call(method, params = {}, timeoutMs = 30000) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method}: timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, {
        method,
        resolve: value => { clearTimeout(timer); resolve(value); },
        reject: error => { clearTimeout(timer); reject(error); }
      });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  on(method, callback) {
    const callbacks = this.listeners.get(method) ?? [];
    callbacks.push(callback);
    this.listeners.set(method, callbacks);
  }
  close() { try { this.socket?.close(); } catch {} }
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function waitForFile(filePath, processHandle, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (fs.existsSync(filePath)) return;
    if (processHandle.exitCode !== null) throw new Error(`Browser exited early with code ${processHandle.exitCode}`);
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${filePath}`);
}

async function createPage(port) {
  const response = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent("about:blank")}`, {
    method: "PUT",
    signal: AbortSignal.timeout(10000)
  });
  if (!response.ok) throw new Error(`DevTools target creation failed: HTTP ${response.status}`);
  const target = await response.json();
  const client = new CDP(target.webSocketDebuggerUrl);
  await client.connect();
  return client;
}

function resolveUrl(value) { return new URL(value, manifest.base_url).href; }

async function evaluate(client, expression, awaitPromise = true) {
  const result = await client.call("Runtime.evaluate", { expression, awaitPromise, returnByValue: true, userGesture: true });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text ?? "Page script failed");
  }
  return result.result?.value;
}

async function waitForSelector(client, selector, timeoutMs) {
  const encoded = JSON.stringify(selector);
  const expression = `(async () => {
    const deadline = Date.now() + ${Math.round(timeoutMs)};
    while (Date.now() < deadline) {
      const element = document.querySelector(${encoded});
      if (element) return true;
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw new Error("Timed out waiting for selector: " + ${encoded});
  })()`;
  await evaluate(client, expression, true);
}

async function waitForText(client, wantedText, timeoutMs) {
  const encoded = JSON.stringify(wantedText);
  const expression = `(async () => {
    const deadline = Date.now() + ${Math.round(timeoutMs)};
    while (Date.now() < deadline) {
      if ((document.body?.innerText ?? "").includes(${encoded})) return true;
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw new Error("Timed out waiting for text: " + ${encoded});
  })()`;
  await evaluate(client, expression, true);
}

async function waitForDocumentReady(client, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      if (await evaluate(client, "document.readyState === 'complete'", false)) return;
    } catch {}
    await sleep(100);
  }
  throw new Error("Timed out waiting for document.readyState=complete");
}

async function waitForNetworkIdle(client, network, idleMs, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let idleSince = null;
  while (Date.now() < deadline) {
    if (network.size === 0) {
      idleSince ??= Date.now();
      if (Date.now() - idleSince >= idleMs) return;
    } else {
      idleSince = null;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${idleMs}ms of network idle`);
}

async function waitReady(client, network, ready) {
  if (!ready) return;
  const timeoutMs = ready.timeout_ms ?? manifest.defaults?.timeout_ms ?? 20000;
  await waitForDocumentReady(client, timeoutMs);
  if (ready.selector) await waitForSelector(client, ready.selector, timeoutMs);
  if (ready.text) await waitForText(client, ready.text, timeoutMs);
  if (Number.isFinite(ready.network_idle_ms)) await waitForNetworkIdle(client, network, ready.network_idle_ms, timeoutMs);
  if (Number.isFinite(ready.wait_ms) && ready.wait_ms > 0) await sleep(ready.wait_ms);
}

function actionValue(action, location) {
  if (action.value_env) {
    const value = process.env[action.value_env];
    if (value === undefined) throw new Error(`${location}: environment variable ${action.value_env} is not set`);
    return value;
  }
  return String(action.value ?? "");
}

async function runActions(client, network, actions = [], location) {
  for (let index = 0; index < actions.length; index++) {
    const action = actions[index];
    const here = `${location}.actions[${index}]`;
    const timeoutMs = action.timeout_ms ?? manifest.defaults?.timeout_ms ?? 20000;
    if (action.type === "wait") { await sleep(action.wait_ms); continue; }
    if (action.type === "wait_selector") { await waitForSelector(client, action.selector, timeoutMs); continue; }
    if (action.type === "goto") {
      network.clear();
      await client.call("Page.navigate", { url: resolveUrl(action.url) });
      await waitForDocumentReady(client, timeoutMs);
      continue;
    }
    if (action.type === "evaluate") { await evaluate(client, action.script, true); continue; }

    await waitForSelector(client, action.selector, timeoutMs);
    const selector = JSON.stringify(action.selector);
    if (action.type === "click") {
      await evaluate(client, `(() => { const e = document.querySelector(${selector}); e.scrollIntoView({block:'center'}); e.click(); return true; })()`);
    } else if (action.type === "fill") {
      const value = JSON.stringify(actionValue(action, here));
      await evaluate(client, `(() => { const e = document.querySelector(${selector}); e.focus(); const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(e), 'value')?.set; if (setter) setter.call(e, ${value}); else e.value = ${value}; e.dispatchEvent(new Event('input',{bubbles:true})); e.dispatchEvent(new Event('change',{bubbles:true})); return true; })()`);
    } else if (action.type === "select") {
      const value = JSON.stringify(actionValue(action, here));
      await evaluate(client, `(() => { const e = document.querySelector(${selector}); e.value = ${value}; e.dispatchEvent(new Event('input',{bubbles:true})); e.dispatchEvent(new Event('change',{bubbles:true})); return true; })()`);
    } else if (action.type === "press") {
      await evaluate(client, `(() => { document.querySelector(${selector}).focus(); return true; })()`);
      const key = action.key;
      const keyMap = {
        Enter: { code: "Enter", windowsVirtualKeyCode: 13, text: "\r" },
        Tab: { code: "Tab", windowsVirtualKeyCode: 9 },
        Escape: { code: "Escape", windowsVirtualKeyCode: 27 },
        Backspace: { code: "Backspace", windowsVirtualKeyCode: 8 },
        Delete: { code: "Delete", windowsVirtualKeyCode: 46 },
        ArrowUp: { code: "ArrowUp", windowsVirtualKeyCode: 38 },
        ArrowDown: { code: "ArrowDown", windowsVirtualKeyCode: 40 },
        ArrowLeft: { code: "ArrowLeft", windowsVirtualKeyCode: 37 },
        ArrowRight: { code: "ArrowRight", windowsVirtualKeyCode: 39 }
      };
      const details = keyMap[key] ?? {
        code: key.length === 1 ? `Key${key.toUpperCase()}` : key,
        windowsVirtualKeyCode: key.length === 1 ? key.toUpperCase().charCodeAt(0) : 0,
        text: key.length === 1 ? key : undefined
      };
      await client.call("Input.dispatchKeyEvent", { type: "keyDown", key, ...details });
      await client.call("Input.dispatchKeyEvent", { type: "keyUp", key, code: details.code, windowsVirtualKeyCode: details.windowsVirtualKeyCode });
    }
    if (action.wait_after_ms) await sleep(action.wait_after_ms);
  }
}

async function navigate(client, network, url, timeoutMs) {
  network.clear();
  await client.call("Page.navigate", { url: resolveUrl(url) });
  await waitForDocumentReady(client, timeoutMs);
}

async function takeScreenshot(client, filePath, fullPage) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  let params = { format: "png", fromSurface: true, captureBeyondViewport: true };
  if (fullPage !== false) {
    const metrics = await client.call("Page.getLayoutMetrics");
    const size = metrics.cssContentSize ?? metrics.contentSize;
    if (size.width > 16384 || size.height > 16384) {
      throw new Error(
        `Full-page content is ${Math.ceil(size.width)}x${Math.ceil(size.height)}px, exceeding Chromium's 16384px safe capture limit; ` +
        "split this page into multiple manifest entries with focused selectors/actions instead of silently truncating it"
      );
    }
    params.clip = {
      x: 0,
      y: 0,
      width: Math.max(1, Math.ceil(size.width)),
      height: Math.max(1, Math.ceil(size.height)),
      scale: 1
    };
  }
  const result = await client.call("Page.captureScreenshot", params);
  const temporary = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, Buffer.from(result.data, "base64"));
  const validation = readPng(temporary);
  if (!validation.valid) {
    fs.rmSync(temporary, { force: true });
    throw new Error(`Screenshot validation failed: ${validation.reason}`);
  }
  fs.renameSync(temporary, filePath);
  return validation;
}

async function launchRole(role) {
  const profileRoot = path.join(cacheBase, "Codex", "summarize-product-usage", "profiles", documentId, stableSlug(role.name, "role"));
  fs.mkdirSync(profileRoot, { recursive: true });
  const portFile = path.join(profileRoot, "DevToolsActivePort");
  fs.rmSync(portFile, { force: true });
  const viewport = manifest.viewport ?? {};
  const width = viewport.width ?? 1440;
  const height = viewport.height ?? 900;
  const manualLogin = role.login?.mode === "manual";
  const headed = forceHeaded || manualLogin;
  const browserArgs = [
    "--remote-debugging-port=0",
    `--user-data-dir=${profileRoot}`,
    `--window-size=${width},${height}`,
    "--force-device-scale-factor=1",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    "--password-store=basic",
    "about:blank"
  ];
  if (!headed) browserArgs.unshift("--headless=new", "--hide-scrollbars");
  const browser = spawn(browserExecutable, browserArgs, { stdio: "ignore", windowsHide: !headed });
  await waitForFile(portFile, browser);
  const [portLine] = fs.readFileSync(portFile, "utf8").trim().split(/\r?\n/);
  const port = Number(portLine);
  if (!Number.isInteger(port)) throw new Error("Browser returned an invalid DevTools port");
  const client = await createPage(port);
  const network = new Set();
  client.on("Network.requestWillBeSent", event => network.add(event.requestId));
  client.on("Network.loadingFinished", event => network.delete(event.requestId));
  client.on("Network.loadingFailed", event => network.delete(event.requestId));
  await client.call("Page.enable");
  await client.call("Runtime.enable");
  await client.call("Network.enable");
  await client.call("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: viewport.device_scale_factor ?? 1, mobile: false });
  return { browser, client, network, headed };
}

async function closeRole(session) {
  try { await session.client.call("Browser.close"); } catch {}
  session.client.close();
  const deadline = Date.now() + 3000;
  while (session.browser.exitCode === null && Date.now() < deadline) await sleep(100);
  if (session.browser.exitCode === null) session.browser.kill();
}

fs.mkdirSync(outputRoot, { recursive: true });
metadata.schema_version = 1;
metadata.source_revision = manifest.source_revision;
metadata.manifest_hash = manifestHash;
metadata.manifest_path = manifestPath;
metadata.captures ??= {};

const failures = [];
let capturedCount = 0;
let reusedCount = 0;

for (const role of manifest.roles) {
  const pendingPages = role.pages.map((page, pageIndex) => ({ page, pageIndex, state: reuseState(role, page, pageIndex) }));
  for (const item of pendingPages.filter(item => item.state.reusable)) {
    reusedCount += 1;
    console.log(`REUSE ${role.name}/${item.page.name}: ${item.state.filePath}`);
  }
  const work = pendingPages.filter(item => !item.state.reusable);
  if (work.length === 0) continue;

  let session;
  try {
    session = await launchRole(role);
    if (role.login) {
      const login = role.login;
      const timeoutMs = login.ready?.timeout_ms ?? (login.mode === "manual" ? 180000 : 30000);
      console.log(`LOGIN ${role.name}: ${login.mode ?? "actions"}${session.headed ? " (browser visible)" : ""}`);
      await navigate(session.client, session.network, login.url, timeoutMs);
      if (login.mode === "manual") console.log(`  Complete login in the visible browser; waiting up to ${Math.ceil(timeoutMs / 1000)} seconds for the ready condition.`);
      await runActions(session.client, session.network, login.actions, `${role.name}.login`);
      if (login.ready) await waitReady(session.client, session.network, login.ready);
    }

    for (const { page, pageIndex, state } of work) {
      let lastError;
      for (let attempt = 1; attempt <= 2; attempt++) {
        try {
          const timeoutMs = page.ready?.timeout_ms ?? manifest.defaults?.timeout_ms ?? 20000;
          console.log(`CAPTURE ${role.name}/${page.name}: attempt ${attempt}/2`);
          await navigate(session.client, session.network, page.url, timeoutMs);
          await runActions(session.client, session.network, page.actions, `${role.name}.${page.name}`);
          await waitReady(session.client, session.network, page.ready);
          const png = await takeScreenshot(session.client, state.filePath, page.full_page ?? manifest.defaults?.full_page ?? false);
          metadata.captures[state.key] = {
            source_revision: manifest.source_revision,
            manifest_hash: manifestHash,
            path: state.filePath,
            captured_at: new Date().toISOString(),
            url: resolveUrl(page.url),
            width: png.width,
            height: png.height,
            bytes: png.bytes
          };
          writeJsonAtomic(metadataPath, metadata);
          capturedCount += 1;
          console.log(`  OK ${png.width}x${png.height}, ${png.bytes} bytes -> ${state.filePath}`);
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          console.error(`  FAILED attempt ${attempt}/2: ${error.message}`);
          if (attempt === 1) {
            await closeRole(session);
            session = await launchRole(role);
            if (role.login) {
              const login = role.login;
              const loginTimeout = login.ready?.timeout_ms ?? (login.mode === "manual" ? 180000 : 30000);
              await navigate(session.client, session.network, login.url, loginTimeout);
              await runActions(session.client, session.network, login.actions, `${role.name}.login`);
              if (login.ready) await waitReady(session.client, session.network, login.ready);
            }
            await sleep(500);
          }
        }
      }
      if (lastError) failures.push(`${role.name}/${page.name}: ${lastError.message}`);
    }
  } catch (error) {
    for (const { page } of work) failures.push(`${role.name}/${page.name}: role setup/login failed: ${error.message}`);
  } finally {
    if (session) await closeRole(session);
  }
}

console.log(`SUMMARY: ${capturedCount} captured, ${reusedCount} reused, ${failures.length} failed`);
const report = {
  schema_version: 1,
  status: failures.length ? "failed" : "passed",
  source_revision: manifest.source_revision,
  manifest_hash: manifestHash,
  manifest_path: manifestPath,
  output_root: outputRoot,
  generated_at: new Date().toISOString(),
  required_count: manifest.roles.reduce((sum, role) => sum + role.pages.length, 0),
  captured_count: capturedCount,
  reused_count: reusedCount,
  failed_count: failures.length,
  failures,
  captures: metadata.captures
};
writeJsonAtomic(reportPath, report);
console.log(`CAPTURE REPORT: ${reportPath}`);
if (failures.length) {
  fail("One or more required screenshots failed", failures);
} else {
  console.log(`CAPTURE INDEX: ${metadataPath}`);
}
'@

[IO.File]::WriteAllText($helperPath, $helperSource, [Text.UTF8Encoding]::new($false))

$mode = if ($ValidateOnly) { "validate" } elseif ($DryRun) { "dry-run" } else { "capture" }
$nodeArgs = @($helperPath, "--manifest", $manifestPath, "--mode", $mode)

if ($OutputRoot) {
    $nodeArgs += @("--output-root", [IO.Path]::GetFullPath($OutputRoot))
}
if ($Force) { $nodeArgs += @("--force", "true") }
if ($Headed) { $nodeArgs += @("--headed", "true") }

if ($mode -eq "capture") {
    $resolvedBrowser = Resolve-BrowserExecutable -RequestedBrowser $Browser -ExplicitPath $BrowserExecutable
    $nodeArgs += @("--browser-executable", $resolvedBrowser)
}

try {
    & $nodeCommand.Source @nodeArgs
    $exitCode = $LASTEXITCODE
} finally {
    Remove-Item -LiteralPath $helperPath -Force -ErrorAction SilentlyContinue
}
exit $exitCode
