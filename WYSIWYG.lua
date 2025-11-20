-- WizzyWig: Generic WYSIWYG Style System
-- Manages text styling in an extendable way using style providers

local addonName, addon = ...

-- ========================================
-- STYLE PROVIDER CONTRACT
-- ========================================

--[[
    Style Provider Interface:
    All style modules must implement this contract:

    StyleProvider = {
        -- Identification
        GetType() -> string                    -- e.g., "color", "bold", "font"
        GetPriority() -> number                -- for style conflict resolution (lower = higher priority)

        -- Encoding (for network transmission)
        EncodeStyle(styleData) -> string       -- binary encode style data
        DecodeStyle(bytes) -> styleData        -- binary decode style data
        GetEncodedSize() -> number             -- bytes per style range

        -- Application (for display)
        ApplyStyle(text, styleData) -> string  -- apply style to text (returns styled text)

        -- UI (optional)
        CreateUI(parent, callback) -> frame    -- create UI for style selection
    }

    styleData format is provider-specific:
    - ColorStyle: { r = 255, g = 0, b = 0 }
    - BoldStyle: {} (flag-based, no data)
    - FontStyle: { fontId = 3 }
]]

-- ========================================
-- WYSIWYG CLASS
-- ========================================

local WYSIWYG = {}
WYSIWYG.__index = WYSIWYG

-- Message type constants
WYSIWYG.MESSAGE_TYPE = {
    REAL_MESSAGE_STYLES = 0,   -- Style metadata for real SendChatMessage
    FAKE_SAY = 1,              -- Full fake SAY message (text + styles)
    FAKE_EMOTE = 2,            -- Full fake EMOTE message (text + styles)
}

-- Constructor
function WYSIWYG:New(wizzywigAddon)
    local self = setmetatable({}, WYSIWYG)
    self.addon = wizzywigAddon

    -- Style providers registry
    self.providers = {}           -- styleType -> provider
    self.providerList = {}        -- ordered list by priority

    -- Style ranges for current message being edited
    -- Format: { startPos, endPos, styleType, styleData }
    self.activeStyles = {}

    -- Message caches (for receiving)
    self.messageCache = {}        -- Real messages waiting for style data
    self.pendingStyles = {}       -- Style data waiting for messages

    -- Message queue for throttling
    self.messageQueue = {}
    self.lastSendTime = 0
    self.sendTimer = nil
    self.throttleCount = 0

    return self
end

-- ========================================
-- STYLE PROVIDER REGISTRATION
-- ========================================

-- Register a style provider
function WYSIWYG:RegisterProvider(provider)
    local styleType = provider:GetType()

    if self.providers[styleType] then
        self.addon:Print("Warning: Style provider '" .. styleType .. "' already registered")
        return false
    end

    self.providers[styleType] = provider
    table.insert(self.providerList, provider)

    -- Sort by priority (lower number = higher priority)
    table.sort(self.providerList, function(a, b)
        return a:GetPriority() < b:GetPriority()
    end)

    self.addon:DebugPrint("Registered style provider: " .. styleType)
    return true
end

-- Get a style provider by type
function WYSIWYG:GetProvider(styleType)
    return self.providers[styleType]
end

-- ========================================
-- STYLE RANGE MANAGEMENT
-- ========================================

-- Add a style range
function WYSIWYG:AddStyle(startPos, endPos, styleType, styleData)
    table.insert(self.activeStyles, {
        startPos = startPos,
        endPos = endPos,
        styleType = styleType,
        styleData = styleData
    })
end

-- Clear all active styles
function WYSIWYG:ClearStyles()
    self.activeStyles = {}
end

-- Get all active styles
function WYSIWYG:GetStyles()
    return self.activeStyles
end

-- Set styles (replaces all)
function WYSIWYG:SetStyles(styles)
    self.activeStyles = styles or {}
end

-- Remove styles in a range
function WYSIWYG:RemoveStylesInRange(startPos, endPos, styleType)
    local filtered = {}
    for _, style in ipairs(self.activeStyles) do
        -- Keep styles that don't match or don't overlap
        if style.styleType ~= styleType or style.endPos < startPos or style.startPos > endPos then
            table.insert(filtered, style)
        end
    end
    self.activeStyles = filtered
end

-- ========================================
-- ENCODING / PACKING
-- ========================================

-- Pack all styles for a message
-- Format: numStyles(uint8) + [styleType(uint8) + startPos(uint16) + endPos(uint16) + encodedStyle]...
function WYSIWYG:PackStyles(styles)
    if not styles or #styles == 0 then
        return string.char(0)  -- numStyles = 0
    end

    local numStyles = math.min(#styles, 255)
    local data = string.char(numStyles)

    for i = 1, numStyles do
        local style = styles[i]
        local provider = self.providers[style.styleType]

        if provider then
            -- Style type ID (we'll use first byte of type string as ID for now)
            local typeId = string.byte(style.styleType, 1)

            -- Encode: typeId + startPos + endPos + styleData
            data = data .. string.char(
                typeId,
                math.floor(style.startPos / 256), style.startPos % 256,
                math.floor(style.endPos / 256), style.endPos % 256
            )

            -- Encode style-specific data
            local encodedStyle = provider:EncodeStyle(style.styleData)
            data = data .. encodedStyle
        end
    end

    return data
end

-- Pack full message (text + styles) for fake SAY/EMOTE
-- Format: textLen(uint16) + text + packedStyles
function WYSIWYG:PackMessage(text, styles)
    local textLen = #text

    -- Header: textLen(2 bytes)
    local data = string.char(
        math.floor(textLen / 256), textLen % 256
    )

    -- Text content
    data = data .. text

    -- Styles
    data = data .. self:PackStyles(styles)

    return data
end

-- ========================================
-- DECODING / UNPACKING
-- ========================================

-- Unpack styles from binary data
function WYSIWYG:UnpackStyles(data, offset)
    offset = offset or 1

    if offset > #data then
        return {}, offset
    end

    local numStyles = string.byte(data, offset)
    offset = offset + 1

    local styles = {}

    for i = 1, numStyles do
        if offset > #data then break end

        -- Read: typeId + startPos + endPos
        local typeId, s1, s2, e1, e2 = string.byte(data, offset, offset + 4)
        offset = offset + 5

        local startPos = s1 * 256 + s2
        local endPos = e1 * 256 + e2

        -- Find provider by type ID (lookup by first char of type)
        local provider = nil
        local styleType = nil
        for type, prov in pairs(self.providers) do
            if string.byte(type, 1) == typeId then
                provider = prov
                styleType = type
                break
            end
        end

        if provider then
            -- Decode style-specific data
            local encodedSize = provider:GetEncodedSize()
            local encodedData = data:sub(offset, offset + encodedSize - 1)
            offset = offset + encodedSize

            local styleData = provider:DecodeStyle(encodedData)

            table.insert(styles, {
                startPos = startPos,
                endPos = endPos,
                styleType = styleType,
                styleData = styleData
            })
        end
    end

    return styles, offset
end

-- Unpack full message (text + styles)
function WYSIWYG:UnpackMessage(data)
    if #data < 2 then
        return "", {}
    end

    -- Parse header
    local t1, t2 = string.byte(data, 1, 2)
    local textLen = t1 * 256 + t2

    -- Extract text
    local text = data:sub(3, 2 + textLen)

    -- Extract styles
    local styles = self:UnpackStyles(data, 3 + textLen)

    return text, styles
end

-- ========================================
-- STYLE APPLICATION
-- ========================================

-- Apply all styles to text for display
function WYSIWYG:ApplyStylesToText(text, styles)
    if not styles or #styles == 0 then
        return text
    end

    -- Sort styles by start position and priority
    local sortedStyles = {}
    for _, style in ipairs(styles) do
        table.insert(sortedStyles, style)
    end
    table.sort(sortedStyles, function(a, b)
        if a.startPos ~= b.startPos then
            return a.startPos < b.startPos
        end
        -- Same position, sort by provider priority
        local provA = self.providers[a.styleType]
        local provB = self.providers[b.styleType]
        if provA and provB then
            return provA:GetPriority() < provB:GetPriority()
        end
        return false
    end)

    -- Build styled text
    local segments = {}
    local lastPos = 1

    for _, style in ipairs(sortedStyles) do
        -- Add unstyled text before this style
        if style.startPos > lastPos then
            table.insert(segments, text:sub(lastPos, style.startPos - 1))
        end

        -- Apply style
        local provider = self.providers[style.styleType]
        if provider then
            local styledSegment = provider:ApplyStyle(
                text:sub(style.startPos, style.endPos),
                style.styleData
            )
            table.insert(segments, styledSegment)
        else
            -- Provider not found, add unstyled
            table.insert(segments, text:sub(style.startPos, style.endPos))
        end

        lastPos = style.endPos + 1
    end

    -- Add remaining unstyled text
    if lastPos <= #text then
        table.insert(segments, text:sub(lastPos))
    end

    return table.concat(segments)
end

-- ========================================
-- MESSAGE QUEUE & THROTTLING
-- ========================================

-- Queue an addon message for sending (handles throttling)
function WYSIWYG:QueueAddonMessage(prefix, data, chatType, target)
    table.insert(self.messageQueue, {
        prefix = prefix,
        data = data,
        chatType = chatType,
        target = target,
        timestamp = time()
    })

    self:ProcessQueue()
end

-- Process the message queue
function WYSIWYG:ProcessQueue()
    if #self.messageQueue == 0 then
        return
    end

    local now = GetTime()
    local timeSinceLastSend = now - self.lastSendTime

    -- Enforce 0.5 second delay between messages
    if timeSinceLastSend < 0.5 then
        if not self.sendTimer then
            self.sendTimer = C_Timer.After(0.5 - timeSinceLastSend, function()
                self.sendTimer = nil
                self:ProcessQueue()
            end)
        end
        return
    end

    -- Send next message
    local msg = table.remove(self.messageQueue, 1)
    local result = C_ChatInfo.SendAddonMessage(msg.prefix, msg.data, msg.chatType, msg.target)

    if result == Enum.SendAddonMessageResult.Success then
        self.lastSendTime = now
        self.throttleCount = 0

        -- Process next if queue not empty
        if #self.messageQueue > 0 then
            self.sendTimer = C_Timer.After(0.5, function()
                self.sendTimer = nil
                self:ProcessQueue()
            end)
        end
    elseif result == Enum.SendAddonMessageResult.AddonMessageThrottle or
           result == Enum.SendAddonMessageResult.ChannelThrottle then
        -- Put message back in queue
        table.insert(self.messageQueue, 1, msg)

        self.throttleCount = self.throttleCount + 1
        if self.throttleCount == 1 then
            self.addon:Print("Rate limit reached. Messages will be queued.")
        end

        -- Wait longer before retry
        self.sendTimer = C_Timer.After(2.0, function()
            self.sendTimer = nil
            self:ProcessQueue()
        end)
    else
        self.addon:Print("Failed to send message: " .. tostring(result))
    end
end

-- ========================================
-- MESSAGE CACHE MANAGEMENT (for receiving)
-- ========================================

-- Cache a real message
function WYSIWYG:CacheRealMessage(sender, text, event, timestamp)
    local key = sender .. ":" .. text:sub(1, 50)

    self.messageCache[key] = {
        sender = sender,
        text = text,
        event = event,
        timestamp = timestamp,
        styles = nil
    }

    -- Check if we have pending styles
    local styles = self:GetPendingStyles(sender)
    if styles then
        self.messageCache[key].styles = styles
        self:ClearPendingStyles(sender)
    end

    -- Clean up old cache
    self:CleanMessageCache(timestamp - 5)
end

-- Cache style data that arrived before the message
function WYSIWYG:CachePendingStyles(sender, styles, timestamp)
    self.pendingStyles[sender] = {
        styles = styles,
        timestamp = timestamp
    }

    C_Timer.After(10, function()
        if self.pendingStyles[sender] and self.pendingStyles[sender].timestamp == timestamp then
            self.pendingStyles[sender] = nil
        end
    end)
end

-- Get pending styles for a sender
function WYSIWYG:GetPendingStyles(sender)
    local data = self.pendingStyles[sender]
    if data and (time() - data.timestamp) < 10 then
        return data.styles
    end
    return nil
end

-- Clear pending styles
function WYSIWYG:ClearPendingStyles(sender)
    self.pendingStyles[sender] = nil
end

-- Clean up old message cache
function WYSIWYG:CleanMessageCache(cutoffTime)
    for key, msg in pairs(self.messageCache) do
        if msg.timestamp < cutoffTime then
            self.messageCache[key] = nil
        end
    end
end

-- Get style data for a message
function WYSIWYG:GetStyleDataForMessage(sender, text)
    local key = sender .. ":" .. text:sub(1, 50)

    local msg = self.messageCache[key]
    if msg and msg.styles then
        return msg.styles
    end

    return self:GetPendingStyles(sender)
end

-- Try to match received styles with a recent message
function WYSIWYG:MatchAndApplyStyles(sender, styles)
    for key, msg in pairs(self.messageCache) do
        if msg.sender == sender and (time() - msg.timestamp) < 3 then
            msg.styles = styles
            return true
        end
    end
    return false
end

-- ========================================
-- EXPORT
-- ========================================

if not WizzyWig then
    error("WizzyWig namespace not found! Ensure Core.lua loads before WYSIWYG.lua")
end
WizzyWig.WYSIWYG = WYSIWYG
