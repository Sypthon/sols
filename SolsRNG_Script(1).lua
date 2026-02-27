--[[
    ============================================================
    SOL'S RNG - FULL AUTO SCRIPT v3.0
    Compatible: Delta Executor
    Features:
      [x] Auto Fishing + Minigame Solver + Auto Sell (Captain Flarg)
      [x] Auto Buy Merchant (Jester & Mari via chat detection)
      [x] Auto Craft Potions (Portal Stella -> Cauldron)
      [x] Biome Detector (Glitched, Dreamspace, Cyberspace -> Discord Webhook)
      [x] Full Interactive GUI dengan 5 Tab
      [x] Auto Fish & Auto Craft saling mengunci
    ============================================================
    DISCLAIMER: Hanya untuk edukasi. Melanggar ToS Roblox.
    ============================================================
]]

-- ================================================================
--  SERVICES
-- ================================================================
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService       = game:GetService("TweenService")
local HttpService        = game:GetService("HttpService")
local TextChatService    = game:GetService("TextChatService")

local LP   = Players.LocalPlayer
local PG   = LP.PlayerGui
local Char = LP.Character or LP.CharacterAdded:Wait()
local HRP  = Char:WaitForChild("HumanoidRootPart")
local Hum  = Char:WaitForChild("Humanoid")

LP.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
    Hum  = c:WaitForChild("Humanoid")
end)

-- ================================================================
--  CONFIG
-- ================================================================
local CONFIG = {
    WEBHOOK_URL          = "https://discord.com/api/webhooks/MASUKKAN_WEBHOOK_ANDA_DISINI",
    AUTO_FISH            = false,
    AUTO_SELL            = true,
    SELL_EVERY           = 5,
    AUTO_BUY             = true,
    AUTO_CRAFT           = false,
    TARGET_POTION        = "Heavenly Potion",
    BIOME_DETECT         = true,
    NOTIFY_GLITCHED      = true,
    NOTIFY_DREAMSPACE    = true,
    NOTIFY_CYBERSPACE    = true,
    FISH_WAIT_TIMEOUT    = 30,
    MINIGAME_SPEED       = 0.05,
}

-- ================================================================
--  STATE
-- ================================================================
local State = {
    fishCount       = 0,
    currentBiome    = "",
    merchantQueued  = false,
    merchantName    = "",
    craftingActive  = false,
    craftAutoOn     = false,
}

-- ================================================================
--  UTILITY
-- ================================================================
local function Log(tag, msg) print(("[SolsRNG][%s] %s"):format(tag, tostring(msg))) end
local function Wait(t) task.wait(t or 0.05) end
local function SafeCall(f, ...) local ok,e = pcall(f,...) if not ok then Log("ERR",e) end return ok end

-- ================================================================
--  REMOTE FINDER
-- ================================================================
local RemoteCache = {}
local function FindRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == name and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            RemoteCache[name] = v; return v
        end
    end
end
local function FireR(name, ...)
    local r = FindRemote(name)
    if not r then return end
    if r:IsA("RemoteEvent") then r:FireServer(...) return true end
    if r:IsA("RemoteFunction") then return r:InvokeServer(...) end
end

-- ================================================================
--  GUI HELPERS
-- ================================================================
local function FindGuiDeep(parent, partialName, depth)
    depth = depth or 8
    if depth <= 0 then return nil end
    for _, c in ipairs(parent:GetChildren()) do
        if c.Name:lower():find(partialName:lower()) then return c end
        local f = FindGuiDeep(c, partialName, depth-1)
        if f then return f end
    end
end

local function FindBtnText(parent, text, depth)
    depth = depth or 10
    if depth <= 0 then return nil end
    for _, c in ipairs(parent:GetChildren()) do
        if (c:IsA("TextButton") or c:IsA("ImageButton")) and c.Visible then
            if c.Text and c.Text:lower():find(text:lower()) then return c end
        end
        local f = FindBtnText(c, text, depth-1)
        if f then return f end
    end
end

local function ClickBtn(btn)
    if not btn then return false end
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos = btn.AbsolutePosition + btn.AbsoluteSize/2
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
        Wait(0.04)
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
    end)
    pcall(function() btn.MouseButton1Click:Fire() end)
    Wait(0.1)
    return true
end

-- ================================================================
--  PATHFINDING
-- ================================================================
local function WalkTo(target, timeout)
    timeout = timeout or 20
    if not Char or not HRP then return false end
    local path = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
    local ok = pcall(function() path:ComputeAsync(HRP.Position, target) end)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        Hum:MoveTo(target)
        local t0 = tick()
        repeat Wait(0.2) until (HRP.Position-target).Magnitude < 8 or tick()-t0 > timeout
        return (HRP.Position-target).Magnitude < 8
    end
    local wps = path:GetWaypoints()
    local t0  = tick()
    for _, wp in ipairs(wps) do
        if tick()-t0 > timeout then break end
        Hum:MoveTo(wp.Position)
        if wp.Action == Enum.PathWaypointAction.Jump then Hum.Jump = true end
        Hum.MoveToFinished:Wait(3)
    end
    return (HRP.Position-target).Magnitude < 8
end

-- ================================================================
--  WORLD HELPERS
-- ================================================================
local function FindNearestWaterEdge()
    local best, bestDist = nil, math.huge
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local isW = v.Material == Enum.Material.Water
                or v.Name:lower():find("water") or v.Name:lower():find("ocean")
                or v.Name:lower():find("sea")   or v.Name:lower():find("lake")
            if isW then
                local c = v.Position
                local d = (HRP.Position - c)
                local h = v.Size/2
                local edge = c + Vector3.new(
                    math.clamp(d.X,-h.X,h.X), 0, math.clamp(d.Z,-h.Z,h.Z)
                ) + Vector3.new(0,3,0)
                local dist = (HRP.Position - edge).Magnitude
                if dist < bestDist then bestDist=dist; best=edge end
            end
        end
    end
    return best
end

local function FindNPC(name)
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name:lower():find(name:lower()) then
            local r = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
            if r then return v, r.Position end
        end
    end
    return nil, nil
end

local function InteractNPC(model)
    if not model then return false end
    local r = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
    if not r then return false end
    WalkTo(r.Position + Vector3.new(0,0,3), 12)
    Wait(0.4)
    for _, pp in ipairs(model:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt, pp) Wait(0.4); return true end
    end
    for _, cd in ipairs(model:GetDescendants()) do
        if cd:IsA("ClickDetector") then pcall(fireclickdetector, cd) Wait(0.4); return true end
    end
    return false
end

-- ================================================================
--  FISHING MINIGAME SOLVER
-- ================================================================
local function GetMinigameFrames()
    for _, gui in ipairs(PG:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local ff = FindGuiDeep(gui,"fish") or FindGuiDeep(gui,"reel")
                    or FindGuiDeep(gui,"minigame") or FindGuiDeep(gui,"catch")
            if ff then
                local blue, green, white
                for _, c in ipairs(ff:GetDescendants()) do
                    if c:IsA("Frame") then
                        local bc = c.BackgroundColor3
                        if bc.G>0.4 and bc.R<0.5 and bc.B<0.5 and not green  then green=c end
                        if bc.B>0.4 and bc.R<0.4 and bc.G<0.5 and not blue   then blue=c  end
                        if bc.R>0.7 and bc.G>0.7 and bc.B>0.7 and not white  then white=c end
                    end
                end
                if blue or green then return ff, blue, green, white end
            end
        end
    end
end

local function SolveMinigame(timeout)
    timeout = timeout or 22
    Log("Fish","Tunggu minigame UI...")
    local t0 = tick()
    local ff, blue, green, white
    repeat ff, blue, green, white = GetMinigameFrames(); Wait(0.1) until ff or tick()-t0 > timeout
    if not ff then
        Log("Fish","UI tidak ketemu - spam reel remote")
        for i=1,25 do FireR("Reel") FireR("ReelIn") FireR("HoldReel") Wait(0.3) end
        return true
    end
    Log("Fish","Minigame ditemukan! Solving...")
    local vim; pcall(function() vim = game:GetService("VirtualInputManager") end)
    local solveT = tick()
    while tick()-solveT < timeout do
        if not ff or not ff.Parent or not ff.Visible then break end
        local hold = false
        if blue and green then
            local bY  = blue.AbsolutePosition.Y + blue.AbsoluteSize.Y
            local gY1 = green.AbsolutePosition.Y
            local gY2 = gY1 + green.AbsoluteSize.Y
            hold = (bY >= gY1 and bY <= gY2)
        else
            hold = true
        end
        if hold then
            pcall(function() vim:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
            pcall(function() keypress(69) end)
            FireR("HoldReel") FireR("Reel")
        else
            pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
            pcall(function() keyrelease(69) end)
        end
        if white then
            local prog = white.AbsoluteSize.X / (white.Parent and white.Parent.AbsoluteSize.X or 1)
            if prog >= 0.99 then Log("Fish","Progress penuh!"); break end
        end
        Wait(CONFIG.MINIGAME_SPEED)
    end
    pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
    pcall(function() keyrelease(69) end)
    Wait(0.4)
    return true
end

-- ================================================================
--  AUTO FISHING LOOP
-- ================================================================
local function DoOneFish()
    -- Cast
    local castBtn = FindBtnText(PG,"fish") or FindBtnText(PG,"cast")
    if castBtn then ClickBtn(castBtn)
    else FireR("CastRod") FireR("StartFishing") FireR("Fish") FireR("Cast") end
    Log("Fish","Memancing...")

    -- Tunggu bite
    local t0 = tick(); local bite = false
    repeat
        local f = GetMinigameFrames()
        if f then bite=true break end
        local bui = FindGuiDeep(PG,"bite") or FindGuiDeep(PG,"hooked") or FindGuiDeep(PG,"reel")
        if bui and bui.Visible then bite=true break end
        Wait(0.5)
    until bite or tick()-t0 > CONFIG.FISH_WAIT_TIMEOUT
    if not bite then Log("Fish","Timeout menunggu gigitan"); return false end

    -- Klik Reel jika ada tombolnya
    local reelBtn = FindBtnText(PG,"reel") or FindBtnText(PG,"hook")
    if reelBtn then ClickBtn(reelBtn) end

    -- Solve
    SolveMinigame(25)

    -- Collect
    Wait(0.3)
    local col = FindBtnText(PG,"collect") or FindBtnText(PG,"catch") or FindBtnText(PG,"claim")
    if col then ClickBtn(col) end
    FireR("CatchFish") FireR("CollectFish")

    State.fishCount = State.fishCount + 1
    Log("Fish","Ikan ke-"..State.fishCount.." didapat!")
    if _G.SolsGUI then _G.SolsGUI.UpdateFish(State.fishCount) end
    return true
end

local function SellFish()
    Log("Fish","Menuju Captain Flarg...")
    local npc, pos = FindNPC("Flarg")
    if not pos then npc, pos = FindNPC("Captain") end
    if not pos then npc, pos = FindNPC("fishmonger") end
    if not pos then Log("Fish","Captain Flarg tidak ketemu!"); return end

    WalkTo(pos + Vector3.new(0,0,3), 20)
    Wait(0.4)
    InteractNPC(npc)
    Wait(0.7)

    -- Klik Sell
    local sellBtn = FindBtnText(PG,"sell")
    if sellBtn then ClickBtn(sellBtn); Wait(0.4) end

    -- Klik semua item di sell UI
    local sellGui = FindGuiDeep(PG,"sell") or FindGuiDeep(PG,"shop")
    if sellGui then
        for _, c in ipairs(sellGui:GetDescendants()) do
            if (c:IsA("ImageButton") or c:IsA("TextButton")) and c.Visible then
                ClickBtn(c); Wait(0.12)
            end
        end
    end

    -- Konfirmasi (hijau)
    Wait(0.3)
    local cf = FindBtnText(PG,"confirm") or FindBtnText(PG,"sell all") or FindBtnText(PG,"yes")
    if cf then ClickBtn(cf) end
    FireR("SellFish") FireR("SellAllFish") FireR("SellItem")

    State.fishCount = 0
    if _G.SolsGUI then _G.SolsGUI.UpdateFish(0) end
    Log("Fish","Ikan berhasil dijual!")

    local close = FindBtnText(PG,"close") or FindBtnText(PG,"x") or FindBtnText(PG,"back")
    if close then ClickBtn(close) end
    Wait(0.3)
end

local function AutoFishLoop()
    task.spawn(function()
        while CONFIG.AUTO_FISH do
            if State.merchantQueued then
                Log("Fish","Merchant antri, pause..."); Wait(1)
                while State.merchantQueued do Wait(1) end
                Log("Fish","Lanjut fishing")
            end
            local edge = FindNearestWaterEdge()
            if not edge then Log("Fish","Air tidak ketemu"); Wait(5)
            else
                WalkTo(edge, 20); Wait(0.4)
                -- Coba ProximityPrompt rod jika ada
                for _, v in ipairs(workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and (v.Parent.Name:lower():find("rod") or v.Parent.Name:lower():find("fish")) then
                        pcall(fireproximityprompt, v); Wait(0.4); break
                    end
                end
                local ok = DoOneFish()
                if ok and CONFIG.AUTO_SELL and State.fishCount >= CONFIG.SELL_EVERY then
                    SellFish()
                end
            end
            Wait(0.8)
        end
    end)
end

-- ================================================================
--  AUTO BUY (MERCHANT)
-- ================================================================
local function UseItemInventory(itemName)
    local invBtn = FindBtnText(PG,"inventory") or FindBtnText(PG,"bag")
    if invBtn then ClickBtn(invBtn); Wait(0.5) end
    local itemsTab = FindBtnText(PG,"items")
    if itemsTab then ClickBtn(itemsTab); Wait(0.3) end
    -- Search
    for _, v in ipairs(PG:GetDescendants()) do
        if v:IsA("TextBox") and (v.PlaceholderText:lower():find("search") or v.Name:lower():find("search")) then
            v.Text = itemName; Wait(0.4); break
        end
    end
    local itBtn = FindBtnText(PG, itemName)
    if itBtn then ClickBtn(itBtn); Wait(0.3) end
    local useBtn = FindBtnText(PG,"use") or FindBtnText(PG,"equip")
    if useBtn then ClickBtn(useBtn); Wait(1) end
    local close = FindBtnText(PG,"close") or FindBtnText(PG,"x")
    if close then ClickBtn(close) end
    return itBtn ~= nil
end

local function BuyAllMerchant()
    Wait(0.5)
    local shopBtn = FindBtnText(PG,"shop") or FindBtnText(PG,"store") or FindBtnText(PG,"buy")
    if shopBtn then ClickBtn(shopBtn); Wait(0.5) end
    local bought = 0
    for _ = 1, 30 do
        local b = FindBtnText(PG,"buy") or FindBtnText(PG,"purchase")
        if not b then break end
        ClickBtn(b); Wait(0.35)
        local cf = FindBtnText(PG,"confirm") or FindBtnText(PG,"ok") or FindBtnText(PG,"yes")
        if cf then ClickBtn(cf); Wait(0.25) end
        bought = bought + 1
    end
    Log("Buy","Dibeli "..bought.." item")
    local close = FindBtnText(PG,"close") or FindBtnText(PG,"exit") or FindBtnText(PG,"x")
    if close then ClickBtn(close) end
    Wait(0.3)
end

local function HandleMerchant(merchantName)
    if not CONFIG.AUTO_BUY then return end
    Log("Buy", merchantName.." terdeteksi!")
    State.merchantQueued = true
    State.merchantName   = merchantName
    if _G.SolsGUI then _G.SolsGUI.UpdateMerchant(merchantName) end

    -- Tunggu crafting selesai iterasi ini
    local wt = tick()
    while State.craftingActive and tick()-wt < 25 do Wait(1) end

    local used = UseItemInventory("Merchant Teleporter")
    if not used then
        local npc, pos = FindNPC(merchantName)
        if not npc then npc, pos = FindNPC("merchant") end
        if pos then WalkTo(pos, 30) end
    end
    Wait(2)

    local npc = FindNPC(merchantName) or FindNPC("merchant")
    if npc then InteractNPC(npc); Wait(0.7) end
    BuyAllMerchant()

    State.merchantQueued = false
    if _G.SolsGUI then _G.SolsGUI.UpdateMerchant(nil) end
    Log("Buy","Auto Buy selesai!")
end

-- ================================================================
--  AUTO CRAFT
-- ================================================================
local function ScrollFindPotion(name)
    for i = 1, 25 do
        local btn = FindBtnText(PG, name)
        if btn then return btn end
        for _, f in ipairs(PG:GetDescendants()) do
            if f:IsA("ScrollingFrame") and f.Visible then
                f.CanvasPosition = f.CanvasPosition + Vector2.new(0,50)
            end
        end
        Wait(0.25)
    end
    return nil
end

local function FindPortal(names)
    for _, n in ipairs(names) do
        local m, pos = FindNPC(n); if pos then return m, pos end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        for _, n in ipairs(names) do
            if v.Name:lower():find(n:lower()) and (v:IsA("BasePart") or v:IsA("Model")) then
                local p = v:IsA("Model") and v:GetModelCFrame().Position or v.Position
                return v, p
            end
        end
    end
    return nil, nil
end

local function DoCraftCycle()
    State.craftingActive = true

    -- 1. Jalan ke Portal Stella
    local portal, pPos = FindPortal({"stella","portal","craftingroom","cauldronroom"})
    if pPos then
        Log("Craft","Menuju Portal Stella...")
        WalkTo(pPos, 22); Wait(0.5)
        if portal then
            for _, pp in ipairs(portal:IsA("Model") and portal:GetDescendants() or {portal}) do
                if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt,pp); Wait(1); break end
            end
        end
    end
    Wait(1)

    -- 2. Cari & interaksi Cauldron
    local cauldron, cPos = FindPortal({"cauldron","brew","kettle"})
    if cPos then
        WalkTo(cPos + Vector3.new(0,0,3), 15); Wait(0.4)
        if cauldron then InteractNPC(cauldron); Wait(0.8) end
    else
        Log("Craft","Cauldron tidak ketemu, tunggu UI..."); Wait(2)
    end

    -- 3. Scroll cari potion
    local potBtn = ScrollFindPotion(CONFIG.TARGET_POTION)
    if not potBtn then
        Log("Craft","Potion '"..CONFIG.TARGET_POTION.."' tidak ketemu!")
        State.craftingActive = false; return false
    end
    ClickBtn(potBtn); Wait(0.4)

    -- 4. Klik Auto (hanya jika belum aktif)
    if not State.craftAutoOn then
        local autoBtn = FindBtnText(PG,"auto")
        if autoBtn then
            local isGreen = autoBtn.BackgroundColor3.G > 0.5 and autoBtn.BackgroundColor3.R < 0.5
            if not isGreen then ClickBtn(autoBtn); Log("Craft","Tombol Auto ON") end
            State.craftAutoOn = true
        end
        Wait(0.25)
    end

    -- 5. Open Recipe
    local recipeBtn = FindBtnText(PG,"open recipe") or FindBtnText(PG,"recipe") or FindBtnText(PG,"ingredients")
    if recipeBtn then ClickBtn(recipeBtn); Wait(0.4) end

    -- 6. Spam Add Everything + Craft
    Log("Craft","Spam Add Everything & Craft...")
    while CONFIG.AUTO_CRAFT do
        -- Cek merchant
        if State.merchantQueued then
            Log("Craft","Merchant masuk! Tutup UI...")
            local close = FindBtnText(PG,"close") or FindBtnText(PG,"x") or FindBtnText(PG,"back")
            if close then ClickBtn(close) end
            State.craftingActive = false
            HandleMerchant(State.merchantName)
            -- Respawn / reset
            Log("Craft","Respawn ke spawn...")
            Wait(1)
            local resetBtn = FindBtnText(PG,"reset")
            if resetBtn then
                ClickBtn(resetBtn); Wait(0.4)
                local cf2 = FindBtnText(PG,"reset") or FindBtnText(PG,"confirm")
                if cf2 then ClickBtn(cf2) end
            else
                pcall(function() LP:LoadCharacter() end)
            end
            Wait(3)
            State.craftAutoOn = true  -- auto masih aktif, tidak perlu klik lagi
            DoCraftCycle(); return
        end

        -- Add Everything
        local addBtn = FindBtnText(PG,"add everything") or FindBtnText(PG,"add all") or FindBtnText(PG,"fill")
        if addBtn then ClickBtn(addBtn) end

        -- Craft
        local craftBtn = FindBtnText(PG,"craft") or FindBtnText(PG,"brew") or FindBtnText(PG,"make")
        if craftBtn then ClickBtn(craftBtn) end

        -- Jika UI tertutup, re-open
        local stillOpen = FindGuiDeep(PG,"cauldron") or FindGuiDeep(PG,"craft") or FindGuiDeep(PG,"brew")
        if not stillOpen then
            Log("Craft","UI tertutup, re-open..."); Wait(2)
            local c2 = FindPortal({"cauldron","brew","kettle"})
            if c2 then InteractNPC(c2); Wait(0.7) end
            local pb2 = ScrollFindPotion(CONFIG.TARGET_POTION)
            if pb2 then ClickBtn(pb2); Wait(0.3) end
            local rb2 = FindBtnText(PG,"open recipe") or FindBtnText(PG,"recipe")
            if rb2 then ClickBtn(rb2); Wait(0.3) end
        end

        Wait(0.4)
    end

    State.craftingActive = false
    return true
end

local function AutoCraftLoop()
    task.spawn(function()
        while CONFIG.AUTO_CRAFT do
            DoCraftCycle()
            if not CONFIG.AUTO_CRAFT then break end
            Wait(1.5)
        end
    end)
end

-- ================================================================
--  BIOME DETECTOR
-- ================================================================
local RARE = {
    glitch="Glitched", dream="Dreamspace", cyber="Cyberspace"
}

local function ShouldNotify(name)
    local l = name:lower()
    if l:find("glitch") and CONFIG.NOTIFY_GLITCHED   then return true end
    if l:find("dream")  and CONFIG.NOTIFY_DREAMSPACE  then return true end
    if l:find("cyber")  and CONFIG.NOTIFY_CYBERSPACE  then return true end
    return false
end

local function SendWebhook(biome)
    if CONFIG.WEBHOOK_URL:find("MASUKKAN") then Log("Webhook","URL belum diset!"); return end
    local body = HttpService:JSONEncode({
        username = "Sol's RNG - Biome Alert",
        embeds = {{
            title = "Biome Terdeteksi: "..biome,
            description = "Player: **"..LP.Name.."**",
            color = biome:lower():find("glitch") and 0xFF0000
                 or biome:lower():find("dream")  and 0x9B59B6 or 0x00BFFF,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    })
    local req = syn and syn.request or (http and http.request) or request
    if req then
        SafeCall(function()
            req({Url=CONFIG.WEBHOOK_URL,Method="POST",
                 Headers={["Content-Type"]="application/json"},Body=body})
            Log("Webhook","Terkirim: "..biome)
        end)
    end
end

local function CheckBiomeStr(text)
    if not text or text=="" then return end
    local l = text:lower()
    for key, name in pairs(RARE) do
        if l:find(key) then
            if State.currentBiome ~= name then
                State.currentBiome = name
                Log("Biome","Terdeteksi: "..name)
                if _G.SolsGUI then _G.SolsGUI.UpdateBiome(name) end
                if ShouldNotify(name) then SendWebhook(name) end
            end
            break
        end
    end
    -- Merchant detection
    if l:find("mari has arrived") or (l:find("%[merchant%]") and l:find("mari")) then
        task.spawn(function() HandleMerchant("Mari") end)
    end
    if l:find("jester has arrived") or (l:find("%[merchant%]") and l:find("jester")) then
        task.spawn(function() HandleMerchant("Jester") end)
    end
end

local function StartBiomeDetector()
    -- Method 1: Atribut game
    task.spawn(function()
        while CONFIG.BIOME_DETECT do
            local L = game:GetService("Lighting")
            for _, a in ipairs({"Biome","CurrentBiome","BiomeName","ActiveBiome"}) do
                if L:GetAttribute(a) then CheckBiomeStr(tostring(L:GetAttribute(a))); break end
            end
            for _, a in ipairs({"Biome","CurrentBiome"}) do
                if workspace:GetAttribute(a) then CheckBiomeStr(tostring(workspace:GetAttribute(a))); break end
            end
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("StringValue") and v.Name:lower():find("biome") then
                    CheckBiomeStr(v.Value); break
                end
            end
            -- Scan GUI teks
            for _, gui in ipairs(PG:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    for _, lbl in ipairs(gui:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" then
                            CheckBiomeStr(lbl.Text)
                        end
                    end
                end
            end
            Wait(2)
        end
    end)

    -- Method 2: Chat hook
    pcall(function()
        TextChatService.MessageReceived:Connect(function(msg)
            CheckBiomeStr(msg.Text)
        end)
    end)
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            p.Chatted:Connect(CheckBiomeStr)
        end
        Players.PlayerAdded:Connect(function(p)
            p.Chatted:Connect(CheckBiomeStr)
        end)
    end)

    -- Method 3: Scan chat GUI
    task.spawn(function()
        while CONFIG.BIOME_DETECT do
            for _, gui in ipairs(PG:GetChildren()) do
                if gui.Name:lower():find("chat") and gui:IsA("ScreenGui") then
                    for _, lbl in ipairs(gui:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Visible and lbl.Text ~= "" then
                            CheckBiomeStr(lbl.Text)
                        end
                    end
                end
            end
            Wait(3)
        end
    end)
end

-- ================================================================
--  INTERACTIVE GUI
-- ================================================================
local function CreateGUI()
    local ex = PG:FindFirstChild("SolsRNG_GUI"); if ex then ex:Destroy() end

    local C = {
        BG     = Color3.fromRGB(13,13,22),     Panel  = Color3.fromRGB(20,20,36),
        Header = Color3.fromRGB(28,28,52),     TabBG  = Color3.fromRGB(16,16,28),
        TabOn  = Color3.fromRGB(65,65,155),    Accent = Color3.fromRGB(90,90,210),
        ON     = Color3.fromRGB(70,210,110),   OFF    = Color3.fromRGB(210,70,70),
        Text   = Color3.fromRGB(215,215,235),  Sub    = Color3.fromRGB(130,130,160),
        Input  = Color3.fromRGB(24,24,44),     White  = Color3.fromRGB(255,255,255),
        Gold   = Color3.fromRGB(255,205,70),   Blue   = Color3.fromRGB(90,170,255),
        Purple = Color3.fromRGB(170,100,255),  Warn   = Color3.fromRGB(255,180,60),
    }
    local function Tw(o,p,t) TweenService:Create(o,TweenInfo.new(t or 0.15),p):Play() end

    local Gui = Instance.new("ScreenGui")
    Gui.Name="SolsRNG_GUI"; Gui.ResetOnSpawn=false
    Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; Gui.Parent=PG

    local Win = Instance.new("Frame",Gui)
    Win.Size=UDim2.new(0,345,0,460); Win.Position=UDim2.new(0,14,0.5,-230)
    Win.BackgroundColor3=C.BG; Win.BorderSizePixel=0; Win.Active=true; Win.Draggable=true
    Instance.new("UICorner",Win).CornerRadius=UDim.new(0,10)
    local WS=Instance.new("UIStroke",Win); WS.Color=C.Accent; WS.Thickness=1.5

    local TB=Instance.new("Frame",Win); TB.Size=UDim2.new(1,0,0,40)
    TB.BackgroundColor3=C.Header; TB.BorderSizePixel=0
    Instance.new("UICorner",TB).CornerRadius=UDim.new(0,10)
    local TL=Instance.new("TextLabel",TB); TL.Size=UDim2.new(1,-50,1,0)
    TL.Position=UDim2.new(0,12,0,0); TL.BackgroundTransparency=1
    TL.Text="Sol's RNG Script v3.0"; TL.TextColor3=C.White; TL.TextSize=14
    TL.Font=Enum.Font.GothamBold; TL.TextXAlignment=Enum.TextXAlignment.Left
    local MB=Instance.new("TextButton",TB); MB.Size=UDim2.new(0,26,0,20)
    MB.Position=UDim2.new(1,-34,0.5,-10); MB.BackgroundColor3=Color3.fromRGB(55,55,85)
    MB.Text="-"; MB.TextColor3=C.Text; MB.TextSize=14; MB.Font=Enum.Font.GothamBold
    MB.BorderSizePixel=0; Instance.new("UICorner",MB).CornerRadius=UDim.new(0,5)

    local TabBar=Instance.new("Frame",Win); TabBar.Size=UDim2.new(1,-16,0,30)
    TabBar.Position=UDim2.new(0,8,0,46); TabBar.BackgroundColor3=C.TabBG
    TabBar.BorderSizePixel=0; Instance.new("UICorner",TabBar).CornerRadius=UDim.new(0,7)
    local TBL=Instance.new("UIListLayout",TabBar); TBL.FillDirection=Enum.FillDirection.Horizontal
    TBL.SortOrder=Enum.SortOrder.LayoutOrder; TBL.Padding=UDim.new(0,2)
    local TBP=Instance.new("UIPadding",TabBar)
    TBP.PaddingLeft=UDim.new(0,3); TBP.PaddingTop=UDim.new(0,3); TBP.PaddingBottom=UDim.new(0,3)

    local Cont=Instance.new("Frame",Win); Cont.Size=UDim2.new(1,-16,1,-90)
    Cont.Position=UDim2.new(0,8,0,82); Cont.BackgroundTransparency=1; Cont.ClipsDescendants=true

    local SB=Instance.new("Frame",Win); SB.Size=UDim2.new(1,-16,0,28)
    SB.Position=UDim2.new(0,8,1,-34); SB.BackgroundColor3=C.Header; SB.BorderSizePixel=0
    Instance.new("UICorner",SB).CornerRadius=UDim.new(0,6)
    local BioL=Instance.new("TextLabel",SB); BioL.Size=UDim2.new(0.5,0,1,0)
    BioL.Position=UDim2.new(0,8,0,0); BioL.BackgroundTransparency=1; BioL.Text="Biome: —"
    BioL.TextColor3=C.Gold; BioL.TextSize=11; BioL.Font=Enum.Font.GothamSemibold
    BioL.TextXAlignment=Enum.TextXAlignment.Left
    local FishL=Instance.new("TextLabel",SB); FishL.Size=UDim2.new(0.5,-8,1,0)
    FishL.Position=UDim2.new(0.5,0,0,0); FishL.BackgroundTransparency=1
    FishL.Text="Fish: 0 | Idle"; FishL.TextColor3=C.Blue; FishL.TextSize=11
    FishL.Font=Enum.Font.GothamSemibold; FishL.TextXAlignment=Enum.TextXAlignment.Right

    -- Helpers
    local function MakePage()
        local p=Instance.new("ScrollingFrame",Cont); p.Size=UDim2.new(1,0,1,0)
        p.BackgroundTransparency=1; p.BorderSizePixel=0; p.ScrollBarThickness=3
        p.ScrollBarImageColor3=C.Accent; p.CanvasSize=UDim2.new(0,0,0,0); p.Visible=false
        local l=Instance.new("UIListLayout",p); l.SortOrder=Enum.SortOrder.LayoutOrder
        l.Padding=UDim.new(0,5)
        local pad=Instance.new("UIPadding",p)
        pad.PaddingTop=UDim.new(0,4); pad.PaddingLeft=UDim.new(0,2); pad.PaddingRight=UDim.new(0,4)
        l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            p.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+10)
        end)
        return p
    end
    local function MakeTabBtn(lbl,ord)
        local b=Instance.new("TextButton",TabBar); b.Size=UDim2.new(0,56,1,0)
        b.BackgroundColor3=C.TabBG; b.Text=lbl; b.TextColor3=C.Sub; b.TextSize=11
        b.Font=Enum.Font.GothamSemibold; b.BorderSizePixel=0; b.LayoutOrder=ord
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); return b
    end
    local function Sec(txt,parent,ord)
        local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,20)
        f.BackgroundTransparency=1; f.LayoutOrder=ord or 0
        local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,0,1,0)
        l.BackgroundTransparency=1; l.Text="  "..txt; l.TextColor3=C.Accent
        l.TextSize=11; l.Font=Enum.Font.GothamBold; l.TextXAlignment=Enum.TextXAlignment.Left
        return f
    end
    local refreshMap = {}
    local function Toggle(lbl,key,parent,ord,extra)
        local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=C.Panel; row.BorderSizePixel=0; row.LayoutOrder=ord or 0
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
        local l=Instance.new("TextLabel",row); l.Size=UDim2.new(1,-62,1,0)
        l.Position=UDim2.new(0,10,0,0); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=C.Text; l.TextSize=12; l.Font=Enum.Font.Gotham
        l.TextXAlignment=Enum.TextXAlignment.Left
        local btn=Instance.new("TextButton",row); btn.Size=UDim2.new(0,48,0,22)
        btn.Position=UDim2.new(1,-55,0.5,-11); btn.BorderSizePixel=0
        btn.TextSize=11; btn.Font=Enum.Font.GothamBold; btn.TextColor3=C.BG
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,11)
        local function Ref()
            local v=CONFIG[key]; btn.Text=v and "ON" or "OFF"
            Tw(btn,{BackgroundColor3=v and C.ON or C.OFF})
        end
        Ref()
        if extra then refreshMap[extra]=Ref end
        btn.MouseButton1Click:Connect(function()
            -- Mutex
            if key=="AUTO_FISH" and not CONFIG.AUTO_FISH and CONFIG.AUTO_CRAFT then
                CONFIG.AUTO_CRAFT=false; if refreshMap["craft"] then refreshMap["craft"]() end
            end
            if key=="AUTO_CRAFT" and not CONFIG.AUTO_CRAFT and CONFIG.AUTO_FISH then
                CONFIG.AUTO_FISH=false; if refreshMap["fish"] then refreshMap["fish"]() end
            end
            CONFIG[key]=not CONFIG[key]; Ref()
            if key=="AUTO_FISH"  and CONFIG.AUTO_FISH  then AutoFishLoop() end
            if key=="AUTO_CRAFT" and CONFIG.AUTO_CRAFT then AutoCraftLoop() end
            Log("GUI",key.."="..tostring(CONFIG[key]))
        end)
        return row
    end
    local function Num(lbl,key,parent,ord)
        local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=C.Panel; row.BorderSizePixel=0; row.LayoutOrder=ord or 0
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
        local l=Instance.new("TextLabel",row); l.Size=UDim2.new(1,-90,1,0)
        l.Position=UDim2.new(0,10,0,0); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=C.Text; l.TextSize=12; l.Font=Enum.Font.Gotham
        l.TextXAlignment=Enum.TextXAlignment.Left
        local ibg=Instance.new("Frame",row); ibg.Size=UDim2.new(0,72,0,24)
        ibg.Position=UDim2.new(1,-80,0.5,-12); ibg.BackgroundColor3=C.Input; ibg.BorderSizePixel=0
        Instance.new("UICorner",ibg).CornerRadius=UDim.new(0,6)
        local ist=Instance.new("UIStroke",ibg); ist.Color=C.Accent; ist.Thickness=1
        local box=Instance.new("TextBox",ibg); box.Size=UDim2.new(1,-8,1,0)
        box.Position=UDim2.new(0,4,0,0); box.BackgroundTransparency=1
        box.Text=tostring(CONFIG[key]); box.TextColor3=C.White; box.TextSize=12
        box.Font=Enum.Font.GothamSemibold; box.ClearTextOnFocus=false
        box.Focused:Connect(function() Tw(ist,{Color=C.White}) end)
        box.FocusLost:Connect(function()
            Tw(ist,{Color=C.Accent})
            local n=tonumber(box.Text)
            if n and n>0 then CONFIG[key]=math.floor(n); box.Text=tostring(CONFIG[key])
            else box.Text=tostring(CONFIG[key]) end
        end)
    end
    local function Txt(lbl,key,parent,ord)
        local w=Instance.new("Frame",parent); w.Size=UDim2.new(1,0,0,60)
        w.BackgroundColor3=C.Panel; w.BorderSizePixel=0; w.LayoutOrder=ord or 0
        Instance.new("UICorner",w).CornerRadius=UDim.new(0,7)
        local l=Instance.new("TextLabel",w); l.Size=UDim2.new(1,-10,0,18)
        l.Position=UDim2.new(0,10,0,5); l.BackgroundTransparency=1; l.Text=lbl
        l.TextColor3=C.Sub; l.TextSize=11; l.Font=Enum.Font.GothamSemibold
        l.TextXAlignment=Enum.TextXAlignment.Left
        local ibg=Instance.new("Frame",w); ibg.Size=UDim2.new(1,-16,0,26)
        ibg.Position=UDim2.new(0,8,0,28); ibg.BackgroundColor3=C.Input; ibg.BorderSizePixel=0
        Instance.new("UICorner",ibg).CornerRadius=UDim.new(0,6)
        local ist=Instance.new("UIStroke",ibg); ist.Color=C.Accent; ist.Thickness=1
        local box=Instance.new("TextBox",ibg); box.Size=UDim2.new(1,-10,1,0)
        box.Position=UDim2.new(0,5,0,0); box.BackgroundTransparency=1
        box.Text=CONFIG[key] or ""; box.PlaceholderText="Ketik disini..."
        box.PlaceholderColor3=C.Sub; box.TextColor3=C.White; box.TextSize=11
        box.Font=Enum.Font.Gotham; box.ClearTextOnFocus=false
        box.TextXAlignment=Enum.TextXAlignment.Left
        box.Focused:Connect(function() Tw(ist,{Color=C.White}) end)
        box.FocusLost:Connect(function()
            Tw(ist,{Color=C.Accent}); CONFIG[key]=box.Text
        end)
        return w, box
    end
    local function ActBtn(lbl,col,parent,ord,cb)
        local w=Instance.new("Frame",parent); w.Size=UDim2.new(1,0,0,32)
        w.BackgroundTransparency=1; w.LayoutOrder=ord or 0
        local b=Instance.new("TextButton",w); b.Size=UDim2.new(1,0,0,28)
        b.BackgroundColor3=col or C.Accent; b.Text=lbl; b.TextColor3=C.White
        b.TextSize=12; b.Font=Enum.Font.GothamSemibold; b.BorderSizePixel=0
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
        b.MouseButton1Click:Connect(function() if cb then cb(b) end end)
        return w, b
    end
    local function WarnBanner(txt,parent,ord)
        local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,28)
        f.BackgroundColor3=Color3.fromRGB(60,30,10); f.BorderSizePixel=0; f.LayoutOrder=ord or 0
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,6)
        local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-10,1,0)
        l.Position=UDim2.new(0,8,0,0); l.BackgroundTransparency=1; l.Text=txt
        l.TextColor3=C.Warn; l.TextSize=11; l.Font=Enum.Font.GothamSemibold
        l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=true
        return f
    end
    local function InfoBox(txt,col,parent,ord)
        local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,38)
        f.BackgroundColor3=C.Panel; f.BorderSizePixel=0; f.LayoutOrder=ord or 0
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
        local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-16,1,0)
        l.Position=UDim2.new(0,8,0,0); l.BackgroundTransparency=1; l.Text=txt
        l.TextColor3=col or C.Sub; l.TextSize=12; l.Font=Enum.Font.GothamSemibold
        l.TextXAlignment=Enum.TextXAlignment.Left; l.TextWrapped=true
        return f, l
    end

    -- Tabs
    local tNames={"Main","Fish","Buy","Craft","Biome"}
    local tabs,pages={},{}
    for i,n in ipairs(tNames) do tabs[i]=MakeTabBtn(n,i); pages[i]=MakePage() end
    local function ActTab(idx)
        for i,t in ipairs(tabs) do
            local a=(i==idx); Tw(t,{BackgroundColor3=a and C.TabOn or C.TabBG})
            t.TextColor3=a and C.White or C.Sub; pages[i].Visible=a
        end
    end
    for i,t in ipairs(tabs) do t.MouseButton1Click:Connect(function() ActTab(i) end) end

    -- TAB 1: MAIN
    local p1=pages[1]
    Sec("Toggle Semua Fitur",p1,1)
    WarnBanner("Auto Fish & Auto Craft tidak bisa aktif bersamaan",p1,2)
    Toggle("Auto Fish",          "AUTO_FISH",    p1,3,"fish")
    Toggle("Auto Sell Fish",     "AUTO_SELL",    p1,4)
    Toggle("Auto Buy Merchant",  "AUTO_BUY",     p1,5)
    Toggle("Auto Craft Potion",  "AUTO_CRAFT",   p1,6,"craft")
    Toggle("Biome Detector",     "BIOME_DETECT", p1,7)

    -- TAB 2: FISH
    local p2=pages[2]
    Sec("Fishing Settings",p2,1)
    Toggle("Auto Fish",       "AUTO_FISH", p2,2,"fish2")
    Toggle("Auto Sell Fish",  "AUTO_SELL", p2,3)
    Num("Jual setiap X ikan", "SELL_EVERY",p2,4)
    Sec("Status",p2,5)
    local _, fishStatL = InfoBox("Ikan: 0 / "..CONFIG.SELL_EVERY, C.Blue, p2, 6)

    -- TAB 3: BUY
    local p3=pages[3]
    Sec("Auto Buy Merchant",p3,1)
    Toggle("Auto Buy (Jester & Mari)","AUTO_BUY",p3,2)
    local noteB=Instance.new("Frame",p3); noteB.Size=UDim2.new(1,0,0,44)
    noteB.BackgroundColor3=C.Panel; noteB.BorderSizePixel=0; noteB.LayoutOrder=3
    Instance.new("UICorner",noteB).CornerRadius=UDim.new(0,7)
    local noteBL=Instance.new("TextLabel",noteB); noteBL.Size=UDim2.new(1,-16,1,0)
    noteBL.Position=UDim2.new(0,8,0,0); noteBL.BackgroundTransparency=1
    noteBL.Text="Deteksi dari chat:\n\"[Merchant]: Jester/Mari has arrived...\""
    noteBL.TextColor3=C.Sub; noteBL.TextSize=11; noteBL.Font=Enum.Font.Gotham
    noteBL.TextXAlignment=Enum.TextXAlignment.Left; noteBL.TextWrapped=true
    local _, mStatL = InfoBox("Merchant: Belum terdeteksi", C.Gold, p3, 4)

    -- TAB 4: CRAFT
    local p4=pages[4]
    Sec("Auto Craft Potions",p4,1)
    Toggle("Auto Craft","AUTO_CRAFT",p4,2,"craft2")
    WarnBanner("Tidak bisa aktif bersamaan dengan Auto Fish",p4,3)
    Sec("Target Potion",p4,4)
    local _, potionBox = Txt("Nama Potion Target","TARGET_POTION",p4,5)
    potionBox.Text=CONFIG.TARGET_POTION

    -- TAB 5: BIOME
    local p5=pages[5]
    Sec("Biome Detector",p5,1)
    Toggle("Biome Detector",   "BIOME_DETECT",       p5,2)
    Toggle("Notify Glitched",  "NOTIFY_GLITCHED",    p5,3)
    Toggle("Notify Dreamspace","NOTIFY_DREAMSPACE",  p5,4)
    Toggle("Notify Cyberspace","NOTIFY_CYBERSPACE",  p5,5)
    Sec("Discord Webhook",p5,6)
    local _, wBox = Txt("Webhook URL","WEBHOOK_URL",p5,7)
    wBox.Text=CONFIG.WEBHOOK_URL
    ActBtn("Test Kirim Webhook",Color3.fromRGB(50,80,160),p5,8,function(b)
        CONFIG.WEBHOOK_URL=wBox.Text
        SendWebhook("TEST_BIOME (Manual)")
        b.Text="Terkirim!"; task.delay(2,function() b.Text="Test Kirim Webhook" end)
    end)
    local _, bStatL = InfoBox("Biome saat ini: —", C.Purple, p5, 9)

    -- MINIMIZE
    local isMin=false
    MB.MouseButton1Click:Connect(function()
        isMin=not isMin; MB.Text=isMin and "+" or "-"
        Tw(Win,{Size=UDim2.new(0,345,0,isMin and 40 or 460)},0.2)
        Cont.Visible=not isMin; TabBar.Visible=not isMin; SB.Visible=not isMin
    end)

    ActTab(1)

    -- Global refs
    _G.SolsGUI = {
        UpdateBiome = function(n)
            BioL.Text = "Biome: "..n
            bStatL.Text = "Biome saat ini: "..n
        end,
        UpdateFish = function(n)
            FishL.Text = "Fish: "..n.." | "..(CONFIG.AUTO_FISH and "Fishing..." or "Idle")
            fishStatL.Text = "Ikan: "..n.." / "..CONFIG.SELL_EVERY
        end,
        UpdateMerchant = function(n)
            mStatL.Text = "Merchant: "..(n or "Selesai")
            mStatL.TextColor3 = n and C.ON or C.Gold
        end,
    }

    Log("GUI","GUI v3.0 siap!")
end

-- ================================================================
--  MAIN
-- ================================================================
local function Main()
    Log("Main","=== Sol's RNG v3.0 Loading ===")
    if not HRP then LP.CharacterAdded:Wait(); Wait(1) end
    Wait(2)
    CreateGUI()
    StartBiomeDetector()
    if CONFIG.AUTO_FISH  then AutoFishLoop()  end
    if CONFIG.AUTO_CRAFT then AutoCraftLoop() end
    task.spawn(function()
        while true do
            if _G.SolsGUI and _G.SolsGUI.UpdateMerchant then
                if not State.merchantQueued then _G.SolsGUI.UpdateMerchant(nil) end
            end
            Wait(1)
        end
    end)
    Log("Main","=== Siap! Auto Fish & Craft default OFF - nyalakan dari GUI ===")
end

SafeCall(Main)
