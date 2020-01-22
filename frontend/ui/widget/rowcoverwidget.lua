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

local BookInfoManager = require("bookinfomanager")

local RowCoverWidget = InputContainer:new {
    width = nil,
    height = nil,
    per_page = 3,
}

function RowCoverWidget:init()
    self.frame = FrameContainer:new {
        height = self.height,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
    }

    self.tab_group = HorizontalGroup:new{}

    self:update()
    self.frame[1] = self.content
    self[1] = self.frame
    self.dimen = Geom:new(self.frame:getSize())

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
end

function RowCoverWidget:update()
    self.tab_group:clear()
    local widget
    local border_size = Screen:scaleBySize(2)
    local dimen = Geom:new{
        w = math.floor((self.width * 0.95) / self.per_page),
        h = self.height
    }
    for i = 1, #self.elements do
        local bookinfo = BookInfoManager:getBookInfo(self.elements[i].file, true)
        if bookinfo.has_cover and not bookinfo.ignore_cover then
            -- Let ImageWidget do the scaling and give us a bb that fit
            local scale_factor = 1.2 --math.min(max_img_w / bookinfo.cover_w, max_img_h / bookinfo.cover_h)
            local image = ImageWidget:new{
                image = bookinfo.cover_bb,
                scale_factor = scale_factor,
            }
            image:_render()
            local image_size = image:getSize()
            widget = CenterContainer:new{
                dimen = dimen,
                FrameContainer:new{
                    width = image_size.w + 2*border_size,
                    height = image_size.h + 2*border_size,
                    margin = 0,
                    padding = 0,
                    bordersize = border_size,
                    --dim = self.file_deleted,
                    --color = self.file_deleted and Blitbuffer.COLOR_DARK_GRAY or nil,
                    image,
                }
            }
            table.insert(self.tab_group, widget)
        end
    end

    self.content = LeftContainer:new{
        dimen = {w = self.width * 0.95, h = self.height},
        self.tab_group,
    }

    UIManager:setDirty(self.show_parent, function()
        return "ui", self.dimen
    end)
end

--function TabPanelWidget:getSize()
--    --return
--end

function RowCoverWidget:onClose()
    UIManager:close(self)
    return true
end

return RowCoverWidget
