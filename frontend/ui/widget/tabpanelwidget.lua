local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local CloseButton = require("ui/widget/closebutton")
local DocSettings = require("docsettings")
local DocumentRegistry = require("document/documentregistry")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconButton = require("ui/widget/iconbutton")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Math = require("optmath")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local RenderImage = require("ui/renderimage")
local Size = require("ui/size")
local TextViewer = require("ui/widget/textviewer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Input = Device.input
local Screen = Device.screen
local T = require("ffi/util").template
local _ = require("gettext")
local logger = require("logger")

local TabPanelWidget = InputContainer:new {
    width = nil,
    height = nil,
    tabs = {
        { text = "Tab1" },
        { text = "Tab2"},
        { text = "Tab3"},
        { text = "Tab3"},
    },
    select = 2, -- current selected tab
}

function TabPanelWidget:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.dimen = Geom:new {
        w = self.width,
        h = self.height,
    }

    if Device:hasKeys() then
        self.key_events = {
            Close = { { "Back" }, doc = "close page" },
        }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new {
                ges = "swipe",
                range = self.dimen,
            }
        }
    end

    local tabs = HorizontalGroup:new{}
    local line_select = HorizontalGroup:new{}
    local element
    local line_no_select = LineWidget:new{
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        dimen = Geom:new{
            w = math.floor(self.width / #self.tabs),
            h = Size.line.thick,
        }
    }

    local element_width = math.floor(self.width / #self.tabs)
    local line_width
    for i = 1, #self.tabs do
        element = Button:new {
            text = self.tabs[i].text,
            --text_func = btn_entry.text_func,
            --enabled = btn_entry.enabled,
            callback = function()
                print("$$$$$$$$$$$$$$$$$$$$$$$$$$$")
                print(self.select)
                self.select = i
                print(self.select)
                self:init()
            end,
            width = element_width -2,
            max_width = element_width -2,
            bordersize = 0,
            margin = 0,
            padding = 0,
            radius = 0,
            --text_font_face = self.button_font_face,
            --text_font_size = self.button_font_size,
            text_font_bold = i == self. select,
            show_parent = self,
        }

        if i == #self.tabs then
            line_width = element_width +1
        else
            line_width = element_width
        end

        local line = LineWidget:new{
            background = i == self. select and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_LIGHT_GRAY,
            dimen = Geom:new{
                w = line_width,
                h = Size.line.thick,
            }
        }

        table.insert(tabs, element)
        table.insert(line_select, line)
    end



    --local line_select = nil
    local panel = nil
    local footer = nil

    local content = VerticalGroup:new{
        tabs,
        line_select,
        panel,
        footer,
    }

    self[1] = FrameContainer:new {
        height = self.height,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        content
    }
end


function TabPanelWidget:update()

end

--function TabPanelWidget:getSize()
--    --return
--end

function TabPanelWidget:onClose()
    UIManager:close(self)
    return true
end

return TabPanelWidget
