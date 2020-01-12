local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local CloseButton = require("ui/widget/closebutton")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconButton = require("ui/widget/iconbutton")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextViewer = require("ui/widget/textviewer")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Input = Device.input
local Screen = Device.screen
local T = require("ffi/util").template
local _ = require("gettext")

local HomePageWidget = InputContainer:new {
    width = nil,
    height = nil,
}

function HomePageWidget:init()
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


    local header_text = TextWidget:new{
        face = Font:getFace("infofont"),
        text = "header",
    }

    local icon_size = Screen:scaleBySize(35)
    local home_button = IconButton:new{
        icon_file = "resources/icons/appbar.home.png",
        scale_for_dpi = false,
        width = icon_size,
        height = icon_size,
        padding = Size.padding.default,
        padding_left = Size.padding.large,
        padding_right = Size.padding.large,
        --padding_bottom = 0,
        callback = function() end,
        hold_callback = function() end,
    }




    local header = HorizontalGroup:new{
        home_button,
        home_button,
    }

    print("*************************************")
    print(header:getSize().h)

    local header_line = LineWidget:new{
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        dimen = Geom:new{
            w = self.width,
            h = Size.line.thick,
        }
    }


    local footer_text = TextWidget:new{
        face = Font:getFace("infofont"),
        text = "footer",
    }

    --local header = TopContainer:new {
    --    dimen = self.dimen:copy(),
    --    header_text,
    --}


    local footer = BottomContainer:new {
        dimen = self.dimen:copy(),
        footer_text,
    }



    local padding = Size.padding.large
    self.pages = 1 --math.ceil(#self.kv_pairs / self.items_per_page)
    self.main_content = VerticalGroup:new {}


    local content1 = OverlapGroup:new {
        dimen = self.dimen:copy(),
        allow_mirroring = false,
        VerticalGroup:new {
            align = "left",
            self.main_content,
        },
        --footer,
    }



    local content = VerticalGroup:new {
        align = "center",
        header,
        header_line,
    }


    -- assemble page
    self[1] = FrameContainer:new {
        height = self.dimen.h,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        content
    }
end

return HomePageWidget
