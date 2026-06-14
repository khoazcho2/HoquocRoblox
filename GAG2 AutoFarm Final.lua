-- ╔══════════════════════════════════════════╗
-- ║   GROW A GARDEN 2 — AUTO FARM FINAL     ║
-- ║   HoQuoc Dev | ProximityPrompt Based    ║
-- ╚══════════════════════════════════════════╝

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local LP           = Players.LocalPlayer
local PGui         = LP:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════
local CFG = {
    AutoHarvest   = false,
    AutoSell      = false,
    AutoPlant     = false,
    SpeedBoost    = false,

    HarvestDelay  = 0.15,
    SellDelay     = 2,
    PlantDelay    = 0.3,
    SpeedValue    = 60,

    -- Seed ưu tiên theo thứ tự (cái nào có trong inventory thì dùng)
    SeedPriority  = {
        "Bamboo Seed",
        "Tomato Seed",
        "Blueberry Seed",
        "Tulip Seed",
        "Cherry",
        "Sunflower",
        "Strawberry",
        "Carrot",
    },
}

-- ══════════════════════════════════════════
--  UTILS
-- ══════════════════════════════════════════
local function log(msg)
    print("[GAG2] " .. msg)
end

local function getChar()
    return LP.Character
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(part)
    local root = getRoot()
    if root and part then
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 4, 0))
        task.wait(0.25)
    end
end

-- Fire ProximityPrompt
local function firePrompt(pp)
    local ok, err = pcall(function()
        fireproximityprompt(pp)
    end)
    if not ok then
        -- fallback: trigger bằng cách khác
        pcall(function()
            pp:InputHoldBegin()
            task.wait(0.05)
            pp:InputHoldEnd()
        end)
    end
end

-- ══════════════════════════════════════════
--  AUTO HARVEST
-- ══════════════════════════════════════════
local function doHarvest()
    local root = getRoot()
    if not root then return end

    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local action = pp.ActionText:lower()
            if action == "harvest" or action:find("harvest") then
                local part = pp.Parent:IsA("BasePart") and pp.Parent
                    or pp.Parent:FindFirstChildWhichIsA("BasePart")
                if part then
                    tpTo(part)
                    firePrompt(pp)
                    log("Harvest: " .. pp.Parent.Name)
                    task.wait(CFG.HarvestDelay)
                end
            end
        end
    end
end

-- ══════════════════════════════════════════
--  AUTO SELL — click nút Sell trên UI game
-- ══════════════════════════════════════════
local function clickSellButton()
    -- Tìm nút Sell trong UI game
    for _, gui in ipairs(LP.PlayerGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local txt = gui.Name:lower()
            if txt:find("sell") then
                pcall(function()
                    gui.MouseButton1Click:Fire()
                end)
                log("Click Sell button: " .. gui.Name)
                return true
            end
        end
    end
    return false
end

local function doSell()
    -- Thử click UI button trước
    if not clickSellButton() then
        -- Fallback: tìm ProximityPrompt sell
        for _, pp in ipairs(workspace:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then
                local action = pp.ActionText:lower()
                if action:find("sell") or action:find("submit") then
                    local part = pp.Parent:IsA("BasePart") and pp.Parent
                        or pp.Parent:FindFirstChildWhichIsA("BasePart")
                    if part then
                        tpTo(part)
                        firePrompt(pp)
                        log("Sell via PP: " .. pp.Parent.Name)
                    end
                end
            end
        end
    end
end

-- ══════════════════════════════════════════
--  AUTO PLANT — tìm ô trống + seed trong inventory
-- ══════════════════════════════════════════
local function getBestSeed()
    -- Tìm seed trong tool/inventory của player
    local backpack = LP:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, seedName in ipairs(CFG.SeedPriority) do
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool.Name:lower():find(seedName:lower()) then
                return tool
            end
        end
        -- Check tay đang cầm
        local char = getChar()
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") and tool.Name:lower():find(seedName:lower()) then
                    return tool
                end
            end
        end
    end
    return nil
end

local function doPlant()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local action = pp.ActionText:lower()
            if action:find("plant") or action:find("seed") or action:find("sow") then
                local part = pp.Parent:IsA("BasePart") and pp.Parent
                    or pp.Parent:FindFirstChildWhichIsA("BasePart")
                if part then
                    tpTo(part)
                    firePrompt(pp)
                    log("Plant: " .. pp.Parent.Name)
                    task.wait(CFG.PlantDelay)
                end
            end
        end
    end
end

-- ══════════════════════════════════════════
--  SPEED BOOST
-- ══════════════════════════════════════════
local function applySpeed(on)
    local char = getChar() or LP.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = on and CFG.SpeedValue or 16
        log("Speed = " .. hum.WalkSpeed)
    end
end

LP.CharacterAdded:Connect(function(char)
    if CFG.SpeedBoost then
        local hum = char:WaitForChild("Humanoid")
        task.wait(1)
        hum.WalkSpeed = CFG.SpeedValue
    end
end)

-- ══════════════════════════════════════════
--  LOOPS
-- ══════════════════════════════════════════
task.spawn(function()
    while true do
        if CFG.AutoHarvest then pcall(doHarvest) end
        task.wait(1)
    end
end)

task.spawn(function()
    while true do
        if CFG.AutoSell then pcall(doSell) end
        task.wait(CFG.SellDelay)
    end
end)

task.spawn(function()
    while true do
        if CFG.AutoPlant then pcall(doPlant) end
        task.wait(1.5)
    end
end)

-- ══════════════════════════════════════════
--  GUI — SPEED HUB STYLE
-- ══════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name = "GAG2Final"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 290, 0, 420)
Main.Position = UDim2.new(0, 16, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
local MS = Instance.new("UIStroke", Main)
MS.Color = Color3.fromRGB(60, 200, 80)
MS.Thickness = 1.3

-- Gradient
local UIG = Instance.new("UIGradient", Main)
UIG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14,32,18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12,14,22)),
})
UIG.Rotation = 110

-- Title bar
local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Color3.fromRGB(18, 60, 28)
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 14)
local TFix = Instance.new("Frame", TopBar)
TFix.Size = UDim2.new(1, 0, 0.5, 0)
TFix.Position = UDim2.new(0, 0, 0.5, 0)
TFix.BackgroundColor3 = Color3.fromRGB(18, 60, 28)
TFix.BorderSizePixel = 0

local TitleL = Instance.new("TextLabel", TopBar)
TitleL.Size = UDim2.new(1, -45, 0, 26)
TitleL.Position = UDim2.new(0, 12, 0, 4)
TitleL.BackgroundTransparency = 1
TitleL.Text = "🌿 Grow A Garden 2"
TitleL.TextColor3 = Color3.fromRGB(160, 255, 160)
TitleL.TextSize = 15
TitleL.Font = Enum.Font.GothamBold
TitleL.TextXAlignment = Enum.TextXAlignment.Left

local SubL = Instance.new("TextLabel", TopBar)
SubL.Size = UDim2.new(1, -45, 0, 14)
SubL.Position = UDim2.new(0, 12, 0, 30)
SubL.BackgroundTransparency = 1
SubL.Text = "HoQuoc Dev  •  v2.1 Final"
SubL.TextColor3 = Color3.fromRGB(80, 180, 100)
SubL.TextSize = 10
SubL.Font = Enum.Font.Gotham
SubL.TextXAlignment = Enum.TextXAlignment.Left

local CloseB = Instance.new("TextButton", TopBar)
CloseB.Size = UDim2.new(0, 26, 0, 26)
CloseB.Position = UDim2.new(1, -32, 0.5, -13)
CloseB.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseB.Text = "✕"
CloseB.TextColor3 = Color3.white
CloseB.TextSize = 13
CloseB.Font = Enum.Font.GothamBold
CloseB.BorderSizePixel = 0
Instance.new("UICorner", CloseB).CornerRadius = UDim.new(0, 6)
CloseB.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Content scroll
local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -16, 1, -60)
Scroll.Position = UDim2.new(0, 8, 0, 54)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 200, 80)
Scroll.CanvasSize = UDim2.new()
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local LL = Instance.new("UIListLayout", Scroll)
LL.Padding = UDim.new(0, 6)
local LP2 = Instance.new("UIPadding", Scroll)
LP2.PaddingTop = UDim.new(0, 4)

-- Widget helpers
local function secLabel(txt, order)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(60, 200, 80)
    l.TextSize = 11
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center
end

local function toggle(icon, label, cfgKey, order, cb)
    local on = CFG[cfgKey]
    local f = Instance.new("TextButton", Scroll)
    f.Size = UDim2.new(1, 0, 0, 46)
    f.BackgroundColor3 = on and Color3.fromRGB(18,65,28) or Color3.fromRGB(20,22,34)
    f.BorderSizePixel = 0
    f.Text = ""
    f.LayoutOrder = order
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    local fs = Instance.new("UIStroke", f)
    fs.Color = on and Color3.fromRGB(50,200,70) or Color3.fromRGB(40,42,60)
    fs.Thickness = 1

    local ico = Instance.new("TextLabel", f)
    ico.Size = UDim2.new(0, 36, 1, 0)
    ico.BackgroundTransparency = 1
    ico.Text = icon
    ico.TextSize = 20
    ico.Font = Enum.Font.Gotham

    local lbl = Instance.new("TextLabel", f)
    lbl.Size = UDim2.new(1, -88, 1, 0)
    lbl.Position = UDim2.new(0, 38, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = on and Color3.fromRGB(200,255,200) or Color3.fromRGB(170,170,190)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Pill toggle
    local pill = Instance.new("Frame", f)
    pill.Size = UDim2.new(0, 46, 0, 24)
    pill.Position = UDim2.new(1, -52, 0.5, -12)
    pill.BackgroundColor3 = on and Color3.fromRGB(40,210,70) or Color3.fromRGB(45,47,68)
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame", pill)
    dot.Size = UDim2.new(0, 18, 0, 18)
    dot.Position = on and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
    dot.BackgroundColor3 = Color3.white
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    f.MouseButton1Click:Connect(function()
        CFG[cfgKey] = not CFG[cfgKey]
        local s = CFG[cfgKey]
        TweenService:Create(f,   TweenInfo.new(0.18), {BackgroundColor3 = s and Color3.fromRGB(18,65,28)    or Color3.fromRGB(20,22,34)}):Play()
        TweenService:Create(fs,  TweenInfo.new(0.18), {Color            = s and Color3.fromRGB(50,200,70)   or Color3.fromRGB(40,42,60)}):Play()
        TweenService:Create(pill,TweenInfo.new(0.18), {BackgroundColor3 = s and Color3.fromRGB(40,210,70)   or Color3.fromRGB(45,47,68)}):Play()
        TweenService:Create(dot, TweenInfo.new(0.18), {Position         = s and UDim2.new(1,-21,0.5,-9)     or UDim2.new(0,3,0.5,-9)}):Play()
        lbl.TextColor3 = s and Color3.fromRGB(200,255,200) or Color3.fromRGB(170,170,190)
        log(label .. " -> " .. (s and "BẬT" or "TẮT"))
        if cb then cb(s) end
    end)
end

local function inputRow(labelTxt, default, order, onChange)
    local f = Instance.new("Frame", Scroll)
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(0.55, 0, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = labelTxt
    l.TextColor3 = Color3.fromRGB(160, 200, 160)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left

    local tb = Instance.new("TextBox", f)
    tb.Size = UDim2.new(0, 100, 0, 26)
    tb.Position = UDim2.new(1, -108, 0.5, -13)
    tb.BackgroundColor3 = Color3.fromRGB(14, 30, 18)
    tb.TextColor3 = Color3.fromRGB(160, 255, 160)
    tb.Text = tostring(default)
    tb.TextSize = 12
    tb.Font = Enum.Font.Gotham
    tb.BorderSizePixel = 0
    tb.ClearTextOnFocus = false
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)
    Instance.new("UIPadding", tb).PaddingLeft = UDim.new(0, 6)
    tb.FocusLost:Connect(function() if onChange then onChange(tb.Text) end end)
end

-- Build UI
secLabel("── AUTO FARM ──", 1)
toggle("🧺", "Auto Harvest",  "AutoHarvest", 2)
toggle("🌱", "Auto Plant",    "AutoPlant",   3)
toggle("💰", "Auto Sell",     "AutoSell",    4)

secLabel("── UTILS ──", 5)
toggle("⚡", "Speed Boost", "SpeedBoost", 6, function(on)
    applySpeed(on)
end)
inputRow("🏃 WalkSpeed", CFG.SpeedValue, 7, function(v)
    CFG.SpeedValue = tonumber(v) or 60
    if CFG.SpeedBoost then applySpeed(true) end
end)

secLabel("── DELAYS ──", 8)
inputRow("⏱ Harvest Delay", CFG.HarvestDelay, 9,  function(v) CFG.HarvestDelay = tonumber(v) or 0.15 end)
inputRow("⏱ Sell Delay",    CFG.SellDelay,    10, function(v) CFG.SellDelay    = tonumber(v) or 2    end)

-- Status bar
local StatF = Instance.new("Frame", Main)
StatF.Size = UDim2.new(1, -16, 0, 22)
StatF.Position = UDim2.new(0, 8, 1, -28)
StatF.BackgroundColor3 = Color3.fromRGB(16, 40, 20)
StatF.BorderSizePixel = 0
Instance.new("UICorner", StatF).CornerRadius = UDim.new(0, 6)
local StatL = Instance.new("TextLabel", StatF)
StatL.Size = UDim2.new(1, -10, 1, 0)
StatL.Position = UDim2.new(0, 6, 0, 0)
StatL.BackgroundTransparency = 1
StatL.TextColor3 = Color3.fromRGB(120, 210, 130)
StatL.TextSize = 10
StatL.Font = Enum.Font.Gotham
StatL.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while StatL and StatL.Parent do
        local t = {}
        if CFG.AutoHarvest then table.insert(t, "🧺Harvest") end
        if CFG.AutoPlant    then table.insert(t, "🌱Plant") end
        if CFG.AutoSell     then table.insert(t, "💰Sell") end
        if CFG.SpeedBoost   then table.insert(t, "⚡Speed") end
        StatL.Text = #t > 0 and ("✅ " .. table.concat(t, " · ")) or "⏸ Chưa bật tính năng nào"
        task.wait(2)
    end
end)

-- Minimize
local minimized = false
TopBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        minimized = not minimized
        TweenService:Create(Main, TweenInfo.new(0.2), {
            Size = minimized and UDim2.new(0,290,0,48) or UDim2.new(0,290,0,420)
        }):Play()
    end
end)

log("✅ GAG2 Final loaded! HoQuoc Dev")
