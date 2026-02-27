--[[
    =============================================
    SOLS RNG - Multi-Feature Script v2.0
    Dengan Interactive Config GUI
    Features:
      - Auto Fishing & Auto Sell Fish
      - Auto Buy from Jester & Mari
      - Auto Craft Potions
      - Auto Use Biome Randomizer & Strange Controller
      - Biome Detector (Discord Webhook Notifier)
      - Full Interactive GUI (Toggle, Input, Checklist)
    =============================================
    DISCLAIMER: Hanya untuk keperluan edukasi.
    Penggunaan exploit melanggar ToS Roblox.
    =============================================
]]

-- ==================== KONFIGURASI DEFAULT ====================
local CONFIG = {
    WEBHOOK_URL            = "https://discord.com/api/webhooks/MASUKKAN_WEBHOOK_ANDA_DISINI",
    BIOME_NOTIFY_LIST      = {
        Windy    = true,
        Rainy    = true,
        Snowy    = true,
        Foggy    = true,
        Starfall = true,
        Glitched = true,
        Aurora   = true,
        Null     = true,
        Corrupt  = true,
        Sandstorm= true,
        Thunder  = true,
    },
    AUTO_FISH                   = true,
    AUTO_SELL_FISH              = true,
    SELL_FISH_AMOUNT            = 10,
    AUTO_BUY_JESTER             = true,
    AUTO_BUY_MARI               = true,
    BUY_INTERVAL                = 60,
    AUTO_CRAFT                  = true,
    CRAFT_INTERVAL              = 30,
    AUTO_USE_BIOME_RANDOMIZER   = true,
    AUTO_USE_STRANGE_CONTROLLER = true,
    ITEM_USE_INTERVAL           = 5,
}

-- ==================== SERVICES ====================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ==================== UTILITY ====================
local function Log(msg) print("[SolsRNG] " .. tostring(msg)) end
local function Wait(t) task.wait(t or 0.1) end
local function SafeCall(f, ...) local ok, e = pcall(f, ...) if not ok then Log("Err: "..tostring(e)) end return ok end

-- ==================== REMOTE HELPER ====================
local function FireRemote(name, ...)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == name then
            if v:IsA("RemoteEvent") then v:FireServer(...) return true
            elseif v:IsA("RemoteFunction") then return v:InvokeServer(...) end
        end
    end
    return false
end

-- ==================== WEBHOOK ====================
local lastBiome = ""
local function SendWebhook(biome)
    if CONFIG.WEBHOOK_URL:find("MASUKKAN") then Log("[Webhook] URL belum diset!") return end
    local payload = HttpService:JSONEncode({
        username = "Sol's RNG Biome Detector",
        embeds = {{
            title = "Biome Terdeteksi: " .. biome,
            description = "**Player:** " .. LocalPlayer.Name,
            color = 0x00FF7F,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    local req = syn and syn.request or (http and http.request) or request
    if req then SafeCall(function()
        req({ Url=CONFIG.WEBHOOK_URL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload })
        Log("[Webhook] Terkirim: " .. biome)
    end) end
end

-- ==================== BIOME DETECTOR ====================
local function GetCurrentBiome()
    local ok, b = pcall(function()
        local L = game:GetService("Lighting")
        if L:GetAttribute("Biome") then return L:GetAttribute("Biome") end
        local rs = ReplicatedStorage
        for _, n in ipairs({"Biome","CurrentBiome"}) do
            if rs:FindFirstChild(n) then return rs[n].Value end
        end
        for _, n in ipairs({"Biome","CurrentBiome"}) do
            if workspace:GetAttribute(n) then return workspace:GetAttribute(n) end
        end
        for _, o in ipairs(rs:GetChildren()) do
            if o:IsA("StringValue") and o.Name:lower():find("biome") then return o.Value end
        end
        return "Unknown"
    end)
    return ok and b or "Unknown"
end

local function StartBiomeDetector()
    task.spawn(function()
        while true do
            local cur = GetCurrentBiome()
            if cur ~= lastBiome and cur ~= "Unknown" then
                lastBiome = cur
                if _G.SolsGUI then _G.SolsGUI.UpdateBiome(cur) end
                if CONFIG.BIOME_NOTIFY_LIST[cur] then SendWebhook(cur) end
                Log("[Biome] " .. cur)
            end
            Wait(2)
        end
    end)
end

-- ==================== AUTO FISH ====================
local fishCount = 0
local function StartAutoFish()
    task.spawn(function()
        while true do
            if CONFIG.AUTO_FISH then
                SafeCall(function()
                    FireRemote("CastRod") FireRemote("StartFishing") FireRemote("Fish")
                    Wait(3)
                    FireRemote("ReelIn") FireRemote("CatchFish")
                    fishCount = fishCount + 1
                    if _G.SolsGUI then _G.SolsGUI.UpdateFish(fishCount) end
                    if CONFIG.AUTO_SELL_FISH and fishCount >= CONFIG.SELL_FISH_AMOUNT then
                        FireRemote("SellFish") FireRemote("SellAllFish")
                        Log("[Fish] Dijual " .. fishCount .. " ikan")
                        fishCount = 0
                        if _G.SolsGUI then _G.SolsGUI.UpdateFish(0) end
                    end
                end)
            end
            Wait(2)
        end
    end)
end

-- ==================== AUTO BUY ====================
local function StartAutoBuy()
    local function BuyLoop(npc, remote, key)
        task.spawn(function()
            while true do
                if CONFIG[key] then
                    SafeCall(function()
                        FireRemote(remote) FireRemote("Buy"..npc) FireRemote("PurchaseItem")
                        Log("[Buy] Membeli dari " .. npc)
                    end)
                end
                Wait(CONFIG.BUY_INTERVAL)
            end
        end)
    end
    BuyLoop("Jester","BuyJester","AUTO_BUY_JESTER")
    BuyLoop("Mari","BuyMari","AUTO_BUY_MARI")
end

-- ==================== AUTO CRAFT ====================
local function StartAutoCraft()
    task.spawn(function()
        while true do
            if CONFIG.AUTO_CRAFT then
                SafeCall(function()
                    FireRemote("CraftPotion") FireRemote("Craft") FireRemote("CraftAll")
                    Log("[Craft] Crafting potion...")
                end)
            end
            Wait(CONFIG.CRAFT_INTERVAL)
        end
    end)
end

-- ==================== AUTO USE ITEMS ====================
local function StartAutoUseItems()
    local function UseLoop(itemName, configKey, remote)
        task.spawn(function()
            while true do
                if CONFIG[configKey] then
                    SafeCall(function()
                        FireRemote(remote) FireRemote("UseItem", itemName)
                        Log("[Use] " .. itemName)
                    end)
                end
                Wait(CONFIG.ITEM_USE_INTERVAL)
            end
        end)
    end
    UseLoop("Biome Randomizer",    "AUTO_USE_BIOME_RANDOMIZER",   "UseBiomeRandomizer")
    UseLoop("Strange Controller",  "AUTO_USE_STRANGE_CONTROLLER", "UseStrangeController")
end

-- ==================== GUI ====================
local function CreateGUI()
    local existingGui = LocalPlayer.PlayerGui:FindFirstChild("SolsRNG_GUI")
    if existingGui then existingGui:Destroy() end

    -- Color Palette
    local C = {
        BG      = Color3.fromRGB(15, 15, 25),
        Panel   = Color3.fromRGB(22, 22, 38),
        Header  = Color3.fromRGB(30, 30, 55),
        TabBG   = Color3.fromRGB(18, 18, 32),
        TabAct  = Color3.fromRGB(70, 70, 160),
        Accent  = Color3.fromRGB(100, 100, 220),
        ON      = Color3.fromRGB(80, 220, 120),
        OFF     = Color3.fromRGB(220, 80, 80),
        Text    = Color3.fromRGB(220, 220, 240),
        Sub     = Color3.fromRGB(140, 140, 170),
        Input   = Color3.fromRGB(28, 28, 48),
        White   = Color3.fromRGB(255, 255, 255),
        Gold    = Color3.fromRGB(255, 210, 80),
        Blue    = Color3.fromRGB(100, 180, 255),
    }

    local function Tween(obj, props, t)
        TweenService:Create(obj, TweenInfo.new(t or 0.15), props):Play()
    end

    -- ScreenGui
    local Gui = Instance.new("ScreenGui")
    Gui.Name = "SolsRNG_GUI"
    Gui.ResetOnSpawn = false
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.Parent = LocalPlayer.PlayerGui

    -- Main Window
    local Win = Instance.new("Frame")
    Win.Size = UDim2.new(0, 340, 0, 440)
    Win.Position = UDim2.new(0, 16, 0.5, -220)
    Win.BackgroundColor3 = C.BG
    Win.BorderSizePixel = 0
    Win.Active = true
    Win.Draggable = true
    Win.Parent = Gui
    Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 10)
    local WinStroke = Instance.new("UIStroke", Win)
    WinStroke.Color = C.Accent
    WinStroke.Thickness = 1.5

    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = C.Header
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = Win
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

    local TitleLbl = Instance.new("TextLabel")
    TitleLbl.Size = UDim2.new(1, -50, 1, 0)
    TitleLbl.Position = UDim2.new(0, 12, 0, 0)
    TitleLbl.BackgroundTransparency = 1
    TitleLbl.Text = "Sol's RNG Script v2.0"
    TitleLbl.TextColor3 = C.White
    TitleLbl.TextSize = 14
    TitleLbl.Font = Enum.Font.GothamBold
    TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
    TitleLbl.Parent = TitleBar

    -- Minimize Button
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 28, 0, 22)
    MinBtn.Position = UDim2.new(1, -36, 0.5, -11)
    MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = C.Text
    MinBtn.TextSize = 14
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.BorderSizePixel = 0
    MinBtn.Parent = TitleBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 5)

    -- Tab Bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -16, 0, 32)
    TabBar.Position = UDim2.new(0, 8, 0, 46)
    TabBar.BackgroundColor3 = C.TabBG
    TabBar.BorderSizePixel = 0
    TabBar.Parent = Win
    Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 7)
    local TabLayout = Instance.new("UIListLayout", TabBar)
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 2)
    local TabPad = Instance.new("UIPadding", TabBar)
    TabPad.PaddingLeft = UDim.new(0, 3)
    TabPad.PaddingTop = UDim.new(0, 3)
    TabPad.PaddingBottom = UDim.new(0, 3)

    -- Content Area
    local Content = Instance.new("Frame")
    Content.Size = UDim2.new(1, -16, 1, -90)
    Content.Position = UDim2.new(0, 8, 0, 84)
    Content.BackgroundTransparency = 1
    Content.ClipsDescendants = true
    Content.Parent = Win

    -- Status Bar
    local StatusBar = Instance.new("Frame")
    StatusBar.Size = UDim2.new(1, -16, 0, 26)
    StatusBar.Position = UDim2.new(0, 8, 1, -32)
    StatusBar.BackgroundColor3 = C.Header
    StatusBar.BorderSizePixel = 0
    StatusBar.Parent = Win
    Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 6)

    local BiomeLbl = Instance.new("TextLabel")
    BiomeLbl.Size = UDim2.new(0.55, 0, 1, 0)
    BiomeLbl.Position = UDim2.new(0, 8, 0, 0)
    BiomeLbl.BackgroundTransparency = 1
    BiomeLbl.Text = "Biome: Scanning..."
    BiomeLbl.TextColor3 = C.Gold
    BiomeLbl.TextSize = 11
    BiomeLbl.Font = Enum.Font.GothamSemibold
    BiomeLbl.TextXAlignment = Enum.TextXAlignment.Left
    BiomeLbl.Parent = StatusBar

    local FishLbl = Instance.new("TextLabel")
    FishLbl.Size = UDim2.new(0.44, 0, 1, 0)
    FishLbl.Position = UDim2.new(0.56, 0, 0, 0)
    FishLbl.BackgroundTransparency = 1
    FishLbl.Text = "Fish: 0"
    FishLbl.TextColor3 = C.Blue
    FishLbl.TextSize = 11
    FishLbl.Font = Enum.Font.GothamSemibold
    FishLbl.TextXAlignment = Enum.TextXAlignment.Right
    FishLbl.Parent = StatusBar

    -- ==================== HELPER BUILDERS ====================

    local function MakeTabBtn(label, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 58, 1, 0)
        btn.BackgroundColor3 = C.TabBG
        btn.Text = label
        btn.TextColor3 = C.Sub
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        btn.LayoutOrder = order
        btn.Parent = TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        return btn
    end

    local function MakePage()
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = C.Accent
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = Content
        local layout = Instance.new("UIListLayout", page)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
        local pad = Instance.new("UIPadding", page)
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingLeft = UDim.new(0, 2)
        pad.PaddingRight = UDim.new(0, 2)
        return page, layout
    end

    local function AutoCanvas(page)
        local layout = page:FindFirstChildOfClass("UIListLayout")
        if layout then
            local function update()
                page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
            end
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
            update()
        end
    end

    local function SectionLbl(text, parent, order)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 20)
        f.BackgroundTransparency = 1
        f.LayoutOrder = order or 0
        f.Parent = parent
        local lbl = Instance.new("TextLabel", f)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = C.Accent
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        return f
    end

    -- Toggle Row: returns row and a refresh function
    local function ToggleRow(label, configKey, parent, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3 = C.Panel
        row.BorderSizePixel = 0
        row.LayoutOrder = order or 0
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -62, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.Text
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0, 48, 0, 22)
        btn.Position = UDim2.new(1, -56, 0.5, -11)
        btn.BorderSizePixel = 0
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = C.BG
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 11)

        local function Refresh()
            local v = CONFIG[configKey]
            btn.Text = v and "ON" or "OFF"
            Tween(btn, { BackgroundColor3 = v and C.ON or C.OFF })
        end
        Refresh()
        btn.MouseButton1Click:Connect(function()
            CONFIG[configKey] = not CONFIG[configKey]
            Refresh()
            Log("[Config] " .. configKey .. " = " .. tostring(CONFIG[configKey]))
        end)
        return row
    end

    -- Number Row
    local function NumberRow(label, configKey, parent, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3 = C.Panel
        row.BorderSizePixel = 0
        row.LayoutOrder = order or 0
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -90, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.Text
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local ibg = Instance.new("Frame", row)
        ibg.Size = UDim2.new(0, 72, 0, 24)
        ibg.Position = UDim2.new(1, -80, 0.5, -12)
        ibg.BackgroundColor3 = C.Input
        ibg.BorderSizePixel = 0
        Instance.new("UICorner", ibg).CornerRadius = UDim.new(0, 6)
        local ist = Instance.new("UIStroke", ibg)
        ist.Color = C.Accent ist.Thickness = 1

        local box = Instance.new("TextBox", ibg)
        box.Size = UDim2.new(1, -8, 1, 0)
        box.Position = UDim2.new(0, 4, 0, 0)
        box.BackgroundTransparency = 1
        box.Text = tostring(CONFIG[configKey])
        box.TextColor3 = C.White
        box.TextSize = 12
        box.Font = Enum.Font.GothamSemibold
        box.ClearTextOnFocus = false

        box.Focused:Connect(function() Tween(ist, {Color=C.White}) end)
        box.FocusLost:Connect(function()
            Tween(ist, {Color=C.Accent})
            local n = tonumber(box.Text)
            if n and n > 0 then
                CONFIG[configKey] = math.floor(n)
                box.Text = tostring(CONFIG[configKey])
                Log("[Config] " .. configKey .. " = " .. CONFIG[configKey])
            else
                box.Text = tostring(CONFIG[configKey])
            end
        end)
        return row
    end

    -- Webhook Row
    local function WebhookRow(parent, order)
        local wrap = Instance.new("Frame")
        wrap.Size = UDim2.new(1, 0, 0, 62)
        wrap.BackgroundColor3 = C.Panel
        wrap.BorderSizePixel = 0
        wrap.LayoutOrder = order or 0
        wrap.Parent = parent
        Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 7)

        local lbl = Instance.new("TextLabel", wrap)
        lbl.Size = UDim2.new(1, -12, 0, 18)
        lbl.Position = UDim2.new(0, 10, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Discord Webhook URL"
        lbl.TextColor3 = C.Sub
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local ibg = Instance.new("Frame", wrap)
        ibg.Size = UDim2.new(1, -16, 0, 26)
        ibg.Position = UDim2.new(0, 8, 0, 28)
        ibg.BackgroundColor3 = C.Input
        ibg.BorderSizePixel = 0
        Instance.new("UICorner", ibg).CornerRadius = UDim.new(0, 6)
        local ist = Instance.new("UIStroke", ibg)
        ist.Color = C.Accent ist.Thickness = 1

        local box = Instance.new("TextBox", ibg)
        box.Size = UDim2.new(1, -10, 1, 0)
        box.Position = UDim2.new(0, 5, 0, 0)
        box.BackgroundTransparency = 1
        box.Text = CONFIG.WEBHOOK_URL
        box.PlaceholderText = "https://discord.com/api/webhooks/..."
        box.TextColor3 = C.White
        box.PlaceholderColor3 = C.Sub
        box.TextSize = 10
        box.Font = Enum.Font.Gotham
        box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left

        box.Focused:Connect(function() Tween(ist, {Color=C.White}) end)
        box.FocusLost:Connect(function()
            Tween(ist, {Color=C.Accent})
            CONFIG.WEBHOOK_URL = box.Text
            Log("[Config] Webhook URL diperbarui")
        end)
        return wrap, box
    end

    -- Biome Check Row (half-width grid)
    local function BiomeCheckRow(biomeName, parent, order)
        local row = Instance.new("Frame")
        row.BackgroundColor3 = C.Panel
        row.BorderSizePixel = 0
        row.LayoutOrder = order or 0
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -34, 1, 0)
        lbl.Position = UDim2.new(0, 6, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = biomeName
        lbl.TextColor3 = C.Text
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0, 26, 0, 18)
        btn.Position = UDim2.new(1, -30, 0.5, -9)
        btn.BorderSizePixel = 0
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = C.BG
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

        local function Refresh()
            local v = CONFIG.BIOME_NOTIFY_LIST[biomeName]
            btn.Text = v and "v" or "x"
            Tween(btn, {BackgroundColor3 = v and C.ON or C.OFF})
        end
        Refresh()
        btn.MouseButton1Click:Connect(function()
            CONFIG.BIOME_NOTIFY_LIST[biomeName] = not CONFIG.BIOME_NOTIFY_LIST[biomeName]
            Refresh()
        end)
        return row
    end

    -- ==================== BUILD TABS ====================
    local tabDefs = {
        {label="Main",  icon="Main"},
        {label="Fish",  icon="Fish"},
        {label="Buy",   icon="Buy"},
        {label="Craft", icon="Craft"},
        {label="Biome", icon="Biome"},
    }
    local tabBtns  = {}
    local tabPages = {}

    for i, def in ipairs(tabDefs) do
        tabBtns[i]  = MakeTabBtn(def.label, i)
        tabPages[i] = MakePage()
        AutoCanvas(tabPages[i])
    end

    local function ActivateTab(idx)
        for i, btn in ipairs(tabBtns) do
            local act = (i == idx)
            Tween(btn, {BackgroundColor3 = act and C.TabAct or C.TabBG})
            btn.TextColor3 = act and C.White or C.Sub
            tabPages[i].Visible = act
        end
    end
    for i, btn in ipairs(tabBtns) do
        btn.MouseButton1Click:Connect(function() ActivateTab(i) end)
    end

    -- ==================== TAB 1: MAIN ====================
    local p1 = tabPages[1]
    SectionLbl("Status Fitur", p1, 1)
    ToggleRow("Auto Fish",             "AUTO_FISH",                   p1, 2)
    ToggleRow("Auto Sell Fish",        "AUTO_SELL_FISH",              p1, 3)
    ToggleRow("Auto Buy Jester",       "AUTO_BUY_JESTER",            p1, 4)
    ToggleRow("Auto Buy Mari",         "AUTO_BUY_MARI",               p1, 5)
    ToggleRow("Auto Craft",            "AUTO_CRAFT",                  p1, 6)
    ToggleRow("Biome Randomizer",      "AUTO_USE_BIOME_RANDOMIZER",   p1, 7)
    ToggleRow("Strange Controller",    "AUTO_USE_STRANGE_CONTROLLER", p1, 8)

    -- ==================== TAB 2: FISH ====================
    local p2 = tabPages[2]
    SectionLbl("Fishing Settings", p2, 1)
    ToggleRow("Auto Fish",          "AUTO_FISH",       p2, 2)
    ToggleRow("Auto Sell Fish",     "AUTO_SELL_FISH",  p2, 3)
    NumberRow("Jual setiap X ikan", "SELL_FISH_AMOUNT",p2, 4)

    -- ==================== TAB 3: BUY ====================
    local p3 = tabPages[3]
    SectionLbl("Auto Buy Settings", p3, 1)
    ToggleRow("Auto Buy Jester",    "AUTO_BUY_JESTER", p3, 2)
    ToggleRow("Auto Buy Mari",      "AUTO_BUY_MARI",   p3, 3)
    NumberRow("Interval Beli (dtk)","BUY_INTERVAL",    p3, 4)

    -- ==================== TAB 4: CRAFT ====================
    local p4 = tabPages[4]
    SectionLbl("Craft & Items", p4, 1)
    ToggleRow("Auto Craft Potion",      "AUTO_CRAFT",                   p4, 2)
    NumberRow("Craft interval (dtk)",   "CRAFT_INTERVAL",               p4, 3)
    ToggleRow("Biome Randomizer",       "AUTO_USE_BIOME_RANDOMIZER",    p4, 4)
    ToggleRow("Strange Controller",     "AUTO_USE_STRANGE_CONTROLLER",  p4, 5)
    NumberRow("Item use interval (dtk)","ITEM_USE_INTERVAL",            p4, 6)

    -- ==================== TAB 5: BIOME ====================
    local p5 = tabPages[5]
    SectionLbl("Webhook & Biome Notify", p5, 1)
    local _, webhookBox = WebhookRow(p5, 2)

    -- Test Button
    local testWrap = Instance.new("Frame")
    testWrap.Size = UDim2.new(1, 0, 0, 32)
    testWrap.BackgroundTransparency = 1
    testWrap.LayoutOrder = 3
    testWrap.Parent = p5
    local testBtn = Instance.new("TextButton", testWrap)
    testBtn.Size = UDim2.new(1, 0, 0, 28)
    testBtn.BackgroundColor3 = Color3.fromRGB(50, 70, 160)
    testBtn.Text = "Test Kirim Webhook"
    testBtn.TextColor3 = C.White
    testBtn.TextSize = 12
    testBtn.Font = Enum.Font.GothamSemibold
    testBtn.BorderSizePixel = 0
    Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0, 7)
    testBtn.MouseButton1Click:Connect(function()
        CONFIG.WEBHOOK_URL = webhookBox.Text
        SendWebhook("TEST_BIOME")
        testBtn.Text = "Terkirim!"
        task.delay(2, function() testBtn.Text = "Test Kirim Webhook" end)
    end)

    SectionLbl("Pilih Biome yang Di-Notify", p5, 4)

    -- Grid biome
    local biomeGrid = Instance.new("Frame")
    biomeGrid.Size = UDim2.new(1, 0, 0, 10)
    biomeGrid.BackgroundTransparency = 1
    biomeGrid.LayoutOrder = 5
    biomeGrid.Parent = p5
    local gridLayout = Instance.new("UIGridLayout", biomeGrid)
    gridLayout.CellSize = UDim2.new(0.5, -3, 0, 30)
    gridLayout.CellPadding = UDim2.new(0, 6, 0, 4)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local biomeNames = {
        "Windy","Rainy","Snowy","Foggy","Starfall",
        "Glitched","Aurora","Null","Corrupt","Sandstorm","Thunder"
    }
    for i, bName in ipairs(biomeNames) do
        if CONFIG.BIOME_NOTIFY_LIST[bName] == nil then
            CONFIG.BIOME_NOTIFY_LIST[bName] = false
        end
        BiomeCheckRow(bName, biomeGrid, i)
    end
    local rows = math.ceil(#biomeNames / 2)
    biomeGrid.Size = UDim2.new(1, 0, 0, rows * 34 + 4)

    -- ==================== MINIMIZE ====================
    local isMin = false
    MinBtn.MouseButton1Click:Connect(function()
        isMin = not isMin
        MinBtn.Text = isMin and "+" or "-"
        Tween(Win, {Size = UDim2.new(0, 340, 0, isMin and 40 or 440)}, 0.2)
        Content.Visible   = not isMin
        TabBar.Visible    = not isMin
        StatusBar.Visible = not isMin
    end)

    ActivateTab(1)

    -- ==================== GLOBAL REFS ====================
    _G.SolsGUI = {
        UpdateBiome = function(name) BiomeLbl.Text = "Biome: " .. name end,
        UpdateFish  = function(n) FishLbl.Text = "Fish: " .. tostring(n) end,
    }

    Log("[GUI] Interactive GUI v2.0 berhasil dibuat.")
end

-- ==================== MAIN ====================
local function Main()
    Log("=== Sol's RNG v2.0 Dimuat ===")
    Wait(2)
    CreateGUI()
    StartBiomeDetector()
    StartAutoFish()
    StartAutoBuy()
    StartAutoCraft()
    StartAutoUseItems()
    Log("=== Semua fitur aktif! ===")
end

SafeCall(Main)
