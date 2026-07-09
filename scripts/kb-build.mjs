import fs from "node:fs";
import path from "node:path";
import { extractDocumentation } from "./kb-extract-docs.mjs";
import { scanSource } from "./kb-scan-source.mjs";
import { REQUIRED_SYMBOLS, validateKb } from "./kb-validate.mjs";

const sourceRoot = path.resolve(process.argv[2] ?? "wow_reference/wow-ui-source");
const outRoot = path.resolve(process.argv[3] ?? ".");
const kbRoot = path.join(outRoot, "kb");

main();

function main() {
  if (!fs.existsSync(path.join(sourceRoot, "Interface"))) {
    throw new Error(`missing_source_interface:${sourceRoot}`);
  }
  fs.mkdirSync(kbRoot, { recursive: true });

  const version = detectVersion(sourceRoot);
  const buildDate = new Date().toISOString().slice(0, 10);
  const { docs, diagnostics: docDiagnostics } = extractDocumentation(sourceRoot);
  const { records: scanRecords, diagnostics: scanDiagnostics } = scanSource(sourceRoot);

  const topics = {
    api_functions: [],
    widgets_frames: [],
    events: [],
    enums_types: [],
    chat_comm: [],
    ui_patterns: scanRecords,
  };

  for (const doc of docs) emitDoc(doc, topics);

  sortTopics(topics);
  writeTopic("api_functions", topics.api_functions, version, buildDate);
  writeTopic("widgets_frames", topics.widgets_frames, version, buildDate);
  writeTopic("events", topics.events, version, buildDate);
  writeTopic("enums_types", topics.enums_types, version, buildDate);
  writeTopic("chat_comm", topics.chat_comm, version, buildDate);
  writeTopic("ui_patterns", topics.ui_patterns, version, buildDate);

  const diagnostics = {
    version,
    buildDate,
    sourceRoot,
    docDiagnostics,
    scanDiagnostics,
    counts: Object.fromEntries(Object.entries(topics).map(([key, value]) => [key, value.length])),
  };
  writeIndex(version, buildDate, diagnostics);
  writeDiagnostics(diagnostics);
  writeMaster(version, buildDate);
  const failures = validateKb(outRoot, diagnostics);
  writeDiagnostics(diagnostics);
  if (failures.length) {
    console.error(failures.join("\n"));
    process.exitCode = 1;
  } else {
    console.log(`KB_BUILD_OK version=${version} docs=${docDiagnostics.parsedFiles}/${docDiagnostics.docFiles}`);
  }
}

function emitDoc(doc, topics) {
  const owner = normalizeOwner(doc.Name ?? "Global");
  const namespace = doc.Namespace;
  const source = doc.__file;

  if (doc.Type === "ScriptObject") {
    for (const fn of doc.Functions ?? []) {
      const fullName = `${owner}:${fn.Name}`;
      const record = [
        `METHOD:${fullName}`,
        `LOC:${source}`,
        `PARAMS:self,${params(fn.Arguments)}`.replace(/,$/, ""),
        `RET:${returns(fn.Returns, fn.MayReturnNothing)}`,
        flags(fn),
        docLine(fn),
      ].filter(Boolean).join("\n");
      pushTopic(topics, fullName, record);
    }
  } else {
    for (const fn of doc.Functions ?? []) {
      const fullName = namespace ? `${namespace}.${fn.Name}` : fn.Name;
      const record = [
        `FN:${fullName}`,
        `SYS:${doc.Name ?? "Global"}`,
        `LOC:${source}`,
        `PARAMS:${params(fn.Arguments)}`,
        `RET:${returns(fn.Returns, fn.MayReturnNothing)}`,
        flags(fn),
        docLine(fn),
      ].filter(Boolean).join("\n");
      pushTopic(topics, fullName, record);
    }
  }

  for (const event of doc.Events ?? []) {
    const eventName = event.LiteralName ?? event.Name;
    const record = [
      `EVENT:${eventName}`,
      `SYS:${doc.Name ?? "Global"}`,
      `LOC:${source}`,
      `PAYLOAD:${params(event.Payload ?? event.Arguments)}`,
      flags(event),
      docLine(event),
    ].filter(Boolean).join("\n");
    pushTopic(topics, eventName, record);
  }

  for (const table of doc.Tables ?? []) {
    const record = emitTable(table, source);
    pushTopic(topics, table.Name ?? "UNKNOWN_TABLE", record);
  }
}

function emitTable(table, source) {
  if (table.Type === "Enumeration") {
    const values = (table.Fields ?? table.Values ?? [])
      .map((field) => `${field.Name}=${field.EnumValue ?? field.Value ?? "?"}`)
      .join(",");
    return [
      `ENUM:${table.Name}`,
      `LOC:${source}`,
      `VALUES:${values}`,
      bounds(table),
      docLine(table),
    ].filter(Boolean).join("\n");
  }

  if (table.Type === "Constants") {
    const values = (table.Values ?? [])
      .map((field) => `${field.Name}:${typeOf(field)}=${field.Value ?? "?"}`)
      .join(",");
    return [
      `CONST:${table.Name}`,
      `LOC:${source}`,
      `VALUES:${values || "void"}`,
      docLine(table),
    ].filter(Boolean).join("\n");
  }

  const fields = (table.Fields ?? [])
    .map((field) => `${field.Name}:${typeOf(field)}${field.Nilable ? "?" : ""}${field.Value !== undefined ? `=${field.Value}` : ""}`)
    .join(",");
  return [
    `TYPE:${table.Name}`,
    `KIND:${table.Type ?? "Table"}`,
    `LOC:${source}`,
    `FIELDS:${fields || "void"}`,
    docLine(table),
  ].filter(Boolean).join("\n");
}

function pushTopic(topics, name, record) {
  const text = `${name}\n${record}`;
  if (/Chat|CHAT|AddonMessage|SendAddonMessage|RegisterAddonMessagePrefix|ScrollingMessageFrame/.test(text)) {
    topics.chat_comm.push(record);
  } else if (record.startsWith("METHOD:")) {
    topics.widgets_frames.push(record);
  } else if (record.startsWith("EVENT:")) {
    topics.events.push(record);
  } else if (record.startsWith("ENUM:") || record.startsWith("TYPE:") || record.startsWith("CONST:")) {
    topics.enums_types.push(record);
  } else {
    topics.api_functions.push(record);
  }
}

function params(args = []) {
  if (!args.length) return "void";
  return args.map((arg) => {
    const bits = [`${arg.Name ?? "arg"}:${typeOf(arg)}${arg.Nilable ? "?" : ""}`];
    if (arg.Default !== undefined) bits.push(`=${arg.Default}`);
    return bits.join("");
  }).join(",");
}

function returns(rets = [], mayReturnNothing) {
  if (!rets.length) return mayReturnNothing ? "void|nothing" : "void";
  const out = rets.map((ret) => `${ret.Name ?? "ret"}:${typeOf(ret)}${ret.Nilable ? "?" : ""}`).join(",");
  return mayReturnNothing ? `${out}|nothing` : out;
}

function typeOf(item) {
  if (!item) return "unknown";
  return item.InnerType ? `${item.Type}<${item.InnerType}>` : item.Type ?? "unknown";
}

function flags(item) {
  const names = Object.keys(item)
    .filter((key) => /Protected|Secret|Requires|MayReturnNothing|Synchronous/.test(key) && item[key])
    .sort();
  return names.length ? `FLAGS:${names.map((key) => `${key}=${item[key]}`).join(",")}` : "";
}

function docLine(item) {
  const docs = item.Documentation;
  if (!Array.isArray(docs) || !docs.length) return "";
  const text = docs.join(" ").replace(/\s+/g, "_");
  return `DOC:${text.slice(0, 280)}`;
}

function bounds(table) {
  const bits = [];
  if (table.NumValues !== undefined) bits.push(`n=${table.NumValues}`);
  if (table.MinValue !== undefined) bits.push(`min=${table.MinValue}`);
  if (table.MaxValue !== undefined) bits.push(`max=${table.MaxValue}`);
  return bits.length ? `RANGE:${bits.join(",")}` : "";
}

function normalizeOwner(name) {
  return name.endsWith("API") ? name.slice(0, -3) : name;
}

function sortTopics(topics) {
  for (const key of Object.keys(topics)) {
    topics[key] = [...new Set(topics[key])].sort((a, b) => a.localeCompare(b));
  }
}

function writeTopic(name, records, version, buildDate) {
  const header = [
    `KB_TOPIC:${name}`,
    `WOW_VERSION:${version}`,
    `BUILD_DATE:${buildDate}`,
    "AUDIENCE:LLM_ONLY",
    "FORMAT:compact_records_exact_names_grep_first",
    "",
  ].join("\n");
  fs.writeFileSync(path.join(kbRoot, `${name}.txt`), `${header}${records.join("\n\n")}\n`, "utf8");
}

function writeIndex(version, buildDate, diagnostics) {
  const lines = [
    "KB_INDEX:WOW_API",
    `WOW_VERSION:${version}`,
    `BUILD_DATE:${buildDate}`,
    "AUDIENCE:LLM_ONLY",
    "ROUTE:api_functions=C_*_and_global_documented_functions",
    "ROUTE:widgets_frames=ScriptObject_methods_Frame_Button_EditBox_FontString_Region",
    "ROUTE:events=EVENT_payloads",
    "ROUTE:enums_types=ENUM_TYPE_CONST_structures",
    "ROUTE:chat_comm=chat_addon_messages_chatframe_scrollingmessageframe",
    "ROUTE:ui_patterns=CreateFrame_Mixin_hyperlinks_colors_fonts_gotchas",
    `COUNTS:${Object.entries(diagnostics.counts).map(([k, v]) => `${k}=${v}`).join(",")}`,
    `REQUIRED:${REQUIRED_SYMBOLS.join(",")}`,
  ];
  fs.writeFileSync(path.join(kbRoot, "index.txt"), `${lines.join("\n")}\n`, "utf8");
}

function writeDiagnostics(diagnostics) {
  const lines = [
    "KB_DIAGNOSTICS:WOW_API",
    `WOW_VERSION:${diagnostics.version}`,
    `BUILD_DATE:${diagnostics.buildDate}`,
    `DOC_FILES:${diagnostics.docDiagnostics.docFiles}`,
    `PARSED_FILES:${diagnostics.docDiagnostics.parsedFiles}`,
    `PARSE_FAIL:${diagnostics.docDiagnostics.parseFailures.join("|") || "none"}`,
    `UNKNOWN_KEYS:${diagnostics.docDiagnostics.unknownKeys.join(",") || "none"}`,
    `SCAN_WARN:${diagnostics.scanDiagnostics.join("|") || "none"}`,
    `VALIDATION_FAIL:${(diagnostics.validationFailures ?? []).join("|") || "none"}`,
    "AUDIT:review_PARSE_FAIL_UNKNOWN_KEYS_VALIDATION_FAIL_high_risk_chat_secure_frame_hyperlink_color_entries_only",
  ];
  fs.writeFileSync(path.join(kbRoot, "diagnostics.txt"), `${lines.join("\n")}\n`, "utf8");
}

function writeMaster(version, buildDate) {
  const lines = [
    "WOW_API_KB:LLM_ROUTE_INDEX",
    `WOW_VERSION:${version}`,
    `BUILD_DATE:${buildDate}`,
    "LOAD_ORDER:kb/index.txt_then_smallest_relevant_topic",
    "TOPIC:kb/api_functions.txt",
    "TOPIC:kb/widgets_frames.txt",
    "TOPIC:kb/events.txt",
    "TOPIC:kb/enums_types.txt",
    "TOPIC:kb/chat_comm.txt",
    "TOPIC:kb/ui_patterns.txt",
    "DIAGNOSTICS:kb/diagnostics.txt",
    "RULE:prefer_exact_FN_METHOD_EVENT_ENUM_TYPE_records;do_not_infer_when_UNKNOWN_OR_UNVERIFIED_present",
  ];
  fs.writeFileSync(path.join(outRoot, "WOW_API_KB.txt"), `${lines.join("\n")}\n`, "utf8");
}

function detectVersion(root) {
  const versionPath = path.join(root, "version.txt");
  if (fs.existsSync(versionPath)) return fs.readFileSync(versionPath, "utf8").trim();
  return "UNKNOWN";
}
