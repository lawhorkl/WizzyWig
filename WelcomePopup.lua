-- WizzyWig: Welcome Popup (OOP)
local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

-- WelcomePopup class
local WelcomePopup = {}
WelcomePopup.__index = WelcomePopup

-- Constructor
function WelcomePopup:New(wizzywigAddon)
    local self = setmetatable({}, WelcomePopup)
    self.addon = wizzywigAddon
    return self
end

-- Show the welcome popup
function WelcomePopup:Show()
    -- Create welcome frame
    local welcomeFrame = AceGUI:Create("Frame")
    welcomeFrame:SetTitle("Welcome to WizzyWig!")
    welcomeFrame:SetWidth(500)
    welcomeFrame:SetHeight(400)
    welcomeFrame:SetLayout("Flow")

    -- Center the frame
    welcomeFrame.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Thank you message
    local thankYouLabel = AceGUI:Create("Label")
    thankYouLabel:SetText("Thank you for trying WizzyWig!")
    thankYouLabel:SetFullWidth(true)
    thankYouLabel:SetFontObject(GameFontNormalLarge)
    welcomeFrame:AddChild(thankYouLabel)

    -- Spacer
    local spacer1 = AceGUI:Create("Label")
    spacer1:SetText(" ")
    spacer1:SetFullWidth(true)
    welcomeFrame:AddChild(spacer1)

    -- Instructions
    local instructionsLabel = AceGUI:Create("Label")
    instructionsLabel:SetText("To get started:\n\n• Click the minimap button to open the editor\n• Type /ww for commands\n• Configure settings with /ww config")
    instructionsLabel:SetFullWidth(true)
    welcomeFrame:AddChild(instructionsLabel)

    -- Spacer
    local spacer2 = AceGUI:Create("Label")
    spacer2:SetText(" ")
    spacer2:SetFullWidth(true)
    welcomeFrame:AddChild(spacer2)

    -- EmoteSplitter requirement warning
    local warningLabel = AceGUI:Create("Label")
    warningLabel:SetText("|cFFFF0000IMPORTANT:|r |cFFFF0000EmoteSplitter is required for multi-posting long emotes!|r\n\nWithout EmoteSplitter, messages longer than the chat limit will be truncated.")
    warningLabel:SetFullWidth(true)
    warningLabel:SetColor(1, 1, 1)
    welcomeFrame:AddChild(warningLabel)

    -- Spacer
    local spacer3 = AceGUI:Create("Label")
    spacer3:SetText(" ")
    spacer3:SetFullWidth(true)
    welcomeFrame:AddChild(spacer3)

    -- Feedback and bug reporting
    local feedbackLabel = AceGUI:Create("Label")
    feedbackLabel:SetText("|cFF00FF00Found a bug or have feedback?|r\n\nPlease report bugs or share your feedback on our CurseForge page:\n|cFF00CCFFcurseforge.com/wow/addons/wizzywing|r")
    feedbackLabel:SetFullWidth(true)
    feedbackLabel:SetColor(1, 1, 1)
    welcomeFrame:AddChild(feedbackLabel)

    -- Spacer
    local spacer4 = AceGUI:Create("Label")
    spacer4:SetText(" ")
    spacer4:SetFullWidth(true)
    welcomeFrame:AddChild(spacer4)

    -- Close button
    local closeButton = AceGUI:Create("Button")
    closeButton:SetText("Got it!")
    closeButton:SetWidth(200)
    closeButton:SetCallback("OnClick", function()
        welcomeFrame:Release()
    end)
    welcomeFrame:AddChild(closeButton)

    -- Handle frame close
    local addon = self.addon
    welcomeFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        -- Mark first run as complete
        addon.db.profile.firstRun = false
    end)
end

-- Export to addon namespace
if not WizzyWig then
    error("WizzyWig namespace not found! Ensure Core.lua loads before WelcomePopup.lua")
end
WizzyWig.WelcomePopup = WelcomePopup
