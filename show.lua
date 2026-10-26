-- Script path: ReplicatedStorage.ClientComponents.WeaponToolClient
-- Decompile time: 3.17 ms

local UserInputService = game:GetService("UserInputService")
local Trove = require(game.ReplicatedStorage.Modules.Util.Trove)
local Component = require(game.ReplicatedStorage.Modules.Component)
local CombatController = require(game.ReplicatedStorage.Controllers.CombatController)
local GetPlayer = require(game.ReplicatedStorage.Modules.Player.GetPlayer)
local CombatUtil = require(game.ReplicatedStorage.Modules.CombatUtil)
local MobileCombatInput = require(game.ReplicatedStorage.Modules.MobileCombatInput)
local OnlyLocalPlayer = require(game.ReplicatedStorage.Modules.Extensions.OnlyLocalPlayer)
local IsNewCombatSystemEnabled = require(game.ReplicatedStorage.Modules.Extensions.IsNewCombatSystemEnabled)
local LocalPlayer = game.Players.LocalPlayer
local v1 = Component.new({Tag = "WeaponTool", Extensions = {OnlyLocalPlayer, IsNewCombatSystemEnabled}})

function v1.Construct(a1) -- Line: 18 -- upvalues: CombatUtil (val), GetPlayer (val), Trove (val)
    local Instance = a1.Instance
    local WeaponName = CombatUtil:GetWeaponName(Instance)
    a1.weaponName = WeaponName
    a1.weaponData = CombatUtil:GetWeaponData(WeaponName)
    a1.weaponType = a1.weaponData.WeaponType
    a1.player = GetPlayer(Instance)
    a1.trove = Trove.new()
    Instance:SetAttribute("LocalShotsLeft", a1.weaponData.MagSize)
    Instance:SetAttribute("LocalTotalShots", 0)
    if a1.weaponData.ShootStyle == "Gatling" then
        a1.isGatling = true
        Instance:SetAttribute("Overheat", 0)
        Instance:SetAttribute("LocalOverheat", 0)
    end
end

function v1.Start(a1) -- Line: 37
    -- upvalues: CombatController (val), LocalPlayer (val), CombatUtil (val), UserInputService (val)
    -- upvalues: MobileCombatInput (val)
    local Instance = a1.Instance

    local function activated(a1_2) -- Line: 40
        -- upvalues: a1 (val), CombatController (upval), Instance (val), LocalPlayer (upval), CombatUtil (upval)
        if a1.weaponData.WeaponType == "Melee" then
            CombatController:Attack(Instance)
            return
        end
        local Character = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("EquippedWeapon")
        if Character
            and (CombatUtil:GetPureWeaponName((Character:GetAttribute("WeaponName")))) == CombatUtil:GetPureWeaponName(a1.weaponName) then
            CombatController:Attack(Instance, a1_2)
        end
    end

    local u3 = {}
    a1.trove:Add((UserInputService.InputBegan:Connect(function(a1, a2) -- Line: 59
        -- upvalues: Instance (val), LocalPlayer (upval), MobileCombatInput (upval), u3 (val), activated (val)
        local v1 = Instance.Parent == LocalPlayer.Character
        if not a2 and v1 and not MobileCombatInput.isGuiTouch(a1) then
            local UserInputType = a1.UserInputType
            local v2 = a1.KeyCode == Enum.KeyCode.ButtonR2
            if UserInputType ~= Enum.UserInputType.Touch
                and UserInputType ~= Enum.UserInputType.MouseButton1
                and not v2 then
                return
            end
            if a1.UserInputType ~= Enum.UserInputType.Touch then
                activated(a1)
                return
            end
            local v3 = next(u3) ~= nil
            u3[a1] = true
            if not v3 and not MobileCombatInput.isM1Blocked() then
                activated(a1)
                return
            end
            return
        end
    end)))
    a1.trove:Add((UserInputService.InputEnded:Connect(function(a1) -- Line: 78 -- upvalues: u3 (val)
        u3[a1] = nil
    end)))
    if not a1.player.Character:IsDescendantOf(workspace) then
        repeat
            task.wait()
        until a1.player.Character:IsDescendantOf(workspace)
    end
    CombatUtil:ToggleLoadMovesetAnims(a1.player.Character.Humanoid, a1.weaponData, true)
    a1.trove:Add(function() -- Line: 90 -- upvalues: a1 (val), CombatUtil (upval)
        local Character = a1.player.Character and a1.player.Character:FindFirstChild("Humanoid")
        if Character then
            CombatUtil:ToggleLoadMovesetAnims(Character, a1.weaponData, false)
        end
    end)
end

function v1.Stop(a1) -- Line: 98
    a1.trove:Destroy()
end

return v1