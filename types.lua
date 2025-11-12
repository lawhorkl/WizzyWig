---@meta

-- WizzyWig Type Definitions
-- This file is for LSP/Intellisense only and is NOT loaded in-game

---@class LibStub
---@overload fun(libName: "AceGUI-3.0", silent?: boolean): AceGUI
---@overload fun(libName: "AceConfig-3.0", silent?: boolean): any
---@overload fun(libName: "AceConfigDialog-3.0", silent?: boolean): any
---@overload fun(libName: "AceDB-3.0", silent?: boolean): any
---@overload fun(libName: "LibDataBroker-1.1", silent?: boolean): any
---@overload fun(libName: "LibDBIcon-1.0", silent?: boolean): any
---@overload fun(libName: string, silent?: boolean): any

---@type LibStub
LibStub = {}

---@class AceGUIWidget
---@field public frame Frame
---@field public sizer_se Frame?
---@field public sizer_s Frame?
---@field public sizer_e Frame?
---@field AddChild fun(self: AceGUIWidget, child: AceGUIWidget)
---@field SetFullWidth fun(self: AceGUIWidget, fullWidth: boolean)
---@field SetFullHeight fun(self: AceGUIWidget, fullHeight: boolean)
---@field SetLayout fun(self: AceGUIWidget, layout: string)
---@field SetWidth fun(self: AceGUIWidget, width: number)
---@field SetHeight fun(self: AceGUIWidget, height: number)
---@field SetPoint fun(self: AceGUIWidget, point: string, relativeTo: Frame, relativePoint: string, x: number, y: number)
---@field SetTitle fun(self: AceGUIWidget, title: string)
---@field SetStatusText fun(self: AceGUIWidget, text: string)
---@field SetLabel fun(self: AceGUIWidget, label: string)
---@field SetText fun(self: AceGUIWidget, text: string)
---@field SetValue fun(self: AceGUIWidget, value: any)
---@field SetList fun(self: AceGUIWidget, list: table)
---@field SetNumLines fun(self: AceGUIWidget, numLines: number)
---@field SetCallback fun(self: AceGUIWidget, event: string, callback: function)
---@field GetText fun(self: AceGUIWidget): string
---@field GetValue fun(self: AceGUIWidget): any
---@field IsShown fun(self: AceGUIWidget): boolean
---@field Show fun(self: AceGUIWidget)
---@field Hide fun(self: AceGUIWidget)
---@field SetFocus fun(self: AceGUIWidget)
---@field DisableButton fun(self: AceGUIWidget, disable: boolean)
---@field Release fun(self: AceGUIWidget)

---@class AceGUI
---@field Create fun(widgetType: string): AceGUIWidget
---@field Release fun(widget: AceGUIWidget)

---@class MainContainer: AceGUIWidget
---@field public editBox AceGUIWidget
---@field public channelDropdown AceGUIWidget
