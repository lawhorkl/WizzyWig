import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCAN_PATTERNS = [
  ["PATTERN:CreateFrame", ["CreateFrame("], "SIG:CreateFrame(frameType,name,parent,template,id)"],
  ["PATTERN:Mixin", ["Mixin(", "CreateFromMixins("], "SIG:Mixin(object,...mixins);CreateFromMixins(...mixins)"],
  ["PATTERN:ColorEscape", ["|c", "|r", "WrapTextInColorCode"], "SYNTAX:|cAARRGGBBtext|r"],
  ["PATTERN:Hyperlink", ["|H", "|h", "SetHyperlink", "ItemRef"], "SYNTAX:|Htype:payload|h[label]|h"],
  ["PATTERN:ChatFrameInternals", ["ChatFrame_MessageEventHandler", "ChatTypeInfo", "ChatTypeGroup"], "RISK:chat_payloads_filters_color_tables"],
  ["PATTERN:ScrollingMessageFrameMixin", ["ScrollingMessageFrameMixin"], "RISK:chat_frame_message_storage_scroll_copy"],
];

export function scanSource(sourceRoot) {
  const interfaceRoot = path.join(sourceRoot, "Interface");
  const files = listFiles(interfaceRoot).filter((file) => file.endsWith(".lua") || file.endsWith(".xml"));
  const records = [];
  const diagnostics = [];

  for (const [name, needles, detail] of SCAN_PATTERNS) {
    const hits = [];
    for (const file of files) {
      const text = fs.readFileSync(file, "utf8");
      const lines = text.split(/\r?\n/);
      for (let i = 0; i < lines.length; i += 1) {
        if (needles.some((needle) => lines[i].includes(needle))) {
          hits.push(`${rel(sourceRoot, file)}:${i + 1}`);
          break;
        }
      }
      if (hits.length >= 12) break;
    }
    if (hits.length) {
      records.push(`${name}\n${detail}\nLOC:${hits.join(",")}`);
    } else {
      diagnostics.push(`missing_scan_pattern:${name}`);
    }
  }

  records.push(
    "GOTCHA:GeneratedDocsCoverage\nDESC:generated_docs_are_authoritative_for_signatures;source_scan_records_are_routing_hints_not_complete_API_lists"
  );
  records.push(
    "GOTCHA:AuditUnknowns\nDESC:if_kb/diagnostics.txt_has_PARSE_FAIL_OR_UNKNOWN_SHAPE_review_source_before_answering_related_API_questions"
  );

  return { records, diagnostics };
}

function listFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(full));
    else out.push(full);
  }
  return out;
}

function rel(root, file) {
  return path.relative(root, file).replaceAll(path.sep, "/");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const sourceRoot = path.resolve(process.argv[2] ?? "wow_reference/wow-ui-source");
  const result = scanSource(sourceRoot);
  console.log(result.records.join("\n\n"));
}
