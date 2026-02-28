-- SCANNER: Cari semua model di sekitar karakter
local LP = game:GetService("Players").LocalPlayer
local Char = LP.Character
local HRP = Char:WaitForChild("HumanoidRootPart")

local found = {}
for _, v in ipairs(workspace:GetDescendants()) do
    if (v:IsA("Model") or v:IsA("BasePart") or v:IsA("Part")) then
        local pos
        if v:IsA("Model") and v.PrimaryPart then
            pos = v.PrimaryPart.Position
        elseif v:IsA("BasePart") then
            pos = v.Position
        end
        if pos then
            local dist = (HRP.Position - pos).Magnitude
            -- Tampilkan semua object dalam radius 100 studs
            if dist < 100 then
                local key = v.ClassName .. ": " .. v.Name
                if not found[key] then
                    found[key] = true
                    print("[SCAN] ".. key .. " | Dist: " .. math.floor(dist))
                end
            end
        end
    end
end
print("=== Scan selesai ===")
