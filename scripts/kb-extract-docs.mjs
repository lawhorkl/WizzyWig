import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const KNOWN_DOC_KEYS = new Set([
  "Name", "Type", "Namespace", "Environment", "Functions", "Events", "Tables",
  "Predicates", "Documentation", "Arguments", "Returns", "Fields", "Values",
  "LiteralName", "SynchronousEvent", "MayReturnNothing", "Nilable", "Default",
  "InnerType", "EnumValue", "NumValues", "MinValue", "MaxValue",
  "Mixin", "InheritedBy", "ScriptObject", "MixinName",
  "Payload", "Value", "CallbackEvent", "ConditionalSecret", "ConditionalSecretContents",
  "ConstSecretAccessor", "FailureMode", "HasRestrictions", "IsProtectedFunction",
  "MouseFocusValidForLimitedInput", "NeverSecret", "NeverSecretContents",
  "NilableContents", "RequireNPERestricted", "RequiresActiveCommentator",
  "RequiresCanChangeHitTestPoints", "RequiresClubsInitialized", "RequiresCommentator",
  "RequiresComparableUnitTokens", "RequiresDeclassifiedUnitIdentity",
  "RequiresFontStringTextAccess", "RequiresFriendList", "RequiresIndexInRange",
  "RequiresLimitedInput", "RequiresNonReadOnlyCVar", "RequiresNonSecretAura",
  "RequiresNonSecureCVar", "RequiresRecentAllies",
  "RequiresRestrictedAbbreviationBreakpoints", "RequiresScriptObjectAlphaAccess",
  "RequiresScriptObjectDesaturationAccess", "RequiresSpellDiminishUI",
  "RequiresStatusBarDesaturationAccess", "RequiresUnitIdentityAccess",
  "RequiresValidAbbreviationBreakpoints", "RequiresValidActionSlot",
  "RequiresValidAndPublicCVar", "RequiresValidFontAsset", "RequiresValidFontHeight",
  "RequiresValidInviteTarget", "RequiresValidTimelineEvent",
  "RequiresValidUnitAuraInstance", "RestrictedForMacroChatMessages",
  "ReturnsNeverSecret", "SecretArguments", "SecretArgumentsAddAspect",
  "SecretInActivePvPMatch", "SecretInChatMessagingLockdown", "SecretPayloads",
  "SecretReturns", "SecretReturnsForAspect", "SecretValue",
  "SecretWhenAnchoringSecret", "SecretWhenCooldownsRestricted",
  "SecretWhenCurveSecret", "SecretWhenEncounterEvent", "SecretWhenInCombat",
  "SecretWhenLossOfControlInfoRestricted", "SecretWhenNumericFormatterSecret",
  "SecretWhenTotemSlotSecret", "SecretWhenUnitAuraRestricted",
  "SecretWhenUnitComparisonRestricted", "SecretWhenUnitHealthMaxRestricted",
  "SecretWhenUnitIdentityRestricted", "SecretWhenUnitPowerMaxRestricted",
  "SecretWhenUnitPowerRestricted", "SecretWhenUnitSpellCastRestricted",
  "SecretWhenUnitStatsRestricted", "SecretWhenUnitThreatStateRestricted",
  "SecretWhenUnitThreatValuesRestricted", "SecureHooksAllowed", "StrideIndex",
  "UniqueEvent",
]);

export function extractDocumentation(sourceRoot) {
  const addOnsRoot = path.join(sourceRoot, "Interface", "AddOns");
  const files = listFiles(addOnsRoot).filter((file) => file.endsWith("Documentation.lua"));
  const diagnostics = {
    docFiles: files.length,
    parsedFiles: 0,
    parseFailures: [],
    unknownKeys: new Map(),
  };
  const docs = [];

  for (const file of files) {
    try {
      const text = fs.readFileSync(file, "utf8");
      const tableText = firstTopLevelTable(text);
      const parsed = new LuaTableParser(tableText).parse();
      parsed.__file = rel(sourceRoot, file);
      docs.push(parsed);
      diagnostics.parsedFiles += 1;
      collectUnknownKeys(parsed, diagnostics.unknownKeys);
    } catch (error) {
      diagnostics.parseFailures.push(`${rel(sourceRoot, file)}:${error.message}`);
    }
  }

  diagnostics.unknownKeys = [...diagnostics.unknownKeys.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, count]) => `${key}:${count}`);

  return { docs, diagnostics };
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

function firstTopLevelTable(text) {
  const eq = text.indexOf("=");
  if (eq < 0) throw new Error("missing_assignment");
  const start = text.indexOf("{", eq);
  if (start < 0) throw new Error("missing_table_start");
  let depth = 0;
  let quote = null;
  let escape = false;
  for (let i = start; i < text.length; i += 1) {
    const ch = text[i];
    if (quote) {
      if (escape) escape = false;
      else if (ch === "\\") escape = true;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === "\"" || ch === "'") {
      quote = ch;
    } else if (ch === "{") {
      depth += 1;
    } else if (ch === "}") {
      depth -= 1;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  throw new Error("unterminated_table");
}

function collectUnknownKeys(value, unknownKeys) {
  if (Array.isArray(value)) {
    for (const item of value) collectUnknownKeys(item, unknownKeys);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    if (!key.startsWith("__") && !KNOWN_DOC_KEYS.has(key)) {
      unknownKeys.set(key, (unknownKeys.get(key) ?? 0) + 1);
    }
    collectUnknownKeys(child, unknownKeys);
  }
}

function rel(root, file) {
  return path.relative(root, file).replaceAll(path.sep, "/");
}

class LuaTableParser {
  constructor(text) {
    this.tokens = tokenize(text);
    this.pos = 0;
  }

  parse() {
    const value = this.parseValue();
    return value;
  }

  parseValue() {
    let value = this.parseAtom();
    const parts = [value];
    let hasExpression = false;
    while (this.peek()?.value === "+" || this.peek()?.value === "-") {
      hasExpression = true;
      parts.push(this.next().value);
      parts.push(this.parseAtom());
    }
    return hasExpression ? parts.join("") : value;
  }

  parseAtom() {
    const tok = this.peek();
    if (!tok) throw new Error("unexpected_eof");
    if (tok.value === "{") return this.parseTable();
    if (tok.type === "string") return this.next().value;
    if (tok.type === "number") return Number(this.next().value);
    if (tok.type === "ident") {
      const ident = this.parseIdentifierExpression();
      if (ident === "true") return true;
      if (ident === "false") return false;
      if (ident === "nil") return null;
      return ident;
    }
    throw new Error(`unexpected_token_${tok.value}`);
  }

  parseTable() {
    this.expect("{");
    const array = [];
    const object = {};
    let hasKeys = false;

    while (!this.match("}")) {
      if (this.match(",")) continue;
      if (this.match(";")) continue;

      if (this.peek()?.type === "ident" && this.peek(1)?.value === "=") {
        hasKeys = true;
        const key = this.next().value;
        this.expect("=");
        object[key] = this.parseValue();
      } else if (this.match("[")) {
        hasKeys = true;
        const key = String(this.parseValue());
        this.expect("]");
        this.expect("=");
        object[key] = this.parseValue();
      } else {
        array.push(this.parseValue());
      }

      this.match(",");
      this.match(";");
    }

    if (!hasKeys) return array;
    if (array.length) object.__array = array;
    return object;
  }

  parseIdentifierExpression() {
    let out = this.expectType("ident").value;
    while (this.match(".")) {
      out += `.${this.expectType("ident").value}`;
    }
    return out;
  }

  peek(offset = 0) {
    return this.tokens[this.pos + offset];
  }

  next() {
    return this.tokens[this.pos++];
  }

  match(value) {
    if (this.peek()?.value === value) {
      this.pos += 1;
      return true;
    }
    return false;
  }

  expect(value) {
    const tok = this.next();
    if (tok?.value !== value) throw new Error(`expected_${value}_got_${tok?.value ?? "eof"}`);
    return tok;
  }

  expectType(type) {
    const tok = this.next();
    if (tok?.type !== type) throw new Error(`expected_${type}_got_${tok?.value ?? "eof"}`);
    return tok;
  }
}

function tokenize(text) {
  const tokens = [];
  let i = 0;
  while (i < text.length) {
    const ch = text[i];
    if (/\s/.test(ch)) {
      i += 1;
      continue;
    }
    if (ch === "-" && text[i + 1] === "-") {
      while (i < text.length && text[i] !== "\n") i += 1;
      continue;
    }
    if ("{}[]=,;.+".includes(ch) || (ch === "-" && !/[0-9]/.test(text[i + 1]))) {
      tokens.push({ type: "punct", value: ch });
      i += 1;
      continue;
    }
    if (ch === "\"" || ch === "'") {
      const quote = ch;
      let value = "";
      i += 1;
      while (i < text.length) {
        const c = text[i++];
        if (c === "\\") {
          const escaped = text[i++];
          value += escaped === "n" ? "\n" : escaped === "t" ? "\t" : escaped;
        } else if (c === quote) {
          break;
        } else {
          value += c;
        }
      }
      tokens.push({ type: "string", value });
      continue;
    }
    if (/[0-9]/.test(ch) || (ch === "-" && /[0-9]/.test(text[i + 1]))) {
      const start = i;
      i += 1;
      while (i < text.length && /[0-9.]/.test(text[i])) i += 1;
      tokens.push({ type: "number", value: text.slice(start, i) });
      continue;
    }
    if (/[A-Za-z_]/.test(ch)) {
      const start = i;
      i += 1;
      while (i < text.length && /[A-Za-z0-9_]/.test(text[i])) i += 1;
      tokens.push({ type: "ident", value: text.slice(start, i) });
      continue;
    }
    throw new Error(`unhandled_char_${ch}`);
  }
  return tokens;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const sourceRoot = process.argv[2] ?? "wow_reference/wow-ui-source";
  const result = extractDocumentation(path.resolve(sourceRoot));
  console.log(JSON.stringify(result.diagnostics, null, 2));
}
