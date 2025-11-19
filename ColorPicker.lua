-- WizzyWig: Color Picker UI
-- Provides UI for selecting colors from presets or custom RGB

local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

-- ========================================
-- COLOR PICKER CLASS
-- ========================================

local ColorPicker = {}
ColorPicker.__index = ColorPicker

-- Constructor
function ColorPicker:New(wizzywigAddon, colorStyle)
    local self = setmetatable({}, ColorPicker)
    self.addon = wizzywigAddon
    self.colorStyle = colorStyle
    self.currentColor = nil
    return self
end

-- ========================================
-- UI CREATION
-- ========================================

-- Create color picker toolbar (adds to a container)
-- container: AceGUI container to add color buttons to
-- onColorSelected: callback function(colorData) when a color is selected
function ColorPicker:CreateToolbar(container, onColorSelected)
    self.onColorSelected = onColorSelected

    -- Create a horizontal flow group for color buttons
    local colorGroup = AceGUI:Create("SimpleGroup")
    colorGroup:SetFullWidth(true)
    colorGroup:SetLayout("Flow")
    container:AddChild(colorGroup)

    -- Add preset color buttons (first 12 presets)
    local presets = self.colorStyle.PRESETS
    for i = 1, math.min(12, #presets) do
        local preset = presets[i]
        local btn = self:CreateColorButton(preset.name, preset.hex)
        colorGroup:AddChild(btn)
    end

    -- Add "More Colors" button
    local moreBtn = AceGUI:Create("Button")
    moreBtn:SetText("More...")
    moreBtn:SetWidth(70)
    moreBtn:SetCallback("OnClick", function()
        self:ShowColorDialog()
    end)
    colorGroup:AddChild(moreBtn)

    -- Add "Clear Colors" button
    local clearBtn = AceGUI:Create("Button")
    clearBtn:SetText("Clear All")
    clearBtn:SetWidth(80)
    clearBtn:SetCallback("OnClick", function()
        self.currentColor = nil
        -- Clear all styles from WYSIWYG
        if self.addon.wysiwyg then
            self.addon.wysiwyg:ClearStyles()
            self.addon:Print("All colors cleared")
        end
    end)
    colorGroup:AddChild(clearBtn)

    return colorGroup
end

-- Create a single color button
function ColorPicker:CreateColorButton(name, hexColor)
    local btn = AceGUI:Create("Button")

    -- Create colored square icon
    local r = tonumber(hexColor:sub(1, 2), 16) / 255
    local g = tonumber(hexColor:sub(3, 4), 16) / 255
    local b = tonumber(hexColor:sub(5, 6), 16) / 255

    -- Button shows colored text (using color code)
    local colorCode = string.format("|cFF%s", hexColor)
    btn:SetText(colorCode .. "████|r")  -- Block characters
    btn:SetWidth(50)

    -- Set button callback
    btn:SetCallback("OnClick", function()
        local colorData = self.colorStyle:CreateColorDataFromHex(hexColor)
        self.currentColor = colorData

        if self.onColorSelected then
            self.onColorSelected(colorData)
        end

        self.addon:DebugPrint("Selected color: " .. name .. " (" .. hexColor .. ")")
    end)

    -- Set tooltip
    btn:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        GameTooltip:SetText(name, 1, 1, 1)
        GameTooltip:AddLine("|cFF" .. hexColor .. "████████|r", 1, 1, 1)
        GameTooltip:AddLine("Click to apply this color", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    btn:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)

    return btn
end

-- Show full color dialog with all presets
function ColorPicker:ShowColorDialog()
    -- Create dialog frame
    local dialog = AceGUI:Create("Frame")
    dialog:SetTitle("Choose Color")
    dialog:SetWidth(400)
    dialog:SetHeight(500)
    dialog:SetLayout("Flow")

    -- Make it a dialog (auto-centered)
    dialog.frame:SetFrameStrata("DIALOG")

    -- Add all preset colors
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    scroll:SetLayout("Flow")
    dialog:AddChild(scroll)

    local presets = self.colorStyle.PRESETS
    for i, preset in ipairs(presets) do
        local colorGroup = AceGUI:Create("SimpleGroup")
        colorGroup:SetFullWidth(true)
        colorGroup:SetLayout("Flow")

        -- Color button
        local btn = self:CreateColorButton(preset.name, preset.hex)
        colorGroup:AddChild(btn)

        -- Color name label with colored text
        local label = AceGUI:Create("Label")
        local colorCode = string.format("|cFF%s", preset.hex)
        label:SetText(colorCode .. preset.name .. "|r")
        label:SetWidth(200)
        colorGroup:AddChild(label)

        scroll:AddChild(colorGroup)
    end

    -- Add custom RGB section
    local customHeader = AceGUI:Create("Heading")
    customHeader:SetText("Custom RGB")
    customHeader:SetFullWidth(true)
    scroll:AddChild(customHeader)

    -- RGB sliders
    local rgbGroup = AceGUI:Create("SimpleGroup")
    rgbGroup:SetFullWidth(true)
    rgbGroup:SetLayout("Flow")
    scroll:AddChild(rgbGroup)

    local tempR, tempG, tempB = 255, 255, 255

    -- Color preview label
    local previewLabel = AceGUI:Create("Label")
    previewLabel:SetText("|cFFFFFFFFPreview: ████████████|r")
    previewLabel:SetFullWidth(true)
    rgbGroup:AddChild(previewLabel)

    -- Function to update preview
    local function UpdatePreview()
        local hexColor = string.format("%02X%02X%02X", tempR, tempG, tempB)
        previewLabel:SetText(string.format("|cFF%sPreview: ████████████|r", hexColor))
    end

    -- Red slider
    local rSlider = AceGUI:Create("Slider")
    rSlider:SetLabel("Red")
    rSlider:SetSliderValues(0, 255, 1)
    rSlider:SetValue(255)
    rSlider:SetFullWidth(true)
    rSlider:SetCallback("OnValueChanged", function(widget, event, value)
        tempR = value
        UpdatePreview()
    end)
    rgbGroup:AddChild(rSlider)

    -- Green slider
    local gSlider = AceGUI:Create("Slider")
    gSlider:SetLabel("Green")
    gSlider:SetSliderValues(0, 255, 1)
    gSlider:SetValue(255)
    gSlider:SetFullWidth(true)
    gSlider:SetCallback("OnValueChanged", function(widget, event, value)
        tempG = value
        UpdatePreview()
    end)
    rgbGroup:AddChild(gSlider)

    -- Blue slider
    local bSlider = AceGUI:Create("Slider")
    bSlider:SetLabel("Blue")
    bSlider:SetSliderValues(0, 255, 1)
    bSlider:SetValue(255)
    bSlider:SetFullWidth(true)
    bSlider:SetCallback("OnValueChanged", function(widget, event, value)
        tempB = value
        UpdatePreview()
    end)
    rgbGroup:AddChild(bSlider)

    -- Spacer
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    rgbGroup:AddChild(spacer)

    -- Apply custom button
    local applyBtn = AceGUI:Create("Button")
    applyBtn:SetText("Apply Custom Color")
    applyBtn:SetFullWidth(true)
    applyBtn:SetCallback("OnClick", function()
        local colorData = self.colorStyle:CreateColorData(tempR, tempG, tempB)
        self.currentColor = colorData

        if self.onColorSelected then
            self.onColorSelected(colorData)
        end

        dialog:Release()
    end)
    rgbGroup:AddChild(applyBtn)

    -- Close dialog callback
    dialog:SetCallback("OnClose", function(widget)
        widget:Release()
    end)
end

-- Get currently selected color
function ColorPicker:GetCurrentColor()
    return self.currentColor
end

-- Set current color
function ColorPicker:SetCurrentColor(colorData)
    self.currentColor = colorData
end

-- Clear current color
function ColorPicker:ClearCurrentColor()
    self.currentColor = nil
end

-- ========================================
-- EXPORT
-- ========================================

if not WizzyWig then
    error("WizzyWig namespace not found! Ensure Core.lua loads before ColorPicker.lua")
end
WizzyWig.ColorPicker = ColorPicker
