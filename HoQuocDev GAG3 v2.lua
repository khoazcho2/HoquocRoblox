
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP           = Players.LocalPlayer
local PGui         = LP:WaitForChild("PlayerGui")

-- ══════════════════════════════════════════
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
    BuyAllSeed     = false,  -- mua tất cả seed
    BuyAllGear     = false,  -- mua tất cả gear
    SelectedSeeds  = {},     -- seed được chọn để mua
    SelectedGears  = {},     -- gear được chọn để mua
}

-- ══════════════════════════════════════════
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
    if not pp or not pp.Parent or not pp.Enabled then return end
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(pp)
        end
    end)
end

-- ══════════════════════════════════════════
--  REMOTE BUFFER FUNCTIONS (từ xa, không cần tele)
-- ══════════════════════════════════════════
local PacketRemote = nil
local function getPacketRemote()
    if PacketRemote and PacketRemote.Parent then return PacketRemote end
    local rs = game:GetService("ReplicatedStorage")
    local sm = rs:FindFirstChild("SharedModules")
    if sm then
        local pk = sm:FindFirstChild("Packet")
        if pk then
            PacketRemote = pk:FindFirstChild("RemoteEvent")
            return PacketRemote
        end
    end
    return nil
end

-- Tạo buffer từ bytes
local function makeBuffer(bytes)
    local buf = buffer.create(#bytes)
    for i, b in ipairs(bytes) do
        buffer.writeu8(buf, i-1, b)
    end
    return buf
end

-- Encode tên thành bytes ASCII
local function nameToBytes(name)
    local bytes = {}
    for i = 1, #name do
        table.insert(bytes, string.byte(name, i))
    end
    return bytes
end

-- Buy Seed từ xa (không cần tele)
-- Format: 69 00 [len] [name ASCII]
local function remoteBuySeed(seedName)
    local remote = getPacketRemote()
    if not remote then return false end
    local nameBytes = nameToBytes(seedName)
    local bytes = {0x69, 0x00, #nameBytes}
    for _, b in ipairs(nameBytes) do
        table.insert(bytes, b)
    end
    local buf = makeBuffer(bytes)
    local ok, err = pcall(function()
        remote:FireServer(buf)
    end)
    if ok then
        print("[GAG3] Mua seed từ xa: "..seedName)
    else
        warn("[GAG3] remoteBuySeed lỗi: "..tostring(err))
    end
    return ok
end

-- Buy Gear từ xa
-- Format: 6d 00 [len] [name_ascii]  (khác seed: 69 00)
local function remoteBuyGear(gearName)
    local remote = getPacketRemote()
    if not remote then return false end
    local nameBytes = nameToBytes(gearName)
    local bytes = {0x6d, 0x00, #nameBytes}
    for _, b in ipairs(nameBytes) do table.insert(bytes, b) end
    local buf = makeBuffer(bytes)
    local ok, err = pcall(function() remote:FireServer(buf) end)
    if ok then
        print("[GAG3] Mua gear từ xa: "..gearName)
    else
        warn("[GAG3] remoteBuyGear lỗi: "..tostring(err))
    end
    return ok
end

-- Sell All từ xa
-- Format: 42 00 [X float32 LE] [Y float32 LE] [Z float32 LE]
local function remoteSellAll()
    local remote = getPacketRemote()
    if not remote then return false end
    local root = getRoot()
    if not root then return false end

    local pos = root.Position
    local x, y, z = pos.X, pos.Y, pos.Z

    -- Encode float32 little endian
    local function float32LE(f)
        -- Dùng string.pack nếu có, fallback manual
        local ok, result = pcall(function()
            return {string.byte(string.pack("<f", f), 1, 4)}
        end)
        if ok then return result end
        -- Fallback manual encode
        local sign = f < 0 and 1 or 0
        f = math.abs(f)
        local exp = math.floor(math.log(f) / math.log(2))
        local mant = f / (2^exp) - 1
        exp = exp + 127
        local bits = sign * 0x80000000
            + exp * 0x800000
            + math.floor(mant * 0x800000)
        return {
            bits % 256,
            math.floor(bits / 256) % 256,
            math.floor(bits / 65536) % 256,
            math.floor(bits / 16777216) % 256
        }
    end

    local xBytes = float32LE(x)
    local yBytes = float32LE(y)
    local zBytes = float32LE(z)

    local bytes = {0x42, 0x00}
    for _, b in ipairs(xBytes) do table.insert(bytes, b) end
    for _, b in ipairs(yBytes) do table.insert(bytes, b) end
    for _, b in ipairs(zBytes) do table.insert(bytes, b) end

    local buf = makeBuffer(bytes)
    local ok, err = pcall(function() remote:FireServer(buf) end)
    if ok then
        print("[GAG3] Bán từ xa tại "..string.format("%.1f,%.1f,%.1f", x,y,z))
    else
        warn("[GAG3] remoteSellAll lỗi: "..tostring(err))
    end
    return ok
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

-- Cache sell point position
local sellPointPos = nil
local function findSellPoint()
    -- Tìm sell point từ workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local n = obj.Name:lower()
            if n:find("sell") or n:find("market") or n:find("cashier") then
                local part = obj:IsA("BasePart") and obj or obj.PrimaryPart
                if part then return part.Position end
            end
        end
    end
    -- Tìm qua ProximityPrompt
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("sell") or a:find("submit") then
                local part = getPart(pp.Parent)
                if part then return part.Position end
            end
        end
    end
    -- Tìm nút Sell trong UI game
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if (v:IsA("TextButton") or v:IsA("ImageButton")) then
            local n = v.Name:lower()
            local t = v:IsA("TextButton") and v.Text:lower() or ""
            if n == "sell" or t == "sell" or n:find("sellbtn") then
                return nil, v  -- trả về UI button
            end
        end
    end
    return nil, nil
end

local function doSell()
    -- Thử remote sell trước (không cần tele)
    if remoteSellAll() then return end

    local root = getRoot()
    if not root then return end
    local farmPos = root.Position

    -- Fallback: click UI button Sell
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if v:IsA("TextButton") or v:IsA("ImageButton") then
            local n = v.Name:lower()
            local t = v:IsA("TextButton") and v.Text:lower() or ""
            if n == "sell" or t == "sell" or n:find("sell") then
                pcall(function() v.MouseButton1Click:Fire() end)
                task.wait(0.1)
                -- Confirm dialog nếu có
                for _, v2 in ipairs(LP.PlayerGui:GetDescendants()) do
                    if v2:IsA("TextButton") then
                        local t2 = v2.Text:lower()
                        if t2 == "confirm" or t2 == "yes" or t2 == "ok" or t2:find("sell all") then
                            pcall(function() v2.MouseButton1Click:Fire() end)
                        end
                    end
                end
                return
            end
        end
    end

    -- Fallback: tele đến sell point, bán, về ngay
    local bestPP = nil
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("sell") or a:find("submit") then
                bestPP = pp
                break
            end
        end
    end

    if bestPP then
        local part = getPart(bestPP.Parent)
        if part then
            -- Tele instant đến sell point
            root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
            task.wait(0.05)
            firePrompt(bestPP)
            task.wait(0.05)
            -- Về ngay vườn mình
            root.CFrame = CFrame.new(farmPos)
        end
    end
end

-- ══════════════════════════════════════════
-- ══════════════════════════════════════════

-- Chỉ steal từ Epic trở lên
-- score = 0 nghĩa là bỏ qua, không steal
local RARITY_SCORE = {
    mythic    = 1000,  -- ưu tiên cao nhất
    legendary = 800,
    super     = 600,
    epic      = 400,
    -- rare/uncommon/common = 0 -> bỏ qua
}

-- Thêm điểm cho cây to (weight cao hơn)
local SIZE_BONUS = {
    giant     = 500,
    huge      = 400,
    large     = 300,
    big       = 200,
    mega      = 450,
    colossal  = 600,
    enormous  = 500,
}

local function getRarityScore(name)
    local n = name:lower()
    local score = 0
    -- Check rarity
    for rarity, s in pairs(RARITY_SCORE) do
        if n:find(rarity) then
            score = score + s
            break
        end
    end
    -- Check size bonus
    for size, bonus in pairs(SIZE_BONUS) do
        if n:find(size) then
            score = score + bonus
            break
        end
    end
    return score  -- 0 = không đủ tier, bỏ qua
end

local myFarmPos = nil
local function updateMyFarmPos()
    for _, obj in ipairs(workspace:GetDescendants()) do
        local owner = obj:GetAttribute("Owner")
            or obj:GetAttribute("PlotOwner")
            or obj:GetAttribute("PlayerName")
        if owner and owner == LP.Name then
            local part = getPart(obj)
            if part then myFarmPos = part.Position return end
        end
    end
    local root = getRoot()
    if root then myFarmPos = root.Position end
end

local function goHome()
    updateMyFarmPos()
    local root = getRoot()
    if root and myFarmPos then
        root.CFrame = CFrame.new(myFarmPos + Vector3.new(0,4,0))
        task.wait(0.25)
    elseif root then
        -- fallback: đứng yên tại chỗ
        task.wait(0.1)
    end
end

local function collectStealTargets()
    local targets = {}
    -- Lấy vị trí các player khác
    local otherPlayerPositions = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                table.insert(otherPlayerPositions, r.Position)
            end
        end
    end

    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            -- Tìm prompt steal/harvest
            local isTarget = a:find("steal") or a:find("take")
                or a:find("grab") or a:find("pick up") or a:find("harvest")
            if not isTarget then continue end

            local part = getPart(pp.Parent)
            if not part then continue end

            -- Bỏ qua vườn mình
            local owner = pp.Parent:GetAttribute("Owner")
                or pp.Parent:GetAttribute("PlotOwner")
                or pp.Parent:GetAttribute("PlayerName")
            if owner and owner == LP.Name then continue end

            -- Nếu không có owner attribute, kiểm tra xem có gần vườn mình không
            if not owner then
                local myRoot = getRoot()
                if myRoot and myFarmPos then
                    local distToMyFarm = (myFarmPos - part.Position).Magnitude
                    if distToMyFarm < 20 then continue end -- bỏ qua nếu gần vườn mình
                end
            end

            local score = getRarityScore(pp.Parent.Name)
            -- Cho phép steal tất cả rarity (score >= 0) nhưng ưu tiên cao hơn
            -- Thêm điểm nếu gần player khác
            for _, pPos in ipairs(otherPlayerPositions) do
                if (pPos - part.Position).Magnitude < 40 then
                    score = score + 50 -- boost nếu gần vườn người khác
                    break
                end
            end

            table.insert(targets, {
                pp    = pp,
                part  = part,
                score = score,
                name  = pp.Parent.Name,
            })
        end
    end
    table.sort(targets, function(a,b) return a.score > b.score end)
    return targets
end

local stealRunning = false
local lastStealAttempt = 0

local function doSteal()
    if not isNight() then
        stealRunning = false
        return
    end
    -- Reset nếu bị stuck quá 30 giây
    if stealRunning and tick() - lastStealAttempt > 30 then
        stealRunning = false
    end
    if stealRunning then return end
    stealRunning = true
    lastStealAttempt = tick()

    updateMyFarmPos()

    while isNight() and CFG.AutoSteal do
        local targets = collectStealTargets()

        if #targets == 0 then
            task.wait(2)
        else
            for _, t in ipairs(targets) do
                if not isNight() or not CFG.AutoSteal then break end

                local root = getRoot()
                if not root then break end

                -- 1. Tele đến cây của người khác
                root.CFrame = CFrame.new(t.part.Position + Vector3.new(0,4,0))
                task.wait(0.25)

                -- 2. Hái trái
                firePrompt(t.pp)
                task.wait(0.2)

                -- 3. Về vườn mình (bắt buộc trước khi hái tiếp)
                goHome()
                task.wait(0.3)

                -- 4. Lặp lại với cây tiếp theo
            end
        end

        task.wait(0.3)
    end

    stealRunning = false
end

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
                lbl.Text="🌿 "..pp.Parent.Name lbl.TextColor3=Color3.new(1,1,1)
                lbl.TextSize=10 lbl.Font=Enum.Font.GothamBold lbl.TextScaled=true
                table.insert(fruitESPTags,bb)
            end
        end
    end
end

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
    l.Text=text l.TextColor3=Color3.new(1,1,1)
    l.TextSize=13 l.Font=Enum.Font.GothamBold l.TextWrapped=true
    task.delay(3, function() if notif and notif.Parent then notif:Destroy() end end)
end

-- Parse "Xm Ys" hoặc "Xs" thành seconds
local function parseTimeText(txt)
    local m, s = txt:match("(%d+)m%s*(%d+)s")
    if m and s then return tonumber(m)*60 + tonumber(s) end
    local s2 = txt:match("(%d+)s")
    if s2 then return tonumber(s2) end
    local m2 = txt:match("(%d+)m")
    if m2 then return tonumber(m2)*60 end
    return nil
end

-- Tự động detect restock timer từ UI game
local lastDetectedInterval = nil  -- interval thực tế từ game
local lastRestockCountdown = nil  -- countdown cuối cùng đọc được
local wasCountingDown = false

local function checkRestock()
    if not CFG.RestockNotify then return end

    -- Scan UI tìm text restock timer
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if v:IsA("TextLabel") then
            local txt = v.Text:lower()

            -- Detect "Restock In Xm Ys" hoặc "Restock In Xs"
            if txt:find("restock") and (txt:find("in") or txt:find("0m") or txt:find("0s")) then
                local timeStr = txt:match("restock[^%d]*(%d[%d%s:m]+s?)")
                local secs = parseTimeText(txt)

                if secs then
                    -- Lần đầu detect, lưu interval
                    if not lastDetectedInterval and secs > 5 then
                        lastDetectedInterval = secs
                        print("[GAG3] Restock interval detected: "..secs.."s ("..(isNight() and "NIGHT" or "DAY")..")")
                    end
                    lastRestockCountdown = secs
                    wasCountingDown = true
                end

                -- Detect khi về 0 (restock!)
                if secs and secs <= 2 then
                    local now = tick()
                    if now - lastRestockNotif > 15 then
                        lastRestockNotif = now
                        lastRestockTick  = now
                        -- Reset interval để detect lại lần sau
                        lastDetectedInterval = nil
                        wasCountingDown = false
                        local timeLabel = isNight() and "BAN ĐÊM" or "BAN NGÀY"
                        showNotif("🛒 SHOP RESTOCK! ("..timeLabel..")", Color3.fromRGB(20,60,28))
                        print("[GAG3] Shop restocked!")
                    end
                end
            end

            -- Detect text "Restock" khi không có timer (đã restock)
            if (txt == "restock" or txt:find("^restock$")) and wasCountingDown then
                local now = tick()
                if now - lastRestockNotif > 15 then
                    lastRestockNotif = now
                    wasCountingDown = false
                    showNotif("🛒 SHOP ĐÃ RESTOCK!", Color3.fromRGB(20,60,28))
                end
            end
        end
    end

    -- Fallback: đếm theo interval nếu không detect được từ UI
    if lastDetectedInterval == nil then
        local interval = isNight() and CFG.RestockNight or CFG.RestockDay
        local now = tick()
        if now - lastRestockTick >= interval then
            lastRestockTick = now
            showNotif("🛒 SHOP RESTOCK! (ước tính)", Color3.fromRGB(20,60,28))
        end
    end
end

-- ══════════════════════════════════════════
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
    nl.Text="🚨 "..player.Name nl.TextColor3=Color3.new(1,1,1)
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
    local root = getRoot()
    if not root or not targetPlayer.Character then return end
    local thRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not thRoot then return end
    -- Tele về gần kẻ trộm
    root.CFrame = CFrame.new(thRoot.Position + Vector3.new(0,3,2))
    task.wait(0.25)
    equipShovel()
    task.wait(0.2)
    -- Tìm PP attack trên kẻ trộm
    for _, pp in ipairs(targetPlayer.Character:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("hit") or a:find("attack") or a:find("fight") or a:find("shovel") then
                firePrompt(pp) return
            end
        end
    end
    -- Fallback: ClickDetector
    for _, cd in ipairs(targetPlayer.Character:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            pcall(function() fireclickdetector(cd) end) return
        end
    end
    -- Fallback: tool remote
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    pcall(function() v:FireServer(thRoot.Position) end) return
                end
            end
        end
    end
end

local thiefsDetected = {}

-- Vị trí vườn của mình để defend
local myPlotParts = {}
local function updateMyPlot()
    myPlotParts = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local owner = obj:GetAttribute("Owner")
                or obj:GetAttribute("PlotOwner")
                or obj:GetAttribute("PlayerName")
            if owner == LP.Name then
                local part = obj:IsA("BasePart") and obj or obj.PrimaryPart
                if part then table.insert(myPlotParts, part) end
            end
        end
    end
end

local function getMyPlotCenter()
    if #myPlotParts == 0 then
        local root = getRoot()
        return root and root.Position or Vector3.new(0,0,0)
    end
    local sum = Vector3.new(0,0,0)
    for _, p in ipairs(myPlotParts) do sum = sum + p.Position end
    return sum / #myPlotParts
end

local function isNearMyPlot(pos, range)
    range = range or 30
    local center = getMyPlotCenter()
    return (center - pos).Magnitude <= range
end

local function autoAttackThief(p)
    if not p or not p.Character then return end
    local thRoot = p.Character:FindFirstChild("HumanoidRootPart")
    if not thRoot then return end

    -- Tele về vườn mình trước
    local root = getRoot()
    if not root then return end

    -- Đứng gần kẻ trộm trong vườn
    root.CFrame = CFrame.new(thRoot.Position + Vector3.new(2,3,2))
    task.wait(0.2)

    equipShovel()
    task.wait(0.15)

    -- Tìm ProximityPrompt attack trên kẻ trộm
    for _, pp in ipairs(p.Character:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("hit") or a:find("attack") or a:find("fight")
            or a:find("shovel") or a:find("smack") or a:find("bonk") then
                firePrompt(pp)
                task.wait(0.1)
                firePrompt(pp) -- đánh 2 lần
                return
            end
        end
    end

    -- Fallback: ClickDetector
    for _, cd in ipairs(p.Character:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            pcall(function() fireclickdetector(cd) end)
            pcall(function() fireclickdetector(cd) end)
            return
        end
    end

    -- Fallback: tool remote
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    pcall(function() v:FireServer(thRoot.Position) end)
                    return
                end
            end
        end
    end
end

-- Equip slot 1 (Shovel)
local function equipSlot1()
    local char = LP.Character
    if not char then return end
    -- Tìm Shovel trong backpack
    local backpack = LP:FindFirstChild("Backpack")
    if backpack then
        local shovel = backpack:FindFirstChild("Shovel")
        if shovel then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(shovel) return end
        end
        -- Fallback: equip tool đầu tiên
        local firstTool = backpack:FindFirstChildWhichIsA("Tool")
        if firstTool then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(firstTool) end
        end
    end
    -- Thử dùng hotbar slot 1 qua UserInputService
    pcall(function()
        game:GetService("UserInputService"):SendKeyEvent(true, Enum.KeyCode.One, false, game)
    end)
end

-- Đánh liên tục vào kẻ trộm
local defendingTargets = {}

local function continuousAttack(p)
    if defendingTargets[p.Name] then return end -- đang đánh rồi
    defendingTargets[p.Name] = true

    task.spawn(function()
        local myRoot = getRoot()
        if not myRoot then
            defendingTargets[p.Name] = nil
            return
        end
        local myPos = myFarmPos or myRoot.Position

        -- Đánh liên tục cho đến khi hắn rời đi hoặc tắt defend
        while CFG.AutoDefend do
            if not p.Character then break end
            local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if not pRoot then break end

            -- Kiểm tra còn gần vườn không
            local dist = (myPos - pRoot.Position).Magnitude
            if dist > 35 then break end -- hắn đã rời đi

            local root = getRoot()
            if not root then break end

            -- Tele đứng sát kẻ trộm
            root.CFrame = CFrame.new(pRoot.Position + Vector3.new(2, 3, 0))
            task.wait(0.1)

            -- Equip shovel slot 1
            equipSlot1()
            task.wait(0.1)

            -- Tìm ProximityPrompt đánh
            local attacked = false
            for _, pp in ipairs(p.Character:GetDescendants()) do
                if pp:IsA("ProximityPrompt") then
                    local a = pp.ActionText:lower()
                    if a:find("hit") or a:find("attack") or a:find("smack")
                    or a:find("shovel") or a:find("bonk") or a:find("fight") then
                        firePrompt(pp)
                        firePrompt(pp) -- đánh 2 lần
                        attacked = true
                        break
                    end
                end
            end

            -- Fallback ClickDetector
            if not attacked then
                for _, cd in ipairs(p.Character:GetDescendants()) do
                    if cd:IsA("ClickDetector") then
                        pcall(function() fireclickdetector(cd) end)
                        pcall(function() fireclickdetector(cd) end)
                        attacked = true
                        break
                    end
                end
            end

            -- Fallback tool RemoteEvent
            if not attacked then
                local char = LP.Character
                if char then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool then
                        for _, v in ipairs(tool:GetDescendants()) do
                            if v:IsA("RemoteEvent") then
                                pcall(function() v:FireServer(pRoot.Position) end)
                                break
                            end
                        end
                    end
                end
            end

            task.wait(0.4) -- đánh mỗi 0.4 giây
        end

        defendingTargets[p.Name] = nil
        print("[GAG3] Defend: "..p.Name.." đã rời đi")
    end)
end

local function checkDefend()
    if not CFG.AutoDefend then return end

    local myRoot = getRoot()
    if not myRoot then return end
    updateMyFarmPos()
    local myPos = myFarmPos or myRoot.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        if not p.Character then continue end
        local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
        if not pRoot then continue end

        local isThief = false

        -- Detect 1: Player đứng gần vườn mình
        local dist = (myPos - pRoot.Position).Magnitude
        if dist <= 25 then isThief = true end

        -- Detect 2: Thông báo UI "stealing from you"
        for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
            if v:IsA("TextLabel") then
                local txt = v.Text:lower()
                if (txt:find("stealing from you") or txt:find("stole") or txt:find("is stealing"))
                and txt:find(p.Name:lower()) then
                    isThief = true
                end
            end
        end

        -- Detect 3: Highlight đỏ (game gán cho kẻ trộm)
        local hl = p.Character:FindFirstChildWhichIsA("Highlight")
        if hl and hl:IsA("Highlight") then
            if hl.FillColor.R > 0.5 and hl.FillColor.G < 0.3 then
                isThief = true
            end
        end

        if isThief then
            -- Thông báo lần đầu
            if not thiefsDetected[p.Name] or tick() - thiefsDetected[p.Name] > 10 then
                thiefsDetected[p.Name] = tick()
                showNotif("🚨 "..p.Name.." ĐANG VÀO VƯỜN!", Color3.fromRGB(120,10,10))
                markThief(p)
            end
            -- Đánh liên tục
            continuousAttack(p)
        end
    end
end

-- Danh sách seed đầy đủ
local SEED_LIST = {
    "Bamboo Seed","Apple Seed","Blueberry Seed","Tomato Seed",
    "Cactus Seed","Grape Seed","Tulip Seed","Strawberry Seed",
    "Cherry","Sunflower","Venus Fly Trap","Pomegranate",
    "Poison Apple","Moon Bloom","Dragon's Breath",
}

local SEED_LIST_ALL = {
    "Bamboo Seed","Apple Seed","Blueberry Seed","Tomato Seed",
    "Cactus Seed","Grape Seed","Tulip Seed","Strawberry Seed",
    "Cherry","Sunflower","Venus Fly Trap","Pomegranate",
    "Poison Apple","Moon Bloom","Dragon's Breath",
}

local function buySingleSeed(seedName)
    if remoteBuySeed(seedName) then return true end
    local root = getRoot()
    if not root then return false end
    local farmPos = root.Position
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            local pName = pp.Parent.Name:lower()
            if (a:find("buy") or a:find("purchase")) and pName:find(seedName:lower()) then
                local part = getPart(pp.Parent)
                if part then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                    task.wait(0.05)
                    firePrompt(pp)
                    task.wait(0.05)
                    root.CFrame = CFrame.new(farmPos)
                    return true
                end
            end
        end
    end
    return false
end

local function doBuySeed()
    if CFG.BuyAllSeed then
        -- Mua tất cả seed
        for _, sn in ipairs(SEED_LIST_ALL) do
            buySingleSeed(sn)
            task.wait(0.1)
        end
    elseif next(CFG.SelectedSeeds) then
        -- Mua seed đã chọn
        for sn, selected in pairs(CFG.SelectedSeeds) do
            if selected then
                buySingleSeed(sn)
                task.wait(0.1)
            end
        end
    else
        -- Mua seed mặc định
        buySingleSeed(CFG.SeedName)
    end
end

-- Danh sách gear đầy đủ
local GEAR_LIST = {
    "Common Sprinkler","Uncommon Sprinkler","Rare Sprinkler",
    "Legendary Sprinkler","Super Sprinkler",
    "Common Watering Can","Super Watering Can",
    "Trowel","Gnome","Lantern","Basic Pot","Wheelbarrow","Teleporter",
    "Jump Mushroom","Speed Mushroom","Shrink Mushroom",
    "Supersize Mushroom","Invisibility Mushroom",
}

local GEAR_LIST_ALL = {
    "Common Sprinkler","Uncommon Sprinkler","Rare Sprinkler",
    "Legendary Sprinkler","Super Sprinkler",
    "Common Watering Can","Super Watering Can",
    "Trowel","Gnome","Lantern","Basic Pot","Wheelbarrow","Teleporter",
    "Jump Mushroom","Speed Mushroom","Shrink Mushroom",
    "Supersize Mushroom","Invisibility Mushroom",
}

local function buySingleGear(gearName)
    if remoteBuyGear(gearName) then return true end
    local root = getRoot()
    if not root then return false end
    local farmPos = root.Position
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            local pName = pp.Parent.Name:lower()
            if (a:find("buy") or a:find("purchase")) and pName:find(gearName:lower()) then
                local part = getPart(pp.Parent)
                if part then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                    task.wait(0.05)
                    firePrompt(pp)
                    task.wait(0.05)
                    root.CFrame = CFrame.new(farmPos)
                    return true
                end
            end
        end
    end
    return false
end

local function doBuyGear()
    if CFG.BuyAllGear then
        for _, gn in ipairs(GEAR_LIST_ALL) do
            buySingleGear(gn)
            task.wait(0.1)
        end
    elseif next(CFG.SelectedGears) then
        for gn, selected in pairs(CFG.SelectedGears) do
            if selected then
                buySingleGear(gn)
                task.wait(0.1)
            end
        end
    else
        buySingleGear(CFG.GearName)
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

task.spawn(function() while true do if CFG.AutoPlants then local ok,err=pcall(doPlants); if not ok then warn("[GAG3] Plants: "..tostring(err)) end end task.wait(1.5) end end)
task.spawn(function() while true do if CFG.AutoCollection then local ok,err=pcall(doCollection); if not ok then warn("[GAG3] Collection: "..tostring(err)) end end task.wait(0.5) end end)
task.spawn(function() while true do if CFG.AutoSell then local ok,err=pcall(doSell); if not ok then warn("[GAG3] Sell: "..tostring(err)) end end task.wait(CFG.SellDelay) end end)
task.spawn(function() while true do if CFG.AutoSteal then local ok,err=pcall(doSteal); if not ok then warn("[GAG3] Steal: "..tostring(err)) end end task.wait(1) end end)
task.spawn(function() while true do if CFG.AutoReplant then local ok,err=pcall(doReplant); if not ok then warn("[GAG3] Replant: "..tostring(err)) end end task.wait(2) end end)
task.spawn(function() while true do if CFG.FruitESP then local ok,err=pcall(doFruitESP); if not ok then warn("[GAG3] FruitESP: "..tostring(err)) end end task.wait(3) end end)
task.spawn(function() while true do if CFG.RestockNotify then local ok,err=pcall(checkRestock); if not ok then warn("[GAG3] Restock: "..tostring(err)) end end task.wait(1) end end)
task.spawn(function() while true do local ok,err=pcall(checkDefend); if not ok then warn("[GAG3] Defend: "..tostring(err)) end task.wait(0.5) end end)
task.spawn(function() while true do if CFG.AutoBuySeed then local ok,err=pcall(doBuySeed); if not ok then warn("[GAG3] BuySeed: "..tostring(err)) end end task.wait(CFG.BuyDelay) end end)
task.spawn(function() while true do if CFG.AutoBuyGear then local ok,err=pcall(doBuyGear); if not ok then warn("[GAG3] BuyGear: "..tostring(err)) end end task.wait(CFG.BuyDelay+1) end end)

-- ══════════════════════════════════════════
-- ══════════════════════════════════════════
local old = PGui:FindFirstChild("HoQuocHub")
if old then old:Destroy() end
local oldHQ = PGui:FindFirstChild("HoQuocHQ")
local oldHub2 = PGui:FindFirstChild("HoQuocHub_v2")
if oldHub2 then oldHub2:Destroy() end
if oldHQ then oldHQ:Destroy() end

-- ══════════════════════════════════════════
--  SCREEN GUI
-- ══════════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name = "HoQuocHub_v2"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 100
SG.Parent = PGui

-- Màu theme đen xám
local BG    = Color3.fromRGB(15,15,18)
local SBC   = Color3.fromRGB(20,20,24)
local TBC   = Color3.fromRGB(18,18,22)
local ROWC  = Color3.fromRGB(26,26,32)
local ROWON = Color3.fromRGB(18,40,22)
local SKC   = Color3.fromRGB(44,44,55)
local SKON  = Color3.fromRGB(55,185,65)
local PON   = Color3.fromRGB(40,200,65)
local POFF  = Color3.fromRGB(38,40,55)
local WHITE = Color3.fromRGB(255,255,255)
local DIM   = Color3.fromRGB(85,87,108)
local GREEN = Color3.fromRGB(55,180,65)
local RED   = Color3.fromRGB(180,35,35)
local DIVL  = Color3.fromRGB(30,30,38)
local TEXON = Color3.fromRGB(175,255,175)

-- ══════════════════════════════════════════
--  MAIN WINDOW
-- ══════════════════════════════════════════
local Win = Instance.new("Frame", SG)
Win.Name = "Win"
Win.Size = UDim2.new(0.88,0,0,350)
Win.Position = UDim2.new(0.06,0,0.08,0)
Win.BackgroundColor3 = BG
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Win.Visible = false  -- ẩn mặc định, bấm HQ để mở
Instance.new("UICorner", Win).CornerRadius = UDim.new(0,10)

-- TOP BAR
local TB = Instance.new("Frame", Win)
TB.Size = UDim2.new(1,0,0,34)
TB.Position = UDim2.new(0,0,0,0)
TB.BackgroundColor3 = TBC
TB.BorderSizePixel = 0
Instance.new("UICorner", TB).CornerRadius = UDim.new(0,10)

-- Fix UICorner bottom of TB
local TBF = Instance.new("Frame", TB)
TBF.Size = UDim2.new(1,0,0.5,0)
TBF.Position = UDim2.new(0,0,0.5,0)
TBF.BackgroundColor3 = TBC
TBF.BorderSizePixel = 0

local TL = Instance.new("TextLabel", TB)
TL.Size = UDim2.new(0,270,1,0)
TL.Position = UDim2.new(0,10,0,0)
TL.BackgroundTransparency = 1
TL.Text = "Ho Quoc Dev  |  GAG3 Hub v1.0"
TL.TextColor3 = Color3.fromRGB(220,55,55)
TL.TextSize = 12
TL.Font = Enum.Font.GothamBold
TL.TextXAlignment = Enum.TextXAlignment.Left

local DL = Instance.new("TextLabel", TB)
DL.Size = UDim2.new(0,180,1,0)
DL.Position = UDim2.new(0,275,0,0)
DL.BackgroundTransparency = 1
DL.Text = "discord.gg/hoquocdev"
DL.TextColor3 = DIM
DL.TextSize = 10
DL.Font = Enum.Font.Gotham
DL.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize button
local minimized = false
local MinB = Instance.new("TextButton", TB)
MinB.Size = UDim2.new(0,24,0,24)
MinB.Position = UDim2.new(1,-56,0.5,-12)
MinB.BackgroundColor3 = Color3.fromRGB(50,110,50)
MinB.Text = "-"
MinB.TextColor3 = WHITE
MinB.TextSize = 14
MinB.Font = Enum.Font.GothamBold
MinB.BorderSizePixel = 0
Instance.new("UICorner", MinB).CornerRadius = UDim.new(0,5)

-- Close button (ẩn menu, không destroy)
local ClsB = Instance.new("TextButton", TB)
ClsB.Size = UDim2.new(0,24,0,24)
ClsB.Position = UDim2.new(1,-28,0.5,-12)
ClsB.BackgroundColor3 = RED
ClsB.Text = "X"
ClsB.TextColor3 = WHITE
ClsB.TextSize = 12
ClsB.Font = Enum.Font.GothamBold
ClsB.BorderSizePixel = 0
Instance.new("UICorner", ClsB).CornerRadius = UDim.new(0,5)

MinB.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win, TweenInfo.new(0.2), {
        Size = minimized and UDim2.new(0.88,0,0,34) or UDim2.new(0.88,0,0,350)
    }):Play()
    MinB.Text = minimized and "+" or "-"
end)

-- DIV LINE
local DivLine = Instance.new("Frame", Win)
DivLine.Size = UDim2.new(1,0,0,1)
DivLine.Position = UDim2.new(0,0,0,34)
DivLine.BackgroundColor3 = DIVL
DivLine.BorderSizePixel = 0

-- SIDEBAR
local SB = Instance.new("Frame", Win)
SB.Size = UDim2.new(0,140,1,-35)
SB.Position = UDim2.new(0,0,0,35)
SB.BackgroundColor3 = SBC
SB.BorderSizePixel = 0

-- Fix UICorner sidebar
local SBCorner = Instance.new("UICorner", SB)
SBCorner.CornerRadius = UDim.new(0,10)
local SBCF = Instance.new("Frame", SB)
SBCF.Size = UDim2.new(0.5,0,1,0)
SBCF.Position = UDim2.new(0.5,0,0,0)
SBCF.BackgroundColor3 = SBC
SBCF.BorderSizePixel = 0

-- SIDEBAR DIV
local SBDiv = Instance.new("Frame", Win)
SBDiv.Size = UDim2.new(0,1,1,-35)
SBDiv.Position = UDim2.new(0,140,0,35)
SBDiv.BackgroundColor3 = DIVL
SBDiv.BorderSizePixel = 0

-- CONTENT AREA
local CT = Instance.new("Frame", Win)
CT.Size = UDim2.new(1,-141,1,-35)
CT.Position = UDim2.new(0,141,0,35)
CT.BackgroundColor3 = BG
CT.BorderSizePixel = 0
Instance.new("UICorner", CT).CornerRadius = UDim.new(0,10)

-- ══════════════════════════════════════════
--  PAGE SYSTEM (không dùng ScrollingFrame)
-- ══════════════════════════════════════════
local pages = {}
local navBtns = {}
local navYPos = 6  -- y offset cho nav buttons

local function showPage(name)
    for n,pg in pairs(pages) do
        pg.Visible = (n == name)
    end
    for n,b in pairs(navBtns) do
        local on = (n == name)
        b.BackgroundTransparency = on and 0 or 1
        b.TextColor3 = on and WHITE or DIM
    end
end

local function makePage(name)
    local pg = Instance.new("Frame", CT)
    pg.Size = UDim2.new(1,-8,1,-4)
    pg.Position = UDim2.new(0,4,0,2)
    pg.BackgroundTransparency = 1
    pg.BorderSizePixel = 0
    pg.Visible = false

    -- Page title
    local pt = Instance.new("TextLabel", pg)
    pt.Size = UDim2.new(1,0,0,28)
    pt.Position = UDim2.new(0,4,0,4)
    pt.BackgroundTransparency = 1
    pt.Text = name
    pt.TextColor3 = WHITE
    pt.TextSize = 15
    pt.Font = Enum.Font.GothamBold
    pt.TextXAlignment = Enum.TextXAlignment.Left

    -- Divider
    local ln = Instance.new("Frame", pg)
    ln.Size = UDim2.new(1,-8,0,1)
    ln.Position = UDim2.new(0,4,0,32)
    ln.BackgroundColor3 = DIVL
    ln.BorderSizePixel = 0

    -- Item container - dùng Frame + UIListLayout (không ScrollingFrame)
    local c = Instance.new("Frame", pg)
    c.Size = UDim2.new(1,-8,1,-38)
    c.Position = UDim2.new(0,4,0,36)
    c.BackgroundTransparency = 1
    c.BorderSizePixel = 0
    c.ClipsDescendants = true

    local ll = Instance.new("UIListLayout", c)
    ll.Padding = UDim.new(0,4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder

    pages[name] = pg
    return pg, c
end

local function makeNav(icon, label)
    local b = Instance.new("TextButton", SB)
    b.Size = UDim2.new(1,-8,0,30)
    b.Position = UDim2.new(0,4,0,navYPos)
    b.BackgroundColor3 = Color3.fromRGB(28,32,44)
    b.BackgroundTransparency = 1
    b.Text = icon .. "  " .. label
    b.TextColor3 = DIM
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    local pad = Instance.new("UIPadding", b)
    pad.PaddingLeft = UDim.new(0,8)
    navBtns[label] = b
    b.MouseButton1Click:Connect(function() showPage(label) end)
    navYPos = navYPos + 32
end

-- ══════════════════════════════════════════
--  TOGGLE WIDGET
-- ══════════════════════════════════════════
local function mkToggle(parent, icon, label, key, order, cb)
    local row = Instance.new("TextButton", parent)
    row.Size = UDim2.new(1,0,0,38)
    row.BackgroundColor3 = ROWC
    row.BorderSizePixel = 0
    row.Text = ""
    row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)
    local sk = Instance.new("UIStroke", row)
    sk.Color = SKC
    sk.Thickness = 1

    local iL = Instance.new("TextLabel", row)
    iL.Size = UDim2.new(0,30,1,0)
    iL.Position = UDim2.new(0,4,0,0)
    iL.BackgroundTransparency = 1
    iL.Text = icon
    iL.TextSize = 16
    iL.Font = Enum.Font.Gotham

    local lL = Instance.new("TextLabel", row)
    lL.Size = UDim2.new(1,-86,1,0)
    lL.Position = UDim2.new(0,36,0,0)
    lL.BackgroundTransparency = 1
    lL.Text = label
    lL.TextColor3 = Color3.fromRGB(180,182,200)
    lL.TextSize = 11
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local pill = Instance.new("Frame", row)
    pill.Size = UDim2.new(0,38,0,18)
    pill.Position = UDim2.new(1,-44,0.5,-9)
    pill.BackgroundColor3 = POFF
    pill.BorderSizePixel = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)

    local dot = Instance.new("Frame", pill)
    dot.Size = UDim2.new(0,12,0,12)
    dot.Position = UDim2.new(0,3,0.5,-6)
    dot.BackgroundColor3 = Color3.fromRGB(160,162,180)
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    local function refresh()
        local on = CFG[key]
        TweenService:Create(row,  TweenInfo.new(0.15), {BackgroundColor3 = on and ROWON or ROWC}):Play()
        TweenService:Create(sk,   TweenInfo.new(0.15), {Color = on and SKON or SKC}):Play()
        TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = on and PON or POFF}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.15), {Position = on and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)}):Play()
        lL.TextColor3 = on and TEXON or Color3.fromRGB(180,182,200)
    end

    refresh() -- sync ngay khi tạo

    row.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        refresh()
        if cb then cb(CFG[key]) end
    end)
end

-- INPUT WIDGET
local function mkInput(parent, label, default, order, onChange)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = ROWC
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke", row).Color = SKC

    local lL = Instance.new("TextLabel", row)
    lL.Size = UDim2.new(0.55,0,1,0)
    lL.Position = UDim2.new(0,8,0,0)
    lL.BackgroundTransparency = 1
    lL.Text = label
    lL.TextColor3 = DIM
    lL.TextSize = 10
    lL.Font = Enum.Font.Gotham
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local tb = Instance.new("TextBox", row)
    tb.Size = UDim2.new(0,105,0,22)
    tb.Position = UDim2.new(1,-110,0.5,-11)
    tb.BackgroundColor3 = Color3.fromRGB(20,20,28)
    tb.TextColor3 = Color3.fromRGB(130,255,130)
    tb.Text = tostring(default)
    tb.TextSize = 10
    tb.Font = Enum.Font.Gotham
    tb.BorderSizePixel = 0
    tb.ClearTextOnFocus = false
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0,5)
    Instance.new("UIPadding", tb).PaddingLeft = UDim.new(0,5)
    tb.FocusLost:Connect(function()
        if onChange then onChange(tb.Text) end
    end)
end

-- SECTION LABEL
local function mkSec(parent, txt, order)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1,0,0,16)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order
    local l = Instance.new("TextLabel", f)
    l.Size = UDim2.new(1,0,1,0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(65,68,90)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
end

-- MODE BUTTON
local function mkModeBtn(parent, order)
    local row = Instance.new("TextButton", parent)
    row.Size = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = ROWC
    row.BorderSizePixel = 0
    row.Text = ""
    row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)
    local sk = Instance.new("UIStroke", row)
    sk.Color = Color3.fromRGB(50,90,180)
    sk.Thickness = 1

    local lL = Instance.new("TextLabel", row)
    lL.Size = UDim2.new(1,-10,1,0)
    lL.Position = UDim2.new(0,8,0,0)
    lL.BackgroundTransparency = 1
    lL.Font = Enum.Font.GothamBold
    lL.TextSize = 10
    lL.TextXAlignment = Enum.TextXAlignment.Left

    local function r()
        if CFG.TeleportMode then
            lL.Text = "Teleport Mode — tap doi"
            lL.TextColor3 = Color3.fromRGB(100,160,255)
            sk.Color = Color3.fromRGB(50,90,180)
        else
            lL.Text = "Dung Im Mode — tap doi"
            lL.TextColor3 = Color3.fromRGB(255,190,60)
            sk.Color = Color3.fromRGB(180,130,30)
        end
    end
    r()
    row.MouseButton1Click:Connect(function()
        CFG.TeleportMode = not CFG.TeleportMode
        r()
    end)
end

-- ══════════════════════════════════════════
--  BUILD PAGES
-- ══════════════════════════════════════════

-- HOME
local _, hC = makePage("Home")
local hInfo = Instance.new("Frame", hC)
hInfo.Size = UDim2.new(1,0,0,48)
hInfo.BackgroundColor3 = Color3.fromRGB(18,40,22)
hInfo.BorderSizePixel = 0
hInfo.LayoutOrder = 1
Instance.new("UICorner", hInfo).CornerRadius = UDim.new(0,8)
local hT = Instance.new("TextLabel", hInfo)
hT.Size = UDim2.new(1,-8,1,0)
hT.Position = UDim2.new(0,8,0,0)
hT.BackgroundTransparency = 1
hT.Text = "Ho Quoc Dev  GAG3 Hub v1.0  ProximityPrompt AutoFarm"
hT.TextColor3 = TEXON
hT.TextSize = 11
hT.Font = Enum.Font.GothamBold
hT.TextWrapped = true
hT.TextXAlignment = Enum.TextXAlignment.Left

-- Zalo group link
local zaloF = Instance.new("TextButton", hC)
zaloF.Size = UDim2.new(1,0,0,28)
zaloF.BackgroundColor3 = Color3.fromRGB(14,60,100)
zaloF.BorderSizePixel = 0
zaloF.LayoutOrder = 2
zaloF.Text = "Zalo Group: zalo.me/g/orimigxmugvlzj3lcwci"
zaloF.TextColor3 = Color3.fromRGB(100,200,255)
zaloF.TextSize = 9
zaloF.Font = Enum.Font.GothamBold
zaloF.TextTruncate = Enum.TextTruncate.AtEnd
Instance.new("UICorner", zaloF).CornerRadius = UDim.new(0,7)
zaloF.MouseButton1Click:Connect(function()
    setclipboard("https://zalo.me/g/orimigxmugvlzj3lcwci")
    zaloF.Text = "Da copy link!"
    task.delay(2, function()
        zaloF.Text = "Zalo Group: zalo.me/g/orimigxmugvlzj3lcwci"
    end)
end)

local hStat = Instance.new("Frame", hC)
hStat.Size = UDim2.new(1,0,0,28)
hStat.BackgroundColor3 = Color3.fromRGB(18,18,24)
hStat.BorderSizePixel = 0
hStat.LayoutOrder = 3
Instance.new("UICorner", hStat).CornerRadius = UDim.new(0,7)
local hStatL = Instance.new("TextLabel", hStat)
hStatL.Size = UDim2.new(1,-8,1,0)
hStatL.Position = UDim2.new(0,6,0,0)
hStatL.BackgroundTransparency = 1
hStatL.TextColor3 = GREEN
hStatL.TextSize = 10
hStatL.Font = Enum.Font.Gotham
hStatL.TextXAlignment = Enum.TextXAlignment.Left

local _lastAction = "Chua co hanh dong"
task.spawn(function()
    while hStatL and hStatL.Parent do
        local t = {}
        if CFG.AutoPlants     then table.insert(t,"Plant") end
        if CFG.AutoCollection then table.insert(t,"Collect") end
        if CFG.AutoSell       then table.insert(t,"Sell") end
        if CFG.AutoSteal      then table.insert(t,"Steal") end
        if CFG.AutoReplant    then table.insert(t,"Replant") end
        if CFG.AutoBuySeed    then table.insert(t,"BuySeed") end
        if CFG.AutoBuyGear    then table.insert(t,"BuyGear") end
        if CFG.SpeedBoost     then table.insert(t,"Speed") end
        if CFG.PlayerESP      then table.insert(t,"ESP") end
        if CFG.FruitESP       then table.insert(t,"FruitESP") end
        if CFG.RestockNotify  then table.insert(t,"Restock") end
        if CFG.AutoDefend     then table.insert(t,"Defend") end
        if #t > 0 then
            hStatL.Text = "ON: "..table.concat(t," | ")
        else
            hStatL.Text = "Chua bat gi"
        end
        task.wait(1.5)
    end
end)

-- MAIN
local _, mC = makePage("Main")
mkSec(mC,"AUTOMATION",1)
mkToggle(mC,"","Auto Plants",     "AutoPlants",    2)
mkToggle(mC,"","Auto Collection", "AutoCollection",3)
mkToggle(mC,"","Auto Sell",       "AutoSell",      4)
mkToggle(mC,"","Auto Replant",    "AutoReplant",   5)
mkSec(mC,"NIGHT STEAL",6)
mkToggle(mC,"","Auto Steal",      "AutoSteal",     7)
mkSec(mC,"MODE",8)
mkModeBtn(mC,9)

-- AUTOMATICALLY - ScrollingFrame để scroll
local autoPageFrame, _ = makePage("Automatically")
local aScroll = Instance.new("ScrollingFrame", autoPageFrame)
aScroll.Size = UDim2.new(1,-8,1,-38)
aScroll.Position = UDim2.new(0,4,0,36)
aScroll.BackgroundTransparency = 1
aScroll.BorderSizePixel = 0
aScroll.ScrollBarThickness = 3
aScroll.ScrollBarImageColor3 = Color3.fromRGB(55,185,65)
aScroll.CanvasSize = UDim2.new(0,0,0,0)
aScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
-- Không destroy frame vì title/divider cần giữ
local aLL = Instance.new("UIListLayout", aScroll)
aLL.Padding = UDim.new(0,4)
aLL.SortOrder = Enum.SortOrder.LayoutOrder
local aC = aScroll

-- Helper tạo checkbox item
local function mkCheckbox(parent, label, key, subkey, order)
    local row = Instance.new("TextButton", parent)
    row.Size = UDim2.new(1,0,0,30)
    row.BackgroundColor3 = ROWC
    row.BorderSizePixel = 0
    row.Text = ""
    row.LayoutOrder = order
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)

    local box = Instance.new("Frame", row)
    box.Size = UDim2.new(0,18,0,18)
    box.Position = UDim2.new(0,6,0.5,-9)
    box.BackgroundColor3 = ROWC
    box.BorderSizePixel = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,4)
    Instance.new("UIStroke", box).Color = SKC

    local check = Instance.new("TextLabel", box)
    check.Size = UDim2.new(1,0,1,0)
    check.BackgroundTransparency = 1
    check.Text = ""
    check.TextColor3 = GREEN
    check.TextSize = 12
    check.Font = Enum.Font.GothamBold

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1,-30,1,0)
    lbl.Position = UDim2.new(0,28,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = DIM
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    local function refreshCB()
        local on = CFG[key] and CFG[key][subkey]
        check.Text = on and "✓" or ""
        box.BackgroundColor3 = on and Color3.fromRGB(20,80,30) or ROWC
        lbl.TextColor3 = on and TEXON or DIM
    end
    refreshCB()

    row.MouseButton1Click:Connect(function()
        if not CFG[key] then CFG[key] = {} end
        CFG[key][subkey] = not CFG[key][subkey]
        refreshCB()
    end)
end
-- ═══ AUTO BUY SEED ═══
mkSec(aC,"AUTO BUY SEED",1)
mkToggle(aC,"","Auto Buy Seed","AutoBuySeed",2)

-- Buy All Seed toggle
local buyAllSeedRow = Instance.new("TextButton", aC)
buyAllSeedRow.Size = UDim2.new(1,0,0,30)
buyAllSeedRow.BackgroundColor3 = Color3.fromRGB(20,50,20)
buyAllSeedRow.BorderSizePixel = 0
buyAllSeedRow.Text = ""
buyAllSeedRow.LayoutOrder = 3
Instance.new("UICorner", buyAllSeedRow).CornerRadius = UDim.new(0,7)
Instance.new("UIStroke", buyAllSeedRow).Color = Color3.fromRGB(40,140,50)
local basL = Instance.new("TextLabel", buyAllSeedRow)
basL.Size = UDim2.new(0.6,0,1,0)
basL.Position = UDim2.new(0,10,0,0)
basL.BackgroundTransparency = 1
basL.Text = "Mua TẤT CẢ seed"
basL.TextColor3 = TEXON
basL.TextSize = 11
basL.Font = Enum.Font.GothamBold
basL.TextXAlignment = Enum.TextXAlignment.Left
local basPill = Instance.new("Frame", buyAllSeedRow)
basPill.Size = UDim2.new(0,38,0,18)
basPill.Position = UDim2.new(1,-44,0.5,-9)
basPill.BackgroundColor3 = CFG.BuyAllSeed and PON or POFF
basPill.BorderSizePixel = 0
Instance.new("UICorner", basPill).CornerRadius = UDim.new(1,0)
local basDot = Instance.new("Frame", basPill)
basDot.Size = UDim2.new(0,12,0,12)
basDot.Position = CFG.BuyAllSeed and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
basDot.BackgroundColor3 = WHITE
basDot.BorderSizePixel = 0
Instance.new("UICorner", basDot).CornerRadius = UDim.new(1,0)
buyAllSeedRow.MouseButton1Click:Connect(function()
    CFG.BuyAllSeed = not CFG.BuyAllSeed
    TweenService:Create(basPill,TweenInfo.new(0.15),{BackgroundColor3=CFG.BuyAllSeed and PON or POFF}):Play()
    TweenService:Create(basDot,TweenInfo.new(0.15),{Position=CFG.BuyAllSeed and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)}):Play()
end)

-- Seed checkbox list
mkSec(aC,"Chọn seed muốn mua:",4)
local seedOrder = 5
for _, sn in ipairs({"Bamboo Seed","Apple Seed","Blueberry Seed","Tomato Seed",
    "Cactus Seed","Grape Seed","Tulip Seed","Strawberry Seed",
    "Cherry","Sunflower","Venus Fly Trap","Pomegranate",
    "Poison Apple","Moon Bloom","Dragon's Breath"}) do
    mkCheckbox(aC, sn, "SelectedSeeds", sn, seedOrder)
    seedOrder = seedOrder + 1
end

-- ═══ AUTO BUY GEAR ═══
mkSec(aC,"AUTO BUY GEAR", seedOrder)
seedOrder = seedOrder + 1
mkToggle(aC,"","Auto Buy Gear","AutoBuyGear", seedOrder)
seedOrder = seedOrder + 1

-- Buy All Gear toggle
local buyAllGearRow = Instance.new("TextButton", aC)
buyAllGearRow.Size = UDim2.new(1,0,0,30)
buyAllGearRow.BackgroundColor3 = Color3.fromRGB(20,50,20)
buyAllGearRow.BorderSizePixel = 0
buyAllGearRow.Text = ""
buyAllGearRow.LayoutOrder = seedOrder
seedOrder = seedOrder + 1
Instance.new("UICorner", buyAllGearRow).CornerRadius = UDim.new(0,7)
Instance.new("UIStroke", buyAllGearRow).Color = Color3.fromRGB(40,140,50)
local bagL = Instance.new("TextLabel", buyAllGearRow)
bagL.Size = UDim2.new(0.6,0,1,0)
bagL.Position = UDim2.new(0,10,0,0)
bagL.BackgroundTransparency = 1
bagL.Text = "Mua TẤT CẢ gear"
bagL.TextColor3 = TEXON
bagL.TextSize = 11
bagL.Font = Enum.Font.GothamBold
bagL.TextXAlignment = Enum.TextXAlignment.Left
local bagPill = Instance.new("Frame", buyAllGearRow)
bagPill.Size = UDim2.new(0,38,0,18)
bagPill.Position = UDim2.new(1,-44,0.5,-9)
bagPill.BackgroundColor3 = CFG.BuyAllGear and PON or POFF
bagPill.BorderSizePixel = 0
Instance.new("UICorner", bagPill).CornerRadius = UDim.new(1,0)
local bagDot = Instance.new("Frame", bagPill)
bagDot.Size = UDim2.new(0,12,0,12)
bagDot.Position = CFG.BuyAllGear and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
bagDot.BackgroundColor3 = WHITE
bagDot.BorderSizePixel = 0
Instance.new("UICorner", bagDot).CornerRadius = UDim.new(1,0)
buyAllGearRow.MouseButton1Click:Connect(function()
    CFG.BuyAllGear = not CFG.BuyAllGear
    TweenService:Create(bagPill,TweenInfo.new(0.15),{BackgroundColor3=CFG.BuyAllGear and PON or POFF}):Play()
    TweenService:Create(bagDot,TweenInfo.new(0.15),{Position=CFG.BuyAllGear and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)}):Play()
end)

-- Gear checkbox list
mkSec(aC,"Chọn gear muốn mua:", seedOrder)
seedOrder = seedOrder + 1
for _, gn in ipairs({"Common Sprinkler","Uncommon Sprinkler","Rare Sprinkler",
    "Legendary Sprinkler","Super Sprinkler","Common Watering Can","Super Watering Can",
    "Trowel","Gnome","Lantern","Basic Pot","Wheelbarrow","Teleporter",
    "Jump Mushroom","Speed Mushroom","Shrink Mushroom","Supersize Mushroom","Invisibility Mushroom"}) do
    mkCheckbox(aC, gn, "SelectedGears", gn, seedOrder)
    seedOrder = seedOrder + 1
end

-- ═══ AUTO SELL ═══
mkSec(aC,"AUTO SELL", seedOrder)
seedOrder = seedOrder + 1
mkToggle(aC,"","Auto Sell All Fruits","AutoSell", seedOrder)

-- SHOP
local _, shC = makePage("Shop")
mkSec(shC,"SHOP",1)
local shI = Instance.new("TextLabel", shC)
shI.Size = UDim2.new(1,0,0,50)
shI.BackgroundColor3 = ROWC
shI.BorderSizePixel = 0
shI.LayoutOrder = 2
shI.TextColor3 = DIM
shI.TextSize = 10
shI.Font = Enum.Font.Gotham
shI.TextWrapped = true
shI.TextXAlignment = Enum.TextXAlignment.Left
shI.Text = "  Bat Auto Buy trong tab Automatically"
Instance.new("UICorner", shI).CornerRadius = UDim.new(0,8)

-- MISC
local _, miC = makePage("Misc")
mkSec(miC,"VISUAL",1)
mkToggle(miC,"","Player ESP",  "PlayerESP",2,function(on)
    if on then enableESP() else disableESP() end
end)
mkToggle(miC,"","Fruit ESP",   "FruitESP", 3,function(on)
    if not on then clearFruitESP() end
end)
mkSec(miC,"NOTIFY",4)
mkToggle(miC,"","Restock Notify","RestockNotify",5)
mkSec(miC,"DEFEND",6)
mkToggle(miC,"","Auto Defend", "AutoDefend",7)
mkSec(miC,"MISC",8)
mkToggle(miC,"","More FPS",    "MoreFPS",9,function(on)
    if on then
        pcall(function() setfpscap(60) end)
        game:GetService("Lighting").GlobalShadows = false
    end
end)
mkSec(miC,"SERVER",10)
local hopB = Instance.new("TextButton", miC)
hopB.Size = UDim2.new(1,0,0,34)
hopB.BackgroundColor3 = ROWC
hopB.BorderSizePixel = 0
hopB.Text = "Hop Server"
hopB.TextColor3 = Color3.fromRGB(180,182,200)
hopB.TextSize = 11
hopB.Font = Enum.Font.GothamBold
hopB.LayoutOrder = 11
Instance.new("UICorner", hopB).CornerRadius = UDim.new(0,8)
hopB.MouseButton1Click:Connect(function()
    pcall(function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,LP)
    end)
end)

-- SETTINGS
local _, stC = makePage("Settings")
mkSec(stC,"PLAYER",1)
mkToggle(stC,"","Speed Boost","SpeedBoost",2,function(on) applySpeed(on) end)
mkInput(stC,"WalkSpeed",    CFG.SpeedValue,   3,function(v) CFG.SpeedValue=tonumber(v) or 60; if CFG.SpeedBoost then applySpeed(true) end end)
mkSec(stC,"DELAYS",4)
mkInput(stC,"Harvest Delay",CFG.HarvestDelay, 5,function(v) CFG.HarvestDelay=tonumber(v) or 0.15 end)
mkInput(stC,"Sell Delay",   CFG.SellDelay,    6,function(v) CFG.SellDelay=tonumber(v) or 3 end)
mkInput(stC,"Buy Delay",    CFG.BuyDelay,     7,function(v) CFG.BuyDelay=tonumber(v) or 2 end)
mkInput(stC,"Range",        CFG.HarvestRange, 8,function(v) CFG.HarvestRange=tonumber(v) or 15 end)
mkSec(stC,"RESTOCK TIMER",9)
mkInput(stC,"Day (s)",  CFG.RestockDay,   10,function(v) CFG.RestockDay=tonumber(v) or 300 end)
mkInput(stC,"Night (s)",CFG.RestockNight, 11,function(v) CFG.RestockNight=tonumber(v) or 480 end)

-- SETTINGS UI
local _, suC = makePage("Settings UI")
mkSec(suC,"WINDOW",1)
local rstB = Instance.new("TextButton", suC)
rstB.Size = UDim2.new(1,0,0,34)
rstB.BackgroundColor3 = Color3.fromRGB(40,15,15)
rstB.BorderSizePixel = 0
rstB.Text = "Reset vi tri UI"
rstB.TextColor3 = Color3.fromRGB(220,100,100)
rstB.TextSize = 11
rstB.Font = Enum.Font.GothamBold
rstB.LayoutOrder = 2
Instance.new("UICorner", rstB).CornerRadius = UDim.new(0,8)
rstB.MouseButton1Click:Connect(function()
    Win.Position = UDim2.new(0.06,0,0.08,0)
end)

-- ══════════════════════════════════════════
--  NAV BUTTONS
-- ══════════════════════════════════════════
makeNav("H","Home")
makeNav("M","Main")
makeNav("A","Auto")
makeNav("S","Shop")
makeNav("X","Misc")
makeNav("C","Settings")
makeNav("U","Settings UI")

showPage("Home")

-- ══════════════════════════════════════════
--  winVisible toggle
-- ══════════════════════════════════════════
-- HQBtn nằm trong ScreenGui riêng để không bị Win che
local HQ_SG = Instance.new("ScreenGui")
HQ_SG.Name = "HoQuocHQ"
HQ_SG.ResetOnSpawn = false
HQ_SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HQ_SG.DisplayOrder = 999  -- luôn trên cùng
HQ_SG.Parent = PGui

local HQBtn = Instance.new("TextButton", HQ_SG)
HQBtn.Size = UDim2.new(0, 42, 0, 42)
HQBtn.Position = UDim2.new(0, 8, 0, 8)
HQBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
HQBtn.Text = "HQ"
HQBtn.TextColor3 = Color3.new(1,1,1)
HQBtn.TextSize = 14
HQBtn.Font = Enum.Font.GothamBold
HQBtn.BorderSizePixel = 0
HQBtn.ZIndex = 999
HQBtn.Active = true
Instance.new("UICorner", HQBtn).CornerRadius = UDim.new(0, 8)
local HQStroke = Instance.new("UIStroke", HQBtn)
HQStroke.Color = Color3.fromRGB(220, 80, 80)
HQStroke.Thickness = 1.5

local pulsing = true
task.spawn(function()
    while HQBtn and HQBtn.Parent do
        if pulsing and not winVisible then
            TweenService:Create(HQBtn, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            }):Play()
            task.wait(0.6)
            TweenService:Create(HQBtn, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundColor3 = Color3.fromRGB(120, 20, 20)
            }):Play()
            task.wait(0.6)
        else
            task.wait(0.5)
        end
    end
end)

-- isDragging khai báo trước khi dùng
local UIS2 = game:GetService("UserInputService")
local isDragging = false
local dragStart, startPos
local winVisible = false

local function toggleMenu(show)
    winVisible = show
    if show then
        Win.Size = UDim2.new(0.88,0,0,0)
        Win.Visible = true
        TweenService:Create(Win, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0.88,0,0,350)
        }):Play()
        TweenService:Create(HQBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(30,110,50)
        }):Play()
        HQStroke.Color = Color3.fromRGB(60,200,80)
        pulsing = false
    else
        TweenService:Create(Win, TweenInfo.new(0.15, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0.88,0,0,0)
        }):Play()
        task.delay(0.15, function()
            Win.Visible = false
            Win.Size = UDim2.new(0.88,0,0,350)
        end)
        TweenService:Create(HQBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(160,30,30)
        }):Play()
        HQStroke.Color = Color3.fromRGB(220,80,80)
        pulsing = true
    end
end

HQBtn.MouseButton1Click:Connect(function()
    if isDragging then return end
    toggleMenu(not winVisible)
end)

ClsB.MouseButton1Click:Connect(function()
    toggleMenu(false)
end)

HQBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = false
        dragStart = input.Position
        startPos = HQBtn.Position
    end
end)

HQBtn.InputChanged:Connect(function(input)
    if dragStart and (
        input.UserInputType == Enum.UserInputType.Touch or
        input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local delta = input.Position - dragStart
        -- Chỉ tính là drag nếu di chuyển > 5px
        if delta.Magnitude > 5 then
            isDragging = true
            HQBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end
end)

UIS2.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = nil
        isDragging = false
    end
end)

print("✅ Ho Quoc Dev Hub v2.0 loaded! - Remote Buy/Sell enabled")
