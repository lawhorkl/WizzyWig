-- WizzyWig: Main Editor Frame (OOP)
local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

-- MainFrame class
local MainFrame = {}
MainFrame.__index = MainFrame
local CHAT_CHUNK_SIZE = 220

local function SendChatMessageSafe(message, channel)
    local ctl = _G.ChatThrottleLib
    if ctl and ctl.SendChatMessage then
        local ok = pcall(function()
            ctl:SendChatMessage("ALERT", "WizzyWig", message, channel)
        end)
        if ok then
            return true
        end
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
        return true
    end

    if SendChatMessage then
        SendChatMessage(message, channel)
        return true
    end

    return false
end

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
    editBox:SetMaxLetters(0) -- 0 = unlimited (we handle splitting ourselves)
    editBox:SetLabel("Compose your message:")

    -- Store reference for send function
    mainContainer.editBox = editBox

    -- Integrate with Misspelled spell checker if available
    -- We now handle message splitting ourselves, so no EmoteSplitter required
    if Misspelled and Misspelled.WireUpEditBox then
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

    -- Character counter with chunk info
    local charCounter = AceGUI:Create("Label")
    charCounter:SetFullWidth(true)
    charCounter:SetText("0 characters (1 message)")
    charCounter:SetColor(0.7, 0.7, 0.7)
    mainContainer:AddChild(charCounter)

    -- Update character counter on text change
    editBox:SetCallback("OnTextChanged", function(_, _, text)
        local len = string.len(text)
        local chunks = math.max(1, math.ceil(len / 255))
        local color = {0.7, 0.7, 0.7} -- gray
        if len > 255 then
            color = {1.0, 0.8, 0.0} -- orange for multi-chunk
        end
        if len > 1020 then -- 4+ chunks
            color = {1.0, 0.3, 0.0} -- red for very long
        end
        charCounter:SetText(len .. " characters (" .. chunks .. " message" .. (chunks > 1 and "s" or "") .. ")")
        charCounter:SetColor(unpack(color))
    end)

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
        ["RAID_WARNING"] = "Raid Warning",
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
        local sent = self:SendMessage(editBox:GetText(), channelDropdown:GetValue())
        if sent and self.addon.db.profile.clearOnSend then
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
        return false
    end

    if self.isSending then
        self.addon:Print("A message is already being sent. Please wait for it to finish.")
        return false
    end

    -- Trim whitespace
    message = strtrim(message)

    -- Check for empty message
    if message == "" then
        self.addon:Print("Cannot send empty message")
        return false
    end

    -- Check if chat messaging is locked down.
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local isLocked = C_ChatInfo.InChatMessagingLockdown()
        if isLocked then
            self.addon:Print("Cannot send messages while chat messaging is restricted.")
            if self.frame then
                self.frame:SetStatusText("Blocked: chat messaging restricted")
            end
            return false
        end
    end

    -- Validate channel membership before processing
    if channel == "PARTY" then
        if not (IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid(LE_PARTY_CATEGORY_HOME)) then
            self.addon:Print("You are not in a party!")
            return false
        end
    elseif channel == "RAID" or channel == "RAID_WARNING" then
        if not IsInRaid(LE_PARTY_CATEGORY_HOME) then
            self.addon:Print("You are not in a raid!")
            return false
        end
        if channel == "RAID_WARNING" and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            self.addon:Print("You must be raid leader or assistant to use Raid Warning!")
            return false
        end
    elseif channel ~= "SAY" and channel ~= "EMOTE" then
        self.addon:Print("Unknown channel: " .. tostring(channel))
        return false
    end

    -- Convert texture markup to chat codes
    message = ConvertIconsForChat(message)

    return self:SendMessageWithSplitting(message, channel)
end

-- Send message with built-in splitting
function MainFrame:SendMessageWithSplitting(message, channel)
    local chunks = self:SplitMessage(message, CHAT_CHUNK_SIZE)

    if #chunks == 1 then
        -- Single message, send immediately
        self.isSending = true
        if not SendChatMessageSafe(chunks[1], channel) then
            self.isSending = false
            self.addon:Print("Unable to send message: chat API is unavailable.")
            return false
        end
        C_Timer.After(0.5, function()
            self.isSending = false
        end)
        self.addon:DebugPrint("Sent to " .. channel .. ": " .. chunks[1])
        if self.frame then
            self.frame:SetStatusText("Message sent to " .. channel)
        end
        return true
    end

    -- Multiple chunks - queue through ChatThrottleLib when available.
    self.isSending = true
    self.addon:DebugPrint("Splitting message into " .. #chunks .. " chunks")
    if self.frame then
        self.frame:SetStatusText("Queueing " .. #chunks .. " messages to " .. channel .. "...")
    end

    for i, chunk in ipairs(chunks) do
        if not SendChatMessageSafe(chunk, channel) then
            self.addon:Print("Unable to queue message chunk: chat API is unavailable.")
            self.isSending = false
            if self.frame then
                self.frame:SetStatusText("Send failed")
            end
            return false
        end
        self.addon:DebugPrint("Queued chunk " .. i .. "/" .. #chunks)
    end

    self.isSending = false
    if self.frame then
        self.frame:SetStatusText("Queued " .. #chunks .. " messages to " .. channel)
    end

    return true
end

-- Split message into chunks with word-boundary and UTF-8 safety
function MainFrame:SplitMessage(message, maxLength)
    maxLength = maxLength or 255

    -- Phase 1: Protect WoW chat links with placeholders
    local links = {}
    local linkPattern = "(|c[fn][^|]*|H[^|]+|h(.-)|h|r)"
    message = message:gsub(linkPattern, function(fullLink, visibleText)
        table.insert(links, fullLink)
        local linkId = #links
        -- Replace with placeholder matching visible text length
        local padding = string.rep("\002", math.max(0, #visibleText - 4))
        return "\001\002" .. linkId .. padding .. "\003"
    end)

    -- Phase 2: Split at word boundaries
    local chunks = {}
    local pos = 1

    while pos <= #message do
        local endPos = pos + maxLength - 1

        if endPos >= #message then
            table.insert(chunks, message:sub(pos))
            break
        end

        -- Look for space or placeholder marker within last 16 chars
        local splitPos = endPos
        for i = endPos, math.max(pos, endPos - 16), -1 do
            local byte = message:byte(i)
            if byte == 32 or byte == 1 then -- space or placeholder start
                splitPos = i
                break
            end
        end

        -- If no space, find UTF-8 safe boundary
        if splitPos == endPos then
            splitPos = self:FindUTF8Boundary(message, endPos, math.max(pos, endPos - 16))
        end

        table.insert(chunks, message:sub(pos, splitPos))
        pos = splitPos + 1

        -- Skip leading spaces
        while pos <= #message and message:byte(pos) == 32 do
            pos = pos + 1
        end
    end

    -- Phase 3: Restore links to chunks
    for i, chunk in ipairs(chunks) do
        chunks[i] = chunk:gsub("\001\002(%d+)\002*\003", function(linkId)
            return links[tonumber(linkId)] or ""
        end)
    end

    return chunks
end

-- Find UTF-8 safe split point (don't split multi-byte characters)
function MainFrame:FindUTF8Boundary(message, startPos, minPos)
    for i = startPos, minPos, -1 do
        local byte = message:byte(i)
        -- Safe: ASCII printable (32-127). If we land on a UTF-8 start byte,
        -- split before it so the multibyte character stays in the next chunk.
        if byte >= 32 and byte < 128 then
            return i
        elseif byte >= 192 then
            return math.max(minPos, i - 1)
        end
    end
    return startPos
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
