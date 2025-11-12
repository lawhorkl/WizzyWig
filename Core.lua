-- WizzyWig: Core addon file
local addonName, addon = ...

-- Create main addon using Ace3
WizzyWig = LibStub("AceAddon-3.0"):NewAddon("WizzyWig", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Default saved variables
local defaults = {
    profile = {
        enabled = true,
        debugMode = false,
        framePosition = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
    },
}

-- Main frame reference
local mainFrame = nil

-- Initialize function
function WizzyWig:OnInitialize()
    -- Initialize saved variables with defaults
    self.db = LibStub("AceDB-3.0"):New("WizzyWigDB", defaults, true)

    -- Register slash commands
    self:RegisterChatCommand("wizzywing", "SlashCommand")
    self:RegisterChatCommand("ww", "SlashCommand")

    -- Setup options
    self:SetupOptions()

    self:Print("WizzyWig loaded! Type /ww for commands.")
end

-- Enable function (called when player logs in)
function WizzyWig:OnEnable()
    self:Print("WizzyWig enabled!")

    -- Register game events here if needed
    -- self:RegisterEvent("UNIT_HEALTH")
end

-- Disable function (called when player logs out)
function WizzyWig:OnDisable()
    -- Cleanup code here
    if mainFrame then
        mainFrame:Hide()
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
            debugMode = {
                type = "toggle",
                name = "Debug Mode",
                desc = "Enable or disable debug messages",
                get = function() return self.db.profile.debugMode end,
                set = function(info, value)
                    self.db.profile.debugMode = value
                    self:Print("Debug mode " .. (value and "enabled" or "disabled"))
                end,
                order = 2,
            },
            showFrame = {
                type = "execute",
                name = "Show Main Frame",
                desc = "Open the main addon frame",
                func = function() self:ShowMainFrame() end,
                order = 3,
            },
        },
    }

    AceConfig:RegisterOptionsTable("WizzyWig", options)
    AceConfigDialog:AddToBlizOptions("WizzyWig", "WizzyWig")
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
        InterfaceOptionsFrame_OpenToCategory("WizzyWig")
        InterfaceOptionsFrame_OpenToCategory("WizzyWig") -- Called twice due to Blizzard bug
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
function WizzyWig:ShowMainFrame()
    if not self.db.profile.enabled then
        self:Print("Addon is disabled. Enable it first with /ww toggle")
        return
    end

    -- If frame already exists, just show it
    if mainFrame then
        mainFrame:Show()
        return
    end

    -- Create new frame
    mainFrame = AceGUI:Create("Frame")
    mainFrame:SetTitle("WizzyWig")
    mainFrame:SetStatusText("Status: Ready")
    mainFrame:SetWidth(400)
    mainFrame:SetHeight(300)
    mainFrame:SetLayout("Flow")

    -- Position frame
    local pos = self.db.profile.framePosition
    mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    -- Save position when frame is moved
    mainFrame:SetCallback("OnClose", function(widget)
        local point, _, _, x, y = widget.frame:GetPoint()
        self.db.profile.framePosition = {
            point = point,
            x = x,
            y = y,
        }
        AceGUI:Release(widget)
        mainFrame = nil
    end)

    -- Add content to frame
    self:PopulateMainFrame(mainFrame)
end

-- Populate the main frame with widgets
function WizzyWig:PopulateMainFrame(container)
    -- Heading
    local heading = AceGUI:Create("Heading")
    heading:SetText("Welcome to WizzyWig")
    heading:SetFullWidth(true)
    container:AddChild(heading)

    -- Label
    local label = AceGUI:Create("Label")
    label:SetText("This is an example frame created with AceGUI.\n\nYou can add any widgets you need here.")
    label:SetFullWidth(true)
    label:SetFontObject(GameFontHighlight)
    container:AddChild(label)

    -- Spacer
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    container:AddChild(spacer)

    -- Example EditBox
    local editbox = AceGUI:Create("EditBox")
    editbox:SetLabel("Enter Text:")
    editbox:SetFullWidth(true)
    editbox:SetCallback("OnEnterPressed", function(widget, event, text)
        self:Print("You entered: " .. text)
    end)
    container:AddChild(editbox)

    -- Example CheckBox
    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetLabel("Enable Feature")
    checkbox:SetValue(self.db.profile.enabled)
    checkbox:SetCallback("OnValueChanged", function(widget, event, value)
        self.db.profile.enabled = value
        self:Print("Feature " .. (value and "enabled" or "disabled"))
    end)
    container:AddChild(checkbox)

    -- Example Button
    local button = AceGUI:Create("Button")
    button:SetText("Click Me!")
    button:SetWidth(150)
    button:SetCallback("OnClick", function()
        self:Print("Button clicked!")
        self:ExampleFunction()
    end)
    container:AddChild(button)

    -- Close button
    local closeButton = AceGUI:Create("Button")
    closeButton:SetText("Close")
    closeButton:SetWidth(100)
    closeButton:SetCallback("OnClick", function()
        if mainFrame then
            mainFrame:Hide()
        end
    end)
    container:AddChild(closeButton)
end

-- Example function
function WizzyWig:ExampleFunction()
    if not self.db.profile.enabled then return end

    self:Print("Example function called!")

    if self.db.profile.debugMode then
        self:Print("Debug: This is debug information")
    end
end

-- Debug print function
function WizzyWig:DebugPrint(msg)
    if self.db.profile.debugMode then
        self:Print("[DEBUG] " .. tostring(msg))
    end
end
