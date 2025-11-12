# WizzyWig

A WYSIWYG-style chat editor for World of Warcraft roleplayers. See your full emote before sending it!

## Features

- Large multiline text editor for composing emotes and messages
- Channel selector (Say, Emote, Party, Raid)
- Send messages with a single button click
- Built with Ace3 libraries for reliability and performance
- Works seamlessly with EmoteSplitter for long messages

## Development

### Building the Addon

This addon uses the CurseForge packager for building and embedding dependencies.

#### VS Code Tasks (Recommended)

Press `Ctrl+Shift+B` (or `Cmd+Shift+B` on Mac) to run the default build task, or:

1. Press `Ctrl+Shift+P` to open the command palette
2. Type "Tasks: Run Task"
3. Select one of the available tasks:
   - **Build Addon (Development)** - Default build with all libraries embedded
   - **Package Addon (Release)** - Create release package (requires git tag)
   - **Build Addon (Local Only)** - Build zip file locally without uploading
   - **Clean Build Artifacts** - Remove all build files and downloaded libraries

#### Manual Building

```bash
# Development build
./release.sh -d

# Local zip only
./release.sh -z

# Release build (requires git tag)
./release.sh -r

# Clean build artifacts
rm -rf .release Libs *.zip
```

### Build Flags

- `-d` - Development build, packages without git tag requirement
- `-z` - Create zip file only, don't upload
- `-r` - Release build, requires a git tag (e.g., `v1.0.0`)
- `-p` - Skip uploading to CurseForge
- `-w` - Skip uploading to WowInterface

### Installation

After building, the packaged addon will be in the `.release/` directory. Copy the `WizzyWig` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory.

## Usage

### Slash Commands

- `/ww` or `/ww show` - Open the chat editor
- `/ww config` - Open settings panel
- `/ww toggle` - Enable/disable addon
- `/ww help` - Show command list

### How to Use

1. Type `/ww` to open the editor window
2. Write your emote or message in the large text box
3. Select your desired channel from the dropdown (Say, Emote, Party, or Raid)
4. Click "Send" to post your message
5. The editor remains open for your next message

### In-Game Configuration

Access settings via:
- Slash command: `/ww config`
- Game Menu: ESC > Interface > AddOns > WizzyWig

## File Structure

```
WizzyWig/
├── .vscode/
│   └── tasks.json          # VS Code build tasks
├── Core.lua                # Main addon logic
├── WizzyWig.toc           # Addon metadata
├── .pkgmeta               # Packager configuration
├── release.sh             # Build script
└── README.md              # This file
```

## Dependencies

All dependencies are automatically downloaded during the build process:

- LibStub
- CallbackHandler-1.0
- AceAddon-3.0
- AceGUI-3.0
- AceConfig-3.0
- AceConsole-3.0
- AceEvent-3.0
- AceDB-3.0

## License

Add your license here.
