local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local CloseButton = require("ui/widget/closebutton")
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

    local order = require("ui/elements/filemanager_menu_order")

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
            icon = "resources/icons/menu-icon.png",
            callback = function() end,
        },
        {
            icon = "resources/icons/appbar.cabinet.files.png",
            callback = function()
                UIManager:nextTick(function()
                    self:onClose()
                end)
                --UIManager:close(self)
                --
            end,
        },

        {
            --https://materialdesignicons.com/

            icon = "resources/icons/history.png",
            callback = function()
                --self.ui:handleEvent(Event:new("ShowHist"))
                local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
                    FileManagerHistory:onShowHist()
            end,
        },
        {
            -- favorites
            --https://github.com/encharm/Font-Awesome-SVG-PNG/blob/master/black/png/64/star-o.png
            --https://materialdesignicons.com/
            icon = "resources/icons/star.png",
            callback = function()
                --self.ui:handleEvent(Event:new("ShowColl", "favorites"))
                local FileManagerCollection = require("apps/filemanager/filemanagercollection")
                FileManagerCollection:onShowColl("favorites")
            end,
        },
        {
            -- frontlight
            --http://modernuiicons.com/
            icon = "resources/icons/sunny.png",
            callback = function()
                local is_docless = self.ui == nil or self.ui.document == nil
                if is_docless then
                    local ReaderFrontLight = require("apps/reader/modules/readerfrontlight")
                    ReaderFrontLight:onShowFlDialog()
                else
                    self.ui:handleEvent(Event:new("ShowFlDialog"))
                end
            end,
        },

    }



    local icon_widgets = HorizontalGroup:new{}
    local icon_size = Screen:scaleBySize(40)



    local spacing_width = 16
    local size = #icon_set * icon_size
    print("###################################33")
    print(icon_size, size)

    local icon_padding = math.floor((Screen:getWidth() - size) / (2* #icon_set))

    --local icon_padding = math.min(spacing_width, Screen:scaleBySize(16))
    for k, v in ipairs(icon_set) do
        local ib = IconButton:new{
            show_parent = self.show_parent,
            icon_file = v.icon,
            width = icon_size,
            height = icon_size,
            scale_for_dpi = false,
            callback = v.callback,
            padding_top = 10,
            padding_bottom = 10,
            padding_left = icon_padding,
            padding_right = icon_padding,
            --menu = self.menu,
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

    local text_now_reading = TextWidget:new{
        text = _("Reading now"),
        face = Font:getFace("ffont"),
        bold = true,
        max_width = self.width * 0.95,
    }

    local now_reading = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = text_now_reading:getSize().h},
        text_now_reading
    }

    local content = VerticalGroup:new {
        align = "center",
        icon_widgets,
        header_line,
        now_reading,
        self:showLastBook()
        --button switch
        --button select
        --footer
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

function HomePageWidget:showLastBook()
    local last_file = G_reader_settings:readSetting("lastfile")
    self.small_font_face = Font:getFace("smallffont")
    self.medium_font_face = Font:getFace("ffont")
    self.large_font_face = Font:getFace("largeffont")

    local cover
    local document = DocumentRegistry:openDocument(last_file)
    if document then
        if document.loadDocument then
            -- CreDocument
            document:loadDocument(false) -- load only metadata
        end
        cover = document:getCoverPageImage()
        DocumentRegistry:closeDocument(last_file)
    end

    local screen_width = Screen:getWidth()
    local split_span_width = screen_width * 0.05

    local img_width, img_height
    if Screen:getScreenMode() == "landscape" then
        img_width = Screen:scaleBySize(132)
        img_height = Screen:scaleBySize(184)
    else
        img_width = Screen:scaleBySize(132 * 1.5)
        img_height = Screen:scaleBySize(184 * 1.5)
    end

    local height = img_height
    local width = screen_width - split_span_width - img_width
    -- title
    local book_meta_info_group = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = height * 0.2 },
        TextBoxWidget:new{
            text = "BBBBB",--self.props.title,
            width = width,
            face = self.medium_font_face,
            alignment = "center",
        },

    }
    -- author
    local text_author = TextBoxWidget:new{
        text = "AAAA", --self.props.authors,
        face = self.small_font_face,
        width = width,
        alignment = "center",
    }
    table.insert(book_meta_info_group,
        CenterContainer:new{
            dimen = Geom:new{ w = width, h = text_author:getSize().h },
            text_author
        }
    )
    -- progress bar
    local read_percentage = 0,3 --self.view.state.page / self.total_pages
    local progress_bar = ProgressWidget:new{
        width = width * 0.7,
        height = Screen:scaleBySize(10),
        percentage = read_percentage,
        ticks = nil,
        last = nil,
    }
    table.insert(book_meta_info_group,
        CenterContainer:new{
            dimen = Geom:new{ w = width, h = progress_bar:getSize().h },
            progress_bar
        }
    )
    -- complete text
    local text_complete = TextWidget:new{
        text = T(_("%1% Completed"),
            string.format("%1.f", read_percentage * 100)),
        face = self.small_font_face,
    }
    table.insert(book_meta_info_group,
        CenterContainer:new{
            dimen = Geom:new{ w = width, h = text_complete:getSize().h },
            text_complete
        }
    )
    -- build the final group
    local book_info_group = HorizontalGroup:new{
        align = "top",
        HorizontalSpan:new{ width =  split_span_width }
    }
    -- thumbnail
    if cover then
        -- Much like BookInfoManager, honor AR here
        local cbb_w, cbb_h = cover:getWidth(), cover:getHeight()
        if cbb_w > img_width or cbb_h > img_height then
            local scale_factor = math.min(img_width / cbb_w, img_height / cbb_h)
            cbb_w = math.min(math.floor(cbb_w * scale_factor)+1, img_width)
            cbb_h = math.min(math.floor(cbb_h * scale_factor)+1, img_height)
            cover = RenderImage:scaleBlitBuffer(cover, cbb_w, cbb_h, true)
        end

        table.insert(book_info_group, ImageWidget:new{
            image = cover,
            width = cbb_w,
            height = cbb_h,
        })
        -- dereference thumbnail since we let imagewidget manages its lifecycle
        cover = nil
    end

    table.insert(book_info_group, CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        book_meta_info_group,
    })

    return CenterContainer:new{
        dimen = Geom:new{ w = screen_width, h = img_height },
        book_info_group,
    }

end

function HomePageWidget:onClose()
    UIManager:close(self)
    return true
end


return HomePageWidget
