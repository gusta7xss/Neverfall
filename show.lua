-- Script path: Workspace.Characters.hshdyhjhffv.DoubleJump
-- Decompile time: 5.33 ms

local u0 = 30
game:GetService("RunService")
game:GetService("ReplicatedStorage")
local Effect = require(game.ReplicatedStorage:WaitForChild("Effect"))
local Util = require(game.ReplicatedStorage.Util)
local CurrentCamera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character.HumanoidRootPart
local u44 = false
local u45 = false
Humanoid.StateChanged:Connect(function(a1, a2) -- Line: 26 -- upvalues: Humanoid (val), u45 (ref), u44 (ref)
    if a2 == Enum.HumanoidStateType.Landed then
        u45 = false
        u44 = false
        return
    end
    if a2 == Enum.HumanoidStateType.Running and Humanoid.FloorMaterial ~= Enum.Material.Air then
        u45 = false
        u44 = false
        return
    end
    if a2 == Enum.HumanoidStateType.Freefall or a2 == Enum.HumanoidStateType.Jumping then
        u45 = true
    end
end)
;(Humanoid:GetPropertyChangedSignal("FloorMaterial")):Connect(function() -- Line: 37 -- upvalues: Humanoid (val), u45 (ref), u44 (ref)
    if Humanoid.FloorMaterial == Enum.Material.Air then
        u45 = true
        return
    end
    u45 = false
    u44 = false
end)

local function jumped() -- Line: 46
    -- upvalues: u45 (ref), u44 (ref), LocalPlayer (val), Util (val), HumanoidRootPart (val), Humanoid (val)
    -- upvalues: Character (val), u0 (ref), Effect (val)
    game.ReplicatedStorage.PlayerJumpAttempted:Fire()
    if not u45 or u44 then
        return
    end
    local Value = false
    if LocalPlayer.Data.Race.Value == "Cyborg"
        and LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("RaceTransformed")
        and LocalPlayer.Character.RaceTransformed.Value
        and LocalPlayer.Data.Race:FindFirstChild("A")
        and 1 <= LocalPlayer.Data.Race.A.Value then
        Value = LocalPlayer.Data.Race.A.Value
    end
    local v1 = false
    if Util.Ray(HumanoidRootPart.Position, Vector3.new(0, -HumanoidRootPart.Size.Y * 1.5 * 2 - 10), {workspace.Characters, workspace.Enemies}) then
        v1 = true
    end
    local v2 = 0.825
    if Value and Value > 1 then
        v2 = 1
    end
    local v3 = false
    if Value then
        if require(game.ReplicatedStorage.Global).OM.active then
            if v1 and 1.666 < tick() - (require(game.ReplicatedStorage.Global).lastCyborgJump or 0) then
                v3 = true
            end
        elseif Value > 1 and v1 and 1.666 < tick() - (require(game.ReplicatedStorage.Global).lastCyborgJump or 0) then
            v3 = true
        end
    end
    v1 = Humanoid.JumpPower ^ 2 / 392.4
    local v4 = 3 + (if not Character:FindFirstChild("HydraRig") then 0 else 8)
    local v5 = Util.Ray(HumanoidRootPart.Position, Vector3.new(0, -v1 + v4 - Humanoid.HipHeight - HumanoidRootPart.Size.Y / 2, 0), {Character})
    if not v5 then end
    u0 = if LocalPlayer.Data.Race.Value ~= "Skypiea" then 30 else if not LocalPlayer.Data.Race:FindFirstChild("Evolved") then 30 else 10
    if not (LocalPlayer.Character.Humanoid.Health <= 0) and not Humanoid.Sit then
        if Character.Busy.Value and not Character:GetAttribute("NoTransform") then
            return
        end
        if not require(game.ReplicatedStorage.Global).Swimming
            and not require(game.ReplicatedStorage.Global).Dodging
            and not (0 < Character.Stun.Value) then
            local Global, Global_2, v6
            if Character:FindFirstChild("DoorMode") then
                if Character.Energy.Value < u0 then
                    return
                end
                u44 = true
                game.ReplicatedStorage.Remotes.CommE:FireServer("DoubleJump", v3)
                game.ReplicatedStorage.PlayerDoubleJumped:Fire()
                Util.Anims:Get(Character, "DoubleJump"):Play()
                if v3 then
                    v6 = Humanoid
                    v6.JumpPower = v6.JumpPower + v2 * 125
                    ;(Effect.new("RaceAwakenings.CyborgJump")):replicate({
                        ID = 1,
                        CFrame = HumanoidRootPart.CFrame,
                        RootPart = HumanoidRootPart,
                        Strong = Value > 1,
                    })
                    Global = require(game.ReplicatedStorage.Global)
                    Global.lastCyborgJump = tick()
                    Global_2 = require(game.ReplicatedStorage.Global)
                    Global_2.mobilityCooldown = tick()
                end
                HumanoidRootPart.Velocity = Vector3.new(HumanoidRootPart.Velocity.X, Humanoid.JumpPower * 1.4, HumanoidRootPart.Velocity.Z)
                if v3 then
                    v6 = Humanoid
                    v6.JumpPower = v6.JumpPower - v2 * 125
                end
                return
            end
            if not Character:FindFirstChild("Phoenix")
                and not HumanoidRootPart:FindFirstChild("MagnetEnableFlight")
                and not Character:FindFirstChild("GravityFlight")
                and not Character:FindFirstChild("FalconFlight")
                and not Character:FindFirstChild("Dragon")
                and not Character:FindFirstChild("Flamingo") then
                if Character.Energy.Value < u0 then
                    return
                end
                u44 = true
                game.ReplicatedStorage.Remotes.CommE:FireServer("DoubleJump", v3)
                game.ReplicatedStorage.PlayerDoubleJumped:Fire()
                Util.Anims:Get(Character, "DoubleJump"):Play()
                if v3 then
                    v6 = Humanoid
                    v6.JumpPower = v6.JumpPower + v2 * 125
                    ;(Effect.new("RaceAwakenings.CyborgJump")):replicate({
                        ID = 1,
                        CFrame = HumanoidRootPart.CFrame,
                        RootPart = HumanoidRootPart,
                        Strong = Value > 1,
                    })
                    Global = require(game.ReplicatedStorage.Global)
                    Global.lastCyborgJump = tick()
                    Global_2 = require(game.ReplicatedStorage.Global)
                    Global_2.mobilityCooldown = tick()
                end
                HumanoidRootPart.Velocity = Vector3.new(HumanoidRootPart.Velocity.X, Humanoid.JumpPower * 1.4, HumanoidRootPart.Velocity.Z)
                if v3 then
                    v6 = Humanoid
                    v6.JumpPower = v6.JumpPower - v2 * 125
                end
                return
            end
            return
        end
        return
    end
end

UserInputService.InputBegan:Connect(function(a1, a2) -- Line: 133 -- upvalues: UserInputService (val), jumped (val)
    if a2 and not UserInputService.GamepadEnabled then
        return
    end
    if a1.KeyCode == Enum.KeyCode.Space or a1.KeyCode == Enum.KeyCode.ButtonA then
        jumped()
    end
end)
wait(1)
wait(0.5)
if UserInputService.TouchEnabled then
    local TouchGui = PlayerGui:WaitForChild("TouchGui", 10)
    if TouchGui then
        (TouchGui:WaitForChild("TouchControlFrame")):WaitForChild("JumpButton").MouseButton1Down:connect(jumped)
    end
end