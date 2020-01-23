local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
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
local RightContainer = require("ui/widget/container/rightcontainer")
local RowCoverWidget = require("ui/widget/rowcoverwidget")
local Size = require("ui/size")
local TabPanelWidget = require("ui/widget/tabpanelwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Screen = Device.screen
local T = require("ffi/util").template
local _ = require("gettext")
local logger = require("logger")

local HomePageWidget = InputContainer:new {
    width = nil,
    height = nil,
}

local top_icon_set = {
    {
        icon = "resources/icons/menu-icon.png",
        callback = function() end,
    },
    {
        icon = "resources/icons/appbar.cabinet.files.png",
        callback = function(instance)
            UIManager:nextTick(function()
                instance:onClose()
            end)
        end,
    },
    {
        --https://materialdesignicons.com/
        icon = "resources/icons/history.png",
        callback = function()
            local FileManagerHistory = require("apps/filemanager/filemanagerhistory")
            FileManagerHistory:onShowHist()
            -- update panel with history
        end,
    },
    {
        -- favorites
        --https://github.com/encharm/Font-Awesome-SVG-PNG/blob/master/black/png/64/star-o.png
        --https://materialdesignicons.com/
        icon = "resources/icons/star.png",
        callback = function()
            local FileManagerCollection = require("apps/filemanager/filemanagercollection")
            FileManagerCollection:onShowColl("favorites")
            -- update panel with favorites
        end,
    },
    {
        -- frontlight
        --http://modernuiicons.com/
        icon = "resources/icons/sunny.png",
        callback = function(instance)
            local is_docless = instance.ui == nil or instance.ui.document == nil
            if is_docless then
                local ReaderFrontLight = require("apps/reader/modules/readerfrontlight")
                ReaderFrontLight:onShowFlDialog()
            else
                instance.ui:handleEvent(Event:new("ShowFlDialog"))
            end
        end,
    },
}

function HomePageWidget:init()
    -- to update
    self.selected_panel = 2
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

    local icon_widgets = HorizontalGroup:new{}
    local icon_size = Screen:scaleBySize(40)

    local spacing_width = 16
    local size = #top_icon_set * icon_size

    local icon_padding = math.floor((Screen:getWidth() - size) / (2* #top_icon_set))

    --local icon_padding = math.min(spacing_width, Screen:scaleBySize(16))
    for _, v in ipairs(top_icon_set) do
        local ib = IconButton:new{
            show_parent = self.show_parent,
            icon_file = v.icon,
            width = icon_size,
            height = icon_size,
            scale_for_dpi = false,
            callback = function() v.callback(self) end,
            padding_top = 10,
            padding_bottom = 10,
            padding_left = icon_padding,
            padding_right = icon_padding,
            --menu = self.menu,
        }
        table.insert(icon_widgets, ib)
    end

    local header_line = LineWidget:new{
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        dimen = Geom:new{
            w = self.width,
            h = Size.line.thick,
        }
    }

    self.pages = 1 --math.ceil(#self.kv_pairs / self.items_per_page)
    self.main_content = VerticalGroup:new {}

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

    local tab_panel = TabPanelWidget:new{
        height = self.height * 0.15,
        width = self.width,
        select = self.selected_panel,
        tabs = {
            {
                text = "History",
                callback = function()
                    self:updatePanel(1)
                end
            },
            {
                text = "Favorites",
                callback = function()
                    self:updatePanel(2)
                end
            },
            {
                text = "Statistics"
            },
        },
        show_parent = self
    }

    local vertical_span = VerticalSpan:new{ width = self.height * 0.04 }

    local text_footer = TextWidget:new{
        text = self:buildFooterText(),
        face = Font:getFace("ffont", 16),
    }

    local footer_text_container =  RightContainer:new{
        dimen = Geom:new{w = self.width * 0.95, h = text_footer:getSize().h},
        text_footer
    }

    local top_vertical = VerticalGroup:new{
        icon_widgets,
        header_line
    }

    local top_icon_contener = TopContainer:new{
        dimen = Geom:new{ w = self.width, h = top_vertical:getSize().h  },
        top_vertical
    }

    logger.info("#######################################")
    logger.info(top_icon_contener:getSize())
    logger.info(top_vertical:getSize())

    self.content_panel = FrameContainer:new{
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
    }

    self:updatePanel(self.selected_panel, true)

    local center_page_container = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height * 0.85  },
        VerticalGroup:new{
            now_reading,
            self:showLastBook(),
            vertical_span,
            tab_panel,
            self.content_panel,
        }
    }

    local footer_container = BottomContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height * 0.05 },
        VerticalGroup:new{
            header_line,
            footer_text_container
        }
    }

    local content = VerticalGroup:new{
        top_icon_contener,
        center_page_container,
        footer_container,
    }

    -- assemble page
    self[1] = FrameContainer:new {
        height = self.height,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        content
    }
end

function HomePageWidget:buildFooterText()
    local time_info_txt = ""

    if Device:hasFrontlight() then
        local frontlight_icon = "☼"

        local powerd = Device:getPowerDevice()
        if powerd:isFrontlightOn() then
            if Device:isCervantes() or Device:isKobo() then
                time_info_txt = (frontlight_icon .. "%d%%"):format(powerd:frontlightIntensity())
            else
                time_info_txt = (frontlight_icon .. "%d"):format(powerd:frontlightIntensity())
            end
        else
            time_info_txt = T(_("%1 Off"), frontlight_icon)
        end
    end

    if G_reader_settings:nilOrTrue("twelve_hour_clock") then
        time_info_txt = time_info_txt .. " " .. os.date("⌚ %I:%M %p")
    else
        time_info_txt = time_info_txt .. " " .. os.date("⌚ %H:%M")
    end
    local powerd = Device:getPowerDevice()
    local batt_lvl = powerd:getCapacity()
    local batt_symbol
    if powerd:isCharging() then
        batt_symbol = ""
    else
        if batt_lvl >= 100 then
            batt_symbol = ""
        elseif batt_lvl >= 90 then
            batt_symbol = ""
        elseif batt_lvl >= 80 then
            batt_symbol = ""
        elseif batt_lvl >= 70 then
            batt_symbol = ""
        elseif batt_lvl >= 60 then
            batt_symbol = ""
        elseif batt_lvl >= 50 then
            batt_symbol = ""
        elseif batt_lvl >= 40 then
            batt_symbol = ""
        elseif batt_lvl >= 30 then
            batt_symbol = ""
        elseif batt_lvl >= 20 then
            batt_symbol = ""
        elseif batt_lvl >= 10 then
            batt_symbol = ""
        else
            batt_symbol = ""
        end
    end
    time_info_txt = BD.wrap(time_info_txt) .. " " .. BD.wrap("⌁") .. BD.wrap(batt_symbol) ..  BD.wrap(batt_lvl .. "%")
    return time_info_txt
end

function HomePageWidget:showLastBook(max_height)
    local last_file = G_reader_settings:readSetting("lastfile")
    self.small_font_face = Font:getFace("smallffont")
    self.medium_font_face = Font:getFace("ffont")

    local cover_book
    local book_props

    local doc_settings = DocSettings:open(last_file)
    if doc_settings then
        if not book_props then
            -- Files opened after 20170701 have a 'doc_props' setting with
            -- complete metadata and 'doc_pages' with accurate nb of pages
            book_props = doc_settings:readSetting('doc_props')
        end
        if not book_props then
            -- File last opened before 20170701 may have a 'stats' setting
            -- with partial metadata, or empty metadata if statistics plugin
            -- was not enabled when book was read (we can guess that from
            -- the fact that stats.page = 0)
            local stats = doc_settings:readSetting('stats')
            if stats and stats.pages ~= 0 then
                -- Let's use them as is (which was what was done before), even if
                -- incomplete, to avoid expensive book opening
                book_props = stats
            end
        end
        -- Files opened after 20170701 have an accurate 'doc_pages' setting
        local doc_pages = doc_settings:readSetting('doc_pages')

        if doc_pages and book_props then
            book_props.pages = doc_pages
        end

        local percent_finished = doc_settings:readSetting('percent_finished')
        book_props.percent_finished = percent_finished
    end

    local document = DocumentRegistry:openDocument(last_file)
    if document then
        if document.loadDocument then
            -- CreDocument
            document:loadDocument(false) -- load only metadata
        end
        cover_book = document:getCoverPageImage()
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

    -- author
    local book_author = TextBoxWidget:new{
        text = book_props.authors,
        face = self.small_font_face,
        width = width,
        alignment = "center",
    }
    -- title
    local book_title =  TextBoxWidget:new{
        text = book_props.title,
        width = width,
        face = self.medium_font_face,
        bold = true,
        alignment = "center",
    }

    local span_title_read = VerticalSpan:new{ width = height * 0.1 }

    local current_page = Math.round(book_props.percent_finished * book_props.pages)
    local percent = Math.round(book_props.percent_finished * 100)

    local book_read =  TextBoxWidget:new{
        text = T(_("Read: %1/%2 (%3%)"), current_page, book_props.pages, percent),
        width = width,
        face = self.small_font_face,
        alignment = "center",
    }

    local progress_line = ProgressWidget:new{
        width = self.width * 0.4,
        height = nil,
        percentage = book_props.percent_finished,
    }
    progress_line:updateStyle(false, 3)

    local book_info = VerticalGroup:new{
        align = "center",
        book_author,
        book_title,
        span_title_read,
        book_read,
        progress_line,
    }

    -- cover
    local cover_image
    if cover_book then
        -- Much like BookInfoManager, honor AR here
        local cbb_w, cbb_h = cover_book:getWidth(), cover_book:getHeight()
        if cbb_w > img_width or cbb_h > img_height then
            local scale_factor = math.min(img_width / cbb_w, img_height / cbb_h)
            cbb_w = math.min(math.floor(cbb_w * scale_factor)+1, img_width)
            cbb_h = math.min(math.floor(cbb_h * scale_factor)+1, img_height)
            cover_book = RenderImage:scaleBlitBuffer(cover_book, cbb_w, cbb_h, true)
        end
        cover_image = ImageWidget:new{
            image = cover_book,
            width = cbb_w,
            height = cbb_h,
        }
        -- dereference thumbnail since we let imagewidget manages its lifecycle
        cover_book = nil
    end

    local book_info_group = HorizontalGroup:new{
        cover_image,
        book_info,
    }

    return CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = img_height },
        book_info_group,
    }

end

function HomePageWidget:showHistoryPanel()
    local hist = require("readhistory").hist
    local last_history = {}
    for i = 2, 4 do
        table.insert(last_history, { file = hist[i].file })
    end
    return RowCoverWidget:new{
        height = self.height * 0.38,
        width = self.width,
        elements = last_history,
        show_parent = self
    }
end

function HomePageWidget:showFavoritesPanel()
    local coll = require("readcollection"):read()
    local last_collection = {}
    for i = 1, 3 do
        table.insert(last_collection, { file = coll[i].file })
    end
    return RowCoverWidget:new{
        height = self.height * 0.38,
        width = self.width,
        elements = last_collection,
        show_parent = self
    }
end

function HomePageWidget:updatePanel(id, force)
    if force or self.selected_panel ~= id then
        if id == 1 then
            self.content_panel[1] = self:showHistoryPanel()
        elseif id == 2 then
            self.content_panel[1] = self:showFavoritesPanel()
        end
        self.selected_panel = id
    end
end

function HomePageWidget:onClose()
    UIManager:close(self)
    return true
end


return HomePageWidget
