# Changelog

All notable changes to WizzyWig will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-01-31

### Added
- **WoW 12.0.0 compatibility** - Updated for The War Within Season 2
  - Chat messaging lockdown detection (prevents sending during encounters/mythic+/rated PvP)
  - Displays user-friendly error messages when chat is restricted
- **Raid Warning channel** - New channel option in dropdown and settings
  - Available for raid leaders and assistants
  - Permission validation before sending

### Changed
- Updated Interface version to 120000 for WoW 12.0.0
- Enhanced message sending validation with new lockdown checks

## [1.2.0] - 2025-11-17

### Added
- **Misspelled spell checker integration** - Automatic spell checking while composing messages
  - Real-time highlighting of misspelled words
  - Right-click for spelling suggestions
  - Requires EmoteSplitter addon to avoid character limit conflicts
  - Seamless integration with existing Misspelled workflow
- **Frame persistence** - Window now hides instead of destroying when closed
  - Draft text preserved between window opens/closes
  - Maintains Misspelled word tracking state
  - Faster window reopening

### Changed
- Updated OptionalDeps to include EmoteSplitter and Misspelled
- Improved editbox frame compatibility for external addon integrations

### Technical
- Added GetName() override for Misspelled's word location tracking
- Integrated Misspelled:WireUpEditBox() for spell checking hooks
- Modified OnClose callback to preserve frame state

## [1.1.1] - 2025-11-14

### Changed
- Updated Interface version to 110207 for WoW 11.0.7 compatibility

## [1.1.0] - 2025-11-14

### Added
- **EmoteSplitter integration** - Automatic detection and character limit management
  - Shows 255 character limit warning when EmoteSplitter is not loaded
  - Unlimited message length when EmoteSplitter is detected
  - Prevents disconnects from oversized chat messages
- **In-game chat limit enforcement** - Visual feedback for message length

### Changed
- Enhanced label text to indicate EmoteSplitter status
- Improved user messaging about character limitations

## [1.0.1] - 2025-11-14

### Added
- **Custom minimap icon** - Professional branded icon for WizzyWig
  - Replaces default placeholder icon
  - Improved visual identity
  - Click to toggle main window

### Changed
- Minimap button now functional with proper tooltip
- Updated minimap button interaction behavior

### Fixed
- Minimap button visibility and interaction issues

## [1.0.0] - 2025-11-14

### Added
- **Welcome popup** - First-run experience for new users
  - Clear instructions on how to use the addon
  - Information about EmoteSplitter integration
  - Only shows once per character
- **Channel dropdown** - Support for multiple chat channels
  - Say, Emote, Party, Raid, Instance, Guild, Officer, Yell, Whisper
  - Remembers last-used channel preference
  - Quick channel switching
- **Clear on Send option** - User preference for text clearing behavior
  - Configurable via settings menu
  - Defaults to preserving text after sending

### Changed
- Reorganized codebase into proper OOP structure
  - Core.lua: Main addon initialization and settings
  - MainFrame.lua: UI composition and message handling
  - WelcomePopup.lua: First-run experience
- Improved frame management and state handling

## [0.9.0] - 2025-11-13

### Added
- **Raid marker toolbar** - Visual icon buttons for inserting raid markers
  - Click to insert {rt1} through {rt8} codes
  - Icons displayed as textures in editbox preview
  - Converted to chat codes on send
- **Multi-line editbox** - 15-line composition area
  - Full WYSIWYG preview of formatted messages
  - Raid marker texture preview
  - AceGUI MultiLineEditBox widget
- **Send button** - Dedicated button to send messages
- **Channel-aware message sending** - Routes messages to selected channel

### Technical
- Icon insertion with cursor position management
- Texture markup to chat code conversion
- SendChatMessage integration for all supported channels

## [0.8.0] - 2025-11-11

### Added
- **Core addon framework** - Initial working build
  - Ace3 framework integration
  - AceGUI-3.0 for UI components
  - AceConfig-3.0 for settings
  - AceDB-3.0 for saved variables
  - AceConsole-3.0 for slash commands
- **Main window frame** - Resizable addon window
  - Draggable and repositionable
  - Position saved between sessions
- **Minimap button** - LibDBIcon integration
  - Toggle window visibility
  - Draggable around minimap edge
  - Can be hidden via settings
- **Slash commands** - `/ww` and `/wizzywing`
  - Toggle main window
  - Access configuration
- **Settings menu** - Interface options integration
  - Frame position configuration
  - Minimap button show/hide
  - Channel preferences

### Technical
- Frame resizing disabled for consistent layout
- Build automation with release.sh script
- GitHub Actions workflow for releases
- .pkgmeta configuration for library management
- Type definitions for LSP support

## [0.1.0] - 2025-11-11

### Added
- Initial project structure
- Basic TOC file
- Repository initialization
- Build system setup

---

## Version History Summary

- **1.2.x** - Spell checker integration
- **1.1.x** - EmoteSplitter integration and chat limit management
- **1.0.x** - Polish and first stable release
- **0.9.x** - Raid marker toolbar and WYSIWYG preview
- **0.8.x** - Core framework and basic functionality
- **0.1.x** - Project initialization

## Links

- [GitHub Repository](https://github.com/lawhorkl/WizzyWig)
- [CurseForge](https://www.curseforge.com/wow/addons/wizzywig)
- [Issue Tracker](https://github.com/lawhorkl/WizzyWig/issues)
