-- ╔══════════════════════════════════════════╗
-- ║   REMOTE SPY - by HoQuoc Dev            ║
-- ║   Dùng để detect remote trong GAG2      ║
-- ╚══════════════════════════════════════════╝

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ══════════════════════════════════════════
--  GUI
-- ══════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "HoQuocRemoteSpy"
gui.ResetOnSpawn = false
gui.Parent = LP:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromScale(0.5, 0.55)
main.Position = UDim2.fromScale(0.05, 0.4)
main.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local ms = Instance.new("UIStroke", main)
ms.Color = Color3.fromRGB(60, 180, 80)
ms.Thickness = 1.2

-- Title
local title = Instance.new("Frame")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(20, 55, 30)
title.BorderSizePixel = 0
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)
local tfix = Instance.new("Frame", title)
tfix.Size = UDim2.new(1, 0, 0.5, 0)
tfix.Position = UDim2.new(0, 0, 0.5, 0)
tfix.BackgroundColor3 = Color3.fromRGB(20, 55, 30)
tfix.BorderSizePixel = 0

local titleLbl = Instance.new("TextLabel", title)
titleLbl.Size = UDim2.new(1, -90, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🔍 Remote Spy — HoQuoc Dev"
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextColor3 = Color3.fromRGB(160, 255, 160)
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Buttons header
local function hBtn(txt, xOff, color)
    local b = Instance.new("TextButton", title)
    b.Size = UDim2.new(0, 28, 0, 22)
    b.Position = UDim2.new(1, xOff, 0.5, -11)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.white
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local minBtn   = hBtn("–", -66, Color3.fromRGB(60,60,80))
local closeBtn = hBtn("✕", -34, Color3.fromRGB(160,40,40))

-- Drag
do
    local drag, ds, sp
    titleLbl.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true ds=i.Position sp=main.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

-- Search
local search = Instance.new("TextBox", main)
search.Size = UDim2.new(1, -16, 0, 26)
search.Position = UDim2.new(0, 8, 0, 42)
search.PlaceholderText = "🔎 Tìm remote..."
search.Text = ""
search.Font = Enum.Font.Gotham
search.TextSize = 13
search.TextColor3 = Color3.fromRGB(180, 255, 180)
search.BackgroundColor3 = Color3.fromRGB(22, 28, 22)
search.BorderSizePixel = 0
search.ClearTextOnFocus = false
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", search).PaddingLeft = UDim.new(0, 6)

-- Clear button
local clearBtn = Instance.new("TextButton", main)
clearBtn.Size = UDim2.new(1, -16, 0, 24)
clearBtn.Position = UDim2.new(0, 8, 0, 74)
clearBtn.Text = "🗑  XOÁ TẤT CẢ"
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 12
clearBtn.TextColor3 = Color3.white
clearBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
clearBtn.BorderSizePixel = 0
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)

-- Scroll
local scroll = Instance.new("ScrollingFrame", main)
scroll.Size = UDim2.new(1, -16, 1, -108)
scroll.Position = UDim2.new(0, 8, 0, 104)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 200, 80)
scroll.BackgroundTransparency = 1

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ══════════════════════════════════════════
--  LOGIC
-- ══════════════════════════════════════════
local logs = {}
local order = 0
local minimized = false
local origSize = main.Size

local function applySearch()
    local q = search.Text:lower()
    for box, data in pairs(logs) do
        box.Visible = q == "" or data.text:lower():find(q, 1, true)
    end
end
search:GetPropertyChangedSignal("Text"):Connect(applySearch)

local function fmtArgs(args)
    local t = {}
    for i, v in ipairs(args) do
        t[#t+1] = "["..i.."] "..tostring(v)
    end
    return #t > 0 and table.concat(t, "\n") or "(no args)"
end

local function addLog(remote, args, direction)
    order -= 1
    local fullName = remote:GetFullName()
    local dir = direction or "FireServer"
    local text = dir .. "\n" .. fullName .. "\n" .. fmtArgs(args)

    local box = Instance.new("Frame", scroll)
    box.Size = UDim2.new(1, -4, 0, 0)
    box.AutomaticSize = Enum.AutomaticSize.Y
    box.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
    box.BorderSizePixel = 0
    box.LayoutOrder = order
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local bs = Instance.new("UIStroke", box)
    bs.Color = dir == "FireServer"
        and Color3.fromRGB(60, 200, 80)
        or  Color3.fromRGB(80, 140, 255)
    bs.Thickness = 1

    local lbl = Instance.new("TextLabel", box)
    lbl.Size = UDim2.new(1, -80, 0, 0)
    lbl.Position = UDim2.new(0, 8, 0, 6)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextColor3 = dir == "FireServer"
        and Color3.fromRGB(100, 255, 140)
        or  Color3.fromRGB(140, 180, 255)
    lbl.BackgroundTransparency = 1
    lbl.Text = text

    -- Copy button
    local copyBtn = Instance.new("TextButton", box)
    copyBtn.Size = UDim2.new(0, 58, 0, 22)
    copyBtn.Position = UDim2.new(1, -66, 0, 6)
    copyBtn.Text = "COPY"
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 11
    copyBtn.TextColor3 = Color3.white
    copyBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
    copyBtn.BorderSizePixel = 0
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 5)
    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(text) end
    end)

    -- Delete button
    local delBtn = Instance.new("TextButton", box)
    delBtn.Size = UDim2.new(0, 58, 0, 22)
    delBtn.Position = UDim2.new(1, -66, 0, 32)
    delBtn.Text = "XOÁ"
    delBtn.Font = Enum.Font.GothamBold
    delBtn.TextSize = 11
    delBtn.TextColor3 = Color3.white
    delBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    delBtn.BorderSizePixel = 0
    Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 5)
    delBtn.MouseButton1Click:Connect(function()
        logs[box] = nil
        box:Destroy()
    end)

    logs[box] = { text = text }
    applySearch()
end

-- ══════════════════════════════════════════
--  HOOK REMOTES
-- ══════════════════════════════════════════
local hooked = {}

local function hookRemote(obj)
    if hooked[obj] then return end
    hooked[obj] = true

    if obj:IsA("RemoteEvent") then
        -- Client nhận từ server
        obj.OnClientEvent:Connect(function(...)
            addLog(obj, {...}, "OnClientEvent")
        end)
    end
end

-- Hook tất cả remote hiện có
for _, v in ipairs(game:GetDescendants()) do
    hookRemote(v)
end

-- Hook remote thêm vào sau
game.DescendantAdded:Connect(function(v)
    task.wait(0.1)
    hookRemote(v)
end)

-- Hook FireServer bằng namecall nếu executor support
if hookmetamethod then
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") then
            local ok, _ = pcall(function()
                addLog(self, {...}, method)
            end)
        end
        return oldNC(self, ...)
    end)
end

-- ══════════════════════════════════════════
--  BUTTON EVENTS
-- ══════════════════════════════════════════
clearBtn.MouseButton1Click:Connect(function()
    for box in pairs(logs) do box:Destroy() end
    table.clear(logs)
end)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        origSize = main.Size
        main.Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 36)
        minBtn.Text = "+"
        search.Visible = false
        clearBtn.Visible = false
        scroll.Visible = false
    else
        main.Size = origSize
        minBtn.Text = "–"
        search.Visible = true
        clearBtn.Visible = true
        scroll.Visible = true
    end
end)

print("✅ HoQuoc Remote Spy loaded! Thực hiện action trong game để xem remote.")
