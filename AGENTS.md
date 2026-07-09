# Agent Instructions

## WoW API Source Priority

For any World of Warcraft UI/API/addon implementation, debugging, review, or code generation task, use sources in this order:

1. Local generated KB:
   - `WOW_API_KB.txt`
   - `kb/index.txt`
   - the smallest relevant `kb/*.txt` topic file
2. Local WoW UI source:
   - `wow_reference/wow-ui-source/`
3. Web or external documentation only if the KB and local WoW UI source do not contain the needed fact.

Do not answer from memory when the question depends on WoW API behavior, function signatures, event payloads, widget methods, constants, hyperlink formats, chat behavior, secure/protected behavior, or addon communication.

## KB Usage

If `kb/index.txt` is missing, rebuild the KB before answering WoW API questions:

```powershell
node scripts\kb-build.mjs wow_reference\wow-ui-source .
```

Use `kb/index.txt` for routing:

- `kb/api_functions.txt`: global and `C_*` APIs
- `kb/widgets_frames.txt`: frames, widgets, script object methods
- `kb/events.txt`: events and payloads
- `kb/enums_types.txt`: enums, constants, structures
- `kb/chat_comm.txt`: chat, addon messages, ChatFrame, ScrollingMessageFrame
- `kb/ui_patterns.txt`: CreateFrame, mixins, hyperlinks, colors, fonts, gotchas

Prefer exact `FN:`, `METHOD:`, `EVENT:`, `ENUM:`, `TYPE:`, `CONST:`, `PATTERN:`, and `GOTCHA:` records over interpretation.

## No Guessing

Do not guess silently.

If a fact is not confirmed by the KB, local WoW UI source, or a cited external source, clearly say:

```text
I am guessing: ...
```

If an implementation choice depends on an unverified WoW API behavior, stop and verify from the KB or `wow_reference/wow-ui-source/` first. If verification fails, tell the user exactly what could not be verified.

If using external docs because local sources failed, say that explicitly and include the source.

## Local Build Limitation

This addon cannot be fully built or executed locally as a WoW addon in this workspace. Do not imply runtime verification inside the WoW client unless it actually happened.

Acceptable local checks include:

- Lua/source inspection
- TOC/static file inspection
- KB validation
- targeted grep/search against `kb/` and `wow_reference/wow-ui-source/`

When a change cannot be runtime-tested in WoW, state that clearly in the final response.
