
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

pcall(function() setfpscap(40) end)

local LocalPlayer = Players.LocalPlayer

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

local function GetGunTarget()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    local closestPart = nil
    local closestPos = nil
    local minDist = 500

    if Enemies then
        for _, enemy in pairs(Enemies:GetChildren()) do

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
                if (targetHrp.Position - hrp.Position).Magnitude <= 100 then
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
                local encryptionKey = math.floor(Workspace:GetServerTimeNow() / 10 % 10) + 2
                
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

local function ExecuteEncryptedGun()
    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then return end
    if string.find(string.lower(tool.Name), "skull guitar", 1, true) then return end

    local targetPos, targetPart = GetGunTarget()
    if not targetPos or not targetPart then return end

    for i = 1, 3 do
        local shootGunEvent = Net and Net:FindFirstChild("RE/ShootGunEvent")
        if shootGunEvent then
            shootGunEvent:FireServer(targetPos, { targetPart })
        end
    end
end

task.spawn(function()
    while true do
        pcall(ExecuteFastAttack)
        task.wait(0.00)
    end
end)

task.spawn(function()
    while true do
        pcall(ExecuteEncryptedGun)
        task.wait(0.00)
    end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
local Net = Modules and Modules:WaitForChild("Net", 5)
local Enemies = Workspace:WaitForChild("Enemies", 5)
local Characters = Workspace:WaitForChild("Characters", 5)

local function GetGunTarget()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    local closestPart = nil
    local closestPos = nil
    local minDist = 500

    if Enemies then
        for _, enemy in pairs(Enemies:GetChildren()) do

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

local function ExecuteEncryptedGun()
    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then return end
    if string.find(string.lower(tool.Name), "skull guitar", 1, true) then return end

    local targetPos, targetPart = GetGunTarget()
    if not targetPos or not targetPart then return end

    for i = 1, 3 do
        local shootGunEvent = Net and Net:FindFirstChild("RE/ShootGunEvent")
        if shootGunEvent then
            shootGunEvent:FireServer(targetPos, { targetPart })
        end
    end
end

task.spawn(function()
    while true do
        pcall(ExecuteEncryptedGun)
        task.wait(0.00)
    end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
local Net = Modules and Modules:WaitForChild("Net", 5)
local Enemies = Workspace:WaitForChild("Enemies", 5)
local Characters = Workspace:WaitForChild("Characters", 5)

local function GetGunTarget()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil, nil end

    local closestPart = nil
    local closestPos = nil
    local minDist = 500

    if Enemies then
        for _, enemy in pairs(Enemies:GetChildren()) do

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

local function ExecuteEncryptedGun()
    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then return end
    if string.find(string.lower(tool.Name), "skull guitar", 1, true) then return end

    local targetPos, targetPart = GetGunTarget()
    if not targetPos or not targetPart then return end

    for i = 1, 3 do
        local shootGunEvent = Net and Net:FindFirstChild("RE/ShootGunEvent")
        if shootGunEvent then
            shootGunEvent:FireServer(targetPos, { targetPart })
        end
    end
end

task.spawn(function()
    while true do
        pcall(ExecuteEncryptedGun)
        task.wait(0.00)
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Cấu hình
local MAX_DISTANCE = 450
local COOLDOWN = 0.2 -- Tốc độ gửi (0.2 giây / lần)

-- Danh sách tên các mục tiêu đặc biệt (quái biển, tàu thuyền, crew)
local targetNames = {
	"Shark",
	"Terrorshark",
	"Piranha",
	"Fish Crew Member",
	"Haunted Crew Member",
	"FishBoat",
	"PirateBrigade",
	"PirateGrandBrigade"
}

-- Kiểm tra xem có đang cầm Skull Guitar / Soul Guitar không
local function isHoldingSkullGuitar()
	local character = LocalPlayer.Character
	if not character then return false end
	
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and (tool.Name == "Skull Guitar" or tool.Name == "Soul Guitar") then
		return true
	end
	return false
end

-- Tìm vị trí mục tiêu
local function getTargetPosition()
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
	local myPos = character.HumanoidRootPart.Position

	-- 1. Quét trong workspace.Enemies (Quái thường, quái biển nhỏ, tàu thuyền)
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			if table.find(targetNames, enemy.Name) then
				if enemy:FindFirstChild("VehicleSeat") and enemy:FindFirstChild("Engine") then
					local healthVal = enemy:FindFirstChild("Health")
					if healthVal and healthVal.Value > 0 then
						return enemy.Engine.Position
					end
				else
					local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("RootPart") or enemy:FindFirstChild("Head")
					local humanoid = enemy:FindFirstChildOfClass("Humanoid")
					if hrp and humanoid and humanoid.Health > 0 then
						return hrp.Position
					end
				end
			end
		end
	end

	-- 2. Quét trong workspace.SeaBeasts (Sea Beast hoặc Leviathan)
	local seaBeastsFolder = Workspace:FindFirstChild("SeaBeasts")
	if seaBeastsFolder then
		for _, sb in ipairs(seaBeastsFolder:GetChildren()) do
			local hrp = sb:FindFirstChild("HumanoidRootPart")
			local healthVal = sb:FindFirstChild("Health")
			if hrp and healthVal and healthVal.Value > 0 then
				return hrp.Position
			end
			
			local segment = sb:FindFirstChild("Leviathan Segment")
			if segment and healthVal and healthVal.Value > 0 then
				return segment.Position
			end
		end
	end

	-- 3. Quét người chơi hoặc quái thường gần nhất trong phạm vi 300 studs
	local closestPos = nil
	local shortestDist = MAX_DISTANCE

	-- Quét người chơi khác
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = player.Character.HumanoidRootPart
			local dist = (hrp.Position - myPos).Magnitude
			if dist < shortestDist then
				shortestDist = dist
				closestPos = hrp.Position
			end
		end
	end

	-- Quét quái thường khác trong Enemies
	if enemiesFolder then
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("RootPart") or enemy:FindFirstChild("Head")
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			
			if hrp and humanoid and humanoid.Health > 0 then
				local dist = (hrp.Position - myPos).Magnitude
				if dist < shortestDist then
					shortestDist = dist
					closestPos = hrp.Position
				end
			end
		end
	end

	return closestPos
end

-- Vòng lặp chạy ngầm liên tục với tốc độ 0.2s
task.spawn(function()
	while true do
		if isHoldingSkullGuitar() then
			local targetPos = getTargetPosition()
			if targetPos then
				local args = {"TAP",vector.create(targetPos.X, targetPos.Y, targetPos.Z)}
				
				-- Dùng FindFirstChild thay vì WaitForChild để tránh bị kẹt khi đổi vũ khí
				local character = LocalPlayer.Character
				if character and character:FindFirstChild("Humanoid") then
					local remote = character.Humanoid:FindFirstChild("")
					if remote then
						remote:InvokeServer(unpack(args))
					end
				end
			end
		end
		
		task.wait(COOLDOWN)
	end
end)
