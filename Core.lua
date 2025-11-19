-- WizzyWig: Core addon file
local addonName, addon = ...

-- Create main addon using Ace3
WizzyWig = LibStub("AceAddon-3.0"):NewAddon("WizzyWig", "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Default saved variables
local defaults = {
    profile = {
        enabled = true,
        debugMode = false,
        firstRun = true,
        framePosition = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
        frameSize = {
            width = 500,
            height = 400,
        },
        defaultChannel = "SAY",
        clearOnSend = false,
        minimap = {
            hide = false,
        },
        colors = {
            enabled = true,                    -- Master toggle for color system
            showInDefaultChat = true,          -- Show colors in default chat frames
        },
    },
}

-- Confirmation dialog for resetting settings
StaticPopupDialogs["WIZZYWING_RESET_CONFIRM"] = {
    text = "Are you sure you want to reset all WizzyWig settings to default values?\n\nThis will reset:\n• All addon settings\n• Frame position\n• Channel preferences\n• Welcome popup will show again",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        WizzyWig.db:ResetProfile()
        WizzyWig:Print("All settings have been reset to defaults!")
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Initialize function
function WizzyWig:OnInitialize()
    -- Initialize saved variables with defaults
    self.db = LibStub("AceDB-3.0"):New("WizzyWigDB", defaults, true)

    -- Create MainFrame object
    self.mainFrame = WizzyWig.MainFrame:New(self)

    -- Register slash commands
    self:RegisterChatCommand("wizzywing", "SlashCommand")
    self:RegisterChatCommand("ww", "SlashCommand")

    -- Setup options
    self:SetupOptions()

    -- Setup minimap button
    self:SetupMinimapButton()

    self:Print("WizzyWig loaded! Type /ww for commands.")
end

-- Enable function (called when player logs in)
function WizzyWig:OnEnable()
    self:Print("WizzyWig enabled!")

    -- Check for EmoteSplitter addon
    local emoteSplitterLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EmoteSplitter")) or (IsAddOnLoaded and IsAddOnLoaded("EmoteSplitter"))

    if not emoteSplitterLoaded then
        self:Print("|cFFFF0000WARNING: EmoteSplitter addon not found! WizzyWig is limited to the in-game chat message limit without it.|r")
    end

    -- Initialize WYSIWYG style system
    if self.db.profile.colors.enabled then
        self:InitializeColorSystem()
    end

    -- Register events
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("CHAT_MSG_PARTY")
    self:RegisterEvent("CHAT_MSG_RAID")
    self:RegisterEvent("CHAT_MSG_GUILD")

    -- Show welcome popup for first-time users
    if self.db.profile.firstRun then
        local welcomePopup = WizzyWig.WelcomePopup:New(self)
        welcomePopup:Show()
    end
end

-- Disable function (called when player logs out)
function WizzyWig:OnDisable()
    -- Cleanup code here
    if self.mainFrame then
        self.mainFrame:Hide()
    end

    -- Cleanup color system
    if self.chatIntegration then
        self.chatIntegration:UnhookChatFrames()
    end
end

-- Initialize color/style system
function WizzyWig:InitializeColorSystem()
    -- Create WYSIWYG instance
    self.wysiwyg = WizzyWig.WYSIWYG:New(self)

    -- Create and register ColorStyle provider
    self.colorStyle = WizzyWig.ColorStyle:New(self)
    self.wysiwyg:RegisterProvider(self.colorStyle)

    -- Create chat integration
    self.chatIntegration = WizzyWig.ChatIntegration:New(self, self.wysiwyg)
    self.chatIntegration:Initialize()

    self:DebugPrint("Color system initialized")
end

-- Event handler
function WizzyWig:CHAT_MSG_ADDON(event, prefix, data, channel, sender, ...)
    if self.chatIntegration then
        self.chatIntegration:HandleAddonMessage(prefix, data, channel, sender)
    end
end

function WizzyWig:CHAT_MSG_PARTY(event, text, sender, ...)
    if self.chatIntegration then
        self.chatIntegration:OnChatMessage(event, text, sender, ...)
    end
end

function WizzyWig:CHAT_MSG_RAID(event, text, sender, ...)
    if self.chatIntegration then
        self.chatIntegration:OnChatMessage(event, text, sender, ...)
    end
end

function WizzyWig:CHAT_MSG_GUILD(event, text, sender, ...)
    if self.chatIntegration then
        self.chatIntegration:OnChatMessage(event, text, sender, ...)
    end
end

-- Setup AceConfig options
function WizzyWig:SetupOptions()
    local options = {
        name = "WizzyWig",
        type = "group",
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Addon",
                desc = "Enable or disable the addon",
                get = function() return self.db.profile.enabled end,
                set = function(info, value)
                    self.db.profile.enabled = value
                    self:Print("Addon " .. (value and "enabled" or "disabled"))
                end,
                order = 1,
            },
            showFrame = {
                type = "execute",
                name = "Open Chat Editor",
                desc = "Open the RP chat editor window",
                func = function() self:ShowMainFrame() end,
                order = 2,
            },
            header1 = {
                type = "header",
                name = "Editor Settings",
                order = 3,
            },
            defaultChannel = {
                type = "select",
                name = "Default Channel",
                desc = "The default channel selected when opening the editor",
                values = {
                    ["SAY"] = "Say",
                    ["EMOTE"] = "Emote",
                    ["PARTY"] = "Party",
                    ["RAID"] = "Raid",
                },
                get = function() return self.db.profile.defaultChannel end,
                set = function(info, value)
                    self.db.profile.defaultChannel = value
                    self:Print("Default channel set to: " .. value)
                end,
                order = 4,
            },
            clearOnSend = {
                type = "toggle",
                name = "Clear on Send",
                desc = "Automatically clear the text box after sending a message",
                get = function() return self.db.profile.clearOnSend end,
                set = function(info, value)
                    self.db.profile.clearOnSend = value
                    self:Print("Clear on send " .. (value and "enabled" or "disabled"))
                end,
                order = 5,
            },
            header2 = {
                type = "header",
                name = "Color System",
                order = 6,
            },
            colorsEnabled = {
                type = "toggle",
                name = "Enable Colors",
                desc = "Enable the color/styling system for messages",
                get = function() return self.db.profile.colors.enabled end,
                set = function(info, value)
                    self.db.profile.colors.enabled = value
                    self:Print("Color system " .. (value and "enabled" or "disabled"))
                    if value then
                        self:InitializeColorSystem()
                    end
                end,
                order = 7,
            },
            colorsShowInDefaultChat = {
                type = "toggle",
                name = "Show Colors in Default Chat",
                desc = "Display colored messages in default chat frames",
                get = function() return self.db.profile.colors.showInDefaultChat end,
                set = function(info, value)
                    self.db.profile.colors.showInDefaultChat = value
                    self:Print("Colors in default chat " .. (value and "enabled" or "disabled"))
                end,
                order = 8,
                disabled = function() return not self.db.profile.colors.enabled end,
            },
            header3 = {
                type = "header",
                name = "Minimap Button",
                order = 9,
            },
            minimapHide = {
                type = "toggle",
                name = "Hide Minimap Button",
                desc = "Hide the minimap button",
                get = function() return self.db.profile.minimap.hide end,
                set = function(info, value)
                    self.db.profile.minimap.hide = value
                    local LDBIcon = LibStub("LibDBIcon-1.0", true)
                    if LDBIcon then
                        if value then
                            LDBIcon:Hide("WizzyWig")
                        else
                            LDBIcon:Show("WizzyWig")
                        end
                    end
                    self:Print("Minimap button " .. (value and "hidden" or "shown"))
                end,
                order = 10,
            },
            header4 = {
                type = "header",
                name = "Advanced",
                order = 11,
            },
            debugMode = {
                type = "toggle",
                name = "Debug Mode",
                desc = "Enable or disable debug messages",
                get = function() return self.db.profile.debugMode end,
                set = function(info, value)
                    self.db.profile.debugMode = value
                    self:Print("Debug mode " .. (value and "enabled" or "disabled"))
                end,
                order = 12,
            },
            resetSettings = {
                type = "execute",
                name = "Reset All Settings",
                desc = "Reset all settings to default values. This will also show the welcome popup again on next login.",
                func = function()
                    StaticPopup_Show("WIZZYWING_RESET_CONFIRM")
                end,
                order = 13,
            },
        },
    }

    AceConfig:RegisterOptionsTable("WizzyWig", options)
    AceConfigDialog:AddToBlizOptions("WizzyWig", "WizzyWig")
end

-- Setup minimap button
function WizzyWig:SetupMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)

    if not LDB or not LDBIcon then
        self:Print("Warning: Minimap button libraries not found")
        return
    end

    -- Create LibDataBroker data source
    local minimapButton = LDB:NewDataObject("WizzyWig", {
        type = "launcher",
        text = "WizzyWig",
        icon = "Interface\\AddOns\\WizzyWig\\Media\\minimapIcon",
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                self:ToggleMainFrame()
            elseif button == "RightButton" then
                self:ShowMinimapMenu(clickedframe)
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("WizzyWig")
            tooltip:AddLine("|cFFFFFFFFLeft-click:|r Toggle editor", 0.7, 0.7, 0.7)
            tooltip:AddLine("|cFFFFFFFFRight-click:|r Show menu", 0.7, 0.7, 0.7)
        end,
    })

    -- Register with LibDBIcon
    LDBIcon:Register("WizzyWig", minimapButton, self.db.profile.minimap)
end

-- Toggle main frame (for minimap button)
function WizzyWig:ToggleMainFrame()
    self.mainFrame:Toggle()
end

-- Show minimap button menu (opens settings)
function WizzyWig:ShowMinimapMenu(frame)
    -- Right-click opens the config menu
    Settings.OpenToCategory("WizzyWig")
end

-- Slash command handler
function WizzyWig:SlashCommand(input)
    input = string.lower(string.trim(input))

    if input == "" or input == "help" then
        self:Print("Commands:")
        self:Print("  /ww show - Show main frame")
        self:Print("  /ww config - Open config panel")
        self:Print("  /ww toggle - Toggle addon on/off")
        self:Print("  /ww status - Show current status")
        self:Print("  /ww debug - Toggle debug mode")
    elseif input == "show" then
        self:ShowMainFrame()
    elseif input == "config" then
        Settings.OpenToCategory("WizzyWig")
    elseif input == "toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print("Addon " .. (self.db.profile.enabled and "enabled" or "disabled"))
    elseif input == "status" then
        self:Print("Status: " .. (self.db.profile.enabled and "Enabled" or "Disabled"))
        self:Print("Debug: " .. (self.db.profile.debugMode and "On" or "Off"))
    elseif input == "debug" then
        self.db.profile.debugMode = not self.db.profile.debugMode
        self:Print("Debug mode " .. (self.db.profile.debugMode and "enabled" or "disabled"))
    else
        self:Print("Unknown command. Type /ww help for available commands.")
    end
end

-- Create and show main frame using AceGUI
-- Show the main frame (delegates to MainFrame object)
function WizzyWig:ShowMainFrame()
    self.mainFrame:Show()
end

-- Debug print function
function WizzyWig:DebugPrint(msg)
    if self.db.profile.debugMode then
        self:Print("[DEBUG] " .. tostring(msg))
    end
end
