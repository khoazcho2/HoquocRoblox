-- ╔══════════════════════════════════════════════════╗
-- ║   HỒ QUỐC DEV — GROW A GARDEN 2                ║
-- ║   Full Hub v3.0 | Speed Hub Style               ║
-- ╚══════════════════════════════════════════════════╝

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local LP           = Players.LocalPlayer
local PGui         = LP:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════
local CFG = {
    -- Main
    AutoPlants     = false,
    AutoCollection = false,
    AutoSteal     = false,
    AutoSell       = false,
    AutoPets       = false,
    -- Shop
    AutoBuySeed    = false,
    AutoBuyGear    = false,
    SeedName       = "Bamboo Seed",
    GearName       = "Common Sprinkler",
    -- Misc
    PlayerESP      = false,
    MoreFPS        = false,
    TeleportMode   = true,
    -- Settings
    SpeedBoost     = false,
    SpeedValue     = 60,
    HarvestDelay   = 0.15,
    SellDelay      = 3,
    BuyDelay       = 2,
    HarvestRange   = 15,
}

-- ══════════════════════════════════════════
--  UTILS
-- ══════════════════════════════════════════
local function getRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(pos + Vector3.new(0,4,0))
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

local function getPart(obj)
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChildWhichIsA("BasePart")
end

-- ══════════════════════════════════════════
--  MAIN FUNCTIONS
-- ══════════════════════════════════════════

-- Auto Plants (trồng seed vào ô trống)
local function doPlants()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("plant") or a:find("seed") or a:find("sow") then
                local part = getPart(pp.Parent)
                if part then
                    if CFG.TeleportMode then tpTo(part.Position) end
                    firePrompt(pp)
                    task.wait(0.3)
                end
            end
        end
    end
end

-- Auto Collection (thu hoạch)
local function doCollection()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("harvest") then
            local part = getPart(pp.Parent)
            if part then
                if CFG.TeleportMode then
                    tpTo(part.Position)
                    firePrompt(pp)
                    task.wait(CFG.HarvestDelay)
                else
                    if distTo(part) <= CFG.HarvestRange then
                        firePrompt(pp)
                        task.wait(CFG.HarvestDelay)
                    end
                end
            end
        end
    end
end

-- Auto Sell
local function doSell()
    -- Thử click UI button Sell
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Name:lower():find("sell") then
            pcall(function() v.MouseButton1Click:Fire() end)
            return
        end
    end
    -- Fallback ProximityPrompt
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("sell") then
            local part = getPart(pp.Parent)
            if part then tpTo(part.Position) firePrompt(pp) end
        end
    end
end

-- Auto Buy Seed
local function doBuySeed()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            local o = pp.ObjectText:lower()
            if (a:find("buy") or a:find("purchase")) and
               (o:find(CFG.SeedName:lower()) or pp.Parent.Name:lower():find(CFG.SeedName:lower())) then
                local part = getPart(pp.Parent)
                if part then tpTo(part.Position) firePrompt(pp) task.wait(0.2) end
            end
        end
    end
end

-- Auto Buy Gear
local function doBuyGear()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            local o = pp.ObjectText:lower()
            if (a:find("buy") or a:find("purchase")) and
               (o:find(CFG.GearName:lower()) or pp.Parent.Name:lower():find(CFG.GearName:lower())) then
                local part = getPart(pp.Parent)
                if part then tpTo(part.Position) firePrompt(pp) task.wait(0.2) end
            end
        end
    end
end

-- Speed
local function applySpeed(on)
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = on and CFG.SpeedValue or 16 end
end

LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    if CFG.SpeedBoost then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = CFG.SpeedValue end
    end
end)

-- More FPS
local function applyFPS(on)
    if on then
        setfpscap(60)
        game:GetService("Lighting").GlobalShadows = false
        game:GetService("Lighting").FogEnd = 9e9
        workspace.StreamingEnabled = false
    end
end

-- Player ESP
local espTags = {}
local function removeESP(p)
    if espTags[p] then espTags[p]:Destroy() espTags[p]=nil end
end

local function buildESPTag(player)
    if player == LP then return end
    removeESP(player)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,130,0,44)
    bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true
    bb.Adornee = head
    bb.Parent = head

    local bg = Instance.new("Frame",bb)
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(10,12,20)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    Instance.new("UICorner",bg).CornerRadius = UDim.new(0,7)

    local nL = Instance.new("TextLabel",bg)
    nL.Size = UDim2.new(1,0,0.55,0)
    nL.BackgroundTransparency = 1
    nL.Text = "👤 "..player.Name
    nL.TextColor3 = Color3.fromRGB(100,255,150)
    nL.TextSize = 12
    nL.Font = Enum.Font.GothamBold
    nL.TextScaled = true

    local dL = Instance.new("TextLabel",bg)
    dL.Size = UDim2.new(1,0,0.45,0)
    dL.Position = UDim2.new(0,0,0.55,0)
    dL.BackgroundTransparency = 1
    dL.TextColor3 = Color3.fromRGB(200,200,255)
    dL.TextSize = 10
    dL.Font = Enum.Font.Gotham
    dL.TextScaled = true

    task.spawn(function()
        while bb and bb.Parent and CFG.PlayerESP do
            local root = getRoot()
            local pr = char:FindFirstChild("HumanoidRootPart")
            if root and pr then
                dL.Text = "📍 "..math.floor((root.Position-pr.Position).Magnitude).." studs"
            end
            task.wait(0.5)
        end
        if bb and bb.Parent then bb:Destroy() end
    end)

    espTags[player] = bb
end

local function enableESP()
    for _, p in ipairs(Players:GetPlayers()) do buildESPTag(p) end
    Players.PlayerAdded:Connect(function(p)
        if CFG.PlayerESP then
            p.CharacterAdded:Connect(function() task.wait(1) buildESPTag(p) end)
            buildESPTag(p)
        end
    end)
    for _, p in ipairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function() task.wait(1) if CFG.PlayerESP then buildESPTag(p) end end)
    end
end

local function disableESP()
    for p in pairs(espTags) do removeESP(p) end
end

-- ══════════════════════════════════════════
--  LOOPS
-- ══════════════════════════════════════════
task.spawn(function() while true do if CFG.AutoPlants    then pcall(doPlants)    end task.wait(1.5) end end)
task.spawn(function() while true do if CFG.AutoCollection then pcall(doCollection) end task.wait(0.8) end end)
task.spawn(function() while true do if CFG.AutoSteal    then table.insert(t,"🌙Steal") end
        if CFG.AutoSell      then pcall(doSell)      end task.wait(CFG.SellDelay) end end)
task.spawn(function() while true do if CFG.AutoBuySeed   then pcall(doBuySeed)   end task.wait(CFG.BuyDelay) end end)
task.spawn(function() while true do if CFG.AutoBuyGear   then pcall(doBuyGear)   end task.wait(CFG.BuyDelay+1) end end)

-- ══════════════════════════════════════════
--  GUI — HỒ QUỐC DEV HUB
-- ══════════════════════════════════════════
local old = PGui:FindFirstChild("HoQuocHub")
if old then old:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "HoQuocHub"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PGui

-- ── Main Window
local Win = Instance.new("Frame", SG)
Win.Name = "Window"
Win.Size = UDim2.new(0, 560, 0, 380)
Win.Position = UDim2.new(0.5, -280, 0.5, -190)
Win.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Win).Color = Color3.fromRGB(40, 44, 60)

-- ── Top Bar
local TopBar = Instance.new("Frame", Win)
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)
local tbFix = Instance.new("Frame", TopBar)
tbFix.Size = UDim2.new(1,0,0.5,0)
tbFix.Position = UDim2.new(0,0,0.5,0)
tbFix.BackgroundColor3 = Color3.fromRGB(14,16,24)
tbFix.BorderSizePixel = 0

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size = UDim2.new(1,-100,1,0)
TitleLbl.Position = UDim2.new(0,14,0,0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "Hồ Quốc Dev  |  GAG2 Hub v3.0"
TitleLbl.TextColor3 = Color3.fromRGB(220,80,80)
TitleLbl.TextSize = 13
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

local VerLbl = Instance.new("TextLabel", TopBar)
VerLbl.Size = UDim2.new(0,160,1,0)
VerLbl.Position = UDim2.new(0,220,0,0)
VerLbl.BackgroundTransparency = 1
VerLbl.Text = "discord.gg/hoquocdev"
VerLbl.TextColor3 = Color3.fromRGB(100,100,130)
VerLbl.TextSize = 11
VerLbl.Font = Enum.Font.Gotham
VerLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize + Close
local function topBtn(txt, xOff, col)
    local b = Instance.new("TextButton", TopBar)
    b.Size = UDim2.new(0,26,0,26)
    b.Position = UDim2.new(1,xOff,0.5,-13)
    b.BackgroundColor3 = col
    b.Text = txt
    b.TextColor3 = Color3.white
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    return b
end

local minimized = false
local MinBtn = topBtn("–", -62, Color3.fromRGB(60,130,60))
local CloseBtn2 = topBtn("✕", -32, Color3.fromRGB(180,40,40))

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win, TweenInfo.new(0.25,Enum.EasingStyle.Quart), {
        Size = minimized and UDim2.new(0,560,0,38) or UDim2.new(0,560,0,380)
    }):Play()
    MinBtn.Text = minimized and "+" or "–"
end)

CloseBtn2.MouseButton1Click:Connect(function()
    disableESP()
    SG:Destroy()
end)

-- ── Sidebar
local Sidebar = Instance.new("Frame", Win)
Sidebar.Size = UDim2.new(0, 160, 1, -38)
Sidebar.Position = UDim2.new(0, 0, 0, 38)
Sidebar.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
Sidebar.BorderSizePixel = 0

local SBCorner = Instance.new("UICorner", Sidebar)
SBCorner.CornerRadius = UDim.new(0, 12)
local sbFix = Instance.new("Frame", Sidebar)
sbFix.Size = UDim2.new(0.5,0,1,0)
sbFix.Position = UDim2.new(0.5,0,0,0)
sbFix.BackgroundColor3 = Color3.fromRGB(14,16,24)
sbFix.BorderSizePixel = 0

-- Search box
local SearchBox = Instance.new("TextBox", Sidebar)
SearchBox.Size = UDim2.new(1,-16,0,28)
SearchBox.Position = UDim2.new(0,8,0,8)
SearchBox.BackgroundColor3 = Color3.fromRGB(22,24,34)
SearchBox.TextColor3 = Color3.fromRGB(200,200,220)
SearchBox.PlaceholderText = "🔎 Search"
SearchBox.PlaceholderColor3 = Color3.fromRGB(80,82,100)
SearchBox.Text = ""
SearchBox.TextSize = 12
SearchBox.Font = Enum.Font.Gotham
SearchBox.BorderSizePixel = 0
SearchBox.ClearTextOnFocus = false
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0,7)
Instance.new("UIPadding", SearchBox).PaddingLeft = UDim.new(0,8)

-- Sidebar nav list
local NavList = Instance.new("Frame", Sidebar)
NavList.Size = UDim2.new(1,0,1,-46)
NavList.Position = UDim2.new(0,0,0,44)
NavList.BackgroundTransparency = 1
NavList.BorderSizePixel = 0
local NavLL = Instance.new("UIListLayout", NavList)
NavLL.Padding = UDim.new(0,2)
local NavPad = Instance.new("UIPadding", NavList)
NavPad.PaddingLeft = UDim.new(0,6)
NavPad.PaddingRight = UDim.new(0,6)
NavPad.PaddingTop = UDim.new(0,4)

-- ── Content Area
local Content = Instance.new("Frame", Win)
Content.Size = UDim2.new(1,-160,1,-38)
Content.Position = UDim2.new(0,160,0,38)
Content.BackgroundColor3 = Color3.fromRGB(18,20,28)
Content.BorderSizePixel = 0
Instance.new("UICorner", Content).CornerRadius = UDim.new(0,12)
local cFix = Instance.new("Frame", Content)
cFix.Size = UDim2.new(0,12,1,0)
cFix.BackgroundColor3 = Color3.fromRGB(18,20,28)
cFix.BorderSizePixel = 0

-- Divider line
local Div = Instance.new("Frame", Win)
Div.Size = UDim2.new(0,1,1,-38)
Div.Position = UDim2.new(0,160,0,38)
Div.BackgroundColor3 = Color3.fromRGB(35,38,55)
Div.BorderSizePixel = 0

-- ══════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════
local pages = {}
local navBtns = {}
local currentPage = nil

local function showPage(name)
    for n, pg in pairs(pages) do
        pg.Visible = n == name
    end
    for n, btn in pairs(navBtns) do
        local on = n == name
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = on and Color3.fromRGB(30,34,52) or Color3.fromRGB(0,0,0,0)
        }):Play()
        btn.TextColor3 = on and Color3.white or Color3.fromRGB(140,140,160)
    end
    currentPage = name
end

local function makePage(name)
    local pg = Instance.new("Frame", Content)
    pg.Size = UDim2.new(1,-12,1,0)
    pg.Position = UDim2.new(0,12,0,0)
    pg.BackgroundTransparency = 1
    pg.BorderSizePixel = 0
    pg.Visible = false

    -- Page title
    local ptitle = Instance.new("TextLabel", pg)
    ptitle.Size = UDim2.new(1,0,0,36)
    ptitle.BackgroundTransparency = 1
    ptitle.Text = name
    ptitle.TextColor3 = Color3.white
    ptitle.TextSize = 18
    ptitle.Font = Enum.Font.GothamBold
    ptitle.TextXAlignment = Enum.TextXAlignment.Left
    ptitle.Position = UDim2.new(0,4,0,6)

    -- Line
    local line = Instance.new("Frame", pg)
    line.Size = UDim2.new(1,-8,0,1)
    line.Position = UDim2.new(0,4,0,40)
    line.BackgroundColor3 = Color3.fromRGB(35,38,55)
    line.BorderSizePixel = 0

    -- Scroll
    local scroll = Instance.new("ScrollingFrame", pg)
    scroll.Size = UDim2.new(1,0,1,-48)
    scroll.Position = UDim2.new(0,0,0,46)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(60,200,80)
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local ll = Instance.new("UIListLayout", scroll)
    ll.Padding = UDim.new(0,6)
    local lp = Instance.new("UIPadding", scroll)
    lp.PaddingLeft = UDim.new(0,4)
    lp.PaddingRight = UDim.new(0,8)
    lp.PaddingTop = UDim.new(0,4)
    lp.PaddingBottom = UDim.new(0,8)

    pages[name] = pg
    return pg, scroll
end

local function makeNavBtn(icon, label)
    local btn = Instance.new("TextButton", NavList)
    btn.Size = UDim2.new(1,0,0,36)
    btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
    btn.BackgroundTransparency = 1
    btn.Text = icon .. "  " .. label
    btn.TextColor3 = Color3.fromRGB(140,140,160)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft = UDim.new(0,10)

    navBtns[label] = btn
    btn.MouseButton1Click:Connect(function() showPage(label) end)
    return btn
end

-- ══════════════════════════════════════════
--  WIDGET BUILDERS
-- ══════════════════════════════════════════
local function mkToggleRow(parent, icon, label, key, cb)
    local row = Instance.new("TextButton", parent)
    row.Size = UDim2.new(1,0,0,48)
    row.BackgroundColor3 = Color3.fromRGB(22,24,36)
    row.BorderSizePixel = 0
    row.Text = ""
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
    local rsk = Instance.new("UIStroke", row)
    rsk.Color = Color3.fromRGB(35,38,55)
    rsk.Thickness = 1

    local iL = Instance.new("TextLabel", row)
    iL.Size = UDim2.new(0,36,1,0)
    iL.BackgroundTransparency = 1
    iL.Text = icon
    iL.TextSize = 20
    iL.Font = Enum.Font.Gotham

    local lL = Instance.new("TextLabel", row)
    lL.Size = UDim2.new(1,-100,1,0)
    lL.Position = UDim2.new(0,38,0,0)
    lL.BackgroundTransparency = 1
    lL.Text = label
    lL.TextColor3 = Color3.fromRGB(180,182,200)
    lL.TextSize = 13
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    -- Arrow indicator
    local arr = Instance.new("TextLabel", row)
    arr.Size = UDim2.new(0,20,1,0)
    arr.Position = UDim2.new(1,-60,0,0)
    arr.BackgroundTransparency = 1
    arr.Text = "›"
    arr.TextColor3 = Color3.fromRGB(80,82,100)
    arr.TextSize = 18
    arr.Font = Enum.Font.GothamBold

    -- Pill
    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0,44,0,22)
    pill.Position = UDim2.new(1,-50,0.5,-11)
    pill.BackgroundColor3 = Color3.fromRGB(40,42,62)
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)

    local dot = Instance.new("Frame", pill)
    dot.Size = UDim2.new(0,16,0,16)
    dot.Position = UDim2.new(0,3,0.5,-8)
    dot.BackgroundColor3 = Color3.fromRGB(180,180,200)
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    local function refresh()
        local on = CFG[key]
        TweenService:Create(row,  TweenInfo.new(0.2),{BackgroundColor3= on and Color3.fromRGB(20,50,28) or Color3.fromRGB(22,24,36)}):Play()
        TweenService:Create(rsk,  TweenInfo.new(0.2),{Color           = on and Color3.fromRGB(50,200,70) or Color3.fromRGB(35,38,55)}):Play()
        TweenService:Create(pill, TweenInfo.new(0.2),{BackgroundColor3= on and Color3.fromRGB(40,200,70) or Color3.fromRGB(40,42,62)}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.2),{Position        = on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        lL.TextColor3 = on and Color3.fromRGB(200,255,200) or Color3.fromRGB(180,182,200)
    end

    row.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        refresh()
        if cb then cb(CFG[key]) end
    end)

    return row
end

local function mkInputRow(parent, label, default, onChange)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,44)
    row.BackgroundColor3 = Color3.fromRGB(22,24,36)
    row.BorderSizePixel = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", row).Color = Color3.fromRGB(35,38,55)

    local lL = Instance.new("TextLabel", row)
    lL.Size = UDim2.new(0.55,0,1,0)
    lL.Position = UDim2.new(0,12,0,0)
    lL.BackgroundTransparency = 1
    lL.Text = label
    lL.TextColor3 = Color3.fromRGB(160,162,180)
    lL.TextSize = 12
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local tb = Instance.new("TextBox", row)
    tb.Size = UDim2.new(0,120,0,28)
    tb.Position = UDim2.new(1,-128,0.5,-14)
    tb.BackgroundColor3 = Color3.fromRGB(14,16,26)
    tb.TextColor3 = Color3.fromRGB(160,255,160)
    tb.Text = tostring(default)
    tb.TextSize = 12
    tb.Font = Enum.Font.Gotham
    tb.BorderSizePixel = 0
    tb.ClearTextOnFocus = false
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0,6)
    Instance.new("UIPadding", tb).PaddingLeft = UDim.new(0,6)
    tb.FocusLost:Connect(function() if onChange then onChange(tb.Text) end end)
end

local function mkModeBtn(parent)
    local row = Instance.new("TextButton", parent)
    row.Size = UDim2.new(1,0,0,44)
    row.BackgroundColor3 = Color3.fromRGB(22,24,36)
    row.BorderSizePixel = 0
    row.Text = ""
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
    local rsk = Instance.new("UIStroke", row)
    rsk.Color = Color3.fromRGB(60,100,200)
    rsk.Thickness = 1

    local lL = Instance.new("TextLabel", row)
    lL.Size = UDim2.new(1,-10,1,0)
    lL.Position = UDim2.new(0,12,0,0)
    lL.BackgroundTransparency = 1
    lL.Font = Enum.Font.GothamBold
    lL.TextSize = 12
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local function refreshMode()
        if CFG.TeleportMode then
            lL.Text = "🚀 Harvest Mode: TELEPORT  (tap đổi)"
            lL.TextColor3 = Color3.fromRGB(120,180,255)
            rsk.Color = Color3.fromRGB(60,100,200)
        else
            lL.Text = "🧍 Harvest Mode: ĐỨNG IM  (tap đổi)"
            lL.TextColor3 = Color3.fromRGB(255,200,80)
            rsk.Color = Color3.fromRGB(200,150,40)
        end
    end
    refreshMode()
    row.MouseButton1Click:Connect(function()
        CFG.TeleportMode = not CFG.TeleportMode
        refreshMode()
    end)
end

local function mkSectionLabel(parent, txt)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,22)
    f.BackgroundTransparency = 1
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,0,1,0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(80,84,110)
    l.TextSize = 11
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
end

-- ══════════════════════════════════════════
--  BUILD PAGES
-- ══════════════════════════════════════════

-- HOME
local _, homeScroll = makePage("Home")
local homeLbl = Instance.new("TextLabel", homeScroll)
homeLbl.Size = UDim2.new(1,0,0,80)
homeLbl.BackgroundColor3 = Color3.fromRGB(20,50,28)
homeLbl.TextColor3 = Color3.fromRGB(160,255,160)
homeLbl.Text = "🌿  Hồ Quốc Dev Hub\nGrow A Garden 2 — v3.0"
homeLbl.TextSize = 14
homeLbl.Font = Enum.Font.GothamBold
homeLbl.TextWrapped = true
Instance.new("UICorner", homeLbl).CornerRadius = UDim.new(0,10)

local statusLbl = Instance.new("TextLabel", homeScroll)
statusLbl.Size = UDim2.new(1,0,0,36)
statusLbl.BackgroundColor3 = Color3.fromRGB(14,16,24)
statusLbl.TextColor3 = Color3.fromRGB(120,220,130)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0,8)
Instance.new("UIPadding", statusLbl).PaddingLeft = UDim.new(0,10)

task.spawn(function()
    while statusLbl and statusLbl.Parent do
        local t = {}
        if CFG.AutoPlants     then table.insert(t,"🌱Plants") end
        if CFG.AutoCollection then table.insert(t,"🧺Collect") end
        if CFG.AutoSteal    then table.insert(t,"🌙Steal") end
        if CFG.AutoSell       then table.insert(t,"💰Sell") end
        if CFG.AutoBuySeed    then table.insert(t,"🛒Seed") end
        if CFG.AutoBuyGear    then table.insert(t,"🪣Gear") end
        if CFG.SpeedBoost     then table.insert(t,"⚡Speed") end
        if CFG.PlayerESP      then table.insert(t,"👁ESP") end
        statusLbl.Text = #t>0 and ("✅ "..table.concat(t," · ")) or "⏸ Chưa bật gì"
        task.wait(1.5)
    end
end)

-- MAIN
local _, mainScroll = makePage("Main")
mkSectionLabel(mainScroll, "AUTOMATION")
mkToggleRow(mainScroll,"🌱","Automation Plants",    "AutoPlants")
mkToggleRow(mainScroll,"🧺","Automation Collection","AutoCollection")
mkToggleRow(mainScroll,"💰","Automation Sell",      "AutoSell")
mkSectionLabel(mainScroll,"NIGHT STEAL")
mkToggleRow(mainScroll,"🌙","Auto Steal (ban đêm)","AutoSteal")
mkSectionLabel(mainScroll,"HARVEST MODE")
mkModeBtn(mainScroll)

-- AUTOMATICALLY
local _, autoScroll = makePage("Automatically")
mkSectionLabel(autoScroll,"BUY")
mkToggleRow(autoScroll,"🛒","Auto Buy Seed","AutoBuySeed")
mkInputRow(autoScroll,"Seed Name", CFG.SeedName, function(v) CFG.SeedName=v end)
mkToggleRow(autoScroll,"🪣","Auto Buy Gear","AutoBuyGear")
mkInputRow(autoScroll,"Gear Name", CFG.GearName, function(v) CFG.GearName=v end)

-- SHOP
local _, shopScroll = makePage("Shop")
mkSectionLabel(shopScroll,"SHOP")

local function mkShopBtn(parent, icon, label, sub)
    local row = Instance.new("TextButton", parent)
    row.Size = UDim2.new(1,0,0,52)
    row.BackgroundColor3 = Color3.fromRGB(22,24,36)
    row.BorderSizePixel = 0
    row.Text = ""
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke",row).Color = Color3.fromRGB(35,38,55)

    local iL = Instance.new("TextLabel",row)
    iL.Size = UDim2.new(0,36,1,0)
    iL.BackgroundTransparency = 1
    iL.Text = icon
    iL.TextSize = 22
    iL.Font = Enum.Font.Gotham

    local lL = Instance.new("TextLabel",row)
    lL.Size = UDim2.new(1,-60,0,24)
    lL.Position = UDim2.new(0,38,0,8)
    lL.BackgroundTransparency = 1
    lL.Text = label
    lL.TextColor3 = Color3.white
    lL.TextSize = 13
    lL.Font = Enum.Font.GothamBold
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local sL = Instance.new("TextLabel",row)
    sL.Size = UDim2.new(1,-60,0,16)
    sL.Position = UDim2.new(0,38,0,28)
    sL.BackgroundTransparency = 1
    sL.Text = sub
    sL.TextColor3 = Color3.fromRGB(100,102,130)
    sL.TextSize = 11
    sL.Font = Enum.Font.Gotham
    sL.TextXAlignment = Enum.TextXAlignment.Left

    local arr2 = Instance.new("TextLabel",row)
    arr2.Size = UDim2.new(0,20,1,0)
    arr2.Position = UDim2.new(1,-24,0,0)
    arr2.BackgroundTransparency = 1
    arr2.Text = "›"
    arr2.TextColor3 = Color3.fromRGB(80,82,100)
    arr2.TextSize = 20
    arr2.Font = Enum.Font.GothamBold

    return row
end

mkShopBtn(shopScroll,"🌾","Shop Seeds","Mua seed tự động khi restock")
mkShopBtn(shopScroll,"🪣","Shop Gear","Mua gear, sprinkler tự động")
mkShopBtn(shopScroll,"📦","Shop Crate","Mua crate khi có stock")

-- MISC
local _, miscScroll = makePage("Misc")
mkSectionLabel(miscScroll,"MISC")
mkToggleRow(miscScroll,"👁","Player ESP",   "PlayerESP", function(on)
    if on then enableESP() else disableESP() end
end)
mkToggleRow(miscScroll,"🖼","More FPS",     "MoreFPS", function(on) applyFPS(on) end)

local hopBtn = Instance.new("TextButton", miscScroll)
hopBtn.Size = UDim2.new(1,0,0,44)
hopBtn.BackgroundColor3 = Color3.fromRGB(22,24,36)
hopBtn.BorderSizePixel = 0
hopBtn.Text = ""
Instance.new("UICorner",hopBtn).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke",hopBtn).Color = Color3.fromRGB(35,38,55)
local hopL = Instance.new("TextLabel",hopBtn)
hopL.Size = UDim2.new(1,-10,1,0)
hopL.Position = UDim2.new(0,12,0,0)
hopL.BackgroundTransparency = 1
hopL.Text = "🔄  Hop Server (Rejoin random)"
hopL.TextColor3 = Color3.fromRGB(180,182,200)
hopL.TextSize = 13
hopL.Font = Enum.Font.Gotham
hopL.TextXAlignment = Enum.TextXAlignment.Left
hopBtn.MouseButton1Click:Connect(function()
    local TS = game:GetService("TeleportService")
    TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end)

-- SETTINGS
local _, settScroll = makePage("Settings")
mkSectionLabel(settScroll,"PLAYER")
mkToggleRow(settScroll,"⚡","Speed Boost","SpeedBoost",function(on) applySpeed(on) end)
mkInputRow(settScroll,"🏃 WalkSpeed",     CFG.SpeedValue,    function(v) CFG.SpeedValue=tonumber(v) or 60;  if CFG.SpeedBoost then applySpeed(true) end end)
mkSectionLabel(settScroll,"DELAYS (giây)")
mkInputRow(settScroll,"⏱ Harvest Delay", CFG.HarvestDelay,  function(v) CFG.HarvestDelay=tonumber(v) or 0.15 end)
mkInputRow(settScroll,"⏱ Sell Delay",    CFG.SellDelay,     function(v) CFG.SellDelay=tonumber(v) or 3 end)
mkInputRow(settScroll,"⏱ Buy Delay",     CFG.BuyDelay,      function(v) CFG.BuyDelay=tonumber(v) or 2 end)
mkInputRow(settScroll,"📡 Harvest Range", CFG.HarvestRange,  function(v) CFG.HarvestRange=tonumber(v) or 15 end)

-- SETTINGS UI
local _, suiScroll = makePage("Settings UI")
mkSectionLabel(suiScroll,"WINDOW")
local resetBtn = Instance.new("TextButton",suiScroll)
resetBtn.Size = UDim2.new(1,0,0,44)
resetBtn.BackgroundColor3 = Color3.fromRGB(50,20,20)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "🔄  Reset vị trí UI"
resetBtn.TextColor3 = Color3.fromRGB(255,120,120)
resetBtn.TextSize = 13
resetBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner",resetBtn).CornerRadius = UDim.new(0,10)
resetBtn.MouseButton1Click:Connect(function()
    Win.Position = UDim2.new(0.5,-280,0.5,-190)
end)

-- ══════════════════════════════════════════
--  BUILD NAV BUTTONS
-- ══════════════════════════════════════════
makeNavBtn("🏠","Home")
makeNavBtn("⚙️","Main")
makeNavBtn("▶️","Automatically")
makeNavBtn("🛒","Shop")
makeNavBtn("🔧","Misc")
makeNavBtn("⚙","Settings")
makeNavBtn("🎨","Settings UI")

-- Show Home by default
showPage("Home")

print("✅ Hồ Quốc Dev Hub v3.0 loaded!")

-- ══════════════════════════════════════════
--  AUTO STEAL — chỉ hoạt động ban đêm
-- ══════════════════════════════════════════
CFG.AutoSteal = false

local function isNight()
    local hour = game:GetService("Lighting").ClockTime
    return hour >= 20 or hour < 6
end

local function doSteal()
    if not isNight() then return end
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            local o = pp.ObjectText:lower()
            if a:find("steal") or o:find("steal") or
               a:find("take") or pp.Parent.Name:lower():find("steal") then
                local part = getPart(pp.Parent)
                if part then
                    -- Không steal của chính mình
                    local owner = pp.Parent:GetAttribute("Owner")
                        or pp.Parent:GetAttribute("PlotOwner")
                    if owner == LP.Name then continue end

                    tpTo(part.Position)
                    firePrompt(pp)
                    task.wait(0.3)
                end
            end
        end
    end
end

-- Loop steal
task.spawn(function()
    while true do
        if CFG.AutoSteal then
            if isNight() then
                pcall(doSteal)
            end
        end
        task.wait(1)
    end
end)

-- Thêm vào GUI — tab Main
-- (inject vào page Main đã có)
task.spawn(function()
    task.wait(1)
    local sg = PGui:FindFirstChild("HoQuocHub")
    if not sg then return end
    local win = sg:FindFirstChild("Window")
    if not win then return end
    local content = win:FindFirstChild("Frame") -- Content
    -- Tìm page Main
    for _, pg in ipairs(content:GetChildren()) do
        if pg:IsA("Frame") and pg.Name == "" then
            for _, child in ipairs(pg:GetChildren()) do
                if child:IsA("ScrollingFrame") then
                    -- Thêm section + toggle steal vào scroll
                    local sec = Instance.new("Frame", child)
                    sec.Size = UDim2.new(1,0,0,22)
                    sec.BackgroundTransparency = 1
                    local sl = Instance.new("TextLabel", sec)
                    sl.Size = UDim2.new(1,0,1,0)
                    sl.BackgroundTransparency = 1
                    sl.Text = "NIGHT STEAL"
                    sl.TextColor3 = Color3.fromRGB(80,84,110)
                    sl.TextSize = 11
                    sl.Font = Enum.Font.GothamBold
                    sl.TextXAlignment = Enum.TextXAlignment.Left

                    mkToggleRow(child,"🌙","Auto Steal (ban đêm)","AutoSteal")
                    break
                end
            end
        end
    end
end)
