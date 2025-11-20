-- WizzyWig: Chat Integration
-- Handles receiving styled messages and displaying them in chat frames

local addonName, addon = ...

-- ========================================
-- CHAT INTEGRATION CLASS
-- ========================================

local ChatIntegration = {}
ChatIntegration.__index = ChatIntegration

-- Constants
ChatIntegration.ADDON_PREFIX = "WZWG"
ChatIntegration.CHANNEL_NAME = "WizzyWigColors"

-- Constructor
function ChatIntegration:New(wizzywigAddon, wysiwyg)
    local self = setmetatable({}, ChatIntegration)
    self.addon = wizzywigAddon
    self.wysiwyg = wysiwyg
    self.colorChannelID = nil
    self.originalMessageHandler = nil
    return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

-- Initialize chat integration
function ChatIntegration:Initialize()
    -- Register addon message prefix
    local result = C_ChatInfo.RegisterAddonMessagePrefix(self.ADDON_PREFIX)
    if result ~= Enum.RegisterAddonMessagePrefixResult.Success then
        self.addon:Print("ERROR: Failed to register addon prefix")
        return false
    end

    -- Join custom channel for fake SAY/EMOTE
    self:JoinColorChannel()

    -- Hook chat frame message handler
    self:HookChatFrames()

    self.addon:DebugPrint("Chat integration initialized")
    return true
end

-- ========================================
-- CHANNEL MANAGEMENT
-- ========================================

-- Join custom channel for transmitting fake messages
function ChatIntegration:JoinColorChannel()
    local channelID, channelName = GetChannelName(self.CHANNEL_NAME)

    if channelID == 0 then
        -- Not in channel, join it
        -- JoinPermanentChannel(name, password, frameID, hasPassword)
        JoinPermanentChannel(self.CHANNEL_NAME, nil, DEFAULT_CHAT_FRAME:GetID(), 0)

        -- Wait a moment for channel to register
        C_Timer.After(0.5, function()
            channelID = GetChannelName(self.CHANNEL_NAME)
            if channelID > 0 then
                self.colorChannelID = channelID
                self.addon:DebugPrint("Joined color channel: " .. channelID)
            else
                self.addon:Print("WARNING: Failed to join WizzyWig color channel")
            end
        end)
    else
        self.colorChannelID = channelID
        self.addon:DebugPrint("Already in color channel: " .. channelID)
    end
end

-- Get the best transport channel for sending
function ChatIntegration:GetTransportChannel()
    -- Prefer custom channel for fake SAY/EMOTE
    if self.colorChannelID and self.colorChannelID > 0 then
        return "CHANNEL", self.colorChannelID
    end

    -- Fallback to group
    if IsInRaid() then
        return "RAID", nil
    elseif IsInGroup() then
        return "PARTY", nil
    end

    return nil, nil
end

-- ========================================
-- SENDING MESSAGES
-- ========================================

-- Send a styled message
-- message: plain text
-- displayChannel: "SAY", "EMOTE", "PARTY", "RAID"
-- styles: array of style ranges
function ChatIntegration:SendStyledMessage(message, displayChannel, styles)
    if displayChannel == "SAY" or displayChannel == "EMOTE" then
        return self:SendFakeMessage(message, displayChannel, styles)
    elseif displayChannel == "PARTY" or displayChannel == "RAID" then
        return self:SendRealMessage(message, displayChannel, styles)
    else
        self.addon:Print("Unsupported channel: " .. tostring(displayChannel))
        return false
    end
end

-- Send fake SAY/EMOTE message via custom channel
function ChatIntegration:SendFakeMessage(message, displayChannel, styles)
    -- Always send the visible message first so everyone can see it
    SendChatMessage(message, displayChannel)
    self.addon:DebugPrint("Sent visible " .. displayChannel .. " message")

    -- Then send style metadata if we have styles and a transport channel
    if styles and #styles > 0 then
        local transportChannel, target = self:GetTransportChannel()

        if transportChannel then
            -- Determine message type
            local msgType = displayChannel == "SAY" and self.wysiwyg.MESSAGE_TYPE.FAKE_SAY
                                                     or self.wysiwyg.MESSAGE_TYPE.FAKE_EMOTE

            -- Pack styles only (message already sent via SendChatMessage)
            local packedStyles = self.wysiwyg:PackStyles(styles)
            local fullData = string.char(msgType) .. packedStyles

            self.addon:DebugPrint("Sending addon message: " .. #fullData .. " bytes total")

            -- Send via addon message
            self.wysiwyg:QueueAddonMessage(self.ADDON_PREFIX, fullData, transportChannel, target)

            self.addon:DebugPrint("Sent " .. displayChannel .. " color metadata via " .. transportChannel)
        else
            self.addon:DebugPrint("No color channel available, sent plain " .. displayChannel)
        end
    end

    return true
end

-- Send real PARTY/RAID message with style metadata
function ChatIntegration:SendRealMessage(message, channel, styles)
    -- Check if in appropriate group
    if channel == "PARTY" and (not IsInGroup() or IsInRaid()) then
        self.addon:Print("You are not in a party!")
        return false
    elseif channel == "RAID" and not IsInRaid() then
        self.addon:Print("You are not in a raid!")
        return false
    end

    -- Send visible message first
    SendChatMessage(message, channel)

    -- Send style metadata if styles exist
    if styles and #styles > 0 then
        local packedStyles = self.wysiwyg:PackStyles(styles)
        local fullData = string.char(self.wysiwyg.MESSAGE_TYPE.REAL_MESSAGE_STYLES) .. packedStyles
        self.wysiwyg:QueueAddonMessage(self.ADDON_PREFIX, fullData, channel, nil)
    end

    self.addon:DebugPrint("Sent real " .. channel)
    return true
end

-- ========================================
-- RECEIVING MESSAGES
-- ========================================

-- Handle received addon message
function ChatIntegration:HandleAddonMessage(prefix, data, channel, sender)
    if prefix ~= self.ADDON_PREFIX then
        return
    end

    self.addon:DebugPrint("Received addon message: " .. #data .. " bytes total from " .. sender)

    -- Extract message type
    local msgType = string.byte(data, 1)
    local payload = data:sub(2)

    self.addon:DebugPrint("Message type: " .. tostring(msgType) .. ", payload: " .. #payload .. " bytes")

    if msgType == self.wysiwyg.MESSAGE_TYPE.FAKE_SAY then
        self:HandleFakeMessage(payload, sender, "SAY")
    elseif msgType == self.wysiwyg.MESSAGE_TYPE.FAKE_EMOTE then
        self:HandleFakeMessage(payload, sender, "EMOTE")
    elseif msgType == self.wysiwyg.MESSAGE_TYPE.REAL_MESSAGE_STYLES then
        self:HandleRealMessageStyles(payload, sender, channel)
    else
        self.addon:DebugPrint("Unknown message type: " .. tostring(msgType))
    end
end

-- Handle fake SAY/EMOTE message
function ChatIntegration:HandleFakeMessage(payload, sender, displayChannel)
    -- Now just unpacking styles (message already sent via SendChatMessage)
    self.addon:DebugPrint("Received " .. displayChannel .. " styles, payload length: " .. #payload)

    local styles = self.wysiwyg:UnpackStyles(payload)

    if not styles or #styles == 0 then
        self.addon:DebugPrint("No styles unpacked from payload")
        return
    end

    self.addon:DebugPrint("Unpacked " .. #styles .. " style(s)")

    -- Don't process your own messages (you already see them with colors locally)
    local playerName = UnitName("player")
    local playerNameRealm = playerName .. "-" .. GetRealmName()

    if sender == playerName or sender == playerNameRealm then
        self.addon:DebugPrint("Ignoring own message")
        return
    end

    -- Try to match with recent message and apply styles
    local matched = self.wysiwyg:MatchAndApplyStyles(sender, styles)

    if not matched then
        -- Message hasn't arrived yet, cache styles for when it does
        self.wysiwyg:CachePendingStyles(sender, styles, time())
        self.addon:DebugPrint("Cached " .. displayChannel .. " styles from " .. sender)
    else
        self.addon:DebugPrint("Applied " .. displayChannel .. " styles from " .. sender)
    end
end

-- Handle real message styles
function ChatIntegration:HandleRealMessageStyles(payload, sender, channel)
    -- Unpack styles
    local styles = self.wysiwyg:UnpackStyles(payload)

    -- Try to match with recent message
    local matched = self.wysiwyg:MatchAndApplyStyles(sender, styles)

    if not matched then
        -- Message hasn't arrived yet, cache styles
        self.wysiwyg:CachePendingStyles(sender, styles, time())
    end
end

-- ========================================
-- DISPLAY FUNCTIONS
-- ========================================

-- Display fake SAY/EMOTE message in chat frames
function ChatIntegration:DisplayFakeMessage(sender, text, styles, channel)
    -- Apply styles to text
    local styledText = self.wysiwyg:ApplyStylesToText(text, styles)

    -- Get sender's class color
    local _, classFilename = UnitClass(sender)
    local classColor = RAID_CLASS_COLORS[classFilename] or NORMAL_FONT_COLOR
    local coloredName = classColor:WrapTextInColorCode(sender)

    -- Format message
    local formattedMsg
    if channel == "SAY" then
        formattedMsg = string.format("[%s]: %s", coloredName, styledText)
    elseif channel == "EMOTE" then
        formattedMsg = string.format("%s %s", coloredName, styledText)
    end

    -- Add to all appropriate chat frames
    local messageGroup = "CHAT_MSG_" .. channel
    local info = ChatTypeInfo[channel]

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and frame:IsVisible() then
            -- Check if this frame displays SAY/EMOTE
            if frame.messageTypeList and frame.messageTypeList[messageGroup] then
                frame:AddMessage(formattedMsg, info.r, info.g, info.b, info.id)
            end
        end
    end

    self.addon:DebugPrint("Displayed fake " .. channel .. " from " .. sender)
end

-- ========================================
-- CHAT FRAME HOOKS
-- ========================================

-- Hook default chat frames to inject styles
function ChatIntegration:HookChatFrames()
    if self.originalMessageHandler then
        return  -- Already hooked
    end

    self.originalMessageHandler = ChatFrame_MessageEventHandler

    -- Replace handler
    ChatFrame_MessageEventHandler = function(self, event, ...)
        -- Intercept SAY/EMOTE/PARTY/RAID/GUILD messages
        if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_EMOTE" or
           event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_GUILD" then
            local text, sender = ...

            -- Check if we have style data for this message
            local styles = WizzyWig.wysiwyg:GetStyleDataForMessage(sender, text)

            if styles then
                -- Apply styles to text
                local styledText = WizzyWig.wysiwyg:ApplyStylesToText(text, styles)

                -- Call original with styled text
                return WizzyWig.chatIntegration.originalMessageHandler(
                    self, event, styledText, select(2, ...)
                )
            end
        end

        -- Call original handler
        return WizzyWig.chatIntegration.originalMessageHandler(self, event, ...)
    end

    self.addon:DebugPrint("Hooked chat frames")
end

-- Unhook chat frames
function ChatIntegration:UnhookChatFrames()
    if self.originalMessageHandler then
        ChatFrame_MessageEventHandler = self.originalMessageHandler
        self.originalMessageHandler = nil
        self.addon:DebugPrint("Unhooked chat frames")
    end
end

-- ========================================
-- EVENT HANDLERS
-- ========================================

-- Handle CHAT_MSG_* events for caching
function ChatIntegration:OnChatMessage(event, text, sender, ...)
    self.wysiwyg:CacheRealMessage(sender, text, event, time())
end

-- ========================================
-- EXPORT
-- ========================================

if not WizzyWig then
    error("WizzyWig namespace not found! Ensure Core.lua loads before ChatIntegration.lua")
end
WizzyWig.ChatIntegration = ChatIntegration
