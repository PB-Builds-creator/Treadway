import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const read = path => readFile(resolve(root, path), "utf8");
const [index, manifestText, serviceWorker, config, privacy, setup, insightEngine, app] = await Promise.all([
  read("Web/index.html"),
  read("Web/manifest.webmanifest"),
  read("Web/sw.js"),
  read("Web/config.js"),
  read("Web/privacy.html"),
  read("Web/setup.html"),
  read("Web/insight-engine.js"),
  read("Web/app.js")
]);

const manifest = JSON.parse(manifestText);
assert.equal(manifest.name, "Treadway — Your Daily Path");
assert.equal(manifest.short_name, "Treadway");
assert.equal(manifest.display, "standalone");
assert.match(index, /<title>Treadway<\/title>/);
assert.match(index, /rel="manifest" href="manifest\.webmanifest"/);
assert.match(index, /src="insight-engine\.js"[\s\S]*src="app\.js"/);
assert.match(serviceWorker, /"insight-engine\.js"/);
assert.match(app, /privacy\.html/);
assert.match(privacy, /Treadway/);
assert.match(privacy, /Treadway Brief and AI chats/);
assert.match(privacy, /does not call an AI model, transmit data/);
assert.match(setup, /https:\/\/cairn\.surge\.sh/);
assert.match(serviceWorker, /const CACHE\s*=\s*"treadway-shell-v\d+"/);
assert.match(app, /const TZ = "America\/Denver"/);
assert.match(app, /prefers-reduced-motion/);
assert.match(insightEngine, /PROMPT_VERSION/);
assert.match(insightEngine, /includePrivateText/);
assert.match(app, /Nothing leaves Treadway until you tap Copy/);
assert.match(config, /SUPABASE_ANON_KEY:\s*"sb_publishable_/);
assert.doesNotMatch(config, /sb_secret_|service_role|BEGIN PRIVATE KEY|CRON_SECRET/);
assert.doesNotMatch(index + privacy + setup + app, /vapid-private-KEEP-SECRET/);

console.log("Treadway web verification passed.");
