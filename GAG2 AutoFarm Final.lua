-- ╔══════════════════════════════════════════════════╗
-- ║   HỒ QUỐC DEV — GROW A GARDEN 2  v3.1          ║
-- ║   Fix: NO ScrollingFrame (Delta X iOS compat)   ║
-- ╚══════════════════════════════════════════════════╝

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP           = Players.LocalPlayer
local PGui         = LP:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════
local CFG = {
    AutoPlants     = false,
    AutoCollection = false,
    AutoSell       = false,
    AutoSteal      = false,
    AutoBuySeed    = false,
    AutoBuyGear    = false,
    AutoReplant    = false,
    FruitESP       = false,
    RestockNotify  = false,
    AutoDefend     = false,
    RestockDay     = 300,  -- 5 phut ban ngay
    RestockNight   = 480,  -- 8 phut ban dem
    PlayerESP      = false,
    MoreFPS        = false,
    SpeedBoost     = false,
    TeleportMode   = true,
    SeedName       = "Bamboo Seed",
    GearName       = "Common Sprinkler",
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

local function getPart(obj)
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChildWhichIsA("BasePart")
end

local function distTo(part)
    local root = getRoot()
    if not root or not part then return math.huge end
    return (root.Position - part.Position).Magnitude
end

local function isNight()
    local h = game:GetService("Lighting").ClockTime
    return h >= 20 or h < 6
end

-- ══════════════════════════════════════════
--  FEATURES
-- ══════════════════════════════════════════
local function doPlants()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("plant") or a:find("seed") or a:find("sow") then
                local part = getPart(pp.Parent)
                if part then
                    if CFG.TeleportMode then tpTo(part.Position) end
                    firePrompt(pp) task.wait(0.3)
                end
            end
        end
    end
end

local function doCollection()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("harvest") then
            local part = getPart(pp.Parent)
            if part then
                if CFG.TeleportMode then
                    tpTo(part.Position) firePrompt(pp) task.wait(CFG.HarvestDelay)
                elseif distTo(part) <= CFG.HarvestRange then
                    firePrompt(pp) task.wait(CFG.HarvestDelay)
                end
            end
        end
    end
end

local function doSell()
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Name:lower():find("sell") then
            pcall(function() v.MouseButton1Click:Fire() end) return
        end
    end
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("sell") then
            local part = getPart(pp.Parent)
            if part then tpTo(part.Position) firePrompt(pp) end
        end
    end
end

-- AUTO STEAL — ban đêm, tele đến vườn từng player khác nhặt trái
local function doSteal()
    if not isNight() then return end

    -- Duyệt từng player khác
    for _, target in ipairs(Players:GetPlayers()) do
        if target == LP then continue end
        local tChar = target.Character
        if not tChar then continue end
        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
        if not tRoot then continue end

        -- Tele đến gần vườn của target
        local root = getRoot()
        if not root then return end
        root.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, 4, 4))
        task.wait(0.4)

        -- Tìm tất cả ProximityPrompt trong vùng gần (steal / harvest trên vườn người khác)
        for _, pp in ipairs(workspace:GetDescendants()) do
            if not pp:IsA("ProximityPrompt") then continue end
            local a = pp.ActionText:lower()
            local isStealPrompt = a:find("steal") or a:find("take") or a:find("pick") or a:find("harvest")
            if not isStealPrompt then continue end

            local part = getPart(pp.Parent)
            if not part then continue end

            -- Chỉ nhặt trái gần vườn của target (trong 30 studs)
            local distToTarget = (tRoot.Position - part.Position).Magnitude
            if distToTarget > 30 then continue end

            -- Bỏ qua nếu là vườn mình
            local owner = pp.Parent:GetAttribute("Owner")
                or pp.Parent:GetAttribute("PlotOwner")
                or pp.Parent:GetAttribute("PlayerName")
            if owner and owner == LP.Name then continue end

            -- Tele sát cây rồi fire prompt
            tpTo(part.Position)
            firePrompt(pp)
            task.wait(0.2)
        end

        task.wait(0.3)
    end
end

-- AUTO REPLANT
local function doReplant()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("plant") or a:find("seed") or a:find("empty") then
                local part = getPart(pp.Parent)
                if part then
                    tpTo(part.Position)
                    firePrompt(pp)
                    task.wait(0.3)
                end
            end
        end
    end
end

-- FRUIT ESP
local fruitESPTags = {}
local rarityColors = {
    mythic=Color3.fromRGB(255,50,50), legendary=Color3.fromRGB(255,200,0),
    super=Color3.fromRGB(0,200,255), epic=Color3.fromRGB(180,0,255),
    rare=Color3.fromRGB(0,120,255), uncommon=Color3.fromRGB(0,200,80),
    common=Color3.fromRGB(200,200,200),
}
local function getRarityColor(name)
    local n = name:lower()
    for rarity,color in pairs(rarityColors) do if n:find(rarity) then return color end end
    return rarityColors.common
end
local function clearFruitESP()
    for _,bb in pairs(fruitESPTags) do if bb and bb.Parent then bb:Destroy() end end
    table.clear(fruitESPTags)
end
local function doFruitESP()
    clearFruitESP()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("harvest") then
            local part = getPart(pp.Parent)
            if part then
                local bb = Instance.new("BillboardGui")
                bb.Size=UDim2.new(0,80,0,28) bb.StudsOffset=Vector3.new(0,3,0)
                bb.AlwaysOnTop=true bb.Adornee=part bb.Parent=part
                local bg=Instance.new("Frame",bb)
                bg.Size=UDim2.new(1,0,1,0)
                bg.BackgroundColor3=getRarityColor(pp.Parent.Name)
                bg.BackgroundTransparency=0.3 bg.BorderSizePixel=0
                Instance.new("UICorner",bg).CornerRadius=UDim.new(0,6)
                local lbl=Instance.new("TextLabel",bg)
                lbl.Size=UDim2.new(1,0,1,0) lbl.BackgroundTransparency=1
                lbl.Text="🌿 "..pp.Parent.Name lbl.TextColor3=Color3.white
                lbl.TextSize=10 lbl.Font=Enum.Font.GothamBold lbl.TextScaled=true
                table.insert(fruitESPTags,bb)
            end
        end
    end
end

-- RESTOCK NOTIFIER (5 phút ngày / 8 phút đêm)
local lastRestockNotif = 0
local lastRestockTick  = tick()

local function showNotif(text, color)
    local notif = Instance.new("ScreenGui")
    notif.Name = "HQNotif"
    notif.ResetOnSpawn = false
    notif.Parent = PGui
    local f = Instance.new("Frame", notif)
    f.Size = UDim2.new(0,240,0,46)
    f.Position = UDim2.new(0.5,-120,0,55)
    f.BackgroundColor3 = color or Color3.fromRGB(20,55,28)
    f.BorderSizePixel = 0
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,10)
    local sk = Instance.new("UIStroke",f)
    sk.Color = Color3.fromRGB(255,255,255) sk.Thickness=1
    local l = Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1
    l.Text=text l.TextColor3=Color3.white
    l.TextSize=13 l.Font=Enum.Font.GothamBold l.TextWrapped=true
    task.delay(3, function() if notif and notif.Parent then notif:Destroy() end end)
end

local function checkRestock()
    if not CFG.RestockNotify then return end
    local interval = isNight() and CFG.RestockNight or CFG.RestockDay
    local now = tick()
    if now - lastRestockTick >= interval then
        lastRestockTick = now
        showNotif("🛒 SHOP RESTOCK! Vào mua ngay!", Color3.fromRGB(20,60,28))
    end
    -- Cũng detect từ UI game nếu có text "Restock"
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local txt = v.Text:lower()
            if txt:find("restock") and (txt:find(" 0s") or txt:find("0:00") or txt == "restock") then
                local t2 = tick()
                if t2 - lastRestockNotif > 10 then
                    lastRestockNotif = t2
                    lastRestockTick  = t2
                    showNotif("🛒 SHOP ĐÃ RESTOCK!", Color3.fromRGB(20,60,28))
                end
            end
        end
    end
end

-- ══════════════════════════════════════════
--  AUTO DEFEND — phát hiện kẻ trộm + tele về đánh
-- ══════════════════════════════════════════
local defenderESP = {}

local function clearDefendESP()
    for _, bb in pairs(defenderESP) do
        if bb and bb.Parent then bb:Destroy() end
    end
    table.clear(defenderESP)
end

local function markThief(player)
    if player == LP then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- Xoá ESP cũ của player này
    if defenderESP[player.Name] then
        pcall(function() defenderESP[player.Name]:Destroy() end)
    end

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,120,0,40)
    bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true
    bb.Adornee = head
    bb.Parent = head

    local bg = Instance.new("Frame",bb)
    bg.Size=UDim2.new(1,0,1,0)
    bg.BackgroundColor3=Color3.fromRGB(200,20,20)
    bg.BackgroundTransparency=0.2 bg.BorderSizePixel=0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,7)

    local nl=Instance.new("TextLabel",bg)
    nl.Size=UDim2.new(1,0,0.55,0) nl.BackgroundTransparency=1
    nl.Text="🚨 "..player.Name nl.TextColor3=Color3.white
    nl.TextSize=12 nl.Font=Enum.Font.GothamBold nl.TextScaled=true

    local sl=Instance.new("TextLabel",bg)
    sl.Size=UDim2.new(1,0,0.45,0) sl.Position=UDim2.new(0,0,0.55,0)
    sl.BackgroundTransparency=1 sl.Text="⚠️ ĐANG TRỘM!"
    sl.TextColor3=Color3.fromRGB(255,180,180) sl.TextSize=10
    sl.Font=Enum.Font.GothamBold sl.TextScaled=true

    defenderESP[player.Name] = bb
    task.delay(15, function()
        if bb and bb.Parent then bb:Destroy() end
        defenderESP[player.Name] = nil
    end)
end

local function equipShovel()
    -- Trang bị Shovel (xẻng) từ inventory
    local char = LP.Character
    if not char then return end
    local backpack = LP:FindFirstChild("Backpack")
    if not backpack then return end
    local shovel = backpack:FindFirstChild("Shovel")
        or backpack:FindFirstChildWhichIsA("Tool")
    if shovel then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(shovel) end
    end
end

local function attackThief(targetPlayer)
    local char = LP.Character
    local root = getRoot()
    if not root or not targetPlayer.Character then return end
    local thRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not thRoot then return end

    -- Tele về gần kẻ trộm
    root.CFrame = CFrame.new(thRoot.Position + Vector3.new(0,3,2))
    task.wait(0.2)

    -- Trang bị xẻng
    equipShovel()
    task.wait(0.2)

    -- Swing tool (click)
    local tool = char:FindFirstChildWhichIsA("Tool")
    if tool then
        local event = tool:FindFirstChild("RemoteEvent")
            or tool:FindFirstChildWhichIsA("RemoteEvent")
        if event then
            pcall(function() event:FireServer() end)
        end
        -- Fallback: activate tool
        pcall(function()
            tool:Activate()
        end)
    end
end

local thiefsDetected = {}

local function checkDefend()
    if not CFG.AutoDefend then return end
    -- Scan chat/notification cho thông báo bị trộm
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") or v:IsA("TextBox") then
            local txt = v.Text:lower()
            -- Game hiện "X is stealing from you!" hoặc tương tự
            if txt:find("stealing from you") or txt:find("stole") or txt:find("is stealing") then
                -- Tìm tên player trong text
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and txt:find(p.Name:lower()) then
                        if not thiefsDetected[p.Name] or tick() - thiefsDetected[p.Name] > 10 then
                            thiefsDetected[p.Name] = tick()
                            showNotif("🚨 "..p.Name.." ĐANG TRỘM VƯỜN BẠN!", Color3.fromRGB(120,10,10))
                            markThief(p)
                            task.spawn(function()
                                task.wait(0.5)
                                attackThief(p)
                            end)
                        end
                    end
                end
            end
        end
    end

    -- Cũng detect qua ESP đỏ của game (player có highlight đỏ)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local char = p.Character
            -- Tìm highlight màu đỏ (Highlight object)
            local hl = char:FindFirstChildWhichIsA("Highlight")
                or char:FindFirstChild("SelectionBox")
            if hl then
                local col = nil
                if hl:IsA("Highlight") then col = hl.FillColor end
                if hl:IsA("SelectionBox") then col = hl.Color3 end
                if col then
                    -- Đỏ = kẻ trộm
                    if col.R > 0.6 and col.G < 0.3 and col.B < 0.3 then
                        if not thiefsDetected[p.Name] or tick()-thiefsDetected[p.Name] > 10 then
                            thiefsDetected[p.Name] = tick()
                            showNotif("🚨 "..p.Name.." ĐANG TRỘM!", Color3.fromRGB(120,10,10))
                            markThief(p)
                            task.spawn(function()
                                task.wait(0.3)
                                attackThief(p)
                            end)
                        end
                    end
                end
            end
        end
    end
end

local function doBuySeed()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("buy") and pp.Parent.Name:lower():find(CFG.SeedName:lower()) then
                local part = getPart(pp.Parent)
                if part then tpTo(part.Position) firePrompt(pp) task.wait(0.2) end
            end
        end
    end
end

local function doBuyGear()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("buy") and pp.Parent.Name:lower():find(CFG.GearName:lower()) then
                local part = getPart(pp.Parent)
                if part then tpTo(part.Position) firePrompt(pp) task.wait(0.2) end
            end
        end
    end
end

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

-- ESP
local espTags = {}
local function removeESP(p) if espTags[p] then espTags[p]:Destroy() espTags[p]=nil end end
local function buildESP(player)
    if player == LP then return end
    removeESP(player)
    local char = player.Character if not char then return end
    local head = char:FindFirstChild("Head") if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,130,0,40) bb.StudsOffset = Vector3.new(0,3,0)
    bb.AlwaysOnTop = true bb.Adornee = head bb.Parent = head
    local bg = Instance.new("Frame",bb)
    bg.Size = UDim2.new(1,0,1,0) bg.BackgroundColor3 = Color3.fromRGB(10,12,20)
    bg.BackgroundTransparency = 0.25 bg.BorderSizePixel = 0
    Instance.new("UICorner",bg).CornerRadius = UDim.new(0,7)
    local nL = Instance.new("TextLabel",bg)
    nL.Size = UDim2.new(1,0,0.55,0) nL.BackgroundTransparency = 1
    nL.Text = "👤 "..player.Name nL.TextColor3 = Color3.fromRGB(100,255,150)
    nL.TextSize = 12 nL.Font = Enum.Font.GothamBold nL.TextScaled = true
    local dL = Instance.new("TextLabel",bg)
    dL.Size = UDim2.new(1,0,0.45,0) dL.Position = UDim2.new(0,0,0.55,0)
    dL.BackgroundTransparency = 1 dL.TextColor3 = Color3.fromRGB(200,200,255)
    dL.TextSize = 10 dL.Font = Enum.Font.Gotham dL.TextScaled = true
    task.spawn(function()
        while bb and bb.Parent and CFG.PlayerESP do
            local root = getRoot() local pr = char:FindFirstChild("HumanoidRootPart")
            if root and pr then dL.Text = "📍 "..math.floor((root.Position-pr.Position).Magnitude).." studs" end
            task.wait(0.5)
        end
        if bb and bb.Parent then bb:Destroy() end
    end)
    espTags[player] = bb
end
local function enableESP()
    for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
    Players.PlayerAdded:Connect(function(p) if CFG.PlayerESP then task.wait(1) buildESP(p) end end)
    for _, p in ipairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function() task.wait(1) if CFG.PlayerESP then buildESP(p) end end)
    end
end
local function disableESP() for p in pairs(espTags) do removeESP(p) end end

-- Loops
task.spawn(function() while true do if CFG.AutoPlants     then pcall(doPlants)     end task.wait(1.5) end end)
task.spawn(function() while true do if CFG.AutoCollection then pcall(doCollection) end task.wait(0.8) end end)
task.spawn(function() while true do if CFG.AutoSell       then pcall(doSell)       end task.wait(CFG.SellDelay) end end)
task.spawn(function() while true do if CFG.AutoSteal      then pcall(doSteal)      end task.wait(1) end end)
task.spawn(function() while true do if CFG.AutoReplant    then pcall(doReplant)    end task.wait(2) end end)
task.spawn(function() while true do if CFG.FruitESP       then pcall(doFruitESP)   end task.wait(3) end end)
task.spawn(function() while true do if CFG.RestockNotify  then pcall(checkRestock) end task.wait(1) end end)
task.spawn(function() while true do pcall(checkDefend) task.wait(0.5) end end)
task.spawn(function() while true do if CFG.AutoBuySeed    then pcall(doBuySeed)    end task.wait(CFG.BuyDelay) end end)
task.spawn(function() while true do if CFG.AutoBuyGear    then pcall(doBuyGear)    end task.wait(CFG.BuyDelay+1) end end)

-- ══════════════════════════════════════════
--  GUI — BLACK/GREY SPEED HUB STYLE v3.2
--  Delta X iOS safe — NO ScrollingFrame
-- ══════════════════════════════════════════
local old = PGui:FindFirstChild("HoQuocHub")
if old then old:Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "HoQuocHub"
SG.ResetOnSpawn = false
SG.Parent = PGui

-- Màu theme
local C = {
    bg       = Color3.fromRGB(15, 15, 18),    -- nền chính
    sidebar  = Color3.fromRGB(20, 20, 24),    -- sidebar
    topbar   = Color3.fromRGB(18, 18, 22),    -- topbar
    row      = Color3.fromRGB(26, 26, 32),    -- row item
    rowOn    = Color3.fromRGB(22, 40, 26),    -- row bật
    stroke   = Color3.fromRGB(45, 45, 55),    -- viền
    strokeOn = Color3.fromRGB(60, 180, 70),   -- viền bật
    accent   = Color3.fromRGB(220, 60, 60),   -- đỏ title
    text     = Color3.fromRGB(200, 200, 210), -- text thường
    textOn   = Color3.fromRGB(180, 255, 180), -- text bật
    textDim  = Color3.fromRGB(90, 92, 110),   -- text mờ
    pillOff  = Color3.fromRGB(40, 42, 52),
    pillOn   = Color3.fromRGB(40, 190, 65),
    dotOff   = Color3.fromRGB(160, 162, 180),
    secLbl   = Color3.fromRGB(70, 72, 92),
    divLine  = Color3.fromRGB(32, 32, 40),
    green    = Color3.fromRGB(60, 180, 70),
    red      = Color3.fromRGB(180, 40, 40),
}

-- Window — ngang rộng như Speed Hub
local Win = Instance.new("Frame", SG)
Win.Name = "Win"
Win.Size = UDim2.new(0, 580, 0, 360)
Win.Position = UDim2.new(0.5,-290,0.5,-180)
Win.BackgroundColor3 = C.bg
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Instance.new("UICorner", Win).CornerRadius = UDim.new(0,10)
local winSK = Instance.new("UIStroke", Win)
winSK.Color = Color3.fromRGB(38,38,48) winSK.Thickness = 1

-- ── TopBar
local TB = Instance.new("Frame", Win)
TB.Size = UDim2.new(1,0,0,36)
TB.BackgroundColor3 = C.topbar
TB.BorderSizePixel = 0
Instance.new("UICorner",TB).CornerRadius = UDim.new(0,10)
local tbf = Instance.new("Frame",TB)
tbf.Size=UDim2.new(1,0,0.5,0) tbf.Position=UDim2.new(0,0,0.5,0)
tbf.BackgroundColor3=C.topbar tbf.BorderSizePixel=0

-- Title đỏ giống Speed Hub
local TL = Instance.new("TextLabel",TB)
TL.Size=UDim2.new(0,280,1,0) TL.Position=UDim2.new(0,12,0,0)
TL.BackgroundTransparency=1
TL.Text="Hồ Quốc Dev  |  GAG2 Hub v3.2"
TL.TextColor3=C.accent TL.TextSize=12
TL.Font=Enum.Font.GothamBold TL.TextXAlignment=Enum.TextXAlignment.Left

local DL = Instance.new("TextLabel",TB)
DL.Size=UDim2.new(0,200,1,0) DL.Position=UDim2.new(0,285,0,0)
DL.BackgroundTransparency=1 DL.Text="discord.gg/hoquocdev"
DL.TextColor3=C.textDim DL.TextSize=10
DL.Font=Enum.Font.Gotham DL.TextXAlignment=Enum.TextXAlignment.Left

-- Minimize + Close
local minimized = false
local function mkTopBtn(txt,x,col)
    local b=Instance.new("TextButton",TB)
    b.Size=UDim2.new(0,24,0,24) b.Position=UDim2.new(1,x,0.5,-12)
    b.BackgroundColor3=col b.Text=txt b.TextColor3=Color3.white
    b.TextSize=12 b.Font=Enum.Font.GothamBold b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    return b
end
local MinB = mkTopBtn("–",-58,Color3.fromRGB(50,110,55))
local ClsB = mkTopBtn("✕",-30,Color3.fromRGB(160,35,35))
MinB.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win,TweenInfo.new(0.2,Enum.EasingStyle.Quart),{
        Size = minimized and UDim2.new(0,580,0,36) or UDim2.new(0,580,0,360)
    }):Play()
    MinB.Text = minimized and "+" or "–"
end)
ClsB.MouseButton1Click:Connect(function()
    disableESP() clearDefendESP() clearFruitESP()
    SG:Destroy()
end)

-- ── Divider topbar
local tbDiv = Instance.new("Frame",Win)
tbDiv.Size=UDim2.new(1,0,0,1) tbDiv.Position=UDim2.new(0,0,0,36)
tbDiv.BackgroundColor3=C.divLine tbDiv.BorderSizePixel=0

-- ── Sidebar (150px)
local SB = Instance.new("Frame",Win)
SB.Size=UDim2.new(0,145,1,-37) SB.Position=UDim2.new(0,0,0,37)
SB.BackgroundColor3=C.sidebar SB.BorderSizePixel=0
Instance.new("UICorner",SB).CornerRadius=UDim.new(0,10)
local sbf=Instance.new("Frame",SB)
sbf.Size=UDim2.new(0.5,0,1,0) sbf.Position=UDim2.new(0.5,0,0,0)
sbf.BackgroundColor3=C.sidebar sbf.BorderSizePixel=0

-- Divider sidebar
local sbDiv=Instance.new("Frame",Win)
sbDiv.Size=UDim2.new(0,1,1,-37) sbDiv.Position=UDim2.new(0,145,0,37)
sbDiv.BackgroundColor3=C.divLine sbDiv.BorderSizePixel=0

-- ── Content
local CT=Instance.new("Frame",Win)
CT.Size=UDim2.new(1,-145,1,-37) CT.Position=UDim2.new(0,145,0,37)
CT.BackgroundColor3=C.bg CT.BorderSizePixel=0
Instance.new("UICorner",CT).CornerRadius=UDim.new(0,10)
local ctf=Instance.new("Frame",CT)
ctf.Size=UDim2.new(0,10,1,0) ctf.BackgroundColor3=C.bg ctf.BorderSizePixel=0

-- ══════════════════════════════════════════
--  PAGE + NAV SYSTEM
-- ══════════════════════════════════════════
local pages   = {}
local navBtns = {}

local function showPage(name)
    for n,pg in pairs(pages) do pg.Visible=(n==name) end
    for n,b in pairs(navBtns) do
        local on=n==name
        b.BackgroundTransparency = on and 0 or 1
        b.BackgroundColor3 = Color3.fromRGB(30,32,42)
        b.TextColor3 = on and Color3.white or C.textDim
    end
end

local function makePage(name)
    local pg=Instance.new("Frame",CT)
    pg.Size=UDim2.new(1,-10,1,0) pg.Position=UDim2.new(0,10,0,0)
    pg.BackgroundTransparency=1 pg.Visible=false

    local pt=Instance.new("TextLabel",pg)
    pt.Size=UDim2.new(1,0,0,30) pt.Position=UDim2.new(0,4,0,4)
    pt.BackgroundTransparency=1 pt.Text=name
    pt.TextColor3=Color3.white pt.TextSize=15
    pt.Font=Enum.Font.GothamBold pt.TextXAlignment=Enum.TextXAlignment.Left

    local ln=Instance.new("Frame",pg)
    ln.Size=UDim2.new(1,-8,0,1) ln.Position=UDim2.new(0,4,0,34)
    ln.BackgroundColor3=C.divLine ln.BorderSizePixel=0

    local c=Instance.new("Frame",pg)
    c.Size=UDim2.new(1,-8,1,-42) c.Position=UDim2.new(0,4,0,40)
    c.BackgroundTransparency=1 c.BorderSizePixel=0
    local ll=Instance.new("UIListLayout",c)
    ll.Padding=UDim.new(0,4) ll.SortOrder=Enum.SortOrder.LayoutOrder

    pages[name]=pg
    return pg,c
end

-- Nav layout
local navLL=Instance.new("UIListLayout",SB)
navLL.Padding=UDim.new(0,1) navLL.SortOrder=Enum.SortOrder.LayoutOrder
local navPad=Instance.new("UIPadding",SB)
navPad.PaddingTop=UDim.new(0,6)
navPad.PaddingLeft=UDim.new(0,4)
navPad.PaddingRight=UDim.new(0,4)

local function makeNav(icon,label)
    local b=Instance.new("TextButton",SB)
    b.Size=UDim2.new(1,0,0,32)
    b.BackgroundColor3=Color3.fromRGB(30,32,42)
    b.BackgroundTransparency=1
    b.Text=icon.."  "..label
    b.TextColor3=C.textDim
    b.TextSize=11 b.Font=Enum.Font.GothamBold
    b.BorderSizePixel=0 b.TextXAlignment=Enum.TextXAlignment.Left
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    local pp=Instance.new("UIPadding",b)
    pp.PaddingLeft=UDim.new(0,10)
    navBtns[label]=b
    b.MouseButton1Click:Connect(function() showPage(label) end)
end

-- ══════════════════════════════════════════
--  WIDGET BUILDERS
-- ══════════════════════════════════════════
local function mkToggle(parent,icon,label,key,order,cb)
    local row=Instance.new("TextButton",parent)
    row.Size=UDim2.new(1,0,0,40) row.BackgroundColor3=C.row
    row.BorderSizePixel=0 row.Text="" row.LayoutOrder=order
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local sk=Instance.new("UIStroke",row) sk.Color=C.stroke sk.Thickness=1

    local iL=Instance.new("TextLabel",row)
    iL.Size=UDim2.new(0,32,1,0) iL.BackgroundTransparency=1
    iL.Text=icon iL.TextSize=18 iL.Font=Enum.Font.Gotham

    local lL=Instance.new("TextLabel",row)
    lL.Size=UDim2.new(1,-88,1,0) lL.Position=UDim2.new(0,34,0,0)
    lL.BackgroundTransparency=1 lL.Text=label
    lL.TextColor3=C.text lL.TextSize=12
    lL.Font=Enum.Font.Gotham lL.TextXAlignment=Enum.TextXAlignment.Left

    local pill=Instance.new("Frame",row)
    pill.Size=UDim2.new(0,40,0,20) pill.Position=UDim2.new(1,-46,0.5,-10)
    pill.BackgroundColor3=C.pillOff pill.BorderSizePixel=0
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)

    local dot=Instance.new("Frame",pill)
    dot.Size=UDim2.new(0,14,0,14) dot.Position=UDim2.new(0,3,0.5,-7)
    dot.BackgroundColor3=C.dotOff dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

    -- Arrow
    local arr=Instance.new("TextLabel",row)
    arr.Size=UDim2.new(0,16,1,0) arr.Position=UDim2.new(1,-62,0,0)
    arr.BackgroundTransparency=1 arr.Text="›"
    arr.TextColor3=C.textDim arr.TextSize=16 arr.Font=Enum.Font.GothamBold

    local function refresh()
        local on=CFG[key]
        TweenService:Create(row, TweenInfo.new(0.15),{BackgroundColor3=on and C.rowOn or C.row}):Play()
        TweenService:Create(sk,  TweenInfo.new(0.15),{Color=on and C.strokeOn or C.stroke}):Play()
        TweenService:Create(pill,TweenInfo.new(0.15),{BackgroundColor3=on and C.pillOn or C.pillOff}):Play()
        TweenService:Create(dot, TweenInfo.new(0.15),{Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
        lL.TextColor3=on and C.textOn or C.text
    end

    row.MouseButton1Click:Connect(function()
        CFG[key]=not CFG[key] refresh()
        if cb then cb(CFG[key]) end
    end)
end

local function mkInput(parent,label,default,order,onChange)
    local row=Instance.new("Frame",parent)
    row.Size=UDim2.new(1,0,0,36) row.BackgroundColor3=C.row
    row.BorderSizePixel=0 row.LayoutOrder=order
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    Instance.new("UIStroke",row).Color=C.stroke

    local lL=Instance.new("TextLabel",row)
    lL.Size=UDim2.new(0.55,0,1,0) lL.Position=UDim2.new(0,10,0,0)
    lL.BackgroundTransparency=1 lL.Text=label
    lL.TextColor3=C.textDim lL.TextSize=11
    lL.Font=Enum.Font.Gotham lL.TextXAlignment=Enum.TextXAlignment.Left

    local tb=Instance.new("TextBox",row)
    tb.Size=UDim2.new(0,110,0,24) tb.Position=UDim2.new(1,-116,0.5,-12)
    tb.BackgroundColor3=Color3.fromRGB(22,22,28)
    tb.TextColor3=Color3.fromRGB(140,255,140)
    tb.Text=tostring(default) tb.TextSize=11
    tb.Font=Enum.Font.Gotham tb.BorderSizePixel=0 tb.ClearTextOnFocus=false
    Instance.new("UICorner",tb).CornerRadius=UDim.new(0,5)
    Instance.new("UIPadding",tb).PaddingLeft=UDim.new(0,6)
    tb.FocusLost:Connect(function() if onChange then onChange(tb.Text) end end)
end

local function mkSec(parent,txt,order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,18) f.BackgroundTransparency=1 f.LayoutOrder=order
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1
    l.Text=txt l.TextColor3=C.secLbl l.TextSize=10
    l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left
end

local function mkModeBtn(parent,order)
    local row=Instance.new("TextButton",parent)
    row.Size=UDim2.new(1,0,0,36) row.BackgroundColor3=C.row
    row.BorderSizePixel=0 row.Text="" row.LayoutOrder=order
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local sk=Instance.new("UIStroke",row) sk.Thickness=1 sk.Color=Color3.fromRGB(50,90,180)

    local lL=Instance.new("TextLabel",row)
    lL.Size=UDim2.new(1,-10,1,0) lL.Position=UDim2.new(0,10,0,0)
    lL.BackgroundTransparency=1 lL.Font=Enum.Font.GothamBold
    lL.TextSize=11 lL.TextXAlignment=Enum.TextXAlignment.Left

    local function r()
        if CFG.TeleportMode then
            lL.Text="🚀 Mode: TELEPORT — tap đổi"
            lL.TextColor3=Color3.fromRGB(100,160,255)
            sk.Color=Color3.fromRGB(50,90,180)
        else
            lL.Text="🧍 Mode: ĐỨNG IM — tap đổi"
            lL.TextColor3=Color3.fromRGB(255,190,60)
            sk.Color=Color3.fromRGB(180,130,30)
        end
    end r()
    row.MouseButton1Click:Connect(function() CFG.TeleportMode=not CFG.TeleportMode r() end)
end

-- ══════════════════════════════════════════
--  BUILD PAGES
-- ══════════════════════════════════════════

-- HOME
local _,hC=makePage("Home")
local hInfo=Instance.new("Frame",hC)
hInfo.Size=UDim2.new(1,0,0,52) hInfo.BackgroundColor3=Color3.fromRGB(22,42,26)
hInfo.BorderSizePixel=0 hInfo.LayoutOrder=1
Instance.new("UICorner",hInfo).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",hInfo).Color=C.green
local hT=Instance.new("TextLabel",hInfo)
hT.Size=UDim2.new(1,-10,1,0) hT.Position=UDim2.new(0,10,0,0)
hT.BackgroundTransparency=1
hT.Text="🌿 Hồ Quốc Dev — GAG2 Hub v3.2
ProximityPrompt AutoFarm | HoQuoc Dev"
hT.TextColor3=C.textOn hT.TextSize=11
hT.Font=Enum.Font.GothamBold hT.TextWrapped=true hT.TextXAlignment=Enum.TextXAlignment.Left

local hStat=Instance.new("Frame",hC)
hStat.Size=UDim2.new(1,0,0,30) hStat.BackgroundColor3=Color3.fromRGB(20,20,26)
hStat.BorderSizePixel=0 hStat.LayoutOrder=2
Instance.new("UICorner",hStat).CornerRadius=UDim.new(0,7)
local hStatL=Instance.new("TextLabel",hStat)
hStatL.Size=UDim2.new(1,-10,1,0) hStatL.Position=UDim2.new(0,8,0,0)
hStatL.BackgroundTransparency=1 hStatL.TextColor3=C.green
hStatL.TextSize=10 hStatL.Font=Enum.Font.Gotham hStatL.TextXAlignment=Enum.TextXAlignment.Left

task.spawn(function()
    while hStatL and hStatL.Parent do
        local t={}
        if CFG.AutoPlants     then table.insert(t,"🌱") end
        if CFG.AutoCollection then table.insert(t,"🧺") end
        if CFG.AutoSell       then table.insert(t,"💰") end
        if CFG.AutoSteal      then table.insert(t,"🌙") end
        if CFG.AutoReplant    then table.insert(t,"🔄") end
        if CFG.AutoBuySeed    then table.insert(t,"🛒") end
        if CFG.AutoBuyGear    then table.insert(t,"🪣") end
        if CFG.SpeedBoost     then table.insert(t,"⚡") end
        if CFG.PlayerESP      then table.insert(t,"👁") end
        if CFG.FruitESP       then table.insert(t,"🌿") end
        if CFG.RestockNotify  then table.insert(t,"🛎") end
        if CFG.AutoDefend     then table.insert(t,"🚨") end
        hStatL.Text = #t>0 and ("✅ "..table.concat(t," ")) or "⏸ Chưa bật gì"
        task.wait(1.5)
    end
end)

-- MAIN
local _,mC=makePage("Main")
mkSec(mC,"AUTOMATION",1)
mkToggle(mC,"🌱","Automation Plants",    "AutoPlants",    2)
mkToggle(mC,"🧺","Automation Collection","AutoCollection",3)
mkToggle(mC,"💰","Automation Sell",      "AutoSell",      4)
mkToggle(mC,"🔄","Auto Replant",         "AutoReplant",   5)
mkSec(mC,"NIGHT STEAL",6)
mkToggle(mC,"🌙","Auto Steal (ban đêm)","AutoSteal",     7)
mkSec(mC,"HARVEST MODE",8)
mkModeBtn(mC,9)

-- AUTOMATICALLY
local _,aC=makePage("Automatically")
mkSec(aC,"AUTO BUY",1)
mkToggle(aC,"🛒","Auto Buy Seed","AutoBuySeed",2)
mkInput(aC,"Seed Name",CFG.SeedName,3,function(v) CFG.SeedName=v end)
mkToggle(aC,"🪣","Auto Buy Gear","AutoBuyGear",4)
mkInput(aC,"Gear Name",CFG.GearName,5,function(v) CFG.GearName=v end)

-- SHOP
local _,shC=makePage("Shop")
mkSec(shC,"SHOP INFO",1)
local shI=Instance.new("TextLabel",shC)
shI.Size=UDim2.new(1,0,0,60) shI.BackgroundColor3=C.row
shI.BorderSizePixel=0 shI.LayoutOrder=2
shI.TextColor3=C.textDim shI.TextSize=11
shI.Font=Enum.Font.Gotham shI.TextWrapped=true
shI.Text="  Auto Buy Seed/Gear bật trong tab Automatically\n  Seed: "..CFG.SeedName.."\n  Gear: "..CFG.GearName
Instance.new("UICorner",shI).CornerRadius=UDim.new(0,8)

-- MISC
local _,miC=makePage("Misc")
mkSec(miC,"VISUAL",1)
mkToggle(miC,"👁","Player ESP",          "PlayerESP",2,function(on) if on then enableESP() else disableESP() end end)
mkToggle(miC,"🌿","Fruit ESP (cây chín)","FruitESP", 3,function(on) if not on then clearFruitESP() end end)
mkSec(miC,"NOTIFY",4)
mkToggle(miC,"🛎","Restock Notifier",    "RestockNotify",5)
mkSec(miC,"DEFEND",6)
mkToggle(miC,"🚨","Auto Defend (chống trộm)","AutoDefend",7)
mkSec(miC,"MISC",8)
mkToggle(miC,"🖼","More FPS",            "MoreFPS",9,function(on)
    if on then
        pcall(function() setfpscap(60) end)
        game:GetService("Lighting").GlobalShadows=false
    end
end)
mkSec(miC,"SERVER",10)
local hopB=Instance.new("TextButton",miC)
hopB.Size=UDim2.new(1,0,0,36) hopB.BackgroundColor3=C.row
hopB.BorderSizePixel=0 hopB.Text="" hopB.LayoutOrder=11
Instance.new("UICorner",hopB).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",hopB).Color=C.stroke
local hL=Instance.new("TextLabel",hopB)
hL.Size=UDim2.new(1,-10,1,0) hL.Position=UDim2.new(0,10,0,0)
hL.BackgroundTransparency=1 hL.Text="🔄  Hop Server"
hL.TextColor3=C.text hL.TextSize=12
hL.Font=Enum.Font.Gotham hL.TextXAlignment=Enum.TextXAlignment.Left
local hArr=Instance.new("TextLabel",hopB)
hArr.Size=UDim2.new(0,16,1,0) hArr.Position=UDim2.new(1,-22,0,0)
hArr.BackgroundTransparency=1 hArr.Text="›" hArr.TextColor3=C.textDim
hArr.TextSize=16 hArr.Font=Enum.Font.GothamBold
hopB.MouseButton1Click:Connect(function()
    pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,LP)
    end)
end)

-- SETTINGS
local _,stC=makePage("Settings")
mkSec(stC,"PLAYER",1)
mkToggle(stC,"⚡","Speed Boost","SpeedBoost",2,function(on) applySpeed(on) end)
mkInput(stC,"🏃 WalkSpeed",    CFG.SpeedValue,   3,function(v) CFG.SpeedValue=tonumber(v) or 60; if CFG.SpeedBoost then applySpeed(true) end end)
mkSec(stC,"DELAYS (giây)",4)
mkInput(stC,"⏱ Harvest Delay",CFG.HarvestDelay, 5,function(v) CFG.HarvestDelay=tonumber(v) or 0.15 end)
mkInput(stC,"⏱ Sell Delay",   CFG.SellDelay,    6,function(v) CFG.SellDelay=tonumber(v) or 3 end)
mkInput(stC,"⏱ Buy Delay",    CFG.BuyDelay,     7,function(v) CFG.BuyDelay=tonumber(v) or 2 end)
mkInput(stC,"📡 Range",        CFG.HarvestRange, 8,function(v) CFG.HarvestRange=tonumber(v) or 15 end)
mkSec(stC,"RESTOCK TIMER",9)
mkInput(stC,"☀️ Ngày (giây)",  CFG.RestockDay,   10,function(v) CFG.RestockDay=tonumber(v) or 300 end)
mkInput(stC,"🌙 Đêm (giây)",   CFG.RestockNight, 11,function(v) CFG.RestockNight=tonumber(v) or 480 end)

-- SETTINGS UI
local _,suC=makePage("Settings UI")
mkSec(suC,"WINDOW",1)
local rstB=Instance.new("TextButton",suC)
rstB.Size=UDim2.new(1,0,0,36) rstB.BackgroundColor3=Color3.fromRGB(40,16,16)
rstB.BorderSizePixel=0 rstB.Text="🔄  Reset vị trí UI"
rstB.TextColor3=Color3.fromRGB(220,100,100) rstB.TextSize=12
rstB.Font=Enum.Font.GothamBold rstB.LayoutOrder=2
Instance.new("UICorner",rstB).CornerRadius=UDim.new(0,8)
rstB.MouseButton1Click:Connect(function()
    Win.Position=UDim2.new(0.5,-290,0.5,-180)
end)

-- ══════════════════════════════════════════
--  NAV BUTTONS
-- ══════════════════════════════════════════
makeNav("🏠","Home")
makeNav("⚙️","Main")
makeNav("▶️","Automatically")
makeNav("🛒","Shop")
makeNav("🔧","Misc")
makeNav("⚙","Settings")
makeNav("🎨","Settings UI")

showPage("Home")

-- ══════════════════════════════════════════
--  NÚT HQ — ẩn/hiện window
-- ══════════════════════════════════════════
local HQBtn = Instance.new("TextButton", SG)
HQBtn.Size = UDim2.new(0, 36, 0, 36)
HQBtn.Position = UDim2.new(0, 8, 0, 8)
HQBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
HQBtn.Text = "HQ"
HQBtn.TextColor3 = Color3.white
HQBtn.TextSize = 12
HQBtn.Font = Enum.Font.GothamBold
HQBtn.BorderSizePixel = 0
HQBtn.ZIndex = 10
Instance.new("UICorner", HQBtn).CornerRadius = UDim.new(0, 8)
local HQStroke = Instance.new("UIStroke", HQBtn)
HQStroke.Color = Color3.fromRGB(255, 100, 100)
HQStroke.Thickness = 1.5

local winVisible = true
HQBtn.MouseButton1Click:Connect(function()
    winVisible = not winVisible
    Win.Visible = winVisible
    TweenService:Create(HQBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = winVisible
            and Color3.fromRGB(180, 40, 40)
            or  Color3.fromRGB(40, 40, 60),
        Size = winVisible
            and UDim2.new(0, 36, 0, 36)
            or  UDim2.new(0, 40, 0, 40),
    }):Play()
    HQStroke.Color = winVisible
        and Color3.fromRGB(255, 100, 100)
        or  Color3.fromRGB(60, 200, 80)
end)

-- Kéo nút HQ
local draggingHQ, hqDragStart, hqStartPos
HQBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingHQ = true
        hqDragStart = input.Position
        hqStartPos = HQBtn.Position
    end
end)
game:GetService("UserInputService").InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingHQ = false
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(input)
    if draggingHQ and (
        input.UserInputType == Enum.UserInputType.Touch or
        input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local delta = input.Position - hqDragStart
        HQBtn.Position = UDim2.new(
            hqStartPos.X.Scale,
            hqStartPos.X.Offset + delta.X,
            hqStartPos.Y.Scale,
            hqStartPos.Y.Offset + delta.Y
        )
    end
end)

print("✅ Hồ Quốc Dev Hub v3.1 loaded!")
