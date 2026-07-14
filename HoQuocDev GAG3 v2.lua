-- ================================================================
-- HO QUOC DEV GAG3 HUB v3.0 - VIP ULTIMATE
-- Tác giả: HỒ QUỐC DEV
-- Tính năng mới: Auto Farm tiền/exp vô hạn + Anti-AFK + Full Auto 100%
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
    -- Chức năng gốc
    AutoPlants = true,
    AutoCollection = true,
    AutoSell = true,
    AutoSteal = true,
    AutoBuySeed = true,
    AutoBuyGear = true,
    AutoReplant = true,
    FruitESP = true,
    RestockNotify = true,
    AutoDefend = true,
    PlayerESP = true,
    TeleportMode = true,
    MoreFPS = true,
    
    -- Chức năng VIP mới
    InfiniteYield = true,        -- Auto farm tiền/exp vô hạn
    AntiAFK = true,              -- Chống bị kick AFK
    AutoWater = true,            -- Tự động tưới cây
    AutoFertilize = true,        -- Tự động bón phân
    AutoCatchBugs = true,        -- Tự động bắt sâu
    AutoCompost = true,          -- Tự động ủ phân
    AutoEvent = true,            -- Tự động tham gia sự kiện
    SmartHarvest = true,         -- Thu hoạch thông minh (ưu tiên cây hiếm)
    FarmESP = true,              -- Hiển thị trạng thái tất cả cây
    AutoRebirth = true,          -- Tự động rebirth khi đủ điều kiện
    SpeedBoost = true,           -- Tăng tốc độ di chuyển
    NoClip = false,              -- Xuyên tường (cẩn thận)
    AutoTrade = false,           -- Tự động giao dịch
    
    -- Thông số
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
    
    -- Seed list tự động mua
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

local function getPart(obj)
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChildWhichIsA("BasePart")
end

local function isNight()
    local h = game:GetService("Lighting").ClockTime
    return h >= 20 or h < 6
end

-- ══════════════════════════════════════════
-- 1. INFINITE YIELD (AUTO FARM TIỀN/EXP VÔ HẠN)
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
                        
                        -- Ưu tiên cây hiếm
                        if name:lower():find("mythic") then score = 1000
                        elseif name:lower():find("legendary") then score = 800
                        elseif name:lower():find("super") then score = 600
                        elseif name:lower():find("epic") then score = 400
                        elseif name:lower():find("rare") then score = 200
                        else score = 50 end
                        
                        -- Cây to hơn = nhiều tiền hơn
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
                    
                    -- Teleport đến cây
                    tpTo(t.part.Position)
                    
                    -- Thu hoạch
                    firePrompt(t.pp)
                    task.wait(CFG.HarvestDelay)
                    
                    -- Kiểm tra có thêm prompt không (multi-harvest)
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
                -- Không có cây trong range, tìm vị trí mới
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
-- 2. ANTI-AFK (CHỐNG BỊ KICK)
-- ══════════════════════════════════════════
local afkRunning = false

local function doAntiAFK()
    if not CFG.AntiAFK then return end
    if afkRunning then return end
    afkRunning = true
    
    task.spawn(function()
        while CFG.AntiAFK do
            pcall(function()
                -- Method 1: VirtualUser
                VU:CaptureController()
                VU:ClickButton2(Vector2.new())
                
                -- Method 2: Di chuyển nhẹ
                local root = getRoot()
                if root then
                    local hum = LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum:Move(Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)), true)
                    end
                end
                
                -- Method 3: Gửi tín hiệu đến server
                game:GetService("ReplicatedStorage"):FindFirstChild("IdleCheck")
            end)
            
            -- Random delay 30-60 giây để tránh pattern
            task.wait(math.random(30, 60))
        end
        afkRunning = false
    end)
    
    -- Hook vào sự kiện kick
    LP.Idled:Connect(function()
        if CFG.AntiAFK then
            VU:Button2Down(Vector2.new(0, 0), WS.CurrentCamera.CFrame)
            task.wait(0.1)
            VU:Button2Up(Vector2.new(0, 0), WS.CurrentCamera.CFrame)
        end
    end)
end

-- ══════════════════════════════════════════
-- 3. AUTO WATER (TỰ ĐỘNG TƯỚI CÂY)
-- ══════════════════════════════════════════
local function findDryPlants()
    local dryPlants = {}
    local root = getRoot()
    if not root then return dryPlants end
    
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent then
            -- Tìm cây khô (có hiệu ứng, màu sắc, hoặc attribute)
            local attr = obj:GetAttribute("Watered")
                or obj:GetAttribute("Dry")
                or obj.Parent:GetAttribute("Watered")
                or obj.Parent:GetAttribute("Dry")
            
            local isDry = false
            if attr ~= nil then
                isDry = (attr == false or attr == "dry" or attr == 0)
            end
            
            -- Kiểm tra màu sắc (cây khô thường có màu nâu/vàng)
            if obj.BrickColor == BrickColor.new("Brown") or obj.BrickColor == BrickColor.new("Gold") then
                isDry = true
            end
            
            -- Kiểm tra proximity prompt "Water"
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
                    -- Tìm tool tưới nước
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
-- 4. AUTO FERTILIZE (TỰ ĐỘNG BÓN PHÂN)
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
-- 5. AUTO CATCH BUGS (TỰ ĐỘNG BẮT SÂU)
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
    
    -- Kiểm tra cây có sâu (thường có effect hoặc attribute)
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
                
                -- Thử bắt sâu
                local pp = bug.part:FindFirstChildWhichIsA("ProximityPrompt")
                if pp then
                    firePrompt(pp)
                else
                    -- Click trực tiếp
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
-- 6. AUTO COMPOST (TỰ ĐỘNG Ủ PHÂN)
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
-- 7. AUTO EVENT (TỰ ĐỘNG THAM GIA SỰ KIỆN)
-- ══════════════════════════════════════════
local function findActiveEvent()
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("event") or name:find("portal") or name:find("teleport") then
                local pp = obj:FindFirstChildWhichIsA("ProximityPrompt")
                if pp and pp.ActionText:lower():find("enter") or pp.ActionText:lower():find("join") then
                    return obj, pp
                end
            end
        end
    end
    
    -- Kiểm tra GUI thông báo sự kiện
    for _, gui in ipairs(PGui:GetDescendants()) do
        if gui:IsA("TextLabel") then
            local txt = gui.Text:lower()
            if txt:find("event") or txt:find("special") then
                return nil, nil -- Có sự kiện nhưng chưa rõ vị trí
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
            
            task.wait(60) -- Check mỗi 60 giây
        end
    end)
end

-- ══════════════════════════════════════════
-- 8. AUTO REBIRTH (TỰ ĐỘNG REBIRTH)
-- ══════════════════════════════════════════
local function checkRebirth()
    -- Kiểm tra tiền/exp có đủ không
    local currency = LP:FindFirstChild("leaderstats")
    if currency then
        local money = currency:FindFirstChild("Money") or currency:FindFirstChild("Cash")
        if money and money.Value >= CFG.RebirthThreshold then
            return true
        end
    end
    
    -- Kiểm tra GUI rebirth
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
-- 9. FARM ESP (HIỂN THỊ TRẠNG THÁI CÂY)
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
-- 10. SPEED BOOST NÂNG CẤP
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
-- 11. MORE FPS NÂNG CẤP
-- ══════════════════════════════════════════
local function applyMoreFPS()
    if not CFG.MoreFPS then return end
    
    -- Tắt shadow
    pcall(function()
        game:GetService("Lighting").GlobalShadows = false
    end)
    
    -- Giảm graphics
    pcall(function()
        settings().Rendering.QualityLevel = 1
    end)
    
    -- Xóa cỏ
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
-- KHỞI ĐỘNG TẤT CẢ CHỨC NĂNG VIP
-- ══════════════════════════════════════════
local function startAllVIP()
    print("[VIP] ========== KHỞI ĐỘNG GAG3 HUB v3.0 ==========")
    
    -- Gốc
    if CFG.PlayerESP then refreshWhiteESP() end
    
    -- VIP
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
    
    -- Farm ESP loop
    task.spawn(function()
        while true do
            if CFG.FarmESP then
                pcall(doFarmESP)
            end
            task.wait(3)
        end
    end)
    
    print("[VIP] ✅ TẤT CẢ CHỨC NĂNG ĐÃ SẴN SÀNG!")
    print("[VIP]    - Infinite Yield: BẬT")
    print("[VIP]    - Anti-AFK: BẬT")
    print("[VIP]    - Auto Water/Fertilize/Catch Bugs: BẬT")
    print("[VIP]    - Auto Compost/Event/Rebirth: BẬT")
    print("[VIP]    - Farm ESP + Speed Boost + FPS Boost: BẬT")
    print("[VIP] =========================================")
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
-- KHỞI ĐỘNG
-- ══════════════════════════════════════════
showStartupNotif()
task.wait(1)
startAllVIP()

print("╔══════════════════════════════════════════╗")
print("║   HO QUOC DEV GAG3 HUB v3.0 LOADED!    ║")
print("║   VIP ULTIMATE - FULL AUTO 100%        ║")
print("╚══════════════════════════════════════════╝")