local gears = require("gears") -- Unused local gears
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local wibox = require("wibox")
local math = require("math")
local dpi = require("beautiful.xresources").apply_dpi

--- Cached objects
local wbox
local title_widget
local layout_widgets
local num_columns = 3

local hidden = {}

local function debug_print(str)
	naughty.notify({
		preset = naughty.config.presets.normal,
		title = "Debug",
		text = str,
	})
end

local function print_error(str)
	naughty.notify({
		preset = naughty.config.presets.critical,
		title = "Error",
		text = str,
	})
end

local function key_to_string(mod, key)
	if key == " " then
		key = "space"
	end

	local mod_copy = {}
	for _, modifier in ipairs(mod) do
		table.insert(mod_copy, modifier)
	end

	table.sort(mod_copy)

	if #mod_copy > 0 then
		key = table.concat(mod_copy, "-") .. "-" .. key
	end
	-- to lower case
	key = key:lower()
	return key
end

local function colorize(text, fg, bg)
	if fg == nil then
		fg = ""
	else
		fg = ' foreground="' .. fg .. '"'
	end
	if bg == nil then
		bg = ""
	else
		bg = ' background="' .. bg .. '"'
	end
	return "<span" .. fg .. bg .. ">" .. text .. "</span>"
end

local function bold(text)
	return "<b>" .. text .. "</b>"
end

local function escape_markup(text)
	return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local hc = {}
hc.cc = {
	green = 1,
	red = 2,
}

local isin = function(item, t)
	local result = false
	for _, v in ipairs(t) do
		if v == item then
			result = true
			break
		end
	end
	return result
end

local function mk_grabber_func(spec, update_ui, stop)
	local hydra_color = spec.hydra_color

	if hydra_color == hc.cc.green then -- ___{{{ GREEN }}} ~~~~~~~~~~~ Hydra handler
		return function(mod, key, event)
			if event == "release" then
				if key == spec.activation_key then
					stop()
				end
				return
			end

			local mod_copy = {}
			for _, modifier in ipairs(mod) do
				if modifier ~= "Mod2" and not (spec.ignored_keet and isin(modifier, spec.ignored_keet)) then
					table.insert(mod_copy, modifier)
				end
			end
			mod = mod_copy

			local key_string = key_to_string(mod, key)
			-- debug_print("grabber: mod: " .. table.concat(mod, ',')
			--     .. ", key: " .. tostring(key)
			--     .. ", event: " .. tostring(event)
			--     .. ", key_string: " .. key_string)

			local child = spec.current_key_table[key_string]
			if child then
				local description = child[1]
				child = child[2]
				if type(child) == "function" then
					local status, err = pcall(child)
					if not status then
						print_error("Error: " .. err)
					end
					spec.focused_key = key_string
					update_ui()
				else
					table.insert(spec.breadcrumbs, { key, description })
					spec.current_key_table = child
					spec.focused_key = nil
					update_ui()
				end
			end
		end
	elseif hydra_color == hc.cc.red then -- ___{{{ RED }}} ~~~~~~~~~~~ Hydra handler
		return function(mod, key, event)
			if event == "release" then
			end

			local mod_copy = {}
			for _, modifier in ipairs(mod) do
				if modifier ~= "Mod2" and not (spec.ignored_keet and isin(modifier, spec.ignored_keet)) then
					table.insert(mod_copy, modifier)
				end
			end
			mod = mod_copy

			local key_string = key_to_string(mod, key)
			local child = spec.current_key_table[key_string]
			local valid_shift = {
				Super_R = true,
				Super_L = true,
				Control_R = true,
				Control_L = true,
				Shift_R = true,
				Shift_L = true,
			}
			if spec.activation_key then
				valid_shift[spec.activation_key] = true
			end
			if not child then
				if not valid_shift[key] then
					stop()
					return
				end
			else
				local description = child[1]
				local maybe_color = child.hc or child.color
				child = child[2]
				if type(child) == "function" then
					local slay = false
					local status, err = pcall(child)
					if not status then
						debug_print("Error: " .. err)
					end
					spec.focused_key = key_string
					-- spec.activation_key = key
					update_ui()
					if maybe_color and maybe_color == "blue" then
						stop()
						return
					end
				else
					table.insert(spec.breadcrumbs, { key, description })
					spec.current_key_table = child
					spec.focused_key = nil
					spec.activation_key = key
					update_ui()
				end
			end
		end
	else
		error("Invalid hydra_color. Unreachable state.")
	end
end

local function start(args)
	local spec = {}
	do
		local config = args.config
		if not config then
			error("config not given")
		end
		local hcol = args.color
		spec.hydra_color = hcol and hc.cc[hcol] and hc.cc[hcol] or hc.cc.green
		spec.current_key_table = config
	end
	spec.breadcrumbs = {}
	spec.focused_key = nil
	spec.activation_key = args.activation_key
	if not spec.activation_key then
		error("activation_key not given")
	end
	if args.ignored_mod then
		spec.ignored_keet = {}
		if type(args.ignored_mod) == "table" then
			for _, mod in ipairs(args.ignored_mod) do
				spec.ignored_keet[#spec.ignored_keet + 1] = mod
			end
		else
			spec.ignored_keet[#spec.ignored_keet + 1] = args.ignored_mod
		end
	end
	local hide_first_level = args.hide_first_level or false
	local key_fg = args.key_fg or beautiful.fg_normal
	local key_bg = args.key_bg or "#eeeeee"
	local key_control_fg = args.key_control_fg or "#00bb00"
	local key_shift_fg = args.key_shift_fg or "#4488ff"
	local key_modifier_fg = args.key_modifier_fg or "#aa4444"
	local activation_fg = args.activation_fg or "#44aaff"
	local nested_fg = args.nested_fg or "#4488aa"
	local nested_bg = args.nested_bg or nil
	local focused_fg = args.focused_fg or nil
	local focused_bg = args.focused_bg or "#dddddd"

	local initial_screen = awful.screen.focused()

	local margin_size = dpi(6)
	local title_height = dpi(22)
	local key_height = dpi(15)
	local main_width = dpi(800)
	local y_anchor_pos = 0.75

	local colorized_control = colorize("C", key_control_fg)
	local colorized_shift = colorize("S", key_shift_fg)
	local colorized_mod1 = colorize("A", key_modifier_fg)
	local colorized_mod4 = colorize("Super", key_modifier_fg)
	local colorized_mod3 = colorize("Mod3", key_modifier_fg)

	local function key_string_to_label(key_string)
		key_string = key_string:gsub("control", colorized_control)
		key_string = key_string:gsub("shift", colorized_shift)
		key_string = key_string:gsub("mod1", colorized_mod1)
		key_string = key_string:gsub("mod4", colorized_mod4)
		key_string = key_string:gsub("mod3", colorized_mod3)
		return colorize(bold(" " .. key_string .. " "), key_fg, key_bg)
	end

	local function stylize_nested(description)
		return colorize(bold(description), nested_fg, nested_bg)
	end

	local function update_ui()
		if hide_first_level and #spec.breadcrumbs == 0 then
			return
		end

		if not wbox then
			wbox = wibox({
				ontop = true,
				type = "dock",
				border_width = beautiful.border_width,
				border_color = beautiful.border_focus,
				placement = awful.placement.centered,
			})
			wbox.screen = initial_screen
			wbox:set_fg(beautiful.fg_normal)
			wbox:set_bg(beautiful.bg_normal .. "e2")

			local container_inner = wibox.layout.align.vertical()
			local container_layout =
				wibox.container.margin(container_inner, margin_size, margin_size, margin_size, margin_size)
			container_layout = wibox.container.background(container_layout)

			wbox:set_widget(container_layout)
			layout_widgets = {}
			for i = 1, num_columns do
				local layout_widget = wibox.layout.fixed.vertical()
				table.insert(layout_widgets, layout_widget)
			end
			title_widget = wibox.widget({
				markup = "",
				valign = "bottom",
				align = "center",
				forced_height = title_height,
				widget = wibox.widget.textbox,
			})
			container_inner:set_bottom(title_widget)
			local args = {
				layout = wibox.layout.flex.horizontal,
				forced_width = main_width,
			}
			for _, layout_widget in ipairs(layout_widgets) do
				table.insert(args, layout_widget)
			end
			container_inner:set_middle(wibox.widget(args))
		else
			for _, layout_widget in ipairs(layout_widgets) do
				layout_widget:reset()
			end
		end

		-- build title widget markup using spec.breadcrumbs
		local title_markup = colorize(bold(spec.activation_key), activation_fg)
		for i, v in ipairs(spec.breadcrumbs) do
			title_markup = title_markup .. " " .. key_string_to_label(escape_markup(v[1]))
		end
		if #spec.breadcrumbs > 0 then
			local v = spec.breadcrumbs[#spec.breadcrumbs]
			title_markup = title_markup .. " - " .. stylize_nested(escape_markup(v[2]))
		end
		title_widget.markup = title_markup

		-- Set geometry always, the screen might have changed.
		local wa = initial_screen.workarea
		local x = math.ceil(wa.x + wa.width / 2 - main_width / 2) -- Center align
		wbox:geometry({
			x = x,
			width = main_width,
		})
		local wbox_height = title_height

		local keys = {}
		for k, _ in pairs(spec.current_key_table) do
			table.insert(keys, { k, key_string_to_label(escape_markup(k)) })
		end
		table.sort(keys, function(a, b)
			return a[2] < b[2]
		end)

		-- loop through each key
		local current_column = 1
		for _, entry in ipairs(keys) do
			local k = entry[1]
			local label = entry[2]
			local v = spec.current_key_table[k]
			local description = v[1]
			if description ~= hidden then
				description = escape_markup(description)
				local child = v[2]
				local child_is_function = type(child) == "function"
				if not child_is_function then
					description = stylize_nested(description .. "...")
				end
				local height = key_height
				local markup = label .. " - " .. description
				if spec.focused_key == k then
					markup = colorize(markup, focused_fg, focused_bg)
				end
				local key_widget = wibox.widget({
					markup = markup,
					valign = "center",
					align = "left",
					forced_height = height,
					widget = wibox.widget.textbox,
				})
				layout_widgets[current_column]:add(key_widget)
				if current_column == 1 then
					wbox_height = wbox_height + height
				end
				current_column = current_column + 1
				if current_column > num_columns then
					current_column = 1
				end
			end
		end

		local h = wbox_height + margin_size * 2
		wbox.screen = initial_screen
		wbox:geometry({
			height = h,
			y = wa.y + wa.height * y_anchor_pos - h,
		})
		wbox.visible = true
	end

	local grabber

	local function stop()
		if wbox then
			wbox.visible = false
		end
		awful.keygrabber.stop(grabber)
		grabber = nil
		spec.breadcrumbs = {}
	end

	update_ui()

	grabber = awful.keygrabber.run(mk_grabber_func(spec, update_ui, stop))
end

return {
	start = start,
	hidden = hidden,
}
