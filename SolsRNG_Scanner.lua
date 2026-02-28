--[[
    SOL'S RNG - NEARBY OBJECT SCANNER
    Jalankan script ini saat berada di dekat Portal Stella
    Hasil scan akan tampil di GUI, bisa di-scroll dan dicopy
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer
local PG = LP.PlayerGui


-- ===== WARNA =====
local C = {
    BG     = Color3.fromRGB(13, 13, 22),
    Panel  = Color3.fromRGB(20, 20, 36),
    Header = Color3.fromRGB(28, 28, 52),
    Accent = Color3.fromRGB(90, 90, 210),
    Text   = Color3.fromRGB(215, 215, 235),
    Sub    = Color3.fromRGB(130, 130, 160),
    ON     = Color3.fromRGB(70, 210, 110),
    OFF    = Color3.fromRGB(210, 70, 70),
    White  = Color3.fromRGB(255, 255, 255),
    Gold   = Color3.fromRGB(255, 205, 70),
    Blue   = Color3.fromRGB(90, 170, 255),
    Input  = Color3.fromRGB(24, 24, 44),
    Row1   = Color3.fromRGB(22, 22, 40),
    Row2   = Color3.fromRGB(18, 18, 32),
}

-- ===== GUI SETUP =====
local Gui = Instance.new("ScreenGui")
Gui.Name = "SolsScanner"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PG

local Win = Instance.new("Frame", Gui)
Win.Size = UDim2.new(0, 480, 0, 520)
Win.Position = UDim2.new(0.5, -240, 0.5, -260)
Win.BackgroundColor3 = C.BG
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 10)
local WStroke = Instance.new("UIStroke", Win)
WStroke.Color = C.Accent
WStroke.Thickness = 1.5

-- Title Bar
local TBar = Instance.new("Frame", Win)
TBar.Size = UDim2.new(1, 0, 0, 42)
TBar.BackgroundColor3 = C.Header
TBar.BorderSizePixel = 0
Instance.new("UICorner", TBar).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", TBar)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🔍 Object Scanner - Sol's RNG"
Title.TextColor3 = C.White
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", TBar)
CloseBtn.Size = UDim2.new(0, 28, 0, 22)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = C.White
CloseBtn.TextSize = 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)

-- Instruksi
local InfoFrame = Instance.new("Frame", Win)
InfoFrame.Size = UDim2.new(1, -16, 0, 52)
InfoFrame.Position = UDim2.new(0, 8, 0, 50)
InfoFrame.BackgroundColor3 = Color3.fromRGB(25, 40, 25)
InfoFrame.BorderSizePixel = 0
Instance.new("UICorner", InfoFrame).CornerRadius = UDim.new(0, 7)
local InfoStroke = Instance.new("UIStroke", InfoFrame)
InfoStroke.Color = C.ON
InfoStroke.Thickness = 1

local InfoLbl = Instance.new("TextLabel", InfoFrame)
InfoLbl.Size = UDim2.new(1, -16, 1, 0)
InfoLbl.Position = UDim2.new(0, 8, 0, 0)
InfoLbl.BackgroundTransparency = 1
InfoLbl.Text = "1. Jalan ke dekat Portal Stella dulu\n2. Atur radius scan\n3. Klik SCAN, lalu cari nama yang berhubungan dengan Stella/craft"
InfoLbl.TextColor3 = C.ON
InfoLbl.TextSize = 11
InfoLbl.Font = Enum.Font.Gotham
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.TextWrapped = true

-- Controls row
local CtrlFrame = Instance.new("Frame", Win)
CtrlFrame.Size = UDim2.new(1, -16, 0, 36)
CtrlFrame.Position = UDim2.new(0, 8, 0, 110)
CtrlFrame.BackgroundTransparency = 1
CtrlFrame.BorderSizePixel = 0

-- Radius label
local RadLbl = Instance.new("TextLabel", CtrlFrame)
RadLbl.Size = UDim2.new(0, 120, 1, 0)
RadLbl.BackgroundTransparency = 1
RadLbl.Text = "Radius (studs):"
RadLbl.TextColor3 = C.Sub
RadLbl.TextSize = 12
RadLbl.Font = Enum.Font.GothamSemibold
RadLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Radius input
local RadInputBg = Instance.new("Frame", CtrlFrame)
RadInputBg.Size = UDim2.new(0, 70, 0, 28)
RadInputBg.Position = UDim2.new(0, 118, 0.5, -14)
RadInputBg.BackgroundColor3 = C.Input
RadInputBg.BorderSizePixel = 0
Instance.new("UICorner", RadInputBg).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", RadInputBg).Color = C.Accent

local RadBox = Instance.new("TextBox", RadInputBg)
RadBox.Size = UDim2.new(1, -8, 1, 0)
RadBox.Position = UDim2.new(0, 4, 0, 0)
RadBox.BackgroundTransparency = 1
RadBox.Text = "80"
RadBox.TextColor3 = C.White
RadBox.TextSize = 12
RadBox.Font = Enum.Font.GothamSemibold
RadBox.ClearTextOnFocus = false

-- Filter input
local FiltLbl = Instance.new("TextLabel", CtrlFrame)
FiltLbl.Size = UDim2.new(0, 50, 1, 0)
FiltLbl.Position = UDim2.new(0, 200, 0, 0)
FiltLbl.BackgroundTransparency = 1
FiltLbl.Text = "Filter:"
FiltLbl.TextColor3 = C.Sub
FiltLbl.TextSize = 12
FiltLbl.Font = Enum.Font.GothamSemibold
FiltLbl.TextXAlignment = Enum.TextXAlignment.Left

local FiltBg = Instance.new("Frame", CtrlFrame)
FiltBg.Size = UDim2.new(0, 100, 0, 28)
FiltBg.Position = UDim2.new(0, 248, 0.5, -14)
FiltBg.BackgroundColor3 = C.Input
FiltBg.BorderSizePixel = 0
Instance.new("UICorner", FiltBg).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", FiltBg).Color = C.Accent

local FiltBox = Instance.new("TextBox", FiltBg)
FiltBox.Size = UDim2.new(1, -8, 1, 0)
FiltBox.Position = UDim2.new(0, 4, 0, 0)
FiltBox.BackgroundTransparency = 1
FiltBox.Text = ""
FiltBox.PlaceholderText = "cth: portal"
FiltBox.PlaceholderColor3 = C.Sub
FiltBox.TextColor3 = C.White
FiltBox.TextSize = 11
FiltBox.Font = Enum.Font.Gotham
FiltBox.ClearTextOnFocus = false

-- Scan Button
local ScanBtn = Instance.new("TextButton", CtrlFrame)
ScanBtn.Size = UDim2.new(0, 80, 0, 30)
ScanBtn.Position = UDim2.new(1, -82, 0.5, -15)
ScanBtn.BackgroundColor3 = C.Accent
ScanBtn.Text = "🔍 SCAN"
ScanBtn.TextColor3 = C.White
ScanBtn.TextSize = 12
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.BorderSizePixel = 0
Instance.new("UICorner", ScanBtn).CornerRadius = UDim.new(0, 7)

-- Status bar
local StatusBar = Instance.new("Frame", Win)
StatusBar.Size = UDim2.new(1, -16, 0, 24)
StatusBar.Position = UDim2.new(0, 8, 0, 154)
StatusBar.BackgroundColor3 = C.Panel
StatusBar.BorderSizePixel = 0
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 5)

local StatusLbl = Instance.new("TextLabel", StatusBar)
StatusLbl.Size = UDim2.new(1, -12, 1, 0)
StatusLbl.Position = UDim2.new(0, 8, 0, 0)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Belum scan. Jalan ke dekat Portal Stella dulu, lalu klik SCAN."
StatusLbl.TextColor3 = C.Sub
StatusLbl.TextSize = 11
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Column headers
local HeaderRow = Instance.new("Frame", Win)
HeaderRow.Size = UDim2.new(1, -16, 0, 22)
HeaderRow.Position = UDim2.new(0, 8, 0, 184)
HeaderRow.BackgroundColor3 = C.Header
HeaderRow.BorderSizePixel = 0
Instance.new("UICorner", HeaderRow).CornerRadius = UDim.new(0, 5)

local function MakeHeaderLbl(text, xPos, width)
    local l = Instance.new("TextLabel", HeaderRow)
    l.Size = UDim2.new(0, width, 1, 0)
    l.Position = UDim2.new(0, xPos, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.Accent
    l.TextSize = 11
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
end
MakeHeaderLbl("Tipe", 8, 80)
MakeHeaderLbl("Nama Object", 90, 220)
MakeHeaderLbl("Jarak", 314, 60)
MakeHeaderLbl("Copy", 380, 80)

-- Results list
local ListFrame = Instance.new("ScrollingFrame", Win)
ListFrame.Size = UDim2.new(1, -16, 1, -216)
ListFrame.Position = UDim2.new(0, 8, 0, 210)
ListFrame.BackgroundColor3 = C.Panel
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = C.Accent
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", ListFrame).CornerRadius = UDim.new(0, 7)

local ListLayout = Instance.new("UIListLayout", ListFrame)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 1)
ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ListFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 4)
end)

-- ===== SCAN LOGIC =====
local function ClearList()
    for _, c in ipairs(ListFrame:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function AddRow(typeName, objName, dist, rowIndex)
    local row = Instance.new("Frame", ListFrame)
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3 = rowIndex % 2 == 0 and C.Row1 or C.Row2
    row.BorderSizePixel = 0
    row.LayoutOrder = rowIndex

    -- Tipe
    local typeColor = C.Sub
    if typeName:lower():find("model") then typeColor = Color3.fromRGB(100, 180, 255)
    elseif typeName:lower():find("part") then typeColor = Color3.fromRGB(180, 255, 100)
    elseif typeName:lower():find("folder") then typeColor = Color3.fromRGB(255, 200, 80) end

    local typeL = Instance.new("TextLabel", row)
    typeL.Size = UDim2.new(0, 80, 1, 0)
    typeL.Position = UDim2.new(0, 6, 0, 0)
    typeL.BackgroundTransparency = 1
    typeL.Text = typeName
    typeL.TextColor3 = typeColor
    typeL.TextSize = 10
    typeL.Font = Enum.Font.GothamSemibold
    typeL.TextXAlignment = Enum.TextXAlignment.Left
    typeL.TextTruncate = Enum.TextTruncate.AtEnd

    -- Nama
    local nameL = Instance.new("TextLabel", row)
    nameL.Size = UDim2.new(0, 220, 1, 0)
    nameL.Position = UDim2.new(0, 88, 0, 0)
    nameL.BackgroundTransparency = 1
    nameL.Text = objName
    nameL.TextColor3 = C.Text
    nameL.TextSize = 11
    nameL.Font = Enum.Font.Gotham
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.TextTruncate = Enum.TextTruncate.AtEnd

    -- Jarak
    local distL = Instance.new("TextLabel", row)
    distL.Size = UDim2.new(0, 60, 1, 0)
    distL.Position = UDim2.new(0, 312, 0, 0)
    distL.BackgroundTransparency = 1
    distL.Text = math.floor(dist) .. "s"
    distL.TextColor3 = dist < 20 and C.ON or dist < 50 and C.Gold or C.Sub
    distL.TextSize = 11
    distL.Font = Enum.Font.GothamSemibold
    distL.TextXAlignment = Enum.TextXAlignment.Left

    -- Copy button
    local copyBtn = Instance.new("TextButton", row)
    copyBtn.Size = UDim2.new(0, 72, 0, 20)
    copyBtn.Position = UDim2.new(0, 378, 0.5, -10)
    copyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 90)
    copyBtn.Text = "📋 Copy"
    copyBtn.TextColor3 = C.Blue
    copyBtn.TextSize = 10
    copyBtn.Font = Enum.Font.GothamSemibold
    copyBtn.BorderSizePixel = 0
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 5)

    copyBtn.MouseButton1Click:Connect(function()
        -- Set clipboard jika tersedia
        pcall(function() setclipboard(objName) end)
        copyBtn.Text = "✅ Copied!"
        copyBtn.TextColor3 = C.ON
        task.delay(1.5, function()
            if copyBtn and copyBtn.Parent then
                copyBtn.Text = "📋 Copy"
                copyBtn.TextColor3 = C.Blue
            end
        end)
        -- Tampilkan juga di status
        StatusLbl.Text = "Copied: " .. objName
        StatusLbl.TextColor3 = C.ON
    end)

    return row
end

local function DoScan()
    local Char = LP.Character
    if not Char then StatusLbl.Text = "Character tidak ditemukan!"; return end
    local HRP = Char:FindFirstChild("HumanoidRootPart")
    if not HRP then StatusLbl.Text = "HumanoidRootPart tidak ditemukan!"; return end

    local radius = tonumber(RadBox.Text) or 80
    local filter = FiltBox.Text:lower()

    ScanBtn.Text = "⏳ Scanning..."
    ScanBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    StatusLbl.Text = "Scanning radius " .. radius .. " studs..."
    StatusLbl.TextColor3 = C.Gold
    ClearList()

    task.wait(0.05)

    local results = {}
    local seen = {}

    for _, v in ipairs(workspace:GetDescendants()) do
        local pos
        local typeName = v.ClassName

        -- Ambil posisi
        if v:IsA("Model") and v.PrimaryPart then
            pos = v.PrimaryPart.Position
        elseif v:IsA("BasePart") then
            pos = v.Position
        end

        if pos then
            local dist = (HRP.Position - pos).Magnitude
            if dist <= radius then
                local key = typeName .. ":" .. v.Name
                -- Deduplicate nama yang sama di jarak yang mirip
                local dedupKey = typeName .. ":" .. v.Name .. ":" .. math.floor(dist/5)
                if not seen[dedupKey] then
                    seen[dedupKey] = true
                    -- Apply filter
                    if filter == "" or v.Name:lower():find(filter) or typeName:lower():find(filter) then
                        table.insert(results, {
                            type = typeName,
                            name = v.Name,
                            dist = dist,
                        })
                    end
                end
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.dist < b.dist end)

    -- Render
    for i, r in ipairs(results) do
        AddRow(r.type, r.name, r.dist, i)
    end

    local count = #results
    StatusLbl.Text = "Ditemukan " .. count .. " object dalam radius " .. radius .. " studs"
        .. (filter ~= "" and (' (filter: "'..filter..'")') or "")
        .. " | Cari nama yang berhubungan dengan Stella/Portal"
    StatusLbl.TextColor3 = count > 0 and C.ON or C.OFF

    ScanBtn.Text = "🔍 SCAN"
    ScanBtn.BackgroundColor3 = C.Accent
end

ScanBtn.MouseButton1Click:Connect(function()
    task.spawn(DoScan)
end)

-- Filter realtime saat ketik
FiltBox:GetPropertyChangedSignal("Text"):Connect(function()
    -- Re-scan jika ada hasil sebelumnya
    if #ListFrame:GetChildren() > 1 then
        task.spawn(DoScan)
    end
end)

print("[Scanner] GUI Scanner siap! Jalan ke dekat Portal Stella lalu klik SCAN.")
