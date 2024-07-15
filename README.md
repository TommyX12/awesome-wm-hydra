# awesome-wm-hydra
Multi-key-sequence framework for AwesomeWM with key hints display.

It allows you to bind an action to a sequence of any number of keys, such as `Super` + `w` + `c`.

Within the default behavior: `green hydra`, the sequence resets only when the initial activation key, eg. `Super`, is released, allowing you to easily implement modal bindings, such as pressing `Super` + `m` for music-related keys then press `h`/`l` multiple-times for seeking while holding down `Super`.

A different behavior is available: `red hydra`, which will keep the key-bindings and hint display from the active layer open even after the initial activation key is released. Use the `color` argument set to `"red"` when calling the `hydra.start` function in your config to avoid the requirement of a held key. A red hydra will reset once an unavailable key is pressed, or a `blue head` is activated.

This supercharges your AwesomeWM key bindings by allowing you to control an infinite number of actions through the keyboard without having to remember them all.

![Screenshot 1](screenshots/1.png)
![Screenshot 2](screenshots/2.png)
![Screenshot 3](screenshots/3.png)

## Getting started

- Clone this repository to your AwesomeWM configuration directory:
    ```sh
    git clone https://github.com/TommyX12/awesome-wm-hydra.git ~/.config/awesome/awesome-wm-hydra
    ```
- Require the module in your `rc.lua`:
    ```lua
    local hydra = require("awesome-wm-hydra")
    ```
- Write hydra key binding configs somewhere in your setup. Example (describe bindings that are active after pressing left super key):
    ```lua
    local super_key_bindings = {
        ["return"] = {"open a terminal", function() awful.spawn(terminal) end},
        ["control-r"] = {"reload awesome", awesome.restart},
        ["j"] = {"focus down", function()
            awful.client.focus.bydirection("down")
            if client.focus then client.focus:raise() end
        end},
        ["r"] = {"run application", function()
            awful.spawn('rofi -show drun')
        end},
        ["w"] = {"window control", {
            ["c"] = {"clear notifications", function()
                naughty.destroy_all_notifications()
            end},
            ["m"] = {"maximization control", {
                ["m"] = {"toggle maximize", function()
                    local c = client.focus
                    if not c then return end
                    c.maximized = not c.maximized
                    c:raise()
                end},
            }}
        }}
    }
    ```
- Trigger hydra in your main awesome key bindings. Example (trigger when left super key is pressed):
    ```lua
    awful.key({}, "Super_L", function ()
        hydra.start {
            activation_key = "Super_L",
            ignored_mod = "Mod4",
            config = super_key_bindings,
        }
    end),
    ```
- Hydra will display dynamic key hints when the activation key is pressed, and will be updated to show keys at the active level. The key hint can be configured to only show at second level and below.

## Configuration

### Key bindings
The key binding config is a nested table, where each table key is a key ID (see below), and each corresponding value is an table with two required keys: [1], [2], and an optional key: ["color"]

- [1]. A string describing the key.

- [2]. A function OR nested table.
    - A function to be called when the key is pressed. After pressing the key, this function will be called. A green hydra will stay in this level of the key binding config so that other keys at this level can be pressed again as long as the activation key is still held down. A red hydra doesn't require a key to be continuously held down.
    - A nested config table with the same structure as described above. After pressing the key, hydra will go into this level of the key binding config, and the key hints will be updated to show the keys at this level.

- ["color"]. A string. The color of the head: "blue", or "red", or "green"
    - "green": Default. Heads in the current layer can be activated successively without leaving the hydra.
    - "blue": the hydra is stopped once the key is pressed and it's corresponding function is run. Use for "terminal commands" such as launching applications when you want to close the hydra once the head is activated. This will hide the hint popup window and reset the sequence after the key action runs. Mostly useful for red hydras.
    - "red": No meaning yet. Head color is independant of the color/behavior of a hydra's body.

Since this is a plain Lua table, you can define the key binding config in any way you like, such as programmatically generating bindings:
```lua
for i = 1, 9 do
    super_key_bindings[tostring(i)] = {
        color = "blue",
        "view tag " .. i,
        function()
            local tag = awful.screen.focused().tags[i]
            if tag then
                tag:view_only()
            end
        end
    }
end
```

#### Key ID
A key ID is a string that represents a key (along with modifiers). **Every modifier + key combination has a unique key ID**.
- The key ID is a lower case string consists of dash-separated modifiers and the key itself (e.g. `control-a`, `control-shift-a`, `mod1-space`).
- Modifiers are `control`, `shift`, `mod1` (alt), or `mod4` (super), and **they must appear in sorted order** (e.g. `control` before `shift`).
- The key itself is the key name, such as `a`, `b`, `1`, `space`, `return`, etc. Note that when shift is active, the key name is the shifted key name (e.g. `!` instead of `1`), except for alphabets (where they are always lowercase).
- Because every modifier + key combination has a unique key ID, be sure to double-check the key ID when defining key bindings.

#### Hiding key from key hints
Use `hydra.hidden` as the description string to hide the key from key hints. This is useful when there are multiple similar keys such as `1`, `2`, `3`, etc., and you only want to show the hint for `1`.

### Main trigger arguments
Here are the arguments for the `hydra.start` function:
- Required arguments:
    - `activation_key`: The trigger key. This is **not** a key ID, but a AwesomeWM key name. This must match the key used in your awesome key config to trigger hydra, since it's used to detect when the activation key is released.
    - `config`: The key binding config table.
- Optional arguments:
    - `color`: The behavior of the hydra. Currently there is a default `"green"` which requires the activation key to be held down, and the `"red"` hydra which once activated will stay open with no keys held down.
    - `ignored_mod`: The modifier to ignore when detecting the activation key. This is **not** a key ID, but a AwesomeWM modifier name. This is useful when the activation key is a modifier key, such as `Mod4` (super key), so that the activation key itself does not have to be specified in the key binding config. Can optionally be a table if multiple ignored modifiers are needed.
    - `hide_first_level`: Whether to hide the key hints at the first level. Defaults to `false`.
- Key hint theme customizations:
    - `key_fg`: The foreground color of the keys.
    - `key_bg`: The background color of the keys.
    - `key_control_fg`: The foreground color of the control modifier.
    - `key_shift_fg`: The foreground color of the shift modifier.
    - `key_modifier_fg`: The foreground color of the alt and super modifiers.
    - `activation_fg`: The foreground color of the activation key.
    - `nested_fg`: The foreground color of hints that point to nested levels.
    - `nested_bg`: The background color of hints that point to nested levels.
    - `focused_fg`: The foreground color of the key that just got pressed.
    - `focused_bg`: The background color of the key that just got pressed.
