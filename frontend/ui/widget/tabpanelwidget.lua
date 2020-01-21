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
local WidgetContainer = require("ui/widget/container/widgetcontainer")
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
        { text = "Tab2" },
        { text = "Tab3" },
        { text = "Tab4" },
    },
    select = 1, -- current selected tab
}

function TabPanelWidget:init()
    --self.width = Screen:getWidth()
    --self.height = Screen:getHeight()
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
    self.tab_group = HorizontalGroup:new{}
    self.line_select = HorizontalGroup:new{}


    self:update()

    self[1] = FrameContainer:new {
        height = self.height,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        self.content
    }


end


function TabPanelWidget:update()
    print("*************************")
    print(self.select)
    self.tab_group:clear()
    self.line_select:clear()
    --self.content:resetLayout()
    local element
    local element_width = math.floor(self.width / #self.tabs)
    local line_width
    for i = 1, #self.tabs do
        element = Button:new {
            text = self.tabs[i].text,
            --enabled = btn_entry.enabled,
            callback = function()
                print("$$$$$$$$$$$$$$$$$$$$$$$$$$$")
                print(self.select)
                self.select = i
                print(self.select)
                self:update()
                --UIManager:setDirty("all")
                --UIManager:setDirty(self, "ui")
            end,
            no_flash = true,
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

        table.insert(self.tab_group, element)
        table.insert(self.line_select, line)
    end

    local panel = nil
    local footer = nil

    self.content = VerticalGroup:new{
        self.tab_group,
        self.line_select,
        --panel,
        --footer,
    }

    --local dimen = Geom:new{ x = 0 , y=0, w = self.width, h = self.content:getSize().h }
    --UIManager:setDirty(self.parrent, function()
    --    return "ui", self.dimen
    --end)
    --UIManager:setDirty(self.show_parrent, "ui")
    --return true



    local dimen = Geom:new {
        x = 0,
        y = 0,
        w = Screen:getWidth(),
        h = Screen:getHeight(),
    }



    UIManager:setDirty(self.content, function()
        return "ui", dimen
    end)
    UIManager:setDirty("all")
    --UIManager:setDirty(self, "ui", nil, true)

end

--function TabPanelWidget:getSize()
--    --return
--end

function TabPanelWidget:onClose()
    UIManager:close(self)
    return true
end

return TabPanelWidget
