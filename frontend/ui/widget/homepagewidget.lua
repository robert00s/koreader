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

    self.menu_items = {
        ["KOMenu:menu_buttons"] = {
            -- top menu
        },
        -- items in top menu
        filemanager_settings = {
            icon = "resources/icons/appbar.cabinet.files.png",
            remember = false,
        },
        setting = {
            icon = "resources/icons/appbar.settings.png",
            remember = false,
        },
        tools = {
            icon = "resources/icons/appbar.tools.png",
        },
        search = {
            icon = "resources/icons/appbar.magnify.browse.png",
        },
        plus_menu = {
            icon = "resources/icons/appbar.cabinet.files.png",
            remember = false,
            callback = function()
                --self:onTapCloseMenu()
                self.ui:onClose()
                --self.ui:showFileManager()

            end,
        },
        main = {
            icon = "resources/icons/menu-icon.png",
        },
    }

    local order = require("ui/elements/filemanager_menu_order1")

    local MenuSorter = require("ui/menusorter")
    self.tab_item_table = MenuSorter:mergeAndSort("filemanager", self.menu_items, order)


    local TouchMenu = require("ui/widget/touchmenu")
    local main_menu = TouchMenu:new{
        width = Screen:getWidth(),
        last_index = nil, --tab_index,
        tab_item_table = self.tab_item_table,
        show_parent = self,
    }


    local icon_set = {
        {
            icon = "resources/icons/appbar.settings.png",
            callback = function() end,
        },
        {
            icon = "resources/icons/appbar.magnify.browse.png",
            callback = function() end,
        },

    }

    local icon_widgets = HorizontalGroup:new{}
    local icon_size = Screen:scaleBySize(40)
    local spacing_width = 16
    local icon_padding = math.min(spacing_width, Screen:scaleBySize(16))
    for k, v in ipairs(icon_set) do
        local ib = IconButton:new{
            show_parent = self.show_parent,
            icon_file = v.icon,
            width = icon_size,
            height = icon_size,
            scale_for_dpi = false,
            callback = v.callback ,
            padding_left = icon_padding,
            padding_right = icon_padding,
            menu = self.menu,
        }

        table.insert(icon_widgets, ib)
        --table.insert(self.menu.layout, ib) -- for the focusmanager

    end



--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
        --main_menu,
        --header,
        icon_widgets,
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
