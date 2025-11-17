-- WizzyWig: Main Editor Frame (OOP)
local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

-- MainFrame class
local MainFrame = {}
MainFrame.__index = MainFrame

-- Constructor
function MainFrame:New(wizzywigAddon)
    local self = setmetatable({}, MainFrame)
    self.addon = wizzywigAddon  -- Reference to main addon for db access
    self.frame = nil
    return self
end

-- Setup toolbar with raid icons and other controls
local function SetupToolbar(self, container, editBox)
    -- Create toolbar container
    local toolbar = AceGUI:Create("SimpleGroup")
    toolbar:SetFullWidth(true)
    toolbar:SetLayout("Flow")
    container:AddChild(toolbar)

    -- Add raid icon buttons (reversed order: 8 to 1)
    for i = 8, 1, -1 do
        local btn = AceGUI:Create("Button")
        btn:SetText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":16|t")
        btn:SetWidth(50)
        btn:SetCallback("OnClick", function()
            -- Get current cursor position
            local cursorPos = editBox.editBox:GetCursorPosition()
            local text = editBox:GetText()

            -- Insert texture markup at cursor position (displays icon in edit box)
            local iconMarkup = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i .. ":12|t"
            local before = text:sub(1, cursorPos)
            local after = text:sub(cursorPos + 1)
            local newText = before .. iconMarkup .. after

            editBox:SetText(newText)
            editBox.editBox:SetCursorPosition(cursorPos + string.len(iconMarkup))
            editBox:SetFocus()
        end)
        toolbar:AddChild(btn)
    end
end

-- Convert texture markup to chat codes for sending
local function ConvertIconsForChat(message)
    -- Convert texture markup |TInterface\TargetingFrame\UI-RaidTargetingIcon_#:12|t to {rt#}
    for i = 1, 8 do
        -- Escape special pattern characters: | and -
        local pattern = "%|TInterface\\TargetingFrame\\UI%-RaidTargetingIcon_" .. i .. ":12%|t"
        message = message:gsub(pattern, "{rt" .. i .. "}")
    end
    return message
end

-- Populate the main frame with widgets
function MainFrame:Populate(container)
    -- Create a vertical container for the layout
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

    -- Enforce character limit if EmoteSplitter is not loaded
    local emoteSplitterLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EmoteSplitter")) or (IsAddOnLoaded and IsAddOnLoaded("EmoteSplitter"))
    if not emoteSplitterLoaded then
        editBox:SetMaxLetters(255) -- WoW chat message limit
        editBox:SetLabel("Compose your message (255 char limit - EmoteSplitter not found):")
    end

    -- Store reference for send function
    mainContainer.editBox = editBox

    -- Integrate with Misspelled spell checker if available and EmoteSplitter is loaded
    -- EmoteSplitter is required because Misspelled's color codes can cause character limit issues
    -- without it (255 char limit - ~144 chars of markup = only ~111 usable chars)
    local emoteSplitterLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EmoteSplitter"))
        or (IsAddOnLoaded and IsAddOnLoaded("EmoteSplitter"))

    if emoteSplitterLoaded and Misspelled and Misspelled.WireUpEditBox then
        local rawEditBox = editBox.editBox

        -- Create a compatibility wrapper for Misspelled
        -- Misspelled expects GetName() to return a unique identifier for word location tracking
        -- Since we can't set a name on an already-created frame, we'll wrap the frame
        local compatWrapper = rawEditBox

        -- Store original GetName if it exists
        local originalGetName = rawEditBox.GetName

        -- Override GetName to return a consistent unique name
        rawEditBox.GetName = function(self)
            if originalGetName and originalGetName(self) then
                return originalGetName(self)
            end
            return "WizzyWigEditBox"
        end

        -- Wire up Misspelled's spell checking to the raw editbox frame
        Misspelled:WireUpEditBox(rawEditBox)
    end

    -- Setup toolbar above the editbox
    SetupToolbar(self, mainContainer, editBox)

    -- Add editBox after toolbar
    mainContainer:AddChild(editBox)

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
    channelDropdown:SetValue(self.addon.db.profile.defaultChannel)
    channelDropdown:SetCallback("OnValueChanged", function(widget, event, key)
        self.addon.db.profile.defaultChannel = key
        self.addon:DebugPrint("Channel changed to: " .. key)
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
        if self.addon.db.profile.clearOnSend then
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

-- Show the main frame
function MainFrame:Show()
    if not self.addon.db.profile.enabled then
        self.addon:Print("Addon is disabled. Enable it first with /ww toggle")
        return
    end

    -- If frame already exists, just show it
    if self.frame then
        self.frame:Show()
        return
    end

    -- Create new frame
    self.frame = AceGUI:Create("Frame")
    self.frame:SetTitle("WizzyWig - RP Chat Editor")
    self.frame:SetStatusText("Ready to compose")
    self.frame:SetWidth(self.addon.db.profile.frameSize.width)
    self.frame:SetHeight(self.addon.db.profile.frameSize.height)
    self.frame:SetLayout("Fill")

    -- Disable frame resizing
    self.frame.frame:SetResizable(false)
    if self.frame.sizer_se then
        self.frame.sizer_se:Hide()
    end
    if self.frame.sizer_s then
        self.frame.sizer_s:Hide()
    end
    if self.frame.sizer_e then
        self.frame.sizer_e:Hide()
    end

    -- Position frame
    local pos = self.addon.db.profile.framePosition
    self.frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    -- Save position when frame is moved/closed
    local addon = self.addon
    local mainFrameObj = self
    self.frame:SetCallback("OnClose", function(widget)
        local point, _, _, x, y = widget.frame:GetPoint()
        addon.db.profile.framePosition = {
            point = point,
            x = x,
            y = y,
        }
        -- Just hide the frame instead of releasing it
        -- This preserves the editbox content and Misspelled integration
        widget:Hide()
    end)

    -- Add content to frame
    self:Populate(self.frame)
end

-- Hide the main frame
function MainFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- Toggle visibility
function MainFrame:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Send message to specified channel
function MainFrame:SendMessage(message, channel)
    if not self.addon.db.profile.enabled then
        self.addon:Print("Addon is disabled")
        return
    end

    -- Trim whitespace
    message = strtrim(message)

    -- Check for empty message
    if message == "" then
        self.addon:Print("Cannot send empty message")
        return
    end

    -- Convert texture markup to chat codes
    message = ConvertIconsForChat(message)

    -- Send to appropriate channel
    if channel == "SAY" then
        SendChatMessage(message, "SAY")
        self.addon:DebugPrint("Sent to Say: " .. message)
    elseif channel == "EMOTE" then
        SendChatMessage(message, "EMOTE")
        self.addon:DebugPrint("Sent to Emote: " .. message)
    elseif channel == "PARTY" then
        if IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage(message, "PARTY")
            self.addon:DebugPrint("Sent to Party: " .. message)
        else
            self.addon:Print("You are not in a party!")
            return
        end
    elseif channel == "RAID" then
        if IsInRaid(LE_PARTY_CATEGORY_HOME) then
            SendChatMessage(message, "RAID")
            self.addon:DebugPrint("Sent to Raid: " .. message)
        else
            self.addon:Print("You are not in a raid!")
            return
        end
    else
        self.addon:Print("Unknown channel: " .. tostring(channel))
        return
    end

    -- Update status
    if self.frame then
        self.frame:SetStatusText("Message sent to " .. channel)
    end
end

-- Get frame reference
function MainFrame:GetFrame()
    return self.frame
end

-- Export to addon namespace
if not WizzyWig then
    error("WizzyWig namespace not found! Ensure Core.lua loads before MainFrame.lua")
end
WizzyWig.MainFrame = MainFrame
