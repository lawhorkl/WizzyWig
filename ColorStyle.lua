-- WizzyWig: Color Style Provider
-- Implements the WYSIWYG style provider contract for RGB colors

local addonName, addon = ...

-- ========================================
-- COLOR STYLE PROVIDER
-- ========================================

local ColorStyle = {}
ColorStyle.__index = ColorStyle

-- Constructor
function ColorStyle:New(wizzywigAddon)
    local self = setmetatable({}, ColorStyle)
    self.addon = wizzywigAddon
    return self
end

-- ========================================
-- STYLE PROVIDER CONTRACT IMPLEMENTATION
-- ========================================

-- Get style type identifier
function ColorStyle:GetType()
    return "color"
end

-- Get priority (lower = higher priority)
-- Colors have priority 10 (applied before bold/italic)
function ColorStyle:GetPriority()
    return 10
end

-- ========================================
-- ENCODING / DECODING
-- ========================================

-- Encode color style data to binary
-- Format: r(uint8) + g(uint8) + b(uint8) = 3 bytes
-- styleData format: { r = 255, g = 0, b = 0 }
function ColorStyle:EncodeStyle(styleData)
    return string.char(
        styleData.r or 255,
        styleData.g or 255,
        styleData.b or 255
    )
end

-- Decode binary data to color style data
-- bytes: 3-byte string (rgb)
function ColorStyle:DecodeStyle(bytes)
    if #bytes < 3 then
        return { r = 255, g = 255, b = 255 }
    end

    local r, g, b = string.byte(bytes, 1, 3)
    return { r = r, g = g, b = b }
end

-- Get encoded size in bytes
function ColorStyle:GetEncodedSize()
    return 3  -- RGB = 3 bytes
end

-- ========================================
-- STYLE APPLICATION
-- ========================================

-- Apply color style to text (returns WoW color-coded text)
-- text: the text to colorize
-- styleData: { r = 255, g = 0, b = 0 }
function ColorStyle:ApplyStyle(text, styleData)
    -- Create WoW Color object (expects 0.0-1.0 range)
    local color = CreateColor(
        styleData.r / 255,
        styleData.g / 255,
        styleData.b / 255,
        1.0
    )

    -- Use WoW's built-in color wrapping
    return color:WrapTextInColorCode(text)
end

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Create color data from 0-255 RGB values
function ColorStyle:CreateColorData(r, g, b)
    return {
        r = math.max(0, math.min(255, r)),
        g = math.max(0, math.min(255, g)),
        b = math.max(0, math.min(255, b))
    }
end

-- Create color data from hex string (e.g., "FF0000")
function ColorStyle:CreateColorDataFromHex(hexStr)
    -- Remove # if present
    hexStr = hexStr:gsub("#", "")

    -- Parse hex
    local r = tonumber(hexStr:sub(1, 2), 16) or 255
    local g = tonumber(hexStr:sub(3, 4), 16) or 255
    local b = tonumber(hexStr:sub(5, 6), 16) or 255

    return self:CreateColorData(r, g, b)
end

-- Convert color data to hex string
function ColorStyle:ColorDataToHex(colorData)
    return string.format("%02X%02X%02X", colorData.r, colorData.g, colorData.b)
end

-- ========================================
-- PRESET COLORS
-- ========================================

-- Common RP colors palette
ColorStyle.PRESETS = {
    -- Basic colors
    { name = "Red",          hex = "FF0000" },
    { name = "Orange",       hex = "FFA500" },
    { name = "Yellow",       hex = "FFFF00" },
    { name = "Green",        hex = "00FF00" },
    { name = "Cyan",         hex = "00FFFF" },
    { name = "Blue",         hex = "0000FF" },
    { name = "Purple",       hex = "800080" },
    { name = "Magenta",      hex = "FF00FF" },

    -- Shades
    { name = "White",        hex = "FFFFFF" },
    { name = "Light Gray",   hex = "CCCCCC" },
    { name = "Gray",         hex = "808080" },
    { name = "Dark Gray",    hex = "404040" },
    { name = "Black",        hex = "000000" },

    -- Nature colors
    { name = "Forest Green", hex = "228B22" },
    { name = "Sky Blue",     hex = "87CEEB" },
    { name = "Fire Orange",  hex = "FF4500" },
    { name = "Blood Red",    hex = "8B0000" },
    { name = "Gold",         hex = "FFD700" },
    { name = "Silver",       hex = "C0C0C0" },

    -- Magic colors
    { name = "Arcane",       hex = "4169E1" },
    { name = "Fel Green",    hex = "00FF00" },
    { name = "Shadow",       hex = "9370DB" },
    { name = "Holy",         hex = "FFE66D" },
    { name = "Frost",        hex = "ADD8E6" },
    { name = "Fire",         hex = "FF6347" },
}

-- Get preset color data by name
function ColorStyle:GetPreset(name)
    for _, preset in ipairs(self.PRESETS) do
        if preset.name == name then
            return self:CreateColorDataFromHex(preset.hex)
        end
    end
    return nil
end

-- Get all preset names
function ColorStyle:GetPresetNames()
    local names = {}
    for _, preset in ipairs(self.PRESETS) do
        table.insert(names, preset.name)
    end
    return names
end

-- ========================================
-- EXPORT
-- ========================================

if not WizzyWig then
    error("WizzyWig namespace not found! Ensure Core.lua loads before ColorStyle.lua")
end
WizzyWig.ColorStyle = ColorStyle
