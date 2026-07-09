import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const REQUIRED_SYMBOLS = [
  "C_ChatInfo.RegisterAddonMessagePrefix",
  "C_ChatInfo.SendAddonMessage",
  "CHAT_MSG_ADDON",
  "ChatFrame_MessageEventHandler",
  "ScrollingMessageFrame:AddMessage",
  "SimpleFontString:SetText",
  "SimpleEditBox:SetText",
  "SimpleButton:Click",
  "SimpleFrame:SetScript",
  "Region:SetPoint",
  "CreateFrame",
  "Mixin",
  "CreateFromMixins",
  "|cAARRGGBB",
  "|Htype:payload",
];

export function validateKb(outRoot, diagnostics) {
  const kbRoot = path.join(outRoot, "kb");
  const files = [
    "WOW_API_KB.txt",
    "kb/index.txt",
    "kb/api_functions.txt",
    "kb/widgets_frames.txt",
    "kb/events.txt",
    "kb/enums_types.txt",
    "kb/chat_comm.txt",
    "kb/ui_patterns.txt",
    "kb/diagnostics.txt",
  ];
  const failures = [];
  let allText = "";

  for (const file of files) {
    const full = path.join(outRoot, file);
    if (!fs.existsSync(full)) failures.push(`missing_output:${file}`);
    else allText += `\n${fs.readFileSync(full, "utf8")}`;
  }

  for (const symbol of REQUIRED_SYMBOLS) {
    if (!allText.includes(symbol)) failures.push(`missing_required:${symbol}`);
  }

  const recordIds = new Map();
  for (const file of fs.readdirSync(kbRoot).filter((name) => name.endsWith(".txt"))) {
    if (file === "index.txt" || file === "diagnostics.txt") continue;
    const text = fs.readFileSync(path.join(kbRoot, file), "utf8");
    for (const line of text.split(/\r?\n/)) {
      const match = /^(FN|METHOD|EVENT|ENUM|TYPE|CONST|PATTERN|GOTCHA):(.+)$/.exec(line);
      if (!match) continue;
      const key = `${match[1]}:${match[2]}`;
      recordIds.set(key, (recordIds.get(key) ?? 0) + 1);
    }
  }
  for (const [key, count] of recordIds.entries()) {
    if (count > 1) failures.push(`duplicate_record:${key}:${count}`);
  }

  diagnostics.validationFailures = failures;
  return failures;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const outRoot = path.resolve(process.argv[2] ?? ".");
  const diagnostics = {};
  const failures = validateKb(outRoot, diagnostics);
  console.log(failures.length ? failures.join("\n") : "OK");
  process.exitCode = failures.length ? 1 : 0;
}
