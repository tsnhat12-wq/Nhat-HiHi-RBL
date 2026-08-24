-- =================================================================
-- AXIOM SYSTEM: NO-UI SILENT RUNNER (TARGET: BOATS, HAUNTED & FISH CREW)
-- =================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

pcall(function() setfpscap(30) end)

local LocalPlayer = Players.LocalPlayer

-- HIỆN THÔNG BÁO BẬT SCRIPT THÀNH CÔNG
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Nhat HiHi",
        Text = "Script By Nhat HiHi",
        Duration = 5,
        Icon = "rbxassetid://77399452392419"
    })
end)

-- 1. KHỞI TẠO VÀ QUÉT MÃ HÓA ĐỘNG
local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
local Net = Modules and Modules:WaitForChild("Net", 5)
local Enemies = Workspace:WaitForChild("Enemies", 5)
local Characters = Workspace:WaitForChild("Characters", 5)

local DynamicRemoteTarget = nil
local DynamicRemoteId = nil

local function InitializeHitRegistration()
    local foldersToCheck = {
        ReplicatedStorage:FindFirstChild("Util"),
        ReplicatedStorage:FindFirstChild("Common"),
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Assets"),
        ReplicatedStorage:FindFirstChild("FX")
    }

    for _, folder in ipairs(foldersToCheck) do
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("RemoteEvent") and child:GetAttribute("Id") then
                    DynamicRemoteTarget = child
                    DynamicRemoteId = child:GetAttribute("Id")
                end
            end

            folder.ChildAdded:Connect(function(child)
                if child:IsA("RemoteEvent") and child:GetAttribute("Id") then
                    DynamicRemoteTarget = child
                    DynamicRemoteId = child:GetAttribute("Id")
                end
            end)
        end
    end
end

InitializeHitRegistration()

-- 2. MỤC TIÊU BẮN SÚNG (BỔ SUNG: FISH CREW MEMBER & FISHBOAT/PIRATE BRIGADE/HAUNTED CREW)
local function GetGunTarget()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    local closestPart = nil
    local closestPos = nil
    local minDist = 1500

    -- [DANH SÁCH 1] QUÉT THUYỀN BIỂN, HAUNTED CREW & FISH CREW MEMBER TỪ WORKSPACE.ENEMIES
    if Enemies then
        for _, enemy in pairs(Enemies:GetChildren()) do
            -- Kiểm tra Thuyền (FishBoat, PirateBrigade, PirateGrandBrigade)
            if enemy:FindFirstChild("VehicleSeat") or enemy:FindFirstChild("Engine") then
                local healthObj = enemy:FindFirstChild("Health")
                local isAlive = not healthObj or (healthObj:IsA("ValueBase") and healthObj.Value > 0) or (healthObj:IsA("Humanoid") and healthObj.Health > 0)
                
                if isAlive then
                    local targetPart = enemy:FindFirstChild("Engine") or enemy:FindFirstChild("VehicleSeat") or enemy:FindFirstChildWhichIsA("BasePart")
                    if targetPart then
                        local dist = (targetPart.Position - myHRP.Position).Magnitude
                        if dist < minDist then
                            minDist = dist
                            closestPart = targetPart
                            closestPos = targetPart.Position
                        end
                    end
                end
            end

            -- Kiểm tra Quái Thường, Haunted Crew Member & Fish Crew Member
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local targetPart = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head") or enemy:FindFirstChildWhichIsA("BasePart")
                if targetPart then
                    local dist = (targetPart.Position - myHRP.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closestPart = targetPart
                        closestPos = targetPart.Position
                    end
                end
            end
        end
    end

    -- [DANH SÁCH 2] QUÉT SEABEASTS & LEVIATHAN
    local seaBeastsFolder = Workspace:FindFirstChild("SeaBeasts")
    if seaBeastsFolder then
        for _, b in pairs(seaBeastsFolder:GetChildren()) do
            local hrp = b:FindFirstChild("HumanoidRootPart")
            local healthObj = b:FindFirstChild("Health")
            if hrp and healthObj and healthObj.Value > 0 then
                local targetPart = b:FindFirstChild("Leviathan Segment") or hrp
                local dist = (targetPart.Position - myHRP.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    closestPart = targetPart
                    closestPos = targetPart.Position
                end
            end
        end
    end

    return closestPos, closestPart
end

-- 3. MỤC TIÊU FAST ATTACK CẬN CHIẾN
local function GetMeleeTargets(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    
    local hitTargets = {}
    local function ScanFolder(folder)
        if not folder then return end
        for _, target in ipairs(folder:GetChildren()) do
            local humanoid = target:FindFirstChild("Humanoid")
            local targetHrp = target:FindFirstChild("HumanoidRootPart")
            if humanoid and targetHrp and humanoid.Health > 0 and target ~= character then
                if (targetHrp.Position - hrp.Position).Magnitude <= 60 then
                    for _, child in ipairs(target:GetChildren()) do
                        if child:IsA("BasePart") then
                            table.insert(hitTargets, {target, child})
                        end
                    end
                end
            end
        end
    end
    
    ScanFolder(Enemies)
    ScanFolder(Characters)
    return hitTargets
end

-- 4. FAST ATTACK (MELEE & SWORD) - TỐC ĐỘ 0.1s
local function ExecuteFastAttack()
    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    local weaponType = tool:GetAttribute("WeaponType")
    if weaponType ~= "Melee" and weaponType ~= "Sword" then return end

    local hitTargets = GetMeleeTargets(character)
    if #hitTargets == 0 then return end

    if Net and Net:FindFirstChild("RE/RegisterAttack") and Net:FindFirstChild("RE/RegisterHit") then
        Net["RE/RegisterAttack"]:FireServer()
        local targetHead = hitTargets[1][1]:FindFirstChild("Head") or hitTargets[1][2]
        Net["RE/RegisterHit"]:FireServer(targetHead, hitTargets, {})

        if DynamicRemoteTarget and DynamicRemoteId and Net:FindFirstChild("seed") then
            pcall(function()
                local seed = Net.seed:InvokeServer()
                local remoteCode = "RE/RegisterHit"
                local encryptionKey = math.floor(Workspace:GetServerTimeNow() / 10 % 10) + 1
                
                local encodedString = string.gsub(remoteCode, ".", function(char)
                    return string.char(bit32.bxor(string.byte(char), encryptionKey))
                end)

                local finalId = bit32.bxor(DynamicRemoteId + 909090, seed * 2)
                local cloneRemote = cloneref and cloneref(DynamicRemoteTarget) or DynamicRemoteTarget
                cloneRemote:FireServer(encodedString, finalId, targetHead, hitTargets)
            end)
        end
    end
end

-- 5. BẮN SÚNG MÃ HÓA (GUN ONLY) - TỐC ĐỘ 1/999999
local function ExecuteEncryptedGun()
    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then return end

    local targetPos, targetPart = GetGunTarget()
    if not targetPos or not targetPart then return end

    local shootGunEvent = Net and Net:FindFirstChild("RE/ShootGunEvent")
    if shootGunEvent then
        shootGunEvent:FireServer(targetPos, { targetPart })
    end

    if DynamicRemoteTarget and DynamicRemoteId and Net and Net:FindFirstChild("seed") then
        pcall(function()
            local seed = Net.seed:InvokeServer()
            local remoteCode = "RE/ShootGunEvent"
            local encryptionKey = math.floor(Workspace:GetServerTimeNow() / 10 % 10) + 1
            
            local encodedString = string.gsub(remoteCode, ".", function(char)
                return string.char(bit32.bxor(string.byte(char), encryptionKey))
            end)

            local finalId = bit32.bxor(DynamicRemoteId + 909090, seed * 2)
            local cloneRemote = cloneref and cloneref(DynamicRemoteTarget) or DynamicRemoteTarget
            cloneRemote:FireServer(encodedString, finalId, targetPos, { targetPart })
        end)
    end
end

-- 6. TỰ ĐỘNG CHẠY NGẦM (BACKGROUND LOOPS)
task.spawn(function()
    while true do
        pcall(ExecuteFastAttack)
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        pcall(ExecuteEncryptedGun)
        task.wait(1/999999)
    end
end)

print("[Axiom Systems] Added Fish Crew Member to Targets.")
