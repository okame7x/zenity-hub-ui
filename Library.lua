-- Zenity Hub UI
-- Glass sidebar + topbar, card rows, animated glow/grid background.
-- local Gui = loadstring(game:HttpGet("https://raw.githubusercontent.com/okame7x/zenity-hub-ui/main/Library.lua"))()
-- Gui.bindControl = function(id, control, kind, options) end -- optional: save/restore hook

local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))

local Gui = { connections = {} }

function Gui.create(className, properties)
	local instance = Instance.new(className)
	for key, value in properties do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = properties.Parent
	return instance
end

function Gui.connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Gui.connections, connection)
	return connection
end

-- Accepts an array of values or a { [value] = true } map
function Gui.applyMulti(set, value)
	table.clear(set)
	if type(value) ~= "table" then return end
	for key, state in value do
		if type(key) == "number" then
			set[state] = true
		elseif state == true then
			set[key] = true
		end
	end
end

-- Asset ids / urls become rbxthumb so dropdown icons always load
function Gui.thumbnail(image)
	local text = tostring(image)
	if text:match("^rbxthumb://") then
		return text
	end
	local id = text:match("assetId=(%d+)") or text:match("[?&]id=(%d+)") or tonumber(text) and text
	if id then
		return "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150"
	end
	return text
end

-- Lets the host script save/restore controls by id
function Gui.bind(id, control, kind, options)
	if Gui.bindControl and type(id) == "string" then
		Gui.bindControl(id, control, kind, options)
	end
end


Gui.theme = {
	-- Distinct layers (window < sidebar < card < control) and bright secondary text, so everything reads at a glance
	accent = Color3.fromRGB(150, 108, 255),
	accentText = Color3.fromRGB(255, 255, 255),
	background = Color3.fromRGB(14, 15, 20),
	sidebar = Color3.fromRGB(19, 21, 28),
	surface = Color3.fromRGB(29, 32, 42),
	surfaceHover = Color3.fromRGB(40, 44, 57),
	control = Color3.fromRGB(56, 61, 78),
	border = Color3.fromRGB(255, 255, 255),
	text = Color3.fromRGB(248, 249, 252),
	subtext = Color3.fromRGB(200, 205, 216),
	muted = Color3.fromRGB(155, 162, 178),
}
Gui.motion = { tap = 0.08, fast = 0.12, base = 0.18, panel = 0.24, slow = 0.34 }
Gui.logo = "rbxassetid://123727588877909"
Gui.size = Vector2.new(680, 460)
Gui.sidebarWidth = 178
Gui.tabs = {}
Gui.toastsActive = {}
Gui.order = 0
Gui.query = ""
Gui.Tab = {}
Gui.Tab.__index = Gui.Tab
Gui.Section = {}
Gui.Section.__index = Gui.Section

-- Helpers

function Gui.nextOrder()
	Gui.order += 1
	return Gui.order
end

function Gui.corner(parent, radius)
	return Gui.create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

function Gui.round(parent)
	return Gui.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Gui.stroke(parent, color, transparency, thickness)
	return Gui.create("UIStroke", { Color = color or Gui.theme.border, Transparency = transparency or 0.9, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function Gui.padding(parent, top, right, bottom, left)
	return Gui.create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
		Parent = parent,
	})
end

function Gui.list(parent, spacing, direction)
	return Gui.create("UIListLayout", { Padding = UDim.new(0, spacing), FillDirection = direction or Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent })
end

function Gui.text(properties)
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or Enum.Font.GothamMedium
	properties.TextSize = properties.TextSize or 14
	properties.TextColor3 = properties.TextColor3 or Gui.theme.text
	properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
	properties.TextTruncate = properties.TextTruncate or Enum.TextTruncate.AtEnd
	return Gui.create("TextLabel", properties)
end

function Gui.button(properties)
	properties.Text = properties.Text or ""
	properties.AutoButtonColor = false
	properties.BorderSizePixel = 0
	return Gui.create("TextButton", properties)
end

function Gui.tween(object, goal, time, style)
	local tween = TweenService:Create(object, TweenInfo.new(time or Gui.motion.fast, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

function Gui.glide(object, goal, time)
	return Gui.tween(object, goal, time or Gui.motion.panel, Enum.EasingStyle.Quint)
end

function Gui.pop(object, goal, time)
	return Gui.tween(object, goal, time or Gui.motion.base, Enum.EasingStyle.Back)
end

-- Endless back-and-forth tween; runs in the engine, no per-frame Lua
function Gui.loop(object, goal, time)
	TweenService:Create(object, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal):Play()
end

function Gui.hover(object, onEnter, onLeave)
	object.MouseEnter:Connect(onEnter)
	object.MouseLeave:Connect(onLeave)
end

function Gui.isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Follow the pointer until it's released (window, launcher and slider drags)
function Gui.follow(onMove, onEnd)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			onMove(input.Position)
		end
	end)
	local ended
	ended = UserInputService.InputEnded:Connect(function(input)
		if not Gui.isPress(input) then return end
		moved:Disconnect()
		ended:Disconnect()
		if onEnd then
			onEnd()
		end
	end)
end

function Gui.inside(object, position)
	local topLeft = object.AbsolutePosition
	local bottomRight = topLeft + object.AbsoluteSize
	return position.X >= topLeft.X and position.X <= bottomRight.X and position.Y >= topLeft.Y and position.Y <= bottomRight.Y
end

-- Soft radial glow: stacked translucent circles, denser toward the center
function Gui.glow(parent, position, size, strength)
	local holder = Gui.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
	local layers = 18
	for index = layers, 1, -1 do
		local scale = index / layers
		local circle = Gui.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			BackgroundColor3 = Gui.theme.accent,
			BackgroundTransparency = 1 - strength * (1 - scale) ^ 2.4,
			BorderSizePixel = 0,
			Parent = holder,
		})
		Gui.round(circle)
	end
	return holder
end

-- Window

-- One faint, still glow in a corner: the grid and the drifting glows sat behind the text and made it harder to read
function Gui.buildBackground()
	local effects = Gui.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = Gui.main })
	Gui.glow(effects, UDim2.fromScale(0.05, 0.05), 360, 0.05)
end

function Gui.draggable(handle)
	handle.InputBegan:Connect(function(input)
		if not Gui.isPress(input) then return end
		local start = input.Position
		local origin = Gui.main.Position
		local moving = false
		Gui.follow(function(position)
			local delta = position - start
			-- Small threshold so clicks on the handle don't nudge the window
			if not moving and delta.Magnitude < 4 then return end
			if not moving then
				moving = true
				Gui.closeDropdown()
			end
			Gui.main.Position = origin + UDim2.fromOffset(delta.X, delta.Y)
		end)
	end)
end

function Gui.buildSearch(sidebar)
	local theme = Gui.theme
	local frame = Gui.create("Frame", { Position = UDim2.fromOffset(10, 72), Size = UDim2.fromOffset(Gui.sidebarWidth - 20, 30), BackgroundColor3 = theme.surface, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = sidebar })
	Gui.corner(frame, 8)
	local stroke = Gui.stroke(frame, theme.border, 0.92)
	local box = Gui.create("TextBox", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "", PlaceholderText = "Search...", PlaceholderColor3 = theme.muted, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	box.Focused:Connect(function()
		Gui.tween(stroke, { Color = theme.accent, Transparency = 0.45 })
	end)
	box.FocusLost:Connect(function()
		Gui.tween(stroke, { Color = theme.border, Transparency = 0.92 })
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		Gui.query = box.Text:lower():match("^%s*(.-)%s*$")
		Gui.closeDropdown()
		if Gui.selected then
			Gui.selected:applySearch(Gui.query)
		end
	end)
end

function Gui.buildSidebar(options)
	local theme = Gui.theme
	local width = Gui.sidebarWidth
	local sidebar = Gui.create("Frame", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = theme.sidebar, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 2, Parent = Gui.main })
	Gui.create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = theme.border, BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = sidebar })

	local brand = Gui.create("Frame", { Position = UDim2.fromOffset(14, 16), Size = UDim2.fromOffset(width - 28, 44), BackgroundTransparency = 1, Parent = sidebar })
	Gui.create("ImageLabel", { Image = Gui.logo, Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Parent = brand })
	Gui.text({ Text = options.Title, Font = Enum.Font.GothamBold, TextSize = 15, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -42, 0, 18), Parent = brand })
	Gui.text({ Text = options.Subtitle, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = theme.subtext, Position = UDim2.fromOffset(42, 19), Size = UDim2.new(1, -42, 0, 14), Parent = brand })
	Gui.draggable(brand)

	Gui.buildSearch(sidebar)
	Gui.tabList = Gui.create("ScrollingFrame", { Position = UDim2.fromOffset(10, 112), Size = UDim2.new(0, width - 20, 1, -124), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, Parent = sidebar })
	Gui.list(Gui.tabList, 4)
end

function Gui.controlButton(parent, text, order, onClick)
	local theme = Gui.theme
	local button = Gui.button({ Text = text, Size = UDim2.fromOffset(26, 26), BackgroundColor3 = theme.surfaceHover, BackgroundTransparency = 0.45, TextColor3 = theme.subtext, TextSize = 14, Font = Enum.Font.GothamMedium, LayoutOrder = order, Parent = parent })
	Gui.corner(button, 7)
	Gui.hover(button, function()
		Gui.tween(button, { BackgroundTransparency = 0.1, TextColor3 = theme.text })
	end, function()
		Gui.tween(button, { BackgroundTransparency = 0.45, TextColor3 = theme.subtext })
	end)
	button.MouseButton1Click:Connect(onClick)
	return button
end

function Gui.buildContent()
	local theme = Gui.theme
	local left = Gui.sidebarWidth + 12
	local content = Gui.create("Frame", { Position = UDim2.fromOffset(left, 12), Size = UDim2.new(1, -(left + 12), 1, -24), BackgroundTransparency = 1, ZIndex = 2, Parent = Gui.main })

	local topbar = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = theme.surface, BackgroundTransparency = 0, BorderSizePixel = 0, Parent = content })
	Gui.corner(topbar, 10)
	Gui.stroke(topbar, theme.border, 0.94)
	local mark = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(2, 18), BackgroundColor3 = theme.accent, BorderSizePixel = 0, Parent = topbar })
	Gui.round(mark)
	Gui.title = Gui.text({ Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0), Parent = topbar })
	local controls = Gui.create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(62, 26), BackgroundTransparency = 1, Parent = topbar })
	local layout = Gui.list(controls, 5, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	Gui.minimizeButton = Gui.controlButton(controls, "−", 1, function()
		Gui.setMinimized(not Gui.minimized)
	end)
	Gui.controlButton(controls, "×", 2, function()
		Gui.setVisible(false)
	end)
	Gui.draggable(topbar)

	Gui.pages = Gui.create("Frame", { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), BackgroundTransparency = 1, ClipsDescendants = true, Parent = content })
end

-- Round logo that reopens the window; drag it anywhere, tap to toggle
function Gui.buildLauncher()
	local launcher = Gui.create("ImageButton", { Image = Gui.logo, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Gui.theme.background, AutoButtonColor = false, BorderSizePixel = 0, Parent = Gui.screen })
	Gui.round(launcher)
	local ring = Gui.stroke(launcher, Gui.theme.accent, 0.45, 2)
	Gui.loop(ring, { Transparency = 0.1 }, 1.6)
	launcher.InputBegan:Connect(function(input)
		if not Gui.isPress(input) then return end
		local start = input.Position
		local origin = launcher.Position
		local moved = false
		Gui.follow(function(position)
			local delta = position - start
			if not moved and delta.Magnitude < 6 then return end
			moved = true
			launcher.Position = origin + UDim2.fromOffset(delta.X, delta.Y)
		end, function()
			if not moved then
				Gui.setVisible(not Gui.visible)
			end
		end)
	end)
end

function Gui.buildToasts()
	Gui.toasts = Gui.create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(296, 520), BackgroundTransparency = 1, Parent = Gui.screen })
	local layout = Gui.list(Gui.toasts, 7)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
end

-- One input listener: RightShift toggles, and a press outside an open dropdown closes it
function Gui.bindInput()
	Gui.connect(UserInputService.InputBegan, function(input, processed)
		if input.KeyCode == Enum.KeyCode.RightShift and not processed then
			Gui.setVisible(not Gui.visible)
			return
		end
		local open = Gui.openDropdown
		if open and Gui.isPress(input) and not Gui.inside(open.row, input.Position) then
			open:setOpen(false)
		end
	end)
end

-- Shrink the window on small screens (phones)
function Gui.fitScreen()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	Gui.scale.Scale = math.clamp(math.min((viewport.X - 56) / Gui.size.X, (viewport.Y - 56) / Gui.size.Y, 1), 0.45, 1)
end

function Gui.setVisible(visible)
	if Gui.visible == visible then return end
	Gui.visible = visible
	Gui.closeDropdown()
	Gui.fadeToken = (Gui.fadeToken or 0) + 1
	local token = Gui.fadeToken
	if visible then
		Gui.main.Visible = true
		Gui.tween(Gui.main, { GroupTransparency = 0 }, Gui.motion.base)
		return
	end
	Gui.tween(Gui.main, { GroupTransparency = 1 }, Gui.motion.fast)
	task.delay(Gui.motion.fast, function()
		if Gui.fadeToken == token then
			Gui.main.Visible = false
		end
	end)
end

function Gui.setMinimized(minimized)
	Gui.minimized = minimized
	Gui.closeDropdown()
	Gui.minimizeButton.Text = minimized and "+" or "−"
	local height = minimized and 70 or Gui.size.Y
	Gui.glide(Gui.main, { Size = UDim2.fromOffset(Gui.size.X, height) })
end

function Gui.window(options)
	local theme = Gui.theme
	Gui.screen = Gui.create("ScreenGui", { Name = "ZenityMM2", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = gethui() })
	Gui.main = Gui.create("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 16), Size = UDim2.fromOffset(Gui.size.X, Gui.size.Y), BackgroundColor3 = theme.background, BackgroundTransparency = 0.02, BorderSizePixel = 0, GroupTransparency = 1, Parent = Gui.screen })
	Gui.corner(Gui.main, 14)
	Gui.stroke(Gui.main)
	Gui.scale = Gui.create("UIScale", { Parent = Gui.main })
	Gui.buildBackground()
	Gui.buildSidebar(options)
	Gui.buildContent()
	Gui.buildToasts()
	Gui.buildLauncher()
	Gui.bindInput()
	Gui.fitScreen()
	Gui.connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), Gui.fitScreen)
	-- Intro: fade in while sliding up into place
	Gui.visible = true
	Gui.glide(Gui.main, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, Gui.motion.slow)
	return Gui
end

function Gui:Destroy()
	for _, connection in Gui.connections do
		connection:Disconnect()
	end
	table.clear(Gui.connections)
	Gui.screen:Destroy()
end

-- Toasts slide in, show a draining timer bar, then slide out
function Gui:Notify(options)
	local theme = Gui.theme
	local duration = math.max(tonumber(options.Duration) or 4, 0.5)
	while #Gui.toastsActive >= 5 do
		table.remove(Gui.toastsActive, 1):Destroy()
	end
	local holder = Gui.create("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = Gui.nextOrder(), Parent = Gui.toasts })
	local card = Gui.create("CanvasGroup", { Position = UDim2.fromOffset(26, 0), Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = theme.background, BackgroundTransparency = 0.02, BorderSizePixel = 0, GroupTransparency = 1, Parent = holder })
	Gui.corner(card, 10)
	Gui.stroke(card)
	Gui.padding(card, 11, 12, 11, 13)
	Gui.list(card, 6)
	local head = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
	Gui.create("ImageLabel", { Image = Gui.logo, Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Parent = head })
	Gui.text({ Text = tostring(options.Title or "Notification"), TextSize = 12, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -26, 1, 0), Parent = head })
	Gui.text({ Text = tostring(options.Text or ""), TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = theme.subtext, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
	local timer = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = theme.control, BackgroundTransparency = 0.4, BorderSizePixel = 0, LayoutOrder = 3, Parent = card })
	Gui.round(timer)
	local fill = Gui.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.accent, BorderSizePixel = 0, Parent = timer })
	Gui.round(fill)
	table.insert(Gui.toastsActive, holder)
	Gui.tween(card, { Position = UDim2.new(), GroupTransparency = 0 }, Gui.motion.base)
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	task.delay(duration, function()
		local index = table.find(Gui.toastsActive, holder)
		if not index then return end
		table.remove(Gui.toastsActive, index)
		Gui.tween(card, { Position = UDim2.fromOffset(26, 0), GroupTransparency = 1 }, Gui.motion.base)
		task.delay(Gui.motion.base, function()
			holder:Destroy()
		end)
	end)
end

-- Tabs

-- Tab icons: white line icons shipped in this repo (icons/<name>.png), downloaded once into the executor
-- workspace and shown through getcustomasset. An "rbxassetid://" icon is used as is. nil when unavailable.
Gui.iconUrl = "https://raw.githubusercontent.com/okame7x/zenity-hub-ui/main/icons/"
Gui.iconFolder = "zenity-hub-ui"
function Gui.icon(name)
	if type(name) == "number" then return "rbxassetid://" .. name end
	if type(name) ~= "string" or name == "" then return end
	if name:find("^rbxasset") or name:find("^https?://") then return name end
	local ok, asset = pcall(function()
		local path = ("%s/%s.png"):format(Gui.iconFolder, name)
		if not isfile(path) then
			local response = request({ Url = Gui.iconUrl .. name .. ".png", Method = "GET" })
			if not response or response.StatusCode ~= 200 or not response.Body or #response.Body == 0 then return end
			if not isfolder(Gui.iconFolder) then makefolder(Gui.iconFolder) end
			writefile(path, response.Body)
		end
		return getcustomasset(path)
	end)
	return ok and asset or nil
end

function Gui:CreateTab(options)
	local theme = Gui.theme
	local button = Gui.button({ Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme.surfaceHover, BackgroundTransparency = 1, LayoutOrder = #Gui.tabs + 1, Parent = Gui.tabList })
	Gui.corner(button, 8)
	local indicator = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(2, 0), BackgroundColor3 = theme.accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = button })
	Gui.round(indicator)
	local image = Gui.icon(options.Icon)
	local icon = image and Gui.create("ImageLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 13, 0.5, 0), Size = UDim2.fromOffset(17, 17), BackgroundTransparency = 1, Image = image, ImageColor3 = theme.subtext, ScaleType = Enum.ScaleType.Fit, Parent = button })
	local textX = icon and 38 or 14
	local label = Gui.text({ Text = options.Name, TextColor3 = theme.subtext, Position = UDim2.fromOffset(textX, 0), Size = UDim2.new(1, -(textX + 8), 1, 0), Parent = button })
	local page = Gui.create("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = Gui.pages })
	local container = Gui.create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = theme.accent, ScrollBarImageTransparency = 0.35, Parent = page })
	Gui.list(container, 10)
	Gui.padding(container, 2, 8, 10, 2)

	local tab = setmetatable({ name = options.Name, button = button, indicator = indicator, label = label, icon = icon, textX = textX, page = page, container = container, sections = {}, token = 0 }, Gui.Tab)
	button.MouseButton1Click:Connect(function()
		Gui.selectTab(tab)
	end)
	Gui.hover(button, function()
		if tab.selected then return end
		Gui.tween(button, { BackgroundTransparency = 0.6 })
		Gui.tween(label, { TextColor3 = theme.text })
		if icon then Gui.tween(icon, { ImageColor3 = theme.text }) end
		Gui.glide(label, { Position = UDim2.fromOffset(textX + 3, 0) }, Gui.motion.base)
	end, function()
		if tab.selected then return end
		Gui.tween(button, { BackgroundTransparency = 1 })
		Gui.tween(label, { TextColor3 = theme.subtext })
		if icon then Gui.tween(icon, { ImageColor3 = theme.subtext }) end
		Gui.glide(label, { Position = UDim2.fromOffset(textX, 0) }, Gui.motion.base)
	end)
	table.insert(Gui.tabs, tab)
	if #Gui.tabs == 1 then
		Gui.selectTab(tab)
	end
	return tab
end

function Gui.selectTab(tab)
	if Gui.selected == tab then return end
	Gui.closeDropdown()
	if Gui.selected then
		Gui.selected:setSelected(false)
	end
	Gui.selected = tab
	tab:setSelected(true)
	Gui.title.Text = tab.name
	tab:applySearch(Gui.query)
end

-- New page slides in from the right; the old one slides left and fades
function Gui.Tab:setSelected(selected)
	local theme = Gui.theme
	self.selected = selected
	self.token += 1
	local token = self.token
	if selected then
		self.page.Visible = true
		self.page.Position = UDim2.fromOffset(14, 0)
		self.page.GroupTransparency = 1
		Gui.glide(self.page, { Position = UDim2.new() })
		Gui.tween(self.page, { GroupTransparency = 0 }, Gui.motion.base)
		Gui.tween(self.button, { BackgroundTransparency = 0.35 }, Gui.motion.base)
		Gui.tween(self.label, { TextColor3 = theme.text, Position = UDim2.fromOffset(self.textX, 0) }, Gui.motion.base)
		if self.icon then Gui.tween(self.icon, { ImageColor3 = theme.accent }, Gui.motion.base) end
		Gui.pop(self.indicator, { Size = UDim2.fromOffset(2, 16) }, Gui.motion.panel)
		Gui.tween(self.indicator, { BackgroundTransparency = 0 })
		return
	end
	Gui.glide(self.page, { Position = UDim2.fromOffset(-10, 0) }, Gui.motion.base)
	Gui.tween(self.page, { GroupTransparency = 1 })
	task.delay(Gui.motion.base, function()
		if self.token == token then
			self.page.Visible = false
		end
	end)
	Gui.tween(self.button, { BackgroundTransparency = 1 })
	Gui.tween(self.label, { TextColor3 = theme.subtext })
	if self.icon then Gui.tween(self.icon, { ImageColor3 = theme.subtext }) end
	Gui.tween(self.indicator, { Size = UDim2.fromOffset(2, 0), BackgroundTransparency = 1 })
end

-- Sidebar search: a section title match shows the whole section
function Gui.Tab:applySearch(query)
	for _, section in self.sections do
		local sectionMatch = query ~= "" and section.title:find(query, 1, true) ~= nil
		local anyVisible = false
		for _, element in section.elements do
			local visible = query == "" or sectionMatch or element.text:find(query, 1, true) ~= nil
			element.row.Visible = visible
			anyVisible = anyVisible or visible
		end
		section.root.Visible = query == "" or anyVisible
	end
end

function Gui.Tab:AddSection(title)
	local theme = Gui.theme
	local root = Gui.create("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = #self.sections + 1, Parent = self.container })
	Gui.list(root, 8)
	local header = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 1, Parent = root })
	local mark = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(2, 11), BackgroundColor3 = theme.accent, BorderSizePixel = 0, Parent = header })
	Gui.round(mark)
	Gui.text({ Text = title:upper(), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = theme.subtext, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0), Parent = header })
	local container = Gui.create("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = root })
	Gui.list(container, 7)
	Gui.padding(container, 2)
	local section = setmetatable({ root = root, container = container, title = title:lower(), elements = {} }, Gui.Section)
	table.insert(self.sections, section)
	return section
end

-- Card row: title on the left, control on the right, extras stack below. Descriptions are not shown: the titles
-- say enough and the extra lines made every tab long and hard to scan
function Gui.Section:card(options, controlSize, clickable)
	local theme = Gui.theme
	local row = Gui.create(clickable and "TextButton" or "Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = theme.surface, BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = Gui.nextOrder(), Parent = self.container })
	if clickable then
		row.AutoButtonColor = false
		row.Text = ""
	end
	Gui.corner(row, 10)
	local stroke = Gui.stroke(row, theme.border, 0.86)
	Gui.padding(row, 11, 14)
	Gui.list(row, 9)

	local head = Gui.create("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
	local headLayout = Gui.list(head, 14, Enum.FillDirection.Horizontal)
	headLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local controlWidth = controlSize and controlSize.X or 0
	local info = Gui.create("Frame", { Size = UDim2.new(1, controlWidth > 0 and -(controlWidth + 14) or 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = head })
	Gui.list(info, 3)
	Gui.text({ Text = options.Text or "", Font = Enum.Font.GothamBold, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = info })
	local control
	if controlWidth > 0 then
		control = Gui.create("Frame", { Size = UDim2.fromOffset(controlSize.X, controlSize.Y), BackgroundTransparency = 1, LayoutOrder = 2, Parent = head })
	end

	Gui.hover(row, function()
		Gui.tween(row, { BackgroundColor3 = theme.surfaceHover })
		Gui.tween(stroke, { Transparency = 0.7 })
	end, function()
		Gui.tween(row, { BackgroundColor3 = theme.surface })
		Gui.tween(stroke, { Transparency = 0.86 })
	end)
	table.insert(self.elements, { row = row, text = (options.Text or ""):lower() })
	return row, control
end

-- Callback first, then let Config know the value changed
function Gui.fire(control, callback, ...)
	if callback then
		pcall(callback, ...)
	end
	if control.onChanged then
		control.onChanged()
	end
end

function Gui.apply(object, goal)
	for key, value in goal do
		object[key] = value
	end
end

-- Elements

function Gui.Section:AddToggle(id, options)
	local theme = Gui.theme
	local row, holder = self:card(options, Vector2.new(36, 20), true)
	local track = Gui.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.control, BorderSizePixel = 0, Parent = holder })
	Gui.round(track)
	local dot = Gui.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = theme.subtext, BorderSizePixel = 0, Parent = track })
	Gui.round(dot)

	local control = { value = options.Default == true }
	function control:render(instant)
		local on = self.value
		local trackGoal = { BackgroundColor3 = on and theme.accent or theme.control }
		local dotGoal = { Position = on and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0), BackgroundColor3 = on and theme.accentText or theme.subtext }
		if instant then
			Gui.apply(track, trackGoal)
			Gui.apply(dot, dotGoal)
			return
		end
		Gui.tween(track, trackGoal, Gui.motion.base)
		Gui.glide(dot, dotGoal, Gui.motion.base)
		-- Squash the dot as it slides, then pop it back
		Gui.tween(dot, { Size = UDim2.fromOffset(17, 12) }, Gui.motion.tap)
		task.delay(Gui.motion.tap, function()
			Gui.pop(dot, { Size = UDim2.fromOffset(14, 14) })
		end)
	end
	function control:Set(value)
		self.value = value == true
		self:render()
		Gui.fire(self, options.Callback, self.value)
	end
	function control:Get()
		return self.value
	end
	row.MouseButton1Click:Connect(function()
		control:Set(not control.value)
	end)
	control:render(true)
	Gui.bind(id, control, "toggle", options)
	return control
end

function Gui.Section:AddSlider(id, options)
	local theme = Gui.theme
	local min = options.Min or 0
	local max = options.Max or 100
	local decimals = options.Rounding or 0
	local step = 10 ^ -decimals
	local row, holder = self:card(options, Vector2.new(70, 20), false)
	local valueLabel = Gui.text({ TextColor3 = theme.subtext, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1), Parent = holder })
	local bar = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1, LayoutOrder = 2, Parent = row })
	local track = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = theme.control, BorderSizePixel = 0, Parent = bar })
	Gui.round(track)
	local fill = Gui.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.accent, BorderSizePixel = 0, Parent = track })
	Gui.round(fill)
	local knob = Gui.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = theme.accentText, BorderSizePixel = 0, ZIndex = 2, Parent = track })
	Gui.round(knob)
	Gui.stroke(knob, theme.accent, 0.2, 2)
	local hitbox = Gui.button({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = bar })

	local control = { value = math.clamp(options.Default or min, min, max) }
	function control:render(instant)
		local alpha = (self.value - min) / (max - min)
		local time = instant and 0 or self.dragging and 0.05 or 0.14
		Gui.tween(fill, { Size = UDim2.fromScale(alpha, 1) }, time)
		Gui.tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, time)
		valueLabel.Text = ("%." .. decimals .. "f"):format(self.value)
	end
	function control:Set(value)
		value = math.clamp(math.round(value / step) * step, min, max)
		if value == self.value then return end
		self.value = value
		self:render()
		Gui.fire(self, options.Callback, value)
	end
	function control:Get()
		return self.value
	end
	local function setFromPointer(position)
		local width = track.AbsoluteSize.X
		if width <= 0 then return end
		control:Set(min + (max - min) * math.clamp((position.X - track.AbsolutePosition.X) / width, 0, 1))
	end
	hitbox.InputBegan:Connect(function(input)
		if not Gui.isPress(input) then return end
		control.dragging = true
		Gui.pop(knob, { Size = UDim2.fromOffset(15, 15) })
		setFromPointer(input.Position)
		Gui.follow(setFromPointer, function()
			control.dragging = false
			Gui.tween(knob, { Size = UDim2.fromOffset(13, 13) })
		end)
	end)
	control:render(true)
	Gui.bind(id, control, "slider", options)
	return control
end

function Gui.Section:AddDropdown(id, options)
	local theme = Gui.theme
	local row, holder = self:card(options, Vector2.new(160, 28), false)
	local box = Gui.button({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.control, BackgroundTransparency = 0.25, Parent = holder })
	Gui.corner(box, 7)
	local icon = Gui.create("ImageLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = box })
	local valuePreview = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Visible = false, Parent = box })
	local valueLabel = Gui.text({ TextSize = 13, TextColor3 = theme.subtext, Size = UDim2.new(1, -32, 1, 0), Parent = box })
	local arrow = Gui.text({ Text = "›", TextSize = 17, TextColor3 = theme.subtext, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(16, 16), Rotation = 90, Parent = box })

	local panel = Gui.create("Frame", { Size = UDim2.fromScale(1, 0), BackgroundColor3 = theme.background, BackgroundTransparency = 0.15, BorderSizePixel = 0, ClipsDescendants = true, Visible = false, LayoutOrder = 2, Parent = row })
	Gui.corner(panel, 8)
	Gui.stroke(panel, theme.border, 0.92)
	Gui.padding(panel, 6)
	Gui.list(panel, 5)
	local filterable = options.Searchable or #(options.Values or {}) >= 9
	local filterBox
	if filterable then
		local filterFrame = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.2, BorderSizePixel = 0, LayoutOrder = 1, Parent = panel })
		Gui.corner(filterFrame, 6)
		filterBox = Gui.create("TextBox", { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -18, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "", PlaceholderText = "Filter...", PlaceholderColor3 = theme.muted, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = filterFrame })
	end
	local list = Gui.create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, filterable and -31 or 0), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = theme.accent, LayoutOrder = 2, Parent = panel })
	Gui.list(list, 3)

	local control = { row = row, multi = options.Multi == true, values = options.Values or {}, icons = options.Icons or {}, selected = {}, options = {}, open = false, dirty = true, filter = "", optionHeight = options.Preview and 38 or 30 }
	if control.multi then
		Gui.applyMulti(control.selected, options.Default or {})
	else
		control.value = options.Default
	end

	function control:has(value)
		if self.multi then
			return self.selected[value] == true
		end
		return self.value == value
	end

	function control:summary()
		if not self.multi then
			return self.value or "Select"
		end
		local chosen = {}
		for _, value in self.values do
			if self.selected[value] then
				table.insert(chosen, value)
			end
		end
		if #chosen == 0 then
			return "None"
		end
		return #chosen <= 2 and table.concat(chosen, ", ") or #chosen .. " selected"
	end

	-- Preview = function(value, holder): draws a live sample of the option into holder
	function control:drawPreview(holder, value)
		holder:ClearAllChildren()
		pcall(options.Preview, value, holder)
	end

	function control:render()
		local image = not self.multi and self.value and self.icons[self.value]
		icon.Visible = image ~= nil and image ~= false
		if icon.Visible then
			icon.Image = Gui.thumbnail(image)
		end
		local previewing = options.Preview ~= nil and not self.multi and self.value ~= nil
		if previewing and self.previewValue ~= self.value then
			self.previewValue = self.value
			self:drawPreview(valuePreview, self.value)
		end
		valuePreview.Visible = previewing
		valueLabel.Position = UDim2.fromOffset((icon.Visible or previewing) and 30 or 10, 0)
		valueLabel.Text = self:summary()
		for value, option in self.options do
			local selected = self:has(value)
			option.button.BackgroundTransparency = selected and 0.2 or 1
			option.label.TextColor3 = selected and theme.text or theme.subtext
			option.indicator.BackgroundTransparency = selected and 0 or 1
		end
	end

	function control:changed()
		self:render()
		Gui.fire(self, options.Callback, self.multi and table.clone(self.selected) or self.value)
	end

	function control:Set(value)
		if self.multi then
			Gui.applyMulti(self.selected, value)
		else
			self.value = value
		end
		self:changed()
	end

	function control:Get()
		if not self.multi then
			return self.value
		end
		local chosen = {}
		for _, value in self.values do
			if self.selected[value] then
				table.insert(chosen, value)
			end
		end
		return chosen
	end

	function control:choose(value)
		if self.multi then
			self.selected[value] = not self.selected[value] or nil
			self:changed()
			return
		end
		self:Set(value)
		self:setOpen(false)
	end

	function control:addOption(value, index)
		local button = Gui.button({ Size = UDim2.new(1, -2, 0, self.optionHeight), BackgroundColor3 = theme.surfaceHover, BackgroundTransparency = 1, LayoutOrder = index, Parent = list })
		Gui.corner(button, 6)
		local indicator = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(2, 13), BackgroundColor3 = theme.accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = button })
		Gui.round(indicator)
		local textX = 17
		local image = self.icons[value]
		if options.Preview then
			local holder = Gui.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = theme.background, BackgroundTransparency = 0.3, BorderSizePixel = 0, ClipsDescendants = true, Parent = button })
			Gui.corner(holder, 6)
			local canvas = Gui.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder })
			self:drawPreview(canvas, value)
			textX = 52
		elseif image then
			Gui.create("ImageLabel", { Image = Gui.thumbnail(image), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Parent = button })
			textX = 44
		end
		local label = Gui.text({ Text = value, TextSize = 13, TextColor3 = theme.subtext, Position = UDim2.fromOffset(textX, 0), Size = UDim2.new(1, -(textX + 8), 1, 0), Parent = button })
		Gui.hover(button, function()
			Gui.tween(button, { BackgroundTransparency = 0.45 }, 0.1)
		end, function()
			Gui.tween(button, { BackgroundTransparency = self:has(value) and 0.2 or 1 }, 0.1)
		end)
		button.MouseButton1Click:Connect(function()
			self:choose(value)
		end)
		self.options[value] = { button = button, label = label, indicator = indicator }
	end

	-- Option rows are only (re)built when the list is opened after a change
	function control:rebuild()
		for _, option in self.options do
			option.button:Destroy()
		end
		table.clear(self.options)
		for index, value in self.values do
			self:addOption(value, index)
		end
		self.dirty = false
		self:applyFilter()
		self:render()
	end

	function control:applyFilter()
		for value, option in self.options do
			option.button.Visible = self.filter == "" or value:lower():find(self.filter, 1, true) ~= nil
		end
	end

	function control:panelHeight()
		local shown = 0
		for _, option in self.options do
			if option.button.Visible then
				shown += 1
			end
		end
		shown = math.clamp(shown, 1, 6)
		return shown * self.optionHeight + (shown - 1) * 3 + 12 + (filterable and 31 or 0)
	end

	function control:setOpen(open)
		if self.open == open then return end
		self.open = open
		if open then
			if Gui.openDropdown and Gui.openDropdown ~= self then
				Gui.openDropdown:setOpen(false)
			end
			Gui.openDropdown = self
			if self.dirty then
				self:rebuild()
			end
			panel.Visible = true
			panel.Size = UDim2.fromScale(1, 0)
			Gui.glide(panel, { Size = UDim2.new(1, 0, 0, self:panelHeight()) })
			Gui.glide(arrow, { Rotation = -90 })
			Gui.tween(arrow, { TextColor3 = theme.accent }, Gui.motion.base)
			Gui.tween(box, { BackgroundTransparency = 0.05 }, Gui.motion.base)
			return
		end
		if Gui.openDropdown == self then
			Gui.openDropdown = nil
		end
		if filterBox then
			filterBox:ReleaseFocus()
			filterBox.Text = ""
		end
		Gui.glide(panel, { Size = UDim2.fromScale(1, 0) }, Gui.motion.base)
		Gui.glide(arrow, { Rotation = 90 }, Gui.motion.base)
		Gui.tween(arrow, { TextColor3 = theme.subtext })
		Gui.tween(box, { BackgroundTransparency = 0.25 })
		task.delay(0.15, function()
			if not self.open then
				panel.Visible = false
			end
		end)
	end

	function control:SetValues(values, icons)
		self.values = values
		self.icons = icons or self.icons
		if not self.multi and self.value and not table.find(values, self.value) then
			self.value = nil
		end
		self.dirty = true
		if self.open then
			self:rebuild()
			Gui.tween(panel, { Size = UDim2.new(1, 0, 0, self:panelHeight()) })
		end
		self:render()
	end

	-- Redraw previews (e.g. after the host changed the color they use)
	function control:RefreshPreviews()
		self.previewValue = nil
		self:SetValues(self.values)
	end

	if filterBox then
		filterBox:GetPropertyChangedSignal("Text"):Connect(function()
			control.filter = filterBox.Text:lower()
			control:applyFilter()
			if control.open then
				Gui.tween(panel, { Size = UDim2.new(1, 0, 0, control:panelHeight()) })
			end
		end)
	end
	box.MouseButton1Click:Connect(function()
		control:setOpen(not control.open)
	end)
	Gui.hover(box, function()
		if not control.open then
			Gui.tween(box, { BackgroundTransparency = 0.05 })
		end
	end, function()
		if not control.open then
			Gui.tween(box, { BackgroundTransparency = 0.25 })
		end
	end)
	control:render()
	Gui.bind(id, control, "dropdown", options)
	return control
end

function Gui.closeDropdown()
	if Gui.openDropdown then
		Gui.openDropdown:setOpen(false)
	end
end

function Gui.Section:AddInput(_, options)
	local theme = Gui.theme
	local _, holder = self:card(options, Vector2.new(160, 28), false)
	local field = Gui.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = theme.control, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = holder })
	Gui.corner(field, 7)
	local stroke = Gui.stroke(field, theme.border, 0.92)
	local box = Gui.create("TextBox", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "", PlaceholderText = options.Placeholder or "", PlaceholderColor3 = theme.muted, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = field })
	box.Focused:Connect(function()
		Gui.tween(stroke, { Color = theme.accent, Transparency = 0.45 })
	end)
	box.FocusLost:Connect(function()
		Gui.tween(stroke, { Color = theme.border, Transparency = 0.92 })
		if options.Callback then
			pcall(options.Callback, box.Text)
		end
	end)
	return box
end

function Gui.Section:AddLabel(options)
	local row = self:card({ Text = "" }, nil, false)
	row:FindFirstChildWhichIsA("Frame"):Destroy()
	local label = Gui.text({ Text = options.Text, TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = Gui.theme.subtext, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = row })
	local control = {}
	function control:Set(text)
		label.Text = text
	end
	return control
end

-- Left/right rows (coin bags), reused between updates
function Gui.Section:AddInfoList()
	local theme = Gui.theme
	local row = self:card({ Text = "" }, nil, false)
	row:FindFirstChildWhichIsA("Frame"):Destroy()
	local empty = Gui.text({ Text = "Nothing yet", TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = theme.muted, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0, Parent = row })
	local control = { rows = {} }
	function control:SetRows(rows)
		empty.Visible = #rows == 0
		for index, data in rows do
			local entry = self.rows[index]
			if not entry then
				local frame = Gui.create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = theme.control, BackgroundTransparency = 0.4, BorderSizePixel = 0, LayoutOrder = index, Parent = row })
				Gui.corner(frame, 6)
				entry = {
					frame = frame,
					left = Gui.text({ TextSize = 12, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, -10, 1, 0), Parent = frame }),
					right = Gui.text({ TextSize = 12, TextColor3 = theme.subtext, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, -10, 1, 0), Parent = frame }),
				}
				self.rows[index] = entry
			end
			entry.frame.Visible = true
			entry.left.Text = data.Left
			entry.right.Text = data.Right
		end
		for index = #rows + 1, #self.rows do
			self.rows[index].frame.Visible = false
		end
	end
	return control
end


return Gui
