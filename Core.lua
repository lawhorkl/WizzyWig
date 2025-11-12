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
        frameSize = {
            width = 500,
            height = 400,
        },
        defaultChannel = "SAY",
        clearOnSend = false,
        minimap = {
            hide = false,
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

    -- Setup minimap button
    self:SetupMinimapButton()

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
                name = "Minimap Button",
                order = 6,
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
                order = 7,
            },
            header3 = {
                type = "header",
                name = "Advanced",
                order = 8,
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
                order = 9,
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
        icon = "Interface\\Icons\\INV_Misc_Book_11",
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
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    else
        self:ShowMainFrame()
    end
end

-- Show minimap button menu
function WizzyWig:ShowMinimapMenu(frame)
    local menu = {
        {
            text = "WizzyWig",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Toggle Editor",
            func = function() self:ToggleMainFrame() end,
            notCheckable = true,
        },
        {
            text = "Settings",
            func = function()
                InterfaceOptionsFrame_OpenToCategory("WizzyWig")
                InterfaceOptionsFrame_OpenToCategory("WizzyWig")
            end,
            notCheckable = true,
        },
        {
            text = "Close",
            func = function() end,
            notCheckable = true,
        },
    }

    local menuFrame = CreateFrame("Frame", "WizzyWigMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
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
    mainFrame:SetTitle("WizzyWig - RP Chat Editor")
    mainFrame:SetStatusText("Ready to compose")
    mainFrame:SetWidth(self.db.profile.frameSize.width)
    mainFrame:SetHeight(self.db.profile.frameSize.height)
    mainFrame:SetLayout("Fill")

    -- Disable frame resizing
    mainFrame.frame:SetResizable(false)
    if mainFrame.sizer_se then
        mainFrame.sizer_se:Hide()
    end
    if mainFrame.sizer_s then
        mainFrame.sizer_s:Hide()
    end
    if mainFrame.sizer_e then
        mainFrame.sizer_e:Hide()
    end

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
    -- Create a vertical container for the layout
    ---@type MainContainer
    local mainContainer = AceGUI:Create("SimpleGroup")
    mainContainer:SetFullWidth(true)
    mainContainer:SetFullHeight(true)
    mainContainer:SetLayout("Flow")
    container:AddChild(mainContainer)

    -- MultiLine EditBox for message composition (takes most of the space)
    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("Compose your message:")
    editBox:SetFullWidth(true)
    editBox:SetNumLines(15)
    editBox:DisableButton(true)
    editBox:SetText("")
    mainContainer:AddChild(editBox)

    -- Store reference for send function
    mainContainer.editBox = editBox

    -- Bottom controls container
    local controlsGroup = AceGUI:Create("SimpleGroup")
    controlsGroup:SetFullWidth(true)
    controlsGroup:SetLayout("Flow")
    mainContainer:AddChild(controlsGroup)

    -- Channel dropdown
    local channelDropdown = AceGUI:Create("Dropdown")
    channelDropdown:SetLabel("Channel:")
    channelDropdown:SetWidth(150)
    channelDropdown:SetList({
        ["SAY"] = "Say",
        ["EMOTE"] = "Emote",
        ["PARTY"] = "Party",
        ["RAID"] = "Raid",
    })
    channelDropdown:SetValue(self.db.profile.defaultChannel)
    channelDropdown:SetCallback("OnValueChanged", function(widget, event, key)
        self.db.profile.defaultChannel = key
        self:DebugPrint("Channel changed to: " .. key)
    end)
    controlsGroup:AddChild(channelDropdown)

    -- Store reference for send function
    mainContainer.channelDropdown = channelDropdown

    -- Send button
    local sendButton = AceGUI:Create("Button")
    sendButton:SetText("Send Message")
    sendButton:SetWidth(150)
    sendButton:SetCallback("OnClick", function()
        self:SendMessage(editBox:GetText(), channelDropdown:GetValue())
        if self.db.profile.clearOnSend then
            editBox:SetText("")
        end
        editBox:SetFocus()
    end)
    controlsGroup:AddChild(sendButton)

    -- Clear button
    local clearButton = AceGUI:Create("Button")
    clearButton:SetText("Clear")
    clearButton:SetWidth(100)
    clearButton:SetCallback("OnClick", function()
        editBox:SetText("")
        editBox:SetFocus()
    end)
    controlsGroup:AddChild(clearButton)

    -- Set focus to edit box
    editBox:SetFocus()
end

-- Send message to specified channel
function WizzyWig:SendMessage(message, channel)
    if not self.db.profile.enabled then
        self:Print("Addon is disabled")
        return
    end

    -- Trim whitespace
    message = strtrim(message)

    -- Check for empty message
    if message == "" then
        self:Print("Cannot send empty message")
        return
    end

    -- Send to appropriate channel
    if channel == "SAY" then
        SendChatMessage(message, "SAY")
        self:DebugPrint("Sent to Say: " .. message)
    elseif channel == "EMOTE" then
        SendChatMessage(message, "EMOTE")
        self:DebugPrint("Sent to Emote: " .. message)
    elseif channel == "PARTY" then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage(message, "PARTY")
            self:DebugPrint("Sent to Party: " .. message)
        else
            self:Print("You are not in a party!")
            return
        end
    elseif channel == "RAID" then
        if IsInRaid(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage(message, "RAID")
            self:DebugPrint("Sent to Raid: " .. message)
        else
            self:Print("You are not in a raid!")
            return
        end
    else
        self:Print("Unknown channel: " .. tostring(channel))
        return
    end

    -- Update status
    if mainFrame then
        mainFrame:SetStatusText("Message sent to " .. channel)
    end
end

-- Debug print function
function WizzyWig:DebugPrint(msg)
    if self.db.profile.debugMode then
        self:Print("[DEBUG] " .. tostring(msg))
    end
end
