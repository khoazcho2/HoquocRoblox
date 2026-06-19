
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
    if not pp then return end
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

-- Buy Seed từ xa (thử thêm, không block fallback)
local function remoteBuySeed(seedName)
    local remote = getPacketRemote()
    if not remote then return end
    local nameBytes = nameToBytes(seedName)
    local bytes = {0x69, 0x00, #nameBytes}
    for _, b in ipairs(nameBytes) do table.insert(bytes, b) end
    local buf = makeBuffer(bytes)
    pcall(function() remote:FireServer(buf) end)
end

-- Buy Gear từ xa (thử thêm, không block fallback)
local function remoteBuyGear(gearName)
    local remote = getPacketRemote()
    if not remote then return end
    local nameBytes = nameToBytes(gearName)
    local bytes = {0x6d, 0x00, #nameBytes}
    for _, b in ipairs(nameBytes) do table.insert(bytes, b) end
    local buf = makeBuffer(bytes)
    pcall(function() remote:FireServer(buf) end)
end

-- Sell All từ xa (thử thêm, không block fallback)
local function remoteSellAll()
    local remote = getPacketRemote()
    if not remote then return end
    local root = getRoot()
    if not root then return end
    local pos = root.Position
    local x, y, z = pos.X, pos.Y, pos.Z
    local function float32LE(f)
        local ok, result = pcall(function()
            return {string.byte(string.pack("<f", f), 1, 4)}
        end)
        if ok then return result end
        local sign = f < 0 and 1 or 0
        f = math.abs(f)
        local exp = math.floor(math.log(f) / math.log(2))
        local mant = f / (2^exp) - 1
        exp = exp + 127
        local bits = sign * 0x80000000 + exp * 0x800000 + math.floor(mant * 0x800000)
        return {bits%256, math.floor(bits/256)%256, math.floor(bits/65536)%256, math.floor(bits/16777216)%256}
    end
    local bytes = {0x42, 0x00}
    for _, b in ipairs(float32LE(x)) do table.insert(bytes, b) end
    for _, b in ipairs(float32LE(y)) do table.insert(bytes, b) end
    for _, b in ipairs(float32LE(z)) do table.insert(bytes, b) end
    pcall(function() remote:FireServer(makeBuffer(bytes)) end)
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

-- Kiểm tra prompt có thuộc vườn mình không
local function isOwnPrompt(pp)
    local cur = pp.Parent
    for _ = 1, 6 do
        if not cur then break end
        local o = cur:GetAttribute("Owner") or cur:GetAttribute("PlotOwner")
            or cur:GetAttribute("PlayerName") or cur:GetAttribute("OwnerName")
        if o == LP.Name then return true end
        if o and o ~= LP.Name then return false end
        cur = cur.Parent
    end
    -- Không có owner attribute: dùng myFarmPos đã cache (không gọi updateMyFarmPos lại)
    if myFarmPos then
        local part = getPart(pp.Parent)
        if part and (myFarmPos - part.Position).Magnitude < 40 then return true end
    end
    return false
end

local function doCollection()
    if not CFG.AutoCollection then return end  -- guard ngay đầu
    updateMyFarmPos()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if not CFG.AutoCollection then return end  -- check trong loop
        if pp:IsA("ProximityPrompt") and pp.Enabled
        and pp.ActionText:lower():find("harvest") then
            -- CHỈ hái vườn mình
            if not isOwnPrompt(pp) then continue end
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
    local root = getRoot()
    if not root then return end
    local farmPos = root.Position

    -- ── Ưu tiên 1: Remote sell ──
    remoteSellAll()
    task.wait(0.05)

    -- ── Ưu tiên 2: Click GUI button "Sell" (như trong screenshot) ──
    local function trySellGui()
        for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
            if v:IsA("TextButton") or v:IsA("ImageButton") then
                local txt = v:IsA("TextButton") and v.Text:lower() or ""
                local nm  = v.Name:lower()
                if txt == "sell" or nm == "sell" or nm == "sellbutton"
                or txt:find("sell all") or nm:find("sellbtn") then
                    pcall(function() v.MouseButton1Click:Fire() end)
                    pcall(function() v.Activated:Fire() end)
                    pcall(function() v:Activate() end)
                    task.wait(0.2)
                    -- Xác nhận popup nếu có
                    for _, v2 in ipairs(LP.PlayerGui:GetDescendants()) do
                        if v2:IsA("TextButton") then
                            local t2 = v2.Text:lower()
                            if t2 == "confirm" or t2 == "yes" or t2 == "ok"
                            or t2:find("sell all") or t2:find("submit") then
                                pcall(function() v2.MouseButton1Click:Fire() end)
                                pcall(function() v2.Activated:Fire() end)
                            end
                        end
                    end
                    return true
                end
            end
        end
        return false
    end

    if trySellGui() then
        root.CFrame = CFrame.new(farmPos)
        return
    end

    -- ── Ưu tiên 3: ProximityPrompt sell gần nhất ──
    local bestPP, bestDist = nil, math.huge
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local a     = pp.ActionText:lower()
            local pName = (pp.Parent and pp.Parent.Name or ""):lower()
            if a:find("sell") or a:find("submit") or a:find("cash")
            or pName:find("sell") or pName:find("market") or pName:find("cashier") then
                local part = getPart(pp.Parent)
                if part then
                    local d = (root.Position - part.Position).Magnitude
                    if d < bestDist then bestDist = d bestPP = pp end
                end
            end
        end
    end

    if bestPP then
        local part = getPart(bestPP.Parent)
        if part then
            root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
            task.wait(0.1)
            firePrompt(bestPP) firePrompt(bestPP)
            task.wait(0.15)
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

-- ═══════════════════════════════════════════
--  AUTO STEAL (viết lại hoàn toàn)
-- ═══════════════════════════════════════════
local function collectStealTargets()
    local targets = {}
    updateMyFarmPos()
    local myPos = myFarmPos

    -- Tập hợp vị trí vườn của các player khác để ưu tiên
    local otherPlayerPos = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then table.insert(otherPlayerPos, r.Position) end
        end
    end

    for _, pp in ipairs(workspace:GetDescendants()) do
        if not pp:IsA("ProximityPrompt") then continue end

        local a = pp.ActionText:lower()
        -- Tìm tất cả prompt có thể hái/steal: harvest, steal, take, grab, pick, collect
        local isHarvest = a:find("harvest") or a:find("steal") or a:find("take")
            or a:find("grab") or a:find("pick") or a:find("collect")
        if not isHarvest then continue end
        if not pp.Enabled then continue end

        local part = getPart(pp.Parent)
        if not part then continue end

        -- Bỏ qua vườn của mình (kiểm tra owner attribute + khoảng cách farm)
        local owner = nil
        local cur = pp.Parent
        for _ = 1, 4 do
            if not cur then break end
            owner = cur:GetAttribute("Owner") or cur:GetAttribute("PlotOwner")
                or cur:GetAttribute("PlayerName") or cur:GetAttribute("OwnerName")
            if owner then break end
            cur = cur.Parent
        end
        if owner == LP.Name then continue end
        -- Nếu không có owner, bỏ qua nếu quá gần farm mình
        if not owner and myPos then
            if (myPos - part.Position).Magnitude < 25 then continue end
        end

        local score = getRarityScore(pp.Parent.Name)
        score = score + 10  -- tất cả đều được steal (không lọc rarity)
        for _, pPos in ipairs(otherPlayerPos) do
            if (pPos - part.Position).Magnitude < 50 then
                score = score + 30
                break
            end
        end

        table.insert(targets, { pp=pp, part=part, score=score })
    end

    table.sort(targets, function(a,b) return a.score > b.score end)
    return targets
end

local stealRunning = false

local function doSteal()
    if not CFG.AutoSteal then stealRunning = false return end
    if not isNight() then stealRunning = false return end
    if stealRunning then return end
    stealRunning = true

    -- Lưu vị trí farm trước khi đi steal
    updateMyFarmPos()
    local savedFarmPos = myFarmPos

    local ok, err = pcall(function()
        while isNight() and CFG.AutoSteal do
            local targets = collectStealTargets()

            if #targets == 0 then
                task.wait(1.5)
            else
                for _, t in ipairs(targets) do
                    if not isNight() or not CFG.AutoSteal then break end
                    if not t.pp or not t.pp.Parent then continue end -- pp có thể đã mất

                    local root = getRoot()
                    if not root then break end

                    -- Tele đến cây
                    root.CFrame = CFrame.new(t.part.Position + Vector3.new(0, 3.5, 0))
                    task.wait(0.15)

                    -- Hái 3 lần để chắc chắn
                    firePrompt(t.pp) task.wait(0.08)
                    firePrompt(t.pp) task.wait(0.08)
                    firePrompt(t.pp) task.wait(0.08)

                    -- Về farm ngay
                    if savedFarmPos then
                        root.CFrame = CFrame.new(savedFarmPos + Vector3.new(0, 4, 0))
                    end
                    task.wait(0.2)
                end
            end
            task.wait(0.2)
        end
    end)

    if not ok then warn("[GAG3] Steal error: "..tostring(err)) end
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
    mythic    = Color3.fromRGB(255, 40,  40),
    legendary = Color3.fromRGB(255, 210,  0),
    super     = Color3.fromRGB(  0, 220, 255),
    epic      = Color3.fromRGB(200,   0, 255),
    rare      = Color3.fromRGB( 50, 130, 255),
    uncommon  = Color3.fromRGB(  0, 220,  90),
    common    = Color3.fromRGB(180, 180, 180),
}
local rarityEmojis = {
    mythic="🔴", legendary="⭐", super="💎", epic="💜", rare="🔵", uncommon="🟢", common="⚪",
}
local function getRarityColor(name)
    local n = name:lower()
    for rarity, color in pairs(rarityColors) do if n:find(rarity) then return color end end
    return rarityColors.common
end
local function getRarityEmoji(name)
    local n = name:lower()
    for rarity, emoji in pairs(rarityEmojis) do if n:find(rarity) then return emoji end end
    return "🌿"
end
-- Lấy tên thật của cây (bỏ qua tên generic như HarvestPart/Part)
local function getFruitName(pp)
    if not pp or not pp.Parent then return "Fruit" end
    local function isGeneric(n)
        n = n:lower()
        return n == "harvestpart" or n == "part" or n == "basepart"
            or n:find("^base") or n:find("^mesh") or n:find("^union")
    end
    local cur = pp.Parent
    for _ = 1, 4 do  -- leo lên tối đa 4 tầng
        if not cur then break end
        if not isGeneric(cur.Name) then return cur.Name end
        cur = cur.Parent
    end
    return pp.Parent.Name
end

-- Bỏ prefix rarity khỏi tên để hiện gọn: "Common Bamboo Seed" → "Bamboo Seed"
local rarityPrefixes = {"mythic ","legendary ","super ","epic ","rare ","uncommon ","common "}
local function stripRarity(name)
    local lower = name:lower()
    for _, prefix in ipairs(rarityPrefixes) do
        if lower:sub(1, #prefix) == prefix then
            return name:sub(#prefix + 1)
        end
    end
    return name
end

-- Đọc attribute từ object và tổ tiên
local function getAttr(obj, key)
    local cur = obj
    for _ = 1, 5 do
        if not cur then break end
        local v = cur:GetAttribute(key)
        if v ~= nil then return v end
        -- Thử tìm con Value có tên key
        local child = cur:FindFirstChild(key)
        if child and child:IsA("ValueBase") then return child.Value end
        cur = cur.Parent
    end
    return nil
end

-- Format số tiền: 1500 → "1.5K", 1000000 → "1M"
local function fmtNum(n)
    if not n then return nil end
    n = tonumber(n)
    if not n then return nil end
    if n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

-- Lấy hạng rarity text từ tên hoặc attribute
local function getRarityLabel(name, obj)
    -- Thử đọc attribute Rarity
    local r = getAttr(obj, "Rarity") or getAttr(obj, "rarity") or getAttr(obj, "Type")
    if r then return tostring(r):upper() end
    -- Fallback: detect từ tên
    local n = name:lower()
    local order = {"mythic","legendary","super","epic","rare","uncommon","common"}
    for _, rarity in ipairs(order) do
        if n:find(rarity) then return rarity:upper() end
    end
    return "COMMON"
end

local function clearFruitESP()
    for _, bb in pairs(fruitESPTags) do if bb and bb.Parent then bb:Destroy() end end
    table.clear(fruitESPTags)
end

local function doFruitESP()
    clearFruitESP()
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.ActionText:lower():find("harvest") then
            local part = getPart(pp.Parent)
            if part then
                local rawName    = getFruitName(pp)        -- "Common Bamboo Seed"
                local fruitName  = stripRarity(rawName)    -- "Bamboo Seed" (hiện cho gọn)
                local rarityCol  = getRarityColor(rawName) -- dùng tên đầy đủ để detect rarity
                local emoji      = getRarityEmoji(rawName)
                local rarityTxt  = getRarityLabel(rawName, pp.Parent)

                -- Đọc giá & cân nặng từ Attribute
                local price  = fmtNum(getAttr(pp.Parent, "Price")
                    or getAttr(pp.Parent, "SellPrice") or getAttr(pp.Parent, "Value"))
                local weight = getAttr(pp.Parent, "Weight")
                    or getAttr(pp.Parent, "Mass") or getAttr(pp.Parent, "Size")
                if weight then weight = string.format("%.1f", tonumber(weight) or 0) end

                -- Dòng info dưới: hạng | giá | cân
                local infoStr = rarityTxt
                if price  then infoStr = infoStr .. "  💰" .. price end
                if weight then infoStr = infoStr .. "  ⚖" .. weight end

                -- Billboard to hơn để chứa 2 dòng
                local bb = Instance.new("BillboardGui")
                bb.Size        = UDim2.new(0, 170, 0, 56)
                bb.StudsOffset = Vector3.new(0, 5, 0)
                bb.AlwaysOnTop = true
                bb.Adornee     = part
                bb.Parent      = part

                -- Glow halo
                local glow = Instance.new("Frame", bb)
                glow.Size                   = UDim2.new(1, 6, 1, 6)
                glow.Position               = UDim2.new(0, -3, 0, -3)
                glow.BackgroundColor3       = rarityCol
                glow.BackgroundTransparency = 0.55
                glow.BorderSizePixel        = 0
                Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 13)

                -- Nền tối
                local bg = Instance.new("Frame", bb)
                bg.Size                   = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3       = Color3.fromRGB(6, 6, 10)
                bg.BackgroundTransparency = 0.05
                bg.BorderSizePixel        = 0
                Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 9)

                -- Neon stroke pulse
                local sk = Instance.new("UIStroke", bg)
                sk.Color       = rarityCol
                sk.Thickness   = 2.5
                sk.Transparency = 0

                -- Emoji
                local eL = Instance.new("TextLabel", bg)
                eL.Size               = UDim2.new(0, 28, 0, 28)
                eL.Position           = UDim2.new(0, 2, 0, 2)
                eL.BackgroundTransparency = 1
                eL.Text               = emoji
                eL.TextSize           = 22
                eL.Font               = Enum.Font.GothamBold
                eL.TextScaled         = true

                -- Tên cây (dòng 1)
                local nameL = Instance.new("TextLabel", bg)
                nameL.Size            = UDim2.new(1, -34, 0, 24)
                nameL.Position        = UDim2.new(0, 32, 0, 3)
                nameL.BackgroundTransparency = 1
                nameL.Text            = fruitName
                nameL.TextColor3      = rarityCol
                nameL.TextSize        = 13
                nameL.Font            = Enum.Font.GothamBold
                nameL.TextScaled      = true
                nameL.TextXAlignment  = Enum.TextXAlignment.Left
                nameL.TextTruncate    = Enum.TextTruncate.AtEnd

                -- Divider mỏng
                local div = Instance.new("Frame", bg)
                div.Size              = UDim2.new(1, -10, 0, 1)
                div.Position          = UDim2.new(0, 5, 0, 29)
                div.BackgroundColor3  = rarityCol
                div.BackgroundTransparency = 0.6
                div.BorderSizePixel   = 0

                -- Hạng + giá + cân (dòng 2)
                local infoL = Instance.new("TextLabel", bg)
                infoL.Size            = UDim2.new(1, -8, 0, 20)
                infoL.Position        = UDim2.new(0, 4, 0, 32)
                infoL.BackgroundTransparency = 1
                infoL.Text            = infoStr
                infoL.TextColor3      = Color3.fromRGB(210, 210, 210)
                infoL.TextSize        = 9
                infoL.Font            = Enum.Font.GothamBold
                infoL.TextScaled      = true
                infoL.TextXAlignment  = Enum.TextXAlignment.Left
                infoL.TextTruncate    = Enum.TextTruncate.AtEnd

                -- Pulse animation
                task.spawn(function()
                    while bb and bb.Parent and CFG.FruitESP do
                        TweenService:Create(sk,   TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency=0.8}):Play()
                        TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency=0.85}):Play()
                        task.wait(0.7)
                        TweenService:Create(sk,   TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency=0}):Play()
                        TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency=0.45}):Play()
                        task.wait(0.7)
                    end
                end)

                table.insert(fruitESPTags, bb)
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

-- ═══════════════════════════════════════════
--  AUTO DEFEND (viết lại hoàn toàn)
-- ═══════════════════════════════════════════
local defendingTargets = {}

-- Tấn công kẻ trộm bằng TẤT CẢ phương pháp cùng lúc
local function strikeThief(p)
    if not p or not p.Character then return end
    local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
    if not pRoot then return end

    local root = getRoot()
    if not root then return end

    -- Tele sát kẻ trộm (offset nhỏ để tránh bị block)
    root.CFrame = CFrame.new(pRoot.Position + Vector3.new(0, 2.5, 1.5))
    task.wait(0.05)

    -- Equip shovel / tool
    equipSlot1()

    -- === Phương pháp 1: ProximityPrompt trên character kẻ trộm ===
    for _, pp in ipairs(p.Character:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local a = pp.ActionText:lower()
            if a:find("hit") or a:find("attack") or a:find("smack")
            or a:find("shovel") or a:find("bonk") or a:find("fight")
            or a:find("punch") or a:find("kick") or a:find("steal") then
                firePrompt(pp) firePrompt(pp) firePrompt(pp)
            end
        end
    end

    -- === Phương pháp 2: ClickDetector trên character kẻ trộm ===
    for _, cd in ipairs(p.Character:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            pcall(function() fireclickdetector(cd) end)
            pcall(function() fireclickdetector(cd) end)
        end
    end

    -- === Phương pháp 3: Tool RemoteEvent của mình (shovel fire) ===
    local char = LP.Character
    if char then
        local tool = char:FindFirstChildWhichIsA("Tool")
        if tool then
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    pcall(function() v:FireServer(pRoot.Position) end)
                    pcall(function() v:FireServer(p.Character) end)
                end
            end
            -- Thử ActivateRemoteEvent / UseRemoteEvent
            local activateRemote = tool:FindFirstChild("ActivateRemoteEvent")
                or tool:FindFirstChild("UseRemoteEvent")
                or tool:FindFirstChild("Attack")
            if activateRemote and activateRemote:IsA("RemoteEvent") then
                pcall(function() activateRemote:FireServer(pRoot.Position) end)
            end
        end
    end

    -- === Phương pháp 4: Workspace-level attack prompt gần kẻ trộm ===
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local a = pp.ActionText:lower()
            if a:find("hit") or a:find("attack") or a:find("bonk") or a:find("shovel") then
                local ppPart = getPart(pp.Parent)
                if ppPart and (ppPart.Position - pRoot.Position).Magnitude < 8 then
                    firePrompt(pp) firePrompt(pp)
                end
            end
        end
    end
end

local function continuousAttack(p)
    if defendingTargets[p.Name] then return end
    defendingTargets[p.Name] = true

    task.spawn(function()
        updateMyFarmPos()
        local myPos = myFarmPos or (getRoot() and getRoot().Position)

        while CFG.AutoDefend do
            if not p or not p.Character then break end
            local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if not pRoot then break end
            if not myPos then break end

            -- Kiểm tra kẻ trộm còn trong vườn không (mở rộng range 40 studs)
            if (myPos - pRoot.Position).Magnitude > 40 then break end

            strikeThief(p)
            task.wait(0.25) -- đánh mỗi 0.25s (nhanh hơn cũ)
        end

        defendingTargets[p.Name] = nil
    end)
end

local function checkDefend()
    if not CFG.AutoDefend then return end
    updateMyFarmPos()
    local myPos = myFarmPos
    if not myPos then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        if not p.Character then continue end
        local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
        if not pRoot then continue end

        local isThief = false

        -- Detect 1: Gần vườn mình (30 studs)
        if (myPos - pRoot.Position).Magnitude <= 30 then
            isThief = true
        end

        -- Detect 2: UI text báo đang bị steal
        pcall(function()
            for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") then
                    local txt = v.Text:lower()
                    if txt:find("stealing") or txt:find("stole") or txt:find("is stealing") then
                        if txt:find(p.Name:lower()) or #Players:GetPlayers() == 2 then
                            isThief = true
                        end
                    end
                end
            end
        end)

        -- Detect 3: Highlight đỏ trên character (game tô màu kẻ trộm)
        pcall(function()
            local hl = p.Character:FindFirstChildWhichIsA("Highlight")
            if hl and hl.FillColor.R > 0.5 and hl.FillColor.G < 0.3 then
                isThief = true
            end
        end)

        -- Detect 4: Player đang fire harvest prompt trong vườn mình
        pcall(function()
            for _, pp in ipairs(workspace:GetDescendants()) do
                if pp:IsA("ProximityPrompt") and pp.Enabled then
                    local a = pp.ActionText:lower()
                    if a:find("steal") or a:find("harvest") then
                        local ppPart = getPart(pp.Parent)
                        if ppPart and (myPos - ppPart.Position).Magnitude < 30 then
                            -- Có prompt steal trong vườn mình — có kẻ trộm gần đó
                            if (pRoot.Position - ppPart.Position).Magnitude < 15 then
                                isThief = true
                            end
                        end
                    end
                end
            end
        end)

        if isThief then
            if not thiefsDetected[p.Name] or tick() - thiefsDetected[p.Name] > 8 then
                thiefsDetected[p.Name] = tick()
                showNotif("🚨 "..p.Name.." ĐANG VÀO VƯỜN!", Color3.fromRGB(180, 10, 10))
                markThief(p)
            end
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

-- ─── Helper click GUI button (tất cả cách) ───
local function clickBtn(btn)
    if not btn then return end
    pcall(function() btn.MouseButton1Click:Fire() end)
    pcall(function() btn.Activated:Fire() end)
    pcall(function() btn:Activate() end)
end

-- Tìm và click button GUI có text/name chứa keyword
local function clickGuiByKeyword(kw, root)
    local source = root and root:GetDescendants() or LP.PlayerGui:GetDescendants()
    for _, v in ipairs(source) do
        if v:IsA("TextButton") or v:IsA("ImageButton") then
            local txt = v:IsA("TextButton") and v.Text:lower() or ""
            local nm  = v.Name:lower()
            if txt:find(kw, 1, true) or nm:find(kw, 1, true) then
                clickBtn(v)
                return v
            end
        end
    end
end

-- Mở tab Seeds hoặc Gear trong GUI game (click button đầu trang)
local function openShopTab(tabKw)
    -- Tìm button tab ở top bar
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        if v:IsA("TextButton") or v:IsA("ImageButton") then
            local txt = v:IsA("TextButton") and v.Text:lower() or ""
            local nm  = v.Name:lower()
            if txt:find(tabKw, 1, true) or nm:find(tabKw, 1, true) then
                clickBtn(v)
                task.wait(0.3)
                return true
            end
        end
    end
    return false
end

-- Mua qua GUI: mở tab → tìm item → click buy
local function buyViaGui(itemName, tabKw)
    openShopTab(tabKw)
    local lower = itemName:lower()
    -- Tìm TextLabel / Frame có text = tên item
    for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
        local txt = ""
        if v:IsA("TextLabel") or v:IsA("TextButton") then
            txt = v.Text:lower()
        end
        if txt:find(lower, 1, true) then
            -- Tìm nút Buy/Purchase trong cùng frame cha
            local parent = v.Parent
            for _ = 1, 5 do
                if not parent then break end
                for _, child in ipairs(parent:GetDescendants()) do
                    if child:IsA("TextButton") or child:IsA("ImageButton") then
                        local ct = child:IsA("TextButton") and child.Text:lower() or ""
                        local cn = child.Name:lower()
                        if ct:find("buy") or ct:find("purchase") or ct:find("get")
                        or cn:find("buy") or cn:find("purchase") then
                            clickBtn(child)
                            task.wait(0.15)
                            -- Xác nhận nếu có popup
                            clickGuiByKeyword("confirm")
                            clickGuiByKeyword("yes")
                            return true
                        end
                    end
                end
                -- Nếu chính v là TextButton thì click thẳng
                if v:IsA("TextButton") then
                    clickBtn(v)
                    task.wait(0.15)
                    clickGuiByKeyword("confirm")
                    return true
                end
                parent = parent.Parent
            end
        end
    end
    return false
end

local function buySingleSeed(seedName)
    -- Ưu tiên 1: Remote packet
    remoteBuySeed(seedName)

    -- Ưu tiên 2: Click GUI shop (Seeds tab)
    if buyViaGui(seedName, "seed") then return true end

    -- Ưu tiên 3: ProximityPrompt workspace
    local root = getRoot()
    if not root then return false end
    local farmPos = root.Position
    local seedLower = seedName:lower()

    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local a     = pp.ActionText:lower()
            local pName = (pp.Parent and pp.Parent.Name or ""):lower()
            local oText = (pp.ObjectText or ""):lower()
            local ok = (a:find("buy") or a:find("purchase") or a:find("get") or a == "")
                    and (pName:find(seedLower) or oText:find(seedLower))
            if ok then
                local part = getPart(pp.Parent)
                if part then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                    task.wait(0.1)
                    firePrompt(pp) firePrompt(pp)
                    task.wait(0.1)
                    root.CFrame = CFrame.new(farmPos)
                    return true
                end
            end
        end
    end

    -- Fallback: object tên chứa seed name
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find(seedLower) then
            local pp = obj:FindFirstChildWhichIsA("ProximityPrompt")
                or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("ProximityPrompt"))
            if pp then
                local part = getPart(obj:IsA("BasePart") and obj or obj.Parent)
                if part then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                    task.wait(0.1)
                    firePrompt(pp) firePrompt(pp)
                    task.wait(0.1)
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
    -- Ưu tiên 1: Remote packet
    remoteBuyGear(gearName)

    -- Ưu tiên 2: Click GUI shop (Gear/Go tab)
    if buyViaGui(gearName, "gear") then return true end
    if buyViaGui(gearName, "go") then return true end  -- "Gourds" tab có thể là "Go..."

    -- Ưu tiên 3: ProximityPrompt workspace
    local root = getRoot()
    if not root then return false end
    local farmPos = root.Position
    local gearLower = gearName:lower()

    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local a     = pp.ActionText:lower()
            local pName = (pp.Parent and pp.Parent.Name or ""):lower()
            local oText = (pp.ObjectText or ""):lower()
            local ok = (a:find("buy") or a:find("purchase") or a:find("get") or a == "")
                    and (pName:find(gearLower) or oText:find(gearLower))
            if ok then
                local part = getPart(pp.Parent)
                if part then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                    task.wait(0.1)
                    firePrompt(pp) firePrompt(pp)
                    task.wait(0.1)
                    root.CFrame = CFrame.new(farmPos)
                    return true
                end
            end
        end
    end

    -- Fallback: object tên chứa gear name
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find(gearLower) then
            local pp = obj:FindFirstChildWhichIsA("ProximityPrompt")
                or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("ProximityPrompt"))
            if pp then
                local part = getPart(obj:IsA("BasePart") and obj or obj.Parent)
                if part then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
                    task.wait(0.1)
                    firePrompt(pp) firePrompt(pp)
                    task.wait(0.1)
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
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- ── BillboardGui nhỏ gọn ──
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 110, 0, 38)
    bb.StudsOffset = Vector3.new(0, 2.8, 0)
    bb.AlwaysOnTop = true
    bb.Adornee     = head
    bb.Parent      = head

    -- Nền tối mỏng
    local bg = Instance.new("Frame", bb)
    bg.Size                  = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3      = Color3.fromRGB(8, 9, 14)
    bg.BackgroundTransparency = 0.12
    bg.BorderSizePixel       = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 7)

    -- Viền mỏng trắng mờ
    local sk = Instance.new("UIStroke", bg)
    sk.Color       = Color3.fromRGB(255, 255, 255)
    sk.Thickness   = 0.8
    sk.Transparency = 0.6

    -- Chấm định vị + tên (hàng trên)
    local nameL = Instance.new("TextLabel", bg)
    nameL.Size               = UDim2.new(1, -6, 0, 16)
    nameL.Position           = UDim2.new(0, 6, 0, 2)
    nameL.BackgroundTransparency = 1
    nameL.Text               = "◈ " .. player.Name
    nameL.TextColor3         = Color3.fromRGB(255, 255, 255)
    nameL.TextSize           = 11
    nameL.Font               = Enum.Font.GothamBold
    nameL.TextXAlignment     = Enum.TextXAlignment.Left
    nameL.TextTruncate       = Enum.TextTruncate.AtEnd

    -- Khoảng cách (hàng giữa)
    local distL = Instance.new("TextLabel", bg)
    distL.Size               = UDim2.new(1, -6, 0, 11)
    distL.Position           = UDim2.new(0, 6, 0, 17)
    distL.BackgroundTransparency = 1
    distL.TextColor3         = Color3.fromRGB(140, 180, 255)
    distL.TextSize           = 9
    distL.Font               = Enum.Font.Gotham
    distL.TextXAlignment     = Enum.TextXAlignment.Left

    -- HP bar nền (hàng dưới)
    local hpBG = Instance.new("Frame", bg)
    hpBG.Size               = UDim2.new(1, -8, 0, 5)
    hpBG.Position           = UDim2.new(0, 4, 1, -8)
    hpBG.BackgroundColor3   = Color3.fromRGB(35, 35, 45)
    hpBG.BorderSizePixel    = 0
    Instance.new("UICorner", hpBG).CornerRadius = UDim.new(1, 0)

    -- HP bar fill
    local hpFill = Instance.new("Frame", hpBG)
    hpFill.Size             = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(60, 220, 80)
    hpFill.BorderSizePixel  = 0
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(1, 0)

    -- Loop cập nhật HP + khoảng cách
    task.spawn(function()
        while bb and bb.Parent and CFG.PlayerESP do
            local myRoot = getRoot()
            local pr     = char:FindFirstChild("HumanoidRootPart")
            local hum    = char:FindFirstChildOfClass("Humanoid")

            -- Khoảng cách
            if myRoot and pr then
                local dist = math.floor((myRoot.Position - pr.Position).Magnitude)
                distL.Text = "⊙ " .. dist .. " studs"
            end

            -- HP bar + màu
            if hum then
                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                hpFill.Size = UDim2.new(pct, 0, 1, 0)
                -- Màu: xanh → vàng → đỏ
                if pct > 0.6 then
                    hpFill.BackgroundColor3 = Color3.fromRGB(60, 220, 80)
                elseif pct > 0.3 then
                    hpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                else
                    hpFill.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
                end
            end

            task.wait(0.3)
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

-- ══════════════════════════════════════════
--  SAFE LOOP RUNNER  (tự khởi động lại nếu crash)
-- ══════════════════════════════════════════
local function safeLoop(name, interval, condFn, fn)
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                while true do
                    local waitTime = math.max(interval, 0.05)
                    if condFn() then
                        local ok2, err2 = pcall(fn)
                        if not ok2 then
                            warn("[GAG3]["..name.."] "..tostring(err2))
                        end
                    end
                    task.wait(waitTime)
                end
            end)
            if not ok then
                warn("[GAG3]["..name.."] loop crash: "..tostring(err)..". Restarting in 3s")
                task.wait(3)
            end
        end
    end)
end

safeLoop("Plants",     1.5,  function() return CFG.AutoPlants     end, doPlants)
safeLoop("Collection", 0.5,  function() return CFG.AutoCollection  end, doCollection)
safeLoop("Sell",       3,    function() return CFG.AutoSell        end, doSell)
safeLoop("Steal",      1,    function() return CFG.AutoSteal       end, doSteal)
safeLoop("Replant",    2,    function() return CFG.AutoReplant     end, doReplant)
safeLoop("FruitESP",   3,    function() return CFG.FruitESP        end, doFruitESP)
safeLoop("Restock",    1,    function() return CFG.RestockNotify   end, checkRestock)
safeLoop("Defend",     0.5,  function() return true                end, checkDefend)
safeLoop("BuySeed",    2,    function() return CFG.AutoBuySeed     end, doBuySeed)
safeLoop("BuyGear",    3,    function() return CFG.AutoBuyGear     end, doBuyGear)

-- ══════════════════════════════════════════
--  24/7 STABILITY SYSTEM
-- ══════════════════════════════════════════

-- 1. ANTI-AFK: giả lập input mỗi 3 phút để không bị kick
task.spawn(function()
    local VU = game:GetService("VirtualUser")
    while true do
        task.wait(170)  -- 2 phút 50 giây
        pcall(function()
            VU:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VU:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

-- 2. CHARACTER RESPAWN HANDLER
--    Reset tất cả state khi character respawn (chết/reset)
local function onCharacterAdded(char)
    -- Đợi character load xong
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(1)

    -- Reset stuck flags
    stealRunning = false
    table.clear(defendingTargets)
    table.clear(thiefsDetected)

    -- Reset farm position cache
    myFarmPos  = nil
    myPlotParts = {}
    PacketRemote = nil  -- re-cache remote

    -- Rebuild ESP nếu đang bật
    if CFG.PlayerESP then
        disableESP()
        task.wait(0.5)
        enableESP()
    end
    if CFG.FruitESP then
        clearFruitESP()
    end

    -- Áp lại speed nếu đang bật
    if CFG.SpeedBoost then
        task.wait(0.5)
        applySpeed(true)
    end

    warn("[GAG3] Character respawned – state reset OK")
end

LP.CharacterAdded:Connect(onCharacterAdded)
-- Chạy ngay cho character hiện tại nếu đã có
if LP.Character then
    task.spawn(function() onCharacterAdded(LP.Character) end)
end

-- 3. WATCHDOG: reset stealRunning nếu stuck > 20 giây
task.spawn(function()
    local lastResetTime = tick()
    while true do
        task.wait(20)
        if stealRunning then
            if tick() - lastStealAttempt > 20 then
                warn("[GAG3] Watchdog: stealRunning stuck → reset")
                stealRunning = false
            end
        end
        -- Reset defendingTargets cũ (player đã offline)
        for name, _ in pairs(defendingTargets) do
            if not Players:FindFirstChild(name) then
                defendingTargets[name] = nil
            end
        end
        lastResetTime = tick()
    end
end)

-- 4. MEMORY CLEANUP: dọn ESP tag orphan mỗi 30 giây
task.spawn(function()
    while true do
        task.wait(30)
        -- Dọn fruitESPTags chết
        for i = #fruitESPTags, 1, -1 do
            local bb = fruitESPTags[i]
            if not bb or not bb.Parent then
                table.remove(fruitESPTags, i)
            end
        end
        -- Dọn espTags player đã offline
        for p, bb in pairs(espTags) do
            if not p or not p.Parent then
                if bb and bb.Parent then bb:Destroy() end
                espTags[p] = nil
            end
        end
        -- Dọn defenderESP cũ
        for name, bb in pairs(defenderESP) do
            if bb and not bb.Parent then
                defenderESP[name] = nil
            end
        end
    end
end)

-- 5. AUTO RECONNECT REMOTE: clear cache nếu RemoteEvent mất
task.spawn(function()
    while true do
        task.wait(60)
        if PacketRemote and not PacketRemote.Parent then
            PacketRemote = nil
            warn("[GAG3] PacketRemote lost – will re-cache next use")
        end
    end
end)

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
Win.ClipsDescendants = true
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
    hopB.Text = "Đang chuyển..."
    pcall(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
    end)
    task.delay(3, function()
        if hopB and hopB.Parent then hopB.Text = "Hop Server" end
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
makeNav("A","Automatically")
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

local winVisible = false  -- khai báo trước pulse loop
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

local UIS2 = game:GetService("UserInputService")
local isDragging = false
local dragStart, startPos

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

-- ══════════════════════════════════════════
--  NÚT SELL NHANH (tele đến chỗ bán) — nổi trên màn hình
-- ══════════════════════════════════════════
local SELL_SG = Instance.new("ScreenGui")
SELL_SG.Name           = "HoQuocSellBtn"
SELL_SG.ResetOnSpawn   = false
SELL_SG.DisplayOrder   = 998
SELL_SG.Parent         = PGui

local sellBtn = Instance.new("TextButton", SELL_SG)
sellBtn.Size            = UDim2.new(0, 68, 0, 34)
sellBtn.Position        = UDim2.new(0, 58, 0, 8)  -- ngay cạnh HQ button
sellBtn.BackgroundColor3 = Color3.fromRGB(220, 145, 0)
sellBtn.Text            = "💰 SELL"
sellBtn.TextColor3      = Color3.fromRGB(255,255,255)
sellBtn.TextSize        = 12
sellBtn.Font            = Enum.Font.GothamBold
sellBtn.BorderSizePixel = 0
sellBtn.ZIndex          = 998
sellBtn.Active          = true
Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 8)
local sellBtnStroke = Instance.new("UIStroke", sellBtn)
sellBtnStroke.Color     = Color3.fromRGB(255, 200, 50)
sellBtnStroke.Thickness = 1.5

-- Drag cho nút Sell
local sellDrag, sellDragStart, sellDragPos = false, nil, nil
sellBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sellDrag = false
        sellDragStart = input.Position
        sellDragPos = sellBtn.Position
    end
end)
sellBtn.InputChanged:Connect(function(input)
    if sellDragStart and (input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = input.Position - sellDragStart
        if d.Magnitude > 5 then
            sellDrag = true
            sellBtn.Position = UDim2.new(
                sellDragPos.X.Scale, sellDragPos.X.Offset + d.X,
                sellDragPos.Y.Scale, sellDragPos.Y.Offset + d.Y
            )
        end
    end
end)
UIS2.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sellDragStart = nil
    end
end)

-- Click → tele đến chỗ bán và sell
sellBtn.MouseButton1Click:Connect(function()
    if sellDrag then return end
    sellBtn.Text = "..."
    sellBtnStroke.Color = Color3.fromRGB(255, 255, 100)

    local root = getRoot()
    if not root then sellBtn.Text = "💰 SELL" return end
    local farmPos = root.Position  -- ghi nhớ vị trí để về sau

    -- Tìm sell stand (ProximityPrompt)
    local bestPP, bestDist = nil, math.huge
    for _, pp in ipairs(workspace:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local a     = pp.ActionText:lower()
            local pName = (pp.Parent and pp.Parent.Name or ""):lower()
            if a:find("sell") or a:find("submit") or a:find("cash")
            or pName:find("sell") or pName:find("market") or pName:find("cashier") then
                local part = getPart(pp.Parent)
                if part then
                    local d = (root.Position - part.Position).Magnitude
                    if d < bestDist then bestDist = d bestPP = pp end
                end
            end
        end
    end

    if bestPP then
        -- Tele đến chỗ bán
        local part = getPart(bestPP.Parent)
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
        task.wait(0.15)
        firePrompt(bestPP)
        firePrompt(bestPP)
        task.wait(0.2)
        -- Về farm
        root.CFrame = CFrame.new(farmPos + Vector3.new(0, 2, 0))
        sellBtn.Text = "✓ SOLD!"
    else
        -- Không tìm thấy PP: thử GUI + remote
        remoteSellAll()
        local function trySellBtnGui()
            for _, v in ipairs(LP.PlayerGui:GetDescendants()) do
                if v:IsA("TextButton") or v:IsA("ImageButton") then
                    local txt = v:IsA("TextButton") and v.Text:lower() or ""
                    local nm  = v.Name:lower()
                    if txt == "sell" or nm == "sell" or nm == "sellbutton" or txt:find("sell all") then
                        pcall(function() v.MouseButton1Click:Fire() end)
                        pcall(function() v.Activated:Fire() end)
                        task.wait(0.2)
                        for _, v2 in ipairs(LP.PlayerGui:GetDescendants()) do
                            if v2:IsA("TextButton") then
                                local t2 = v2.Text:lower()
                                if t2:find("confirm") or t2:find("yes") or t2:find("sell all") then
                                    pcall(function() v2.MouseButton1Click:Fire() end)
                                end
                            end
                        end
                        return true
                    end
                end
            end
        end
        trySellBtnGui()
        sellBtn.Text = "✓ SOLD!"
    end

    sellBtnStroke.Color = Color3.fromRGB(255, 200, 50)
    task.delay(1.5, function()
        if sellBtn and sellBtn.Parent then sellBtn.Text = "💰 SELL" end
    end)
end)

print("✅ Ho Quoc Dev Hub v2.0 loaded! - Remote Buy/Sell enabled")
