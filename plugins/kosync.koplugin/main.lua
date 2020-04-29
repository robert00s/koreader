local InputContainer = require("ui/widget/container/inputcontainer")
local LoginDialog = require("ui/widget/logindialog")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local DeviceModel = require("device").model
local Event = require("ui/event")
local Math = require("optmath")
local DEBUG = require("dbg")
local T = require("ffi/util").template
local _ = require("gettext")
local md5 = require("ffi/MD5")
local random = require("random")

if not G_reader_settings:readSetting("device_id") then
    G_reader_settings:saveSetting("device_id", random.uuid())
end

-- DAUTO_SAVE_PAGING_COUNT was set to nil in defaults.lua, but
-- could be overriden in defaults.persistent.lua with a value
-- that was also used here as the interval for auto sync.
-- DAUTO_SAVE_PAGING_COUNT has been removed, but let's allow
-- this plugin to still pick it from defaults.persistent.lua.
--- @todo make this tunable via an added menu item below
local SYNC_PAGING_COUNT = DAUTO_SAVE_PAGING_COUNT -- luacheck: ignore

local KOSync = InputContainer:new{
    name = "kosync",
    is_doc_only = true,
    title = _("Register/login to KOReader server"),

    page_update_times = 0,
    last_page = -1,
    last_page_turn_ticks = 0,
}

local SYNC_STRATEGY = {
    -- Forward and backward whisper sync settings are using different
    -- default value, so none of following opinions should be zero.
    PROMPT = 1,
    WHISPER = 2,
    DISABLE = 3,

    DEFAULT_FORWARD = 1,
    DEFAULT_BACKWARD = 3,
}

local function getNameStrategy(type)
    if type == 1 then
        return _("Prompt")
    elseif type == 2 then
        return _("Auto")
    else
        return _("Disable")
    end
end

local function showSyncedMessage()
    UIManager:show(InfoMessage:new{
        text = _("Progress has been synchronized."),
        timeout = 3,
    })
end

local function promptLogin()
    UIManager:show(InfoMessage:new{
        text = _("Please register or login before using the progress synchronization feature."),
        timeout = 3,
    })
end

local function showSyncError()
    UIManager:show(InfoMessage:new{
        text = _("Something went wrong when syncing progress, please check your network connection and try again later."),
        timeout = 3,
    })
end

local function validate(entry)
    if not entry then return false end
    if type(entry) == "string" then
        if entry == "" or not entry:match("%S") then return false end
    end
    return true
end

local function validateUser(user, pass)
    local error_message = nil
    local user_ok = validate(user)
    local pass_ok = validate(pass)
    if not user_ok and not pass_ok then
        error_message = _("invalid username and password")
    elseif not user_ok then
        error_message = _("invalid username")
    elseif not pass_ok then
        error_message = _("invalid password")
    end

    if not error_message then
        return user_ok and pass_ok
    else
        return user_ok and pass_ok, error_message
    end
end

function KOSync:init()
    local ReaderGesture = require("apps/reader/modules/readergesture")
    ReaderGesture.KOSyncPushProgress = function()
        if not self.kosync_userkey then return end
        self:updateProgress(true)
    end
    ReaderGesture.KOSyncPullProgress = function()
        if not self.kosync_userkey then return end
        self:getProgress(true)
    end
end

function KOSync:onReaderReady()
    local settings = G_reader_settings:readSetting("kosync") or {}
    self.kosync_custom_server = settings.custom_server
    self.kosync_username = settings.username
    self.kosync_userkey = settings.userkey
    self.kosync_auto_sync = not (settings.auto_sync == false)
    self.kosync_whisper_forward = settings.whisper_forward or SYNC_STRATEGY.DEFAULT_FORWARD
    self.kosync_whisper_backward = settings.whisper_backward or SYNC_STRATEGY.DEFAULT_BACKWARD
    self.kosync_device_id = G_reader_settings:readSetting("device_id")
    --assert(self.kosync_device_id)
    if self.kosync_auto_sync then
        self:_onResume()
    end
    self:registerEvents()
    self.ui.menu:registerToMainMenu(self)
    -- Make sure checksum has been calculated at the very first time a document has been opened, to
    -- avoid document saving feature to impact the checksum, and eventually impact the document
    -- identity in the progress sync feature.
    self.view.document:fastDigest(self.ui.doc_settings)
end

function KOSync:addToMainMenu(menu_items)
    menu_items.progress_sync = {
        text = _("Progress sync"),
        sub_item_table = {
            {
                text_func = function()
                    return self.kosync_userkey and (_("Logout"))
                        or _("Register") .. " / " .. _("Login")
                end,
                keep_menu_open = true,
                callback_func = function()
                    if self.kosync_userkey then
                        return function(menu)
                            self._menu_to_update = menu
                            self:logout()
                        end
                    else
                        return function(menu)
                            self._menu_to_update = menu
                            self:login()
                        end
                    end
                end,
            },
            {
                text = _("Auto sync now and future"),
                checked_func = function() return self.kosync_auto_sync end,
                callback = function()
                    self.kosync_auto_sync = not self.kosync_auto_sync
                    self:registerEvents()
                    if self.kosync_auto_sync then
                        -- since we will update the progress when closing document, we should pull
                        -- current progress now to avoid to overwrite it silently.
                        self:getProgress(true)
                    else
                        -- since we won't update the progress when closing document, we should push
                        -- current progress now to avoid to lose it silently.
                        self:updateProgress(true)
                    end
                end,
            },
            {
                text = _("Whisper sync"),
                enabled_func = function() return self.kosync_auto_sync end,
                sub_item_table = {
                    {
                        text_func = function()
                            return T(_("Sync to latest record (%1)"), getNameStrategy(self.kosync_whisper_forward))
                        end,
                        sub_item_table = {
                            {
                                text = _("Auto"),
                                checked_func = function()
                                    return self.kosync_whisper_forward == SYNC_STRATEGY.WHISPER
                                end,
                                callback = function()
                                    self:setWhisperForward(SYNC_STRATEGY.WHISPER)
                                end,
                            },
                            {
                                text = _("Prompt"),
                                checked_func = function()
                                    return self.kosync_whisper_forward == SYNC_STRATEGY.PROMPT
                                end,
                                callback = function()
                                    self:setWhisperForward(SYNC_STRATEGY.PROMPT)
                                end,
                            },
                            {
                                text = _("Disable"),
                                checked_func = function()
                                    return self.kosync_whisper_forward == SYNC_STRATEGY.DISABLE
                                end,
                                callback = function()
                                    self:setWhisperForward(SYNC_STRATEGY.DISABLE)
                                end,
                            },
                        }
                    },
                    {
                        text_func = function()
                            return T(_("Sync to a previous record (%1)"), getNameStrategy(self.kosync_whisper_backward))
                        end,
                        sub_item_table = {
                            {
                                text = _("Auto"),
                                checked_func = function()
                                    return self.kosync_whisper_backward == SYNC_STRATEGY.WHISPER
                                end,
                                callback = function()
                                    self:setWhisperBackward(SYNC_STRATEGY.WHISPER)
                                end,
                            },
                            {
                                text = _("Prompt"),
                                checked_func = function()
                                    return self.kosync_whisper_backward == SYNC_STRATEGY.PROMPT
                                end,
                                callback = function()
                                    self:setWhisperBackward(SYNC_STRATEGY.PROMPT)
                                end,
                            },
                            {
                                text = _("Disable"),
                                checked_func = function()
                                    return self.kosync_whisper_backward == SYNC_STRATEGY.DISABLE
                                end,
                                callback = function()
                                    self:setWhisperBackward(SYNC_STRATEGY.DISABLE)
                                end,
                            },
                        }
                    },
                },
            },
            {
                text = _("Push progress from this device"),
                enabled_func = function()
                    return self.kosync_userkey ~= nil
                end,
                callback = function()
                    self:updateProgress(true)
                end,
            },
            {
                text = _("Pull progress from other devices"),
                enabled_func = function()
                    return self.kosync_userkey ~= nil
                end,
                callback = function()
                    self:getProgress(true)
                end,
            },
            {
                text = _("Custom sync server"),
                keep_menu_open = true,
                tap_input_func = function()
                    return {
                        -- @translators Server address defined by user for progress sync.
                        title = _("Custom progress sync server address"),
                        input = self.kosync_custom_server or "https://",
                        type = "text",
                        callback = function(input)
                            self:setCustomServer(input)
                        end,
                    }
                end,
            },
        }
    }
end

function KOSync:setCustomServer(server)
    DEBUG("set custom server", server)
    self.kosync_custom_server = server ~= "" and server or nil
    self:saveSettings()
end

function KOSync:setWhisperForward(strategy)
    self.kosync_whisper_forward = strategy
    self:saveSettings()
end

function KOSync:setWhisperBackward(strategy)
    self.kosync_whisper_backward = strategy
    self:saveSettings()
end

function KOSync:login()
    if not NetworkMgr:isOnline() then
        NetworkMgr:promptWifiOn()
        return
    end
    self.login_dialog = LoginDialog:new{
        title = self.title,
        username = self.kosync_username or "",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    enabled = true,
                    callback = function()
                        self:closeDialog()
                    end,
                },
                {
                    text = _("Login"),
                    enabled = true,
                    callback = function()
                        local username, password = self:getCredential()
                        local ok, err = validateUser(username, password)
                        if not ok then
                            UIManager:show(InfoMessage:new{
                                text = T(_("Cannot login: %1"), err),
                                timeout = 2,
                            })
                        else
                            self:closeDialog()
                            UIManager:scheduleIn(0.5, function()
                                self:doLogin(username, password)
                            end)

                            UIManager:show(InfoMessage:new{
                                text = _("Logging in. Please wait…"),
                                timeout = 1,
                            })
                        end
                    end,
                },
                {
                    text = _("Register"),
                    enabled = true,
                    callback = function()
                        local username, password = self:getCredential()
                        local ok, err = validateUser(username, password)
                        if not ok then
                            UIManager:show(InfoMessage:new{
                                text = T(_("Cannot register: %1"), err),
                                timeout = 2,
                            })
                        else
                            self:closeDialog()
                            UIManager:scheduleIn(0.5, function()
                                self:doRegister(username, password)
                            end)

                            UIManager:show(InfoMessage:new{
                                text = _("Registering. Please wait…"),
                                timeout = 1,
                            })
                        end
                    end,
                },
            },
        },
        width = Screen:getWidth() * 0.8,
        height = Screen:getHeight() * 0.4,
    }

    UIManager:show(self.login_dialog)
    self.login_dialog:onShowKeyboard()
end

function KOSync:closeDialog()
    self.login_dialog:onClose()
    UIManager:close(self.login_dialog)
end

function KOSync:getCredential()
    return self.login_dialog:getCredential()
end

function KOSync:doRegister(username, password)
    local KOSyncClient = require("KOSyncClient")
    local client = KOSyncClient:new{
        custom_url = self.kosync_custom_server,
        service_spec = self.path .. "/api.json"
    }
    local userkey = md5.sum(password)
    local ok, status, body = pcall(client.register, client, username, userkey)
    if not ok then
        if status then
            UIManager:show(InfoMessage:new{
                text = _("An error occurred while registering:") ..
                    "\n" .. status,
            })
        else
            UIManager:show(InfoMessage:new{
                text = _("An unknown error occurred while registering."),
            })
        end
    elseif status then
        self.kosync_username = username
        self.kosync_userkey = userkey
        self._menu_to_update:updateItems()
        UIManager:show(InfoMessage:new{
            text = _("Registered to KOReader server."),
        })
    else
        UIManager:show(InfoMessage:new{
            text = body and body.message or _("Unknown server error"),
        })
    end

    self:saveSettings()
end

function KOSync:doLogin(username, password)
    local KOSyncClient = require("KOSyncClient")
    local client = KOSyncClient:new{
        custom_url = self.kosync_custom_server,
        service_spec = self.path .. "/api.json"
    }
    local userkey = md5.sum(password)
    local ok, status, body = pcall(client.authorize, client, username, userkey)
    if not ok then
        if status then
            UIManager:show(InfoMessage:new{
                text = _("An error occurred while logging in:") ..
                    "\n" .. status,
            })
        else
            UIManager:show(InfoMessage:new{
                text = _("An unknown error occurred while logging in."),
            })
        end
        return
    elseif status then
        self.kosync_username = username
        self.kosync_userkey = userkey
        self._menu_to_update:updateItems()
        UIManager:show(InfoMessage:new{
            text = _("Logged in to KOReader server."),
        })
    else
        UIManager:show(InfoMessage:new{
            text = body and body.message or _("Unknown server error"),
        })
    end

    self:saveSettings()
end

function KOSync:logout()
    self.kosync_userkey = nil
    self.kosync_auto_sync = true
    self._menu_to_update:updateItems()
    self:saveSettings()
end

function KOSync:getLastPercent()
    if self.ui.document.info.has_pages then
        return Math.roundPercent(self.ui.paging:getLastPercent())
    else
        return Math.roundPercent(self.ui.rolling:getLastPercent())
    end
end

function KOSync:getLastProgress()
    if self.ui.document.info.has_pages then
        return self.ui.paging:getLastProgress()
    else
        return self.ui.rolling:getLastProgress()
    end
end

function KOSync:syncToProgress(progress)
    DEBUG("sync to", progress)
    if self.ui.document.info.has_pages then
        self.ui:handleEvent(Event:new("GotoPage", tonumber(progress)))
    else
        self.ui:handleEvent(Event:new("GotoXPointer", progress))
    end
end

function KOSync:updateProgress(manual)
    if not self.kosync_username or not self.kosync_userkey then
        if manual then
            promptLogin()
        end
        return
    end

    local KOSyncClient = require("KOSyncClient")
    local client = KOSyncClient:new{
        custom_url = self.kosync_custom_server,
        service_spec = self.path .. "/api.json"
    }
    local doc_digest = self.view.document:fastDigest()
    local progress = self:getLastProgress()
    local percentage = self:getLastPercent()
    local ok, err = pcall(client.update_progress,
        client,
        self.kosync_username,
        self.kosync_userkey,
        doc_digest,
        progress,
        percentage,
        DeviceModel,
        self.kosync_device_id,
        function(ok, body)
            DEBUG("update progress for", self.view.document.file, ok)
            if manual then
                if ok then
                    UIManager:show(InfoMessage:new{
                        text = _("Progress has been pushed."),
                        timeout = 3,
                    })
                else
                    showSyncError()
                end
            end
        end)
    if not ok then
        if manual then showSyncError() end
        if err then DEBUG("err:", err) end
    end
end

function KOSync:getProgress(manual)
    if not self.kosync_username or not self.kosync_userkey then
        if manual then
            promptLogin()
        end
        return
    end

    local KOSyncClient = require("KOSyncClient")
    local client = KOSyncClient:new{
        custom_url = self.kosync_custom_server,
        service_spec = self.path .. "/api.json"
    }
    local doc_digest = self.view.document:fastDigest()
    local ok, err = pcall(client.get_progress,
        client,
        self.kosync_username,
        self.kosync_userkey,
        doc_digest,
        function(ok, body)
            DEBUG("get progress for", self.view.document.file, ok, body)
            if not ok or not body then
                if manual then
                    showSyncError()
                end
                return
            end

            if not body.percentage then
                if manual then
                    UIManager:show(InfoMessage:new{
                        text = _("No progress found for this document."),
                        timeout = 3,
                    })
                end
                return
            end

            if body.device == DeviceModel
            and body.device_id == self.kosync_device_id then
                if manual then
                    UIManager:show(InfoMessage:new{
                        text = _("Latest progress is coming from this device."),
                        timeout = 3,
                    })
                end
                return
            end

            body.percentage = Math.roundPercent(body.percentage)
            local progress = self:getLastProgress()
            local percentage = self:getLastPercent()
            DEBUG("current progress", percentage)

            if percentage == body.percentage
            or body.progress == progress then
                if manual then
                    UIManager:show(InfoMessage:new{
                        text = _("The progress has already been synchronized."),
                        timeout = 3,
                    })
                end
                return
            end

            -- The progress needs to be updated.
            if manual then
                -- If user actively pulls progress from other devices, we always update the
                -- progress without further confirmation.
                self:syncToProgress(body.progress)
                showSyncedMessage()
                return
            end

            local self_older
            if body.timestamp ~= nil then
                self_older = (body.timestamp > self.last_page_turn_ticks)
            else
                -- If we are working with old sync server, we can only use
                -- percentage field.
                self_older = (body.percentage > percentage)
            end
            if self_older then
                if self.kosync_whisper_forward == SYNC_STRATEGY.WHISPER then
                    self:syncToProgress(body.progress)
                    showSyncedMessage()
                elseif self.kosync_whisper_forward == SYNC_STRATEGY.PROMPT then
                    UIManager:show(ConfirmBox:new{
                        text = T(_("Sync to latest location %1% from device '%2'?"),
                                 Math.round(body.percentage * 100),
                                 body.device),
                        ok_callback = function()
                            self:syncToProgress(body.progress)
                        end,
                    })
                end
            else -- if not self_older then
                if self.kosync_whisper_backward == SYNC_STRATEGY.WHISPER then
                    self:syncToProgress(body.progress)
                    showSyncedMessage()
                elseif self.kosync_whisper_backward == SYNC_STRATEGY.PROMPT then
                    UIManager:show(ConfirmBox:new{
                        text = T(_("Sync to previous location %1% from device '%2'?"),
                                 Math.round(body.percentage * 100),
                                 body.device),
                        ok_callback = function()
                            self:syncToProgress(body.progress)
                        end,
                    })
                end
            end
        end)
    if not ok then
        if manual then showSyncError() end
        if err then DEBUG("err:", err) end
    end
end

function KOSync:saveSettings()
    local settings = {
        custom_server = self.kosync_custom_server,
        username = self.kosync_username,
        userkey = self.kosync_userkey,
        auto_sync = self.kosync_auto_sync,
        whisper_forward =
              (self.kosync_whisper_forward == SYNC_STRATEGY.DEFAULT_FORWARD
               and nil
               or self.kosync_whisper_forward),
        whisper_backward =
              (self.kosync_whisper_backward == SYNC_STRATEGY.DEFAULT_BACKWARD
               and nil
               or self.kosync_whisper_backward),
    }
    G_reader_settings:saveSetting("kosync", settings)
end

function KOSync:onCloseDocument()
    DEBUG("on close document")
    if self.kosync_auto_sync then
        self:updateProgress()
    end
end

function KOSync:_onPageUpdate(page)
    if page == nil then
        return
    end

    if self.last_page == -1 then
        self.last_page = page
    elseif self.last_page ~= page then
        self.last_page = page
        self.last_page_turn_ticks = os.time()
        self.page_update_times = self.page_update_times + 1
        if SYNC_PAGING_COUNT ~= nil
        and (SYNC_PAGING_COUNT <= 0
             or self.page_update_times == SYNC_PAGING_COUNT) then
            self.page_update_times = 0
            UIManager:scheduleIn(1, function() self:updateProgress() end)
        end
    end
end

function KOSync:_onResume()
    UIManager:scheduleIn(1, function() self:getProgress() end)
end

function KOSync:_onFlushSettings()
    if self.ui == nil or self.ui.document == nil then return end
    self:updateProgress()
end

function KOSync:_onNetworkConnected()
    self:_onResume()
end

function KOSync:registerEvents()
    if self.kosync_auto_sync then
        self.onPageUpdate = self._onPageUpdate
        self.onResume = self._onResume
        self.onFlushSettings = self._onFlushSettings
        self.onNetworkConnected = self._onNetworkConnected
    else
        self.onPageUpdate = nil
        self.onResume = nil
        self.onFlushSettings = nil
        self.onNetworkConnected = nil
    end
end

return KOSync
