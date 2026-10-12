FreeFlightCameraMenu = FreeFlightCameraMenu or class(BLTMenu)

function FreeFlightCameraMenu:Init(root)
    self:AutoBindNamedControlsBegin()

    self:Toggle({
        name = "hide_outlines",
        text = "menu_ffc_hide_outlines",
        value = FreeFlightCamera.settings.hide_outlines,
        callback = callback(self, self, "hide_outlines"),
        desc = "menu_ffc_hide_outlines_desc",
        auto_select_on_hover = true
    })
    self:Toggle({
        name = "allow_client_freecam",
        text = "menu_ffc_allow_client_freecam",
        value = FreeFlightCamera.settings.allow_client_freecam,
        callback = callback(self, self, "allow_client_freecam"),
        desc = "menu_ffc_allow_client_freecam_desc",
        auto_select_on_hover = true
    })
    self:Toggle({
        name = "announce_freecam_possible",
        text = "menu_ffc_announce_freecam_possible",
        value = FreeFlightCamera.settings.announce_freecam_possible,
        callback = callback(self, self, "announce_freecam_possible"),
        desc = "menu_ffc_announce_freecam_possible_desc",
        auto_select_on_hover = true
    })
    self:Slider({
        name = "gui_text_on_screen_time",
        text = "menu_ffc_gui_text_on_screen_time",
        value = FreeFlightCamera.settings.gui_text_on_screen_time,
        min = 1,
        max = 10,
        value_format = "%.1f",
        callback = callback(self, self, "gui_text_on_screen_time"),
        desc = "menu_ffc_gui_text_on_screen_time_desc",
        auto_select_on_hover = true
    })

    self:AutoBindNamedControlsEnd()
end

function FreeFlightCameraMenu:Close()
    FreeFlightCamera:Save()
end

function FreeFlightCameraMenu:hide_outlines(value)
    FreeFlightCamera.settings.hide_outlines = value
    FreeFlightCamera:set_outlines(value)
end

function FreeFlightCameraMenu:allow_client_freecam(value)
    FreeFlightCamera.settings.allow_client_freecam = value

    -- clients only learn about this on join otherwise
    if FreeFlightCamera.Sync then
        FreeFlightCamera.Sync:send_state()
    end
end

function FreeFlightCameraMenu:announce_freecam_possible(value)
    FreeFlightCamera.settings.announce_freecam_possible = value
end

function FreeFlightCameraMenu:gui_text_on_screen_time(value)
    FreeFlightCamera.settings.gui_text_on_screen_time = value
end

Hooks:Add("MenuComponentManagerInitialize", "FreeFlightCamera.MenuComponentManagerInitialize", function(self)
	RaidMenuHelper:CreateMenu({
		name = "FreeFlightCamera_options",
		name_id = "menu_ffc_title",
		inject_list = "blt_options",
        icon = "menu_item_video",
		class = FreeFlightCameraMenu
	})
end)