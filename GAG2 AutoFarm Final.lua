-- ╔══════════════════════════════════════════╗
-- ║   GROW A GARDEN 2 — HoQuoc Dev v2.3     ║
-- ╚══════════════════════════════════════════╝

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP           = Players.LocalPlayer
local PGui         = LP:WaitForChild("PlayerGui")

-- CONFIG
local CFG = {
    AutoHarvest   = false,
    AutoPlant     = false,
    AutoSell      = false,
    SpeedBoost    = false,
    TeleportMode  = true,   -- true = tele đến cây | false = đứng im fire range
    HarvestDelay  = 0.15,
    SellDelay     = 3,
    SpeedValue    = 60,
    HarvestRange  = 15,     -- range khi đứng im (studs)
}

-- UTILS
local function getRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
        task.wait(0.2)
    end
end

local function firePrompt(pp)
    pcall(fireproximityprompt, pp)
end

local function distTo(part)
    local root = getRoot()
    if not root or not part then return math.huge end
    return (root.Position - part.Position).Magnitude
end

-- AUTO HARVEST
local function doHarvest()
    local root = getRoot()
    if not root then return end

    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("harvest") then
            local part = pp.Parent:IsA("BasePart") and pp.Parent
                or pp.Parent:FindFirstChildWhichIsA("BasePart")
            if part then
                if CFG.TeleportMode then
                    -- Tele đến cây rồi harvest
                    tpTo(part.Position)
                    firePrompt(pp)
                    task.wait(CFG.HarvestDelay)
                else
                    -- Đứng im, chỉ harvest cây trong range
                    if distTo(part) <= CFG.HarvestRange then
                        firePrompt(pp)
                        task.wait(CFG.HarvestDelay)
                    end
                end
            end
        end
    end
end

-- AUTO PLANT
local function doPlant()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("plant") or a:find("seed") or a:find("sow") then
                local part = pp.Parent:IsA("BasePart") and pp.Parent
                    or pp.Parent:FindFirstChildWhichIsA("BasePart")
                if part then
                    if CFG.TeleportMode then
                        tpTo(part.Position)
                    end
                    firePrompt(pp)
                    task.wait(0.3)
                end
            end
        end
    end
end

-- AUTO SELL
local function doSell()
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Name:lower():find("sell") then
            pcall(function() v.MouseButton1Click:Fire() end)
            return
        end
    end
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("sell") then
            local part = pp.Parent:IsA("BasePart") and pp.Parent
                or pp.Parent:FindFirstChildWhichIsA("BasePart")
            if part then
                tpTo(part.Position)
                firePrompt(pp)
            end
        end
    end
end

-- SPEED
local function applySpeed(on)
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = on and CFG.SpeedValue or 16 end
end

LP.CharacterAdded:Connect(function(char)
    if CFG.SpeedBoost then
        task.wait(1)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = CFG.SpeedValue end
    end
end)

-- LOOPS
task.spawn(function()
    while true do
        if CFG.AutoHarvest then pcall(doHarvest) end
        task.wait(0.8)
    end
end)
task.spawn(function()
    while true do
        if CFG.AutoPlant then pcall(doPlant) end
        task.wait(1.5)
    end
end)
task.spawn(function()
    while true do
        if CFG.AutoSell then pcall(doSell) end
        task.wait(CFG.SellDelay)
    end
end)

-- ══════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════
local old = PGui:FindFirstChild("GAG2_UI")
if old then old:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "GAG2_UI"
SG.ResetOnSpawn = false
SG.Parent = PGui

local Main = Instance.new("Frame", SG)
Main.Size = UDim2.new(0, 270, 0, 430)
Main.Position = UDim2.new(0, 10, 0, 80)
Main.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
local outline = Instance.new("UIStroke", Main)
outline.Color = Color3.fromRGB(50, 200, 80)
outline.Thickness = 1.5

-- Title bar
local TBar = Instance.new("Frame", Main)
TBar.Size = UDim2.new(1, 0, 0, 44)
TBar.BackgroundColor3 = Color3.fromRGB(22, 70, 35)
TBar.BorderSizePixel = 0
Instance.new("UICorner", TBar).CornerRadius = UDim.new(0, 14)
local fix = Instance.new("Frame", TBar)
fix.Size = UDim2.new(1, 0, 0.5, 0)
fix.Position = UDim2.new(0, 0, 0.5, 0)
fix.BackgroundColor3 = Color3.fromRGB(22, 70, 35)
fix.BorderSizePixel = 0

local T1 = Instance.new("TextLabel", TBar)
T1.Size = UDim2.new(1, -40, 0, 24)
T1.Position = UDim2.new(0, 10, 0, 4)
T1.BackgroundTransparency = 1
T1.Text = "🌿 Grow A Garden 2"
T1.TextColor3 = Color3.fromRGB(150, 255, 150)
T1.TextSize = 14
T1.Font = Enum.Font.GothamBold
T1.TextXAlignment = Enum.TextXAlignment.Left

local T2 = Instance.new("TextLabel", TBar)
T2.Size = UDim2.new(1, -40, 0, 14)
T2.Position = UDim2.new(0, 10, 0, 28)
T2.BackgroundTransparency = 1
T2.Text = "HoQuoc Dev  •  v2.3"
T2.TextColor3 = Color3.fromRGB(80, 180, 100)
T2.TextSize = 10
T2.Font = Enum.Font.Gotham
T2.TextXAlignment = Enum.TextXAlignment.Left

local XBtn = Instance.new("TextButton", TBar)
XBtn.Size = UDim2.new(0, 26, 0, 26)
XBtn.Position = UDim2.new(1, -32, 0.5, -13)
XBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
XBtn.Text = "✕"
XBtn.TextColor3 = Color3.white
XBtn.TextSize = 13
XBtn.Font = Enum.Font.GothamBold
XBtn.BorderSizePixel = 0
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 6)
XBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Toggle + Divider factory
local yOff = 52

local function mkDiv(txt)
    local f = Instance.new("Frame", Main)
    f.Size = UDim2.new(1, -16, 0, 18)
    f.Position = UDim2.new(0, 8, 0, yOff)
    f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(60, 180, 80)
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Center
    yOff = yOff + 22
end

local function mkToggle(icon, label, key, cb)
    local btn = Instance.new("TextButton", Main)
    btn.Size = UDim2.new(1, -16, 0, 44)
    btn.Position = UDim2.new(0, 8, 0, yOff)
    btn.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
    btn.BorderSizePixel = 0
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local sk = Instance.new("UIStroke", btn)
    sk.Color = Color3.fromRGB(40, 44, 64)
    sk.Thickness = 1

    local iL = Instance.new("TextLabel", btn)
    iL.Size = UDim2.new(0, 34, 1, 0)
    iL.BackgroundTransparency = 1
    iL.Text = icon
    iL.TextSize = 20
    iL.Font = Enum.Font.Gotham

    local lL = Instance.new("TextLabel", btn)
    lL.Size = UDim2.new(1, -90, 1, 0)
    lL.Position = UDim2.new(0, 36, 0, 0)
    lL.BackgroundTransparency = 1
    lL.Text = label
    lL.TextColor3 = Color3.fromRGB(180, 180, 200)
    lL.TextSize = 13
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local pill = Instance.new("Frame", btn)
    pill.Size = UDim2.new(0, 44, 0, 22)
    pill.Position = UDim2.new(1, -50, 0.5, -11)
    pill.BackgroundColor3 = Color3.fromRGB(44, 46, 68)
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame", pill)
    dot.Size = UDim2.new(0, 16, 0, 16)
    dot.Position = UDim2.new(0, 3, 0.5, -8)
    dot.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on = CFG[key]
        TweenService:Create(btn,  TweenInfo.new(0.2), {BackgroundColor3 = on and Color3.fromRGB(18,60,28)  or Color3.fromRGB(24,28,42)}):Play()
        TweenService:Create(sk,   TweenInfo.new(0.2), {Color            = on and Color3.fromRGB(50,200,70) or Color3.fromRGB(40,44,64)}):Play()
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = on and Color3.fromRGB(40,210,70) or Color3.fromRGB(44,46,68)}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.2), {Position         = on and UDim2.new(1,-19,0.5,-8)   or UDim2.new(0,3,0.5,-8)}):Play()
        lL.TextColor3 = on and Color3.fromRGB(200,255,200) or Color3.fromRGB(180,180,200)
    end

    btn.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        refresh()
        if cb then cb(CFG[key]) end
    end)

    yOff = yOff + 50
end

-- Mode toggle (Teleport vs Đứng im)
local function mkModeToggle()
    local btn = Instance.new("TextButton", Main)
    btn.Size = UDim2.new(1, -16, 0, 44)
    btn.Position = UDim2.new(0, 8, 0, yOff)
    btn.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
    btn.BorderSizePixel = 0
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local sk = Instance.new("UIStroke", btn)
    sk.Color = Color3.fromRGB(60, 120, 200)
    sk.Thickness = 1

    local iL = Instance.new("TextLabel", btn)
    iL.Size = UDim2.new(0, 34, 1, 0)
    iL.BackgroundTransparency = 1
    iL.Text = "🚀"
    iL.TextSize = 20
    iL.Font = Enum.Font.Gotham

    local lL = Instance.new("TextLabel", btn)
    lL.Size = UDim2.new(1, -90, 1, 0)
    lL.Position = UDim2.new(0, 36, 0, 0)
    lL.BackgroundTransparency = 1
    lL.Text = CFG.TeleportMode and "Mode: Teleport" or "Mode: Đứng im"
    lL.TextColor3 = Color3.fromRGB(140, 180, 255)
    lL.TextSize = 12
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", btn)
    sub.Size = UDim2.new(1, -90, 0, 14)
    sub.Position = UDim2.new(0, 36, 1, -18)
    sub.BackgroundTransparency = 1
    sub.Text = CFG.TeleportMode and "Tự tele đến từng cây" or "Đứng im, hái trong range"
    sub.TextColor3 = Color3.fromRGB(100, 130, 180)
    sub.TextSize = 10
    sub.Font = Enum.Font.Gotham
    sub.TextXAlignment = Enum.TextXAlignment.Left

    btn.MouseButton1Click:Connect(function()
        CFG.TeleportMode = not CFG.TeleportMode
        lL.Text = CFG.TeleportMode and "Mode: Teleport" or "Mode: Đứng im"
        sub.Text = CFG.TeleportMode and "Tự tele đến từng cây" or "Đứng im, hái trong range"
        TweenService:Create(sk, TweenInfo.new(0.2), {
            Color = CFG.TeleportMode
                and Color3.fromRGB(60,120,200)
                or  Color3.fromRGB(200,150,40)
        }):Play()
    end)

    yOff = yOff + 50
end

-- Build UI
mkDiv("─── AUTO FARM ───")
mkToggle("🧺", "Auto Harvest", "AutoHarvest")
mkToggle("🌱", "Auto Plant",   "AutoPlant")
mkToggle("💰", "Auto Sell",    "AutoSell")
mkDiv("─── UTILS ───")
mkToggle("⚡", "Speed Boost", "SpeedBoost", function(on) applySpeed(on) end)
mkDiv("─── HARVEST MODE ───")
mkModeToggle()

-- Status bar
local statF = Instance.new("Frame", Main)
statF.Size = UDim2.new(1, -16, 0, 26)
statF.Position = UDim2.new(0, 8, 1, -32)
statF.BackgroundColor3 = Color3.fromRGB(14, 32, 18)
statF.BorderSizePixel = 0
Instance.new("UICorner", statF).CornerRadius = UDim.new(0, 8)

local statL = Instance.new("TextLabel", statF)
statL.Size = UDim2.new(1, -8, 1, 0)
statL.Position = UDim2.new(0, 6, 0, 0)
statL.BackgroundTransparency = 1
statL.TextColor3 = Color3.fromRGB(120, 220, 130)
statL.TextSize = 10
statL.Font = Enum.Font.Gotham
statL.TextXAlignment = Enum.TextXAlignment.Left

task.spawn(function()
    while statL and statL.Parent do
        local t = {}
        if CFG.AutoHarvest then table.insert(t, "🧺") end
        if CFG.AutoPlant   then table.insert(t, "🌱") end
        if CFG.AutoSell    then table.insert(t, "💰") end
        if CFG.SpeedBoost  then table.insert(t, "⚡") end
        local mode = CFG.TeleportMode and "🚀TP" or "🧍Im"
        statL.Text = #t > 0
            and ("✅ " .. table.concat(t," ") .. "  " .. mode)
            or  "⏸ Chưa bật tính năng nào"
        task.wait(1.5)
    end
end)

print("✅ GAG2 HoQuoc Dev v2.3 loaded!")
