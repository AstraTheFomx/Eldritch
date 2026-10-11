local EldritchLib = {}
EldritchLib.Theme = {
    Background = Color3.fromRGB(30, 22, 31),
    Header = Color3.fromRGB(38, 27, 40),
    TabBar = Color3.fromRGB(30, 22, 31),
    Row = Color3.fromRGB(48, 35, 51),
    Input = Color3.fromRGB(20, 13, 21),
    Accent = Color3.fromRGB(255, 122, 197),
    AccentDark = Color3.fromRGB(199, 74, 146),
    Text = Color3.fromRGB(255, 231, 243),
    Dim = Color3.fromRGB(201, 168, 190),
    Stroke = Color3.fromRGB(74, 51, 72),
    TabIdle = Color3.fromRGB(58, 44, 62),
    Success = Color3.fromRGB(255, 122, 197)
}

local cloneref = (typeof and typeof(cloneref) == "function" and cloneref)
    or (type(rawget(_G, "cloneref")) == "function" and rawget(_G, "cloneref"))
    or (type(clone_ref) == "function" and clone_ref)
    or function(x) return x end

local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local LocalPlayer = Players.LocalPlayer

local function tween(obj, props, time)
    local ok, tw = pcall(function()
        return TweenService:Create(obj, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and tw then
        tw:Play()
        return tw
    else
        for k, v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
        return nil
    end
end

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or EldritchLib.Theme.Stroke
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function makeText(className, text, size, color, bold)
    local l = Instance.new(className)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or EldritchLib.Theme.Text
    l.TextSize = size or 13
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextTruncate = Enum.TextTruncate.AtEnd
    return l
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local args = {...}
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args))
        if not ok then
            warn("[EldritchLib] callback error: " .. tostring(err))
        end
    end)
end

local function cleanupTask(t)
    local tt = typeof(t)
    if tt == "RBXScriptConnection" then
        pcall(function() t:Disconnect() end)
    elseif type(t) == "thread" then
        pcall(function() task.cancel(t) end)
    elseif tt == "Instance" then
        pcall(function() t:Destroy() end)
    elseif type(t) == "function" then
        pcall(t)
    end
end

local function resolveParent()
    local hui = nil
    if type(gethui) == "function" then
        pcall(function() hui = gethui() end)
    end
    if hui then return hui end
    if CoreGui then return CoreGui end
    return LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")
end

function EldritchLib:CreateWindow(opts)
    opts = opts or {}
    local title = tostring(opts.Title or "Eldritch")
    local size = opts.Size or UDim2.fromOffset(430, 360)
    local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift

    pcall(function()
        local roots = {}
        if type(gethui) == "function" then
            local h = gethui()
            if h then table.insert(roots, h) end
        end
        if CoreGui then table.insert(roots, CoreGui) end
        if LocalPlayer then
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then table.insert(roots, pg) end
        end
        for _, root in ipairs(roots) do
            for _, c in ipairs(root:GetChildren()) do
                if c:IsA("ScreenGui") and string.sub(c.Name, 1, 9) == "Eldritch_" then
                    c:Destroy()
                end
                if c:IsA("Folder") and string.sub(c.Name, 1, 12) == "EldritchESP_" then
                    c:Destroy()
                end
            end
        end
    end)

    local parent = resolveParent()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Eldritch_" .. tostring(math.random(1000, 9999))
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.IgnoreGuiInset = true
    gui.Parent = parent
    pcall(function()
        if type(protect_gui) == "function" then protect_gui(gui) end
        if syn and type(syn.protect_gui) == "function" then syn.protect_gui(gui) end
    end)
    if type(getgenv) == "function" then
        pcall(function() getgenv().__ELDRITCH_GUI = gui end)
    end

    local T = self.Theme

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = size
    main.Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2)
    main.BackgroundColor3 = T.Background
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = gui
    corner(main, 8)
    stroke(main, T.Stroke, 1)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 34)
    header.BackgroundColor3 = T.Header
    header.BorderSizePixel = 0
    header.Parent = main
    corner(header, 8)
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 10)
    headerFix.Position = UDim2.new(0, 0, 1, -10)
    headerFix.BackgroundColor3 = T.Header
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local titleLabel = makeText("TextLabel", title, 13, T.Text, true)
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Size = UDim2.new(0, 24, 0, 24)
    collapseBtn.Position = UDim2.new(1, -30, 0.5, -12)
    collapseBtn.BackgroundColor3 = T.TabIdle
    collapseBtn.TextColor3 = T.Text
    collapseBtn.Text = "-"
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextSize = 14
    collapseBtn.AutoButtonColor = true
    collapseBtn.Parent = header
    corner(collapseBtn, 6)

    local tabBar = Instance.new("ScrollingFrame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, -16, 0, 34)
    tabBar.Position = UDim2.new(0, 8, 0, 40)
    tabBar.BackgroundTransparency = 1
    tabBar.ScrollBarThickness = 0
    tabBar.ScrollingDirection = Enum.ScrollingDirection.X
    tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabBar.CanvasSize = UDim2.fromOffset(0, 0)
    tabBar.Parent = main
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -118)
    content.Position = UDim2.new(0, 8, 0, 78)
    content.BackgroundTransparency = 1
    content.Parent = main

    local accentLine = Instance.new("Frame")
    accentLine.Size = UDim2.new(1, -16, 0, 3)
    accentLine.Position = UDim2.new(0, 8, 1, -8)
    accentLine.BackgroundColor3 = T.Accent
    accentLine.BorderSizePixel = 0
    accentLine.Parent = main
    corner(accentLine, 3)

    local tasks = {}
    local window = {}
    window._gui = gui
    window._main = main
    window._tasks = tasks
    window._pages = {}
    window._buttons = {}
    window._order = 0
    window._selected = nil

    function window:Track(...)
        for _, t in ipairs({...}) do
            table.insert(tasks, t)
        end
        return ...
    end

    function window:Untrack(t)
        for i = #tasks, 1, -1 do
            if tasks[i] == t then
                table.remove(tasks, i)
            end
        end
        return t
    end

    function window:Cleanup()
        for _, t in ipairs(tasks) do
            cleanupTask(t)
        end
        table.clear(tasks)
    end

    local dragging = false
    local dragStart = Vector2.new()
    local frameStart = UDim2.new()
    window:Track(header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = main.Position
            local endConn = nil
            endConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if endConn ~= nil then
                        window:Untrack(endConn)
                        endConn = nil
                    end
                end
            end)
            window:Track(endConn)
        end
    end))
    window:Track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + d.X, frameStart.Y.Scale, frameStart.Y.Offset + d.Y)
        end
    end))

    local collapsed = false
    local preSize = size
    window:Track(collapseBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        collapseBtn.Text = collapsed and "+" or "-"
        if collapsed then
            preSize = main.Size
            tween(main, {Size = UDim2.new(0, preSize.X.Offset, 0, 34)}, 0.18)
            tabBar.Visible = false
            content.Visible = false
            accentLine.Visible = false
        else
            tween(main, {Size = preSize}, 0.18)
            tabBar.Visible = true
            content.Visible = true
            accentLine.Visible = true
        end
    end))

    window:Track(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == toggleKey then
            gui.Enabled = not gui.Enabled
        end
    end))

    function window:SelectTab(name)
        local entry = self._pages[name]
        if not entry then return end
        self._selected = name
        for tabName, e in pairs(self._pages) do
            e.Page.Visible = (tabName == name)
            local b = self._buttons[tabName]
            if b then
                if tabName == name then
                    tween(b, {BackgroundColor3 = T.Accent, TextColor3 = Color3.fromRGB(42, 18, 32)}, 0.15)
                else
                    tween(b, {BackgroundColor3 = T.TabIdle, TextColor3 = T.Text}, 0.15)
                end
            end
        end
    end

    function window:AddTab(name)
        name = tostring(name)
        if self._pages[name] then return self._pages[name].Api end
        self._order = self._order + 1
        local win = self

        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 86, 0, 26)
        btn.BackgroundColor3 = T.TabIdle
        btn.TextColor3 = T.Text
        btn.Text = name
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.LayoutOrder = self._order
        btn.AutoButtonColor = true
        btn.Parent = tabBar
        corner(btn, 6)
        self._buttons[name] = btn

        local page = Instance.new("ScrollingFrame")
        page.Name = name
        page.Size = UDim2.fromScale(1, 1)
        page.BackgroundTransparency = 1
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = T.AccentDark
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.fromOffset(0, 0)
        page.Visible = false
        page.Parent = content
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page
        local pad = Instance.new("UIPadding")
        pad.PaddingRight = UDim.new(0, 4)
        pad.Parent = page

        local holder = page

        win:Track(btn.MouseButton1Click:Connect(function()
            self:SelectTab(name)
        end))

        local function newRow(h)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, h or 32)
            row.BackgroundColor3 = T.Row
            row.BorderSizePixel = 0
            row.LayoutOrder = #holder:GetChildren() * 2
            row.Parent = holder
            corner(row, 6)
            return row
        end

        local tab = {}

        function tab:AddSection(text)
            local s = makeText("TextLabel", tostring(text), 12, T.Accent, true)
            s.Size = UDim2.new(1, 0, 0, 20)
            s.TextXAlignment = Enum.TextXAlignment.Left
            s.LayoutOrder = #page:GetChildren() * 2
            s.Parent = page
            holder = page
            return s
        end

        function tab:AddSubsection(text, collapsed)
            local box = Instance.new("Frame")
            box.Name = "Subsection"
            box.Size = UDim2.new(1, 0, 0, 0)
            box.AutomaticSize = Enum.AutomaticSize.Y
            box.BackgroundTransparency = 1
            box.LayoutOrder = #page:GetChildren() * 2
            box.Parent = page
            local boxLayout = Instance.new("UIListLayout")
            boxLayout.Padding = UDim.new(0, 4)
            boxLayout.SortOrder = Enum.SortOrder.LayoutOrder
            boxLayout.Parent = box
            local head = Instance.new("TextButton")
            head.LayoutOrder = 1
            head.Size = UDim2.new(1, 0, 0, 24)
            head.BackgroundColor3 = T.TabIdle
            head.TextColor3 = T.Accent
            head.Font = Enum.Font.GothamBold
            head.TextSize = 12
            head.AutoButtonColor = true
            head.Parent = box
            corner(head, 6)
            local body = Instance.new("Frame")
            body.LayoutOrder = 2
            body.Size = UDim2.new(1, 0, 0, 0)
            body.AutomaticSize = Enum.AutomaticSize.Y
            body.BackgroundTransparency = 1
            body.Parent = box
            local bodyLayout = Instance.new("UIListLayout")
            bodyLayout.Padding = UDim.new(0, 6)
            bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
            bodyLayout.Parent = body
            local open = not collapsed
            local function paint()
                head.Text = (open and "-  " or "+  ") .. tostring(text)
            end
            paint()
            win:Track(head.MouseButton1Click:Connect(function()
                open = not open
                body.Visible = open
                paint()
            end))
            body.Visible = open
            holder = body
            local api = {}
            function api:SetOpen(v)
                open = (v == true)
                body.Visible = open
                paint()
            end
            return api
        end

        function tab:AddLabel(text)
            local row = newRow(28)
            local l = makeText("TextLabel", tostring(text), 12, T.Text, false)
            l.Size = UDim2.new(1, -16, 1, 0)
            l.Position = UDim2.new(0, 8, 0, 0)
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = row
            local api = {}
            function api:Set(v) l.Text = tostring(v) end
            return api
        end

        function tab:AddButton(text, callback)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 30)
            b.BackgroundColor3 = T.TabIdle
            b.TextColor3 = T.Text
            b.Text = tostring(text)
            b.Font = Enum.Font.GothamBold
            b.TextSize = 13
            b.LayoutOrder = #holder:GetChildren() * 2
            b.AutoButtonColor = true
            b.Parent = holder
            corner(b, 6)
            stroke(b, T.Stroke, 1)
            win:Track(b.MouseEnter:Connect(function()
                tween(b, {BackgroundColor3 = T.AccentDark}, 0.12)
            end))
            win:Track(b.MouseLeave:Connect(function()
                tween(b, {BackgroundColor3 = T.TabIdle}, 0.12)
            end))
            win:Track(b.MouseButton1Click:Connect(function() safeCall(callback) end))
            local api = {}
            function api:Set(v) b.Text = tostring(v) end
            return api
        end

        function tab:AddToggle(text, default, callback)
            if type(default) == "function" then callback, default = default, false end
            local state = (default == true)
            local row = newRow(32)
            local l = makeText("TextLabel", tostring(text), 13, T.Text, false)
            l.Size = UDim2.new(1, -70, 1, 0)
            l.Position = UDim2.new(0, 10, 0, 0)
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = row
            local pill = Instance.new("TextButton")
            pill.Size = UDim2.new(0, 44, 0, 20)
            pill.Position = UDim2.new(1, -54, 0.5, -10)
            pill.BackgroundColor3 = state and T.Accent or T.Input
            pill.Text = ""
            pill.AutoButtonColor = false
            pill.Parent = row
            corner(pill, 10)
            stroke(pill, T.Stroke, 1)
            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            knob.BorderSizePixel = 0
            knob.Parent = pill
            corner(knob, 8)
            local api = {}
            local function apply()
                tween(pill, {BackgroundColor3 = state and T.Accent or T.Input}, 0.15)
                tween(knob, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.15)
            end
            function api:Set(v)
                state = (v == true)
                apply()
            end
            function api:Get() return state end
            win:Track(pill.MouseButton1Click:Connect(function()
                state = not state
                apply()
                safeCall(callback, state)
            end))
            task.defer(function() safeCall(callback, state) end)
            return api
        end

        function tab:AddInput(text, default, callback)
            if type(default) == "function" then callback, default = default, "" end
            local row = newRow(32)
            local l = makeText("TextLabel", tostring(text), 13, T.Text, false)
            l.Size = UDim2.new(0.42, 0, 1, 0)
            l.Position = UDim2.new(0, 10, 0, 0)
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = row
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(0.58, -18, 0, 22)
            box.Position = UDim2.new(0.42, 8, 0.5, -11)
            box.BackgroundColor3 = T.Input
            box.TextColor3 = T.Text
            box.PlaceholderColor3 = T.Dim
            box.Text = tostring(default or "")
            box.Font = Enum.Font.GothamBold
            box.TextSize = 13
            box.ClearTextOnFocus = false
            box.Parent = row
            corner(box, 5)
            win:Track(box.FocusLost:Connect(function(enter)
                if enter then safeCall(callback, box.Text) end
            end))
            local api = {}
            function api:Set(v) box.Text = tostring(v) end
            function api:Get() return box.Text end
            function api:OnChanged(fn)
                win:Track(box:GetPropertyChangedSignal("Text"):Connect(function() safeCall(fn, box.Text) end))
            end
            return api
        end

        function tab:AddSlider(text, min, max, default, callback)
            min = tonumber(min) or 0
            max = tonumber(max) or 100
            default = math.clamp(tonumber(default) or min, min, max)
            local value = default
            local row = newRow(46)
            local l = makeText("TextLabel", tostring(text), 13, T.Text, false)
            l.Size = UDim2.new(1, -70, 0, 18)
            l.Position = UDim2.new(0, 10, 0, 4)
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = row
            local valBox = Instance.new("TextBox")
            valBox.Size = UDim2.new(0, 52, 0, 20)
            valBox.Position = UDim2.new(1, -60, 0, 3)
            valBox.BackgroundColor3 = T.Input
            valBox.TextColor3 = T.Text
            valBox.Text = tostring(value)
            valBox.Font = Enum.Font.GothamBold
            valBox.TextSize = 12
            valBox.Parent = row
            corner(valBox, 5)
            local bar = Instance.new("TextButton")
            bar.Size = UDim2.new(1, -20, 0, 8)
            bar.Position = UDim2.new(0, 10, 0, 30)
            bar.BackgroundColor3 = T.Input
            bar.Text = ""
            bar.AutoButtonColor = false
            bar.Parent = row
            corner(bar, 4)
            local fill = Instance.new("Frame")
            fill.BackgroundColor3 = T.Accent
            fill.BorderSizePixel = 0
            fill.Size = UDim2.fromScale((value - min) / math.max(1, (max - min)), 1)
            fill.Parent = bar
            corner(fill, 4)
            local api = {}
            local function apply(v)
                value = math.clamp(tonumber(v) or min, min, max)
                fill.Size = UDim2.fromScale((value - min) / math.max(1, (max - min)), 1)
                valBox.Text = tostring(math.floor(value + 0.5))
            end
            function api:Set(v) apply(v) end
            function api:Get() return value end
            local sliding = false
            local function fromInput(inputPos)
                local abs = bar.AbsolutePosition.X
                local w = math.max(1, bar.AbsoluteSize.X)
                local a = math.clamp((inputPos.X - abs) / w, 0, 1)
                apply(min + a * (max - min))
                safeCall(callback, value)
            end
            win:Track(bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    fromInput(input.Position)
                end
            end))
            win:Track(UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end))
            win:Track(UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    fromInput(input.Position)
                end
            end))
            win:Track(valBox.FocusLost:Connect(function(enter)
                if enter then
                    apply(tonumber(valBox.Text) or value)
                    safeCall(callback, value)
                end
            end))
            task.defer(function() safeCall(callback, value) end)
            return api
        end

        function tab:AddDropdown(text, options, default, callback)
            options = (type(options) == "table" and options) or {}
            local current = tostring(default or options[1] or "")
            local row = newRow(32)
            local l = makeText("TextLabel", tostring(text), 13, T.Text, false)
            l.Size = UDim2.new(0.42, 0, 1, 0)
            l.Position = UDim2.new(0, 10, 0, 0)
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = row
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.58, -18, 0, 22)
            btn.Position = UDim2.new(0.42, 8, 0.5, -11)
            btn.BackgroundColor3 = T.Input
            btn.TextColor3 = T.Text
            btn.Text = current .. "  v"
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            btn.Parent = row
            corner(btn, 5)
            local list = Instance.new("Frame")
            list.Size = UDim2.new(1, 0, 0, 0)
            list.BackgroundColor3 = T.Header
            list.BorderSizePixel = 0
            list.LayoutOrder = #holder:GetChildren() * 2 + 1
            list.Visible = false
            list.AutomaticSize = Enum.AutomaticSize.Y
            list.Parent = holder
            corner(list, 6)
            stroke(list, T.Stroke, 1)
            local listLayout = Instance.new("UIListLayout")
            listLayout.Padding = UDim.new(0, 4)
            listLayout.Parent = list
            local listPad = Instance.new("UIPadding")
            listPad.PaddingTop = UDim.new(0, 4)
            listPad.PaddingBottom = UDim.new(0, 4)
            listPad.PaddingLeft = UDim.new(0, 4)
            listPad.PaddingRight = UDim.new(0, 4)
            listPad.Parent = list
            local api = {}
            local dropConns = {}
            local function rebuild()
                for _, c in ipairs(dropConns) do
                    win:Untrack(c)
                end
                table.clear(dropConns)
                for _, c in ipairs(list:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for _, opt in ipairs(options) do
                    local ob = Instance.new("TextButton")
                    ob.Size = UDim2.new(1, 0, 0, 24)
                    ob.BackgroundColor3 = (tostring(opt) == current) and T.Accent or T.Row
                    ob.TextColor3 = (tostring(opt) == current) and Color3.fromRGB(42, 18, 32) or T.Text
                    ob.Text = tostring(opt)
                    ob.Font = Enum.Font.Gotham
                    ob.TextSize = 12
                    ob.Parent = list
                    corner(ob, 5)
                    table.insert(dropConns, win:Track(ob.MouseButton1Click:Connect(function()
                        current = tostring(opt)
                        btn.Text = current .. "  v"
                        list.Visible = false
                        rebuild()
                        safeCall(callback, current)
                    end)))
                end
            end
            function api:Set(v) current = tostring(v) btn.Text = current .. "  v" rebuild() end
            function api:Get() return current end
            function api:SetOptions(o) options = o rebuild() end
            win:Track(btn.MouseButton1Click:Connect(function()
                list.Visible = not list.Visible
            end))
            rebuild()
            task.defer(function() safeCall(callback, current) end)
            return api
        end

        self._pages[name] = { Page = page, Api = tab }
        if self._order == 1 then
            self:SelectTab(name)
        end
        return tab
    end

    function window:Destroy()
        self:Cleanup()
        gui:Destroy()
    end

    function window:SetVisible(v)
        gui.Enabled = (v == true)
    end

    return window
end

return EldritchLib
