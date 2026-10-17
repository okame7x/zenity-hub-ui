# Zenity Hub UI

Roblox UI library: glass sidebar with search, animated glow/grid background, card rows with descriptions, inline dropdowns, toasts.

```lua
local Gui = loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/zenity-hub-ui/main/Library.lua"))()
local window = Gui.window({ Title = "Zenity Hub", Subtitle = "Game" })
local section = window:CreateTab({ Name = "Main" }):AddSection("Options")
section:AddToggle("Example", { Text = "Toggle", Description = "What it does.", Default = false, Callback = print })
```

Controls: `AddToggle`, `AddSlider`, `AddDropdown` (`Multi`, `Icons`, `Searchable`), `AddInput`, `AddLabel`, `AddInfoList`.
Window: `Notify`, `Destroy`. RightShift or the logo button toggles the window.
