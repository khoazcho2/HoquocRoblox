-- ================================================================
-- HO QUOC DEV GAG3 HUB v3.0 - VIP ULTIMATE + MENU GUI
-- Tác giả: HỒ QUỐC DEV
-- ================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local PGui = LP:WaitForChild("PlayerGui")
local VU = game:GetService("VirtualUser")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")

-- ══════════════════════════════════════════
-- CFG VIP
-- ══════════════════════════════════════════
local CFG = {
    InfiniteYield = true,
    AntiAFK = true,
    AutoWater = true,
    AutoFertilize = true,
    AutoCatchBugs = true,
    AutoCompost = true,
    AutoEvent = true,
    SmartHarvest = true,
    FarmESP = true,
    AutoRebirth = true,
    SpeedBoost = true,
    MoreFPS = true,
    
    RestockDay = 300,
    RestockNight = 480,
    SpeedValue = 80,
    HarvestDelay = 0.1,
    SellDelay = 2,
    BuyDelay = 1.5,
    HarvestRange = 20,
    SeedName = "Bamboo Seed",
    GearName = "Common Sprinkler",
    WaterDelay = 30,
    FertilizeDelay = 60,
    BugCheckDelay = 15,
    CompostDelay = 120,
    RebirthThreshold = 1000000,
    SelectedSeeds = {"Bamboo Seed", "Rose Seed", "Sunflower Seed"},
    SelectedGears = {"Common Sprinkler", "Fertilizer", "Compost Bin"},
}

-- ══════════════════════════════════════════
-- HÀM HỖ TRỢ CƠ BẢN
-- ══════════════════════════════════════════
local function getRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local root = getRoot()
    if root and CFG.TeleportMode then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
        task.wait(0.15)
    end
end

local function firePrompt(pp)
    if not pp then return end
    pcall(function()
        if fireproximityprompt then fireproximityprompt(pp, 0) end
    end)
end

local function isNight()
    local h = game:GetService("Lighting").ClockTime
    return h >= 20 or h < 6
end

-- ══════════════════════════════════════════
-- 1. INFINITE YIELD
-- ══════════════════════════════════════════
local yieldRunning = false

local function findBestFarmTarget()
    local targets = {}
    local root = getRoot()
    if not root then return {} end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local pp = obj.Parent:FindFirstChildWhichIsA("ProximityPrompt")
            if pp then
                local action = pp.ActionText:lower()
                if action:find("harvest") or action:find("collect") or action:find("pick") then
                    local dist = (root.Position - obj.Position).Magnitude
                    if dist <= CFG.HarvestRange then
                        local name = obj.Parent.Name or "Unknown"
                        local score = 0
                        if name:lower():find("mythic") then score = 1000
                        elseif name:lower():find("legendary") then score = 800
                        elseif name:lower():find("super") then score = 600
                        elseif name:lower():find("epic") then score = 400
                        elseif name:lower():find("rare") then score = 200
                        else score = 50 end
                        if name:lower():find("giant") then score = score + 500
                        elseif name:lower():find("huge") then score = score + 400
                        elseif name:lower():find("large") then score = score + 200 end
                        
                        table.insert(targets, {
                            pp = pp,
                            part = obj,
                            score = score,
                            name = name,
                            dist = dist
                        })
                    end
                end
            end
        end
    end
    
    table.sort(targets, function(a, b) return a.score > b.score end)
    return targets
end

local function doInfiniteYield()
    if not CFG.InfiniteYield then return end
    if yieldRunning then return end
    yieldRunning = true
    
    task.spawn(function()
        while CFG.InfiniteYield do
            local targets = findBestFarmTarget()
            
            if #targets > 0 then
                for _, t in ipairs(targets) do
                    if not CFG.InfiniteYield then break end
                    tpTo(t.part.Position)
                    firePrompt(t.pp)
                    task.wait(CFG.HarvestDelay)
                    
                    for i = 1, 5 do
                        local extraPP = t.part.Parent:FindFirstChildWhichIsA("ProximityPrompt")
                        if extraPP and extraPP.Enabled then
                            firePrompt(extraPP)
                            task.wait(0.1)
                        else
                            break
                        end
                    end
                    
                    print("[VIP] Đã thu hoạch: " .. t.name .. " (Score: " .. t.score .. ")")
                end
            else
                local randomOffset = Vector3.new(
                    math.random(-30, 30),
                    0,
                    math.random(-30, 30)
                )
                local root = getRoot()
                if root then
                    root.CFrame = CFrame.new(root.Position + randomOffset)
                end
            end
            
            task.wait(0.3)
        end
        yieldRunning = false
    end)
end

-- ══════════════════════════════════════════
-- 2. ANTI-AFK
-- ══════════════════════════════════════════
local afkRunning = false

local function doAntiAFK()
    if not CFG.AntiAFK then return end
    if afkRunning then return end
    afkRunning = true
    
    task.spawn(function()
        while CFG.AntiAFK do
            pcall(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
                
                local root = getRoot()
                if root then
                    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum:Move(Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)), true)
                    end
                end
                
                game:GetService("ReplicatedStorage"):FindFirstChild("IdleCheck")
            end)
            
            task.wait(math.random(30, 60))
        end
        afkRunning = false
    end)
    
    LP.Idled:Connect(function()
        if CFG.AntiAFK then
            VU:Button2Down(Vector2.new(0, 0), WS.CurrentCamera.CFrame)
            task.wait(0.1)
            VU:Button2Up(Vector2.new(0, 0), WS.CurrentCamera.CFrame)
        end
    end)
end

-- ══════════════════════════════════════════
-- 3. AUTO WATER
-- ══════════════════════════════════════════
local function findDryPlants()
    local dryPlants = {}
    local root = getRoot()
    if not root then return dryPlants end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local attr = obj:GetAttribute("Watered")
                or obj:GetAttribute("Dry")
                or obj.Parent:GetAttribute("Watered")
                or obj.Parent:GetAttribute("Dry")
            
            local isDry = false
            if attr ~= nil then
                isDry = (attr == false or attr == "dry" or attr == 0)
            end
            
            if obj.BrickColor == BrickColor.new("Brown") or obj.BrickColor == BrickColor.new("Gold") then
                isDry = true
            end
            
            local pp = obj.Parent:FindFirstChildWhichIsA("ProximityPrompt")
            if pp and pp.ActionText:lower():find("water") then
                isDry = true
            end
            
            if isDry then
                local dist = (root.Position - obj.Position).Magnitude
                if dist <= CFG.HarvestRange then
                    table.insert(dryPlants, {part = obj, pp = pp, dist = dist})
                end
            end
        end
    end
    
    table.sort(dryPlants, function(a, b) return a.dist < b.dist end)
    return dryPlants
end

local function doAutoWater()
    if not CFG.AutoWater then return end
    
    task.spawn(function()
        while CFG.AutoWater do
            local dryPlants = findDryPlants()
            
            for _, plant in ipairs(dryPlants) do
                if not CFG.AutoWater then break end
                
                tpTo(plant.part.Position)
                
                if plant.pp then
                    firePrompt(plant.pp)
                else
                    local char = LP.Character
                    if char then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        if tool and tool.Name:lower():find("water") then
                            pcall(function() tool:Activate() end)
                        end
                    end
                end
                
                print("[VIP] Đã tưới cây khô")
                task.wait(0.5)
            end
            
            task.wait(CFG.WaterDelay)
        end
    end)
end

-- ══════════════════════════════════════════
-- 4. AUTO FERTILIZE
-- ══════════════════════════════════════════
local function findUnfertilizedPlants()
    local plants = {}
    local root = getRoot()
    if not root then return plants end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local pp = obj.Parent:FindFirstChildWhichIsA("ProximityPrompt")
            if pp and pp.ActionText:lower():find("fertilize") then
                local dist = (root.Position - obj.Position).Magnitude
                if dist <= CFG.HarvestRange then
                    table.insert(plants, {part = obj, pp = pp, dist = dist})
                end
            end
        end
    end
    
    table.sort(plants, function(a, b) return a.dist < b.dist end)
    return plants
end

local function doAutoFertilize()
    if not CFG.AutoFertilize then return end
    
    task.spawn(function()
        while CFG.AutoFertilize do
            local plants = findUnfertilizedPlants()
            
            for _, plant in ipairs(plants) do
                if not CFG.AutoFertilize then break end
                
                tpTo(plant.part.Position)
                firePrompt(plant.pp)
                print("[VIP] Đã bón phân")
                task.wait(0.5)
            end
            
            task.wait(CFG.FertilizeDelay)
        end
    end)
end

-- ══════════════════════════════════════════
-- 5. AUTO CATCH BUGS
-- ══════════════════════════════════════════
local function findBugs()
    local bugs = {}
    local root = getRoot()
    if not root then return bugs end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("bug") or name:find("pest") or name:find("insect") or name:find("worm") then
                local dist = (root.Position - obj.Position).Magnitude
                if dist <= CFG.HarvestRange then
                    table.insert(bugs, {part = obj, dist = dist})
                end
            end
        end
    end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local hasBug = obj:GetAttribute("HasBug") or obj.Parent:GetAttribute("HasBug")
            if hasBug then
                local dist = (root.Position - obj.Position).Magnitude
                if dist <= CFG.HarvestRange then
                    table.insert(bugs, {part = obj, dist = dist})
                end
            end
        end
    end
    
    table.sort(bugs, function(a, b) return a.dist < b.dist end)
    return bugs
end

local function doAutoCatchBugs()
    if not CFG.AutoCatchBugs then return end
    
    task.spawn(function()
        while CFG.AutoCatchBugs do
            local bugs = findBugs()
            
            for _, bug in ipairs(bugs) do
                if not CFG.AutoCatchBugs then break end
                
                tpTo(bug.part.Position)
                
                local pp = bug.part:FindFirstChildWhichIsA("ProximityPrompt")
                if pp then
                    firePrompt(pp)
                else
                    pcall(function()
                        fireclickdetector(bug.part:FindFirstChildWhichIsA("ClickDetector"))
                    end)
                end
                
                print("[VIP] Đã bắt sâu")
                task.wait(0.3)
            end
            
            task.wait(CFG.BugCheckDelay)
        end
    end)
end

-- ══════════════════════════════════════════
-- 6. AUTO COMPOST
-- ══════════════════════════════════════════
local function findCompostBin()
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local pp = obj.Parent:FindFirstChildWhichIsA("ProximityPrompt")
            if pp and pp.ActionText:lower():find("compost") then
                return obj, pp
            end
        end
    end
    return nil, nil
end

local function doAutoCompost()
    if not CFG.AutoCompost then return end
    
    task.spawn(function()
        while CFG.AutoCompost do
            local bin, pp = findCompostBin()
            
            if bin and pp then
                tpTo(bin.Position)
                firePrompt(pp)
                print("[VIP] Đã ủ phân")
            end
            
            task.wait(CFG.CompostDelay)
        end
    end)
end

-- ══════════════════════════════════════════
-- 7. AUTO EVENT
-- ══════════════════════════════════════════
local function findActiveEvent()
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("event") or name:find("portal") or name:find("teleport") then
                local pp = obj:FindFirstChildWhichIsA("ProximityPrompt")
                if pp and (pp.ActionText:lower():find("enter") or pp.ActionText:lower():find("join")) then
                    return obj, pp
                end
            end
        end
    end
    return nil, nil
end

local function doAutoEvent()
    if not CFG.AutoEvent then return end
    
    task.spawn(function()
        while CFG.AutoEvent do
            local eventPart, pp = findActiveEvent()
            
            if eventPart and pp then
                tpTo(eventPart.Position)
                firePrompt(pp)
                print("[VIP] Đã tham gia sự kiện")
            end
            
            task.wait(60)
        end
    end)
end

-- ══════════════════════════════════════════
-- 8. AUTO REBIRTH
-- ══════════════════════════════════════════
local function checkRebirth()
    local currency = LP:FindFirstChild("leaderstats")
    if currency then
        local money = currency:FindFirstChild("Money") or currency:FindFirstChild("Cash")
        if money and money.Value >= CFG.RebirthThreshold then
            return true
        end
    end
    
    for _, gui in ipairs(PGui:GetDescendants()) do
        if gui:IsA("TextButton") then
            if gui.Text:lower():find("rebirth") or gui.Text:lower():find("prestige") then
                return true
            end
        end
    end
    
    return false
end

local function doRebirth()
    for _, gui in ipairs(PGui:GetDescendants()) do
        if gui:IsA("TextButton") then
            local txt = gui.Text:lower()
            if txt:find("rebirth") or txt:find("prestige") then
                pcall(function()
                    fireclickdetector(gui)
                end)
                print("[VIP] ĐÃ REBIRTH!")
                return true
            end
        end
    end
    return false
end

local function doAutoRebirth()
    if not CFG.AutoRebirth then return end
    
    task.spawn(function()
        while CFG.AutoRebirth do
            if checkRebirth() then
                doRebirth()
            end
            task.wait(10)
        end
    end)
end

-- ══════════════════════════════════════════
-- 9. FARM ESP
-- ══════════════════════════════════════════
local farmESPObjects = {}

local function clearFarmESP()
    for _, obj in pairs(farmESPObjects) do
        pcall(function() obj:Destroy() end)
    end
    table.clear(farmESPObjects)
end

local function doFarmESP()
    clearFarmESP()
    if not CFG.FarmESP then return end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            local pp = obj.Parent:FindFirstChildWhichIsA("ProximityPrompt")
            if pp then
                local action = pp.ActionText:lower()
                local status = ""
                local color = Color3.fromRGB(255, 255, 255)
                
                if action:find("harvest") then
                    status = "✅ CHÍN"
                    color = Color3.fromRGB(0, 255, 0)
                elseif action:find("water") then
                    status = "💧 KHÔ"
                    color = Color3.fromRGB(100, 150, 255)
                elseif action:find("fertilize") then
                    status = "🌱 CẦN PHÂN"
                    color = Color3.fromRGB(255, 200, 100)
                else
                    status = "⏳ ĐANG LỚN"
                    color = Color3.fromRGB(200, 200, 200)
                end
                
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 100, 0, 20)
                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = obj
                bb.Parent = obj
                
                local bg = Instance.new("Frame", bb)
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                bg.BackgroundTransparency = 0.5
                bg.BorderSizePixel = 0
                
                local lbl = Instance.new("TextLabel", bg)
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = status
                lbl.TextColor3 = color
                lbl.TextSize = 10
                lbl.Font = Enum.Font.GothamBold
                
                table.insert(farmESPObjects, bb)
            end
        end
    end
end

-- ══════════════════════════════════════════
-- 10. SPEED BOOST
-- ══════════════════════════════════════════
local function applySpeedBoost()
    if not CFG.SpeedBoost then return end
    
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = CFG.SpeedValue
        end
    end
end

LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    applySpeedBoost()
end)

-- ══════════════════════════════════════════
-- 11. MORE FPS
-- ══════════════════════════════════════════
local function applyMoreFPS()
    if not CFG.MoreFPS then return end
    
    pcall(function()
        game:GetService("Lighting").GlobalShadows = false
    end)
    
    pcall(function()
        settings().Rendering.QualityLevel = 1
    end)
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("grass") or name:find("leaf") or name:find("bush") or name:find("flower") then
                if obj.Transparency < 0.5 then
                    obj.Transparency = 0.7
                end
            end
        end
    end
end

-- ══════════════════════════════════════════
-- GUI MENU
-- ══════════════════════════════════════════
local function createMenu()
    local gui = Instance.new("ScreenGui")
    gui.Name = "HQ_Menu"
    gui.ResetOnSpawn = false
    gui.Parent = PGui

    -- Nút HQ
    local btnHQ = Instance.new("TextButton")
    btnHQ.Name = "BtnHQ"
    btnHQ.Size = UDim2.new(0, 50, 0, 50)
    btnHQ.Position = UDim2.new(1, -60, 1, -60)
    btnHQ.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    btnHQ.Text = "HQ"
    btnHQ.TextColor3 = Color3.fromRGB(0, 0, 0)
    btnHQ.TextSize = 20
    btnHQ.Font = Enum.Font.GothamBlack
    btnHQ.BorderSizePixel = 0
    btnHQ.ZIndex = 10
    Instance.new("UICorner", btnHQ).CornerRadius = UDim.new(0, 25)
    btnHQ.Parent = gui

    -- Menu chính
    local menuFrame = Instance.new("Frame")
    menuFrame.Name = "MenuFrame"
    menuFrame.Size = UDim2.new(0, 240, 0, 400)
    menuFrame.Position = UDim2.new(1, -250, 1, -470)
    menuFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    menuFrame.BorderSizePixel = 0
    menuFrame.Visible = false
    menuFrame.ZIndex = 9
    Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0, 12)
    menuFrame.Parent = gui

    local stroke = Instance.new("UIStroke", menuFrame)
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 2

    -- Tiêu đề
    local title = Instance.new("TextLabel", menuFrame)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🔥 HO QUOC DEV GAG3 HUB v3.0"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 10

    -- Danh sách chức năng
    local features = {
        {name = "Infinite Yield", cfg = "InfiniteYield"},
        {name = "Anti AFK", cfg = "AntiAFK"},
        {name = "Auto Water", cfg = "AutoWater"},
        {name = "Auto Fertilize", cfg = "AutoFertilize"},
        {name = "Auto Catch Bugs", cfg = "AutoCatchBugs"},
        {name = "Auto Compost", cfg = "AutoCompost"},
        {name = "Auto Event", cfg = "AutoEvent"},
        {name = "Smart Harvest", cfg = "SmartHarvest"},
        {name = "Farm ESP", cfg = "FarmESP"},
        {name = "Auto Rebirth", cfg = "AutoRebirth"},
        {name = "Speed Boost", cfg = "SpeedBoost"},
        {name = "More FPS", cfg = "MoreFPS"},
    }

    local yPos = 40
    for _, feat in ipairs(features) do
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(1, -20, 0, 25)
        toggle.Position = UDim2.new(0, 10, 0, yPos)
        toggle.BackgroundColor3 = CFG[feat.cfg] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggle.TextSize = 12
        toggle.Font = Enum.Font.GothamBold
        toggle.Text = feat.name .. ": " .. (CFG[feat.cfg] and "ON" or "OFF")
        toggle.BorderSizePixel = 0
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)
        toggle.ZIndex = 10
        toggle.Parent = menuFrame

        toggle.MouseButton1Click:Connect(function()
            CFG[feat.cfg] = not CFG[feat.cfg]
            if CFG[feat.cfg] then
                toggle.Text = feat.name .. ": ON"
                toggle.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
            else
                toggle.Text = feat.name .. ": OFF"
                toggle.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
            end
        end)

        yPos = yPos + 30
    end

    -- Nút đóng
    local closeBtn = Instance.new("TextButton", menuFrame)
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -25, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)
    closeBtn.ZIndex = 11

    btnHQ.MouseButton1Click:Connect(function()
        menuFrame.Visible = not menuFrame.Visible
    end)

    closeBtn.MouseButton1Click:Connect(function()
        menuFrame.Visible = false
    end)
end

-- ══════════════════════════════════════════
-- KHỞI ĐỘNG TẤT CẢ CHỨC NĂNG
-- ══════════════════════════════════════════
local function startAllVIP()
    print("[VIP] ========== KHỞI ĐỘNG GAG3 HUB v3.0 ==========")
    
    task.spawn(doInfiniteYield)
    task.spawn(doAntiAFK)
    task.spawn(doAutoWater)
    task.spawn(doAutoFertilize)
    task.spawn(doAutoCatchBugs)
    task.spawn(doAutoCompost)
    task.spawn(doAutoEvent)
    task.spawn(doAutoRebirth)
    task.spawn(applySpeedBoost)
    task.spawn(applyMoreFPS)
    
    task.spawn(function()
        while true do
            if CFG.FarmESP then
                pcall(doFarmESP)
            end
            task.wait(3)
        end
    end)
    
    print("[VIP] ✅ TẤT CẢ CHỨC NĂNG ĐÃ SẴN SÀNG!")
end

-- ══════════════════════════════════════════
-- THÔNG BÁO KHỞI ĐỘNG
-- ══════════════════════════════════════════
local function showStartupNotif()
    local notif = Instance.new("ScreenGui")
    notif.Name = "GAG3_Startup"
    notif.ResetOnSpawn = false
    notif.Parent = PGui
    
    local f = Instance.new("Frame", notif)
    f.Size = UDim2.new(0, 320, 0, 80)
    f.Position = UDim2.new(0.5, -160, 0, 40)
    f.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
    
    local sk = Instance.new("UIStroke", f)
    sk.Color = Color3.fromRGB(255, 215, 0)
    sk.Thickness = 2
    sk.Transparency = 0.3
    
    local title = Instance.new("TextLabel", f)
    title.Size = UDim2.new(1, 0, 0.45, 0)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "🔥 HO QUOC DEV GAG3 HUB v3.0"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBlack
    
    local sub = Instance.new("TextLabel", f)
    sub.Size = UDim2.new(1, 0, 0.45, 0)
    sub.Position = UDim2.new(0, 0, 0.5, 0)
    sub.BackgroundTransparency = 1
    sub.Text = "VIP ULTIMATE - FULL AUTO 100%"
    sub.TextColor3 = Color3.fromRGB(200, 200, 200)
    sub.TextSize = 12
    sub.Font = Enum.Font.GothamBold
    
    task.delay(5, function()
        if notif and notif.Parent then notif:Destroy() end
    end)
end

-- ══════════════════════════════════════════
-- CHẠY
-- ══════════════════════════════════════════
createMenu()
showStartupNotif()
task.wait(1)
startAllVIP()

print("╔══════════════════════════════════════════╗")
print("║   HO QUOC DEV GAG3 HUB v3.0 LOADED!    ║")
print("║   VIP ULTIMATE - FULL AUTO 100%        ║")
print("╚══════════════════════════════════════════╝")