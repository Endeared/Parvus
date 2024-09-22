local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")

task.spawn(function()
    for Index, Connection in pairs(getconnections(game:GetService("ScriptContext").Error)) do
        --print("found ScriptContext error detection, removing")
        Connection:Disable()
    end
    while task.wait(1) do
        for Index, Connection in pairs(getconnections(game:GetService("ScriptContext").Error)) do
            --print("found ScriptContext error detection, removing")
            Connection:Disable()
        end
    end
end)

local Camera = Workspace.CurrentCamera
local LocalPlayer = PlayerService.LocalPlayer
local Aimbot, SilentAim, Trigger = false, nil, nil

local Mannequin = ReplicatedStorage.Assets.Mannequin
local LootBins = Workspace.Map.Shared.LootBins
local Randoms = Workspace.Map.Shared.Randoms
local Vehicles = Workspace.Vehicles.Spawned
local Characters = Workspace.Characters
local Corpses = Workspace.Corpses
local Zombies = Workspace.Zombies
local Loot = Workspace.Loot

local Framework = require(ReplicatedFirst:WaitForChild("Framework"))
Framework:WaitForLoaded()

repeat task.wait() until Framework.Classes.Players.get()
local PlayerClass = Framework.Classes.Players.get()

local Globals = Framework.Configs.Globals
local World = Framework.Libraries.World
local Network = Framework.Libraries.Network
local Cameras = Framework.Libraries.Cameras
local Bullets = Framework.Libraries.Bullets
local Lighting = Framework.Libraries.Lighting
local Interface = Framework.Libraries.Interface
local Resources = Framework.Libraries.Resources
local Raycasting = Framework.Libraries.Raycasting

local Maids = Framework.Classes.Maids
local Animators = Framework.Classes.Animators
local VehicleController = Framework.Classes.VehicleControler

local Events = getupvalue(Network.Add, 1)
local GetSpreadAngle = getupvalue(Bullets.Fire, 1)
local GetSpreadVector = getupvalue(Bullets.Fire, 3)
local CastLocalBullet = getupvalue(Bullets.Fire, 4)
local GetFireImpulse = getupvalue(Bullets.Fire, 6)
local LightingState = getupvalue(Lighting.GetState, 1)
local AnimatedReload = getupvalue(Firearm, 7)

local SetWheelSpeeds = getupvalue(VehicleController.Step, 2)
local SetSteerWheels = getupvalue(VehicleController.Step, 3)

local Effects = getupvalue(CastLocalBullet, 2)
local Sounds = getupvalue(CastLocalBullet, 3)
local ImpactEffects = getupvalue(CastLocalBullet, 6)

if type(Events) == "function" then
    Events = getupvalue(Network.Add, 2)
end

local NetworkSyncHeartbeat
local InteractHeartbeat, FindItemData
for Index, Table in pairs(getgc(true)) do
    if type(Table) == "table" and rawget(Table, "Rate") == 0.05 then
        InteractHeartbeat = Table.Action
        FindItemData = getupvalue(InteractHeartbeat, 11)
    end
end

local ProjectileSpeed = 1000
local ProjectileOrigin = Vector3.new(0, 0, 0)
local ProjectileDirection = Vector3.new(0, 0, 0)
local ProjectileSpread = Vector3.new(0, 0, 0)
local ShotMaxDistance = Globals.ShotMaxDistance
local ProjectileGravity = Globals.ProjectileGravity

local SquadData = nil
local ItemMemory = {}
local GroundPart = Instance.new("Part")
local OldBaseTime = LightingState.BaseTime
local NoClipObjects, NoClipEvent = {}, nil
local SetIdentity = setthreadidentity

local AddObject = Instance.new("BindableEvent")
AddObject.Event:Connect(function(...)
    Parvus.Utilities.Drawing:AddObject(...)
end)

local RemoveObject = Instance.new("BindableEvent")
RemoveObject.Event:Connect(function(...)
    Parvus.Utilities.Drawing:RemoveObject(...)
end)

local SanityBans = {
    "Chat Message Send", "Ping Return", "Bullet Impact Interaction", "Crouch Audio Mute", "Zombie Pushback Force Request", "Camera CFrame Report",
    "Movestate Sync Request", "Update Character Position", "Map Icon History Sync", "Playerlist Staff Icon Get", "Request Physics State Sync",
    "Inventory Sync Request", "Wardrobe Resync Request", "Door Interact ", "Sorry Mate, Wrong Path :/"
}

local KnownBodyParts = {
    {"Head", true},
    {"UpperTorso", true}
}

local Window = Parvus.Utilities.UI:Window({
    Name = ("Parvus Hub %s %s"):format(utf8.char(8212), Parvus.Game.Name),
    Position = UDim2.new(0.5, -248 * 3, 0.5, -248)
}) do

    local CombatTab = Window:Tab({Name = "Combat"}) do
        local SilentAimSection = CombatTab:Section({Name = "Silent Aim", Side = "Right"}) do
            SilentAimSection:Toggle({Name = "Enabled", Flag = "SilentAim/Enabled", Value = false}):Keybind({Mouse = true, Flag = "SilentAim/Keybind"})

            --SilentAimSection:Toggle({Name = "Prediction", Flag = "SilentAim/Prediction", Value = true})

            SilentAimSection:Toggle({Name = "Team Check", Flag = "SilentAim/TeamCheck", Value = false})
            SilentAimSection:Toggle({Name = "Distance Check", Flag = "SilentAim/DistanceCheck", Value = false})
            SilentAimSection:Toggle({Name = "Visibility Check", Flag = "SilentAim/VisibilityCheck", Value = false})
            SilentAimSection:Slider({Name = "Hit Chance", Flag = "SilentAim/HitChance", Min = 0, Max = 100, Value = 100, Unit = "%"})
            SilentAimSection:Slider({Name = "Field Of View", Flag = "SilentAim/FOV/Radius", Min = 0, Max = 500, Value = 100, Unit = "r"})
            SilentAimSection:Slider({Name = "Distance Limit", Flag = "SilentAim/DistanceLimit", Min = 25, Max = 10000, Value = 250, Unit = "studs"})

            local PriorityList, BodyPartsList = {{Name = "Closest", Mode = "Button", Value = true}, {Name = "Random", Mode = "Button"}}, {}
            for Index, Value in pairs(KnownBodyParts) do
                PriorityList[#PriorityList + 1] = {Name = Value[1], Mode = "Button", Value = false}
                BodyPartsList[#BodyPartsList + 1] = {Name = Value[1], Mode = "Toggle", Value = Value[2]}
            end

            SilentAimSection:Dropdown({Name = "Priority", Flag = "SilentAim/Priority", List = PriorityList})
            SilentAimSection:Dropdown({Name = "Body Parts", Flag = "SilentAim/BodyParts", List = BodyPartsList})
        end
        local SAFOVSection = CombatTab:Section({Name = "Silent Aim FOV Circle", Side = "Right"}) do
            SAFOVSection:Toggle({Name = "Enabled", Flag = "SilentAim/FOV/Enabled", Value = true})
            SAFOVSection:Toggle({Name = "Filled", Flag = "SilentAim/FOV/Filled", Value = false})
            SAFOVSection:Colorpicker({Name = "Color", Flag = "SilentAim/FOV/Color",
            Value = {0.6666666865348816, 0.6666666269302368, 1, 0.25, false}})
            SAFOVSection:Slider({Name = "NumSides", Flag = "SilentAim/FOV/NumSides", Min = 3, Max = 100, Value = 14})
            SAFOVSection:Slider({Name = "Thickness", Flag = "SilentAim/FOV/Thickness", Min = 1, Max = 10, Value = 2})
        end
    end
    local VisualsSection = Parvus.Utilities:ESPSection(Window, "Visuals", "ESP/Player", true, true, true, true, true, false) do
        VisualsSection:Colorpicker({Name = "Ally Color", Flag = "ESP/Player/Ally", Value = {0.3333333432674408, 0.6666666269302368, 1, 0, false}})
        VisualsSection:Colorpicker({Name = "Enemy Color", Flag = "ESP/Player/Enemy", Value = {1, 0.6666666269302368, 1, 0, false}})
        VisualsSection:Toggle({Name = "Team Check", Flag = "ESP/Player/TeamCheck", Value = false})
        VisualsSection:Toggle({Name = "Use Team Color", Flag = "ESP/Player/TeamColor", Value = false})
        VisualsSection:Toggle({Name = "Distance Check", Flag = "ESP/Player/DistanceCheck", Value = true})
        VisualsSection:Slider({Name = "Distance", Flag = "ESP/Player/Distance", Min = 25, Max = 10000, Value = 1000, Unit = "studs"})
    end
    local MiscTab = Window:Tab({Name = "Miscellaneous"}) do local LModes = {}
    end Parvus.Utilities:SettingsSection(Window, "RightControl", true)
end Parvus.Utilities.InitAutoLoad(Window)

Parvus.Utilities:SetupWatermark(Window)
Parvus.Utilities:SetupLighting(Window.Flags)
Parvus.Utilities.Drawing.SetupCursor(Window)
Parvus.Utilities.Drawing.SetupCrosshair(Window.Flags)
Parvus.Utilities.Drawing.SetupFOV("Aimbot", Window.Flags)
Parvus.Utilities.Drawing.SetupFOV("Trigger", Window.Flags)
Parvus.Utilities.Drawing.SetupFOV("SilentAim", Window.Flags)

local XZVector = Vector3.new(1, 0, 1)
local WallCheckParams = RaycastParams.new()
WallCheckParams.FilterType = Enum.RaycastFilterType.Blacklist
WallCheckParams.FilterDescendantsInstances = {
    Workspace.Effects, Workspace.Sounds,
    Workspace.Locations, Workspace.Spawns
} WallCheckParams.IgnoreWater = true

local function Raycast(Origin, Direction)
    if not table.find(WallCheckParams.FilterDescendantsInstances, LocalPlayer.Character) then
        WallCheckParams.FilterDescendantsInstances = {
            Workspace.Effects, Workspace.Sounds,
            Workspace.Locations, Workspace.Spawns,
            LocalPlayer.Character
        } --print("added character to raycast")
    end

    local RaycastResult = Workspace:Raycast(Origin, Direction, WallCheckParams)
    if RaycastResult then
        if (RaycastResult.Instance.Transparency == 1
        and RaycastResult.Instance.CanCollide == false)
        or (CollectionService:HasTag(RaycastResult.Instance, "Bullets Penetrate")
        or CollectionService:HasTag(RaycastResult.Instance, "Window Part")
        or CollectionService:HasTag(RaycastResult.Instance, "World Mesh")
        or CollectionService:HasTag(RaycastResult.Instance, "World Water Part")) then
            return true
        end
    end
end
local function InEnemyTeam(Enabled, Player)
    if not Enabled then return true end
    if SquadData and SquadData.Members then
        if table.find(SquadData.Members, Player.Name) then
            return false
        end
    end

    return true
end
local function WithinReach(Enabled, Distance, Limit)
    if not Enabled then return true end
    return Distance < Limit
end
local function ObjectOccluded(Enabled, Origin, Position, Object)
    if not Enabled then return false end
    return Raycast(Origin, Position - Origin, {Object, LocalPlayer.Character})
end
local function SolveTrajectory(Origin, Velocity, Time, Gravity)
    Gravity = Vector3.new(0, math.abs(Gravity), 0)
    return Origin + (Velocity * Time) + (Gravity * Time * Time)
end

local function GetClosest(Enabled,
    TeamCheck, VisibilityCheck, DistanceCheck,
    DistanceLimit, FieldOfView, Priority, BodyParts,
    PredictionEnabled
)

    if not Enabled then return end
    if not PlayerClass.Character then return end


    local CameraPosition, Closest = Camera.CFrame.Position, nil
    for Index, Player in ipairs(PlayerService:GetPlayers()) do
        if Player == LocalPlayer then continue end

        local Character = Player.Character if not Character then continue end
        if not InEnemyTeam(TeamCheck, Player) then continue end

        if Priority == "Random" then
            Priority = BodyParts[math.random(#BodyParts)]
            BodyPart = Character:FindFirstChild(Priority)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition,
            BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
            local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(BodyPartPosition)
            ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            if not OnScreen then continue end

            Distance = (BodyPartPosition - CameraPosition).Magnitude
            if not WithinReach(DistanceCheck, Distance, DistanceLimit) then continue end
            if ObjectOccluded(VisibilityCheck, CameraPosition, BodyPartPosition, Character) then continue end

            local Magnitude = (ScreenPosition - UserInputService:GetMouseLocation()).Magnitude
            if Magnitude >= FieldOfView then continue end

            return {Player, Character, BodyPart, ScreenPosition}
        elseif Priority ~= "Closest" then
            BodyPart = Character:FindFirstChild(Priority)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition,
            BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
            local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(BodyPartPosition)
            ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            if not OnScreen then continue end

            Distance = (BodyPartPosition - CameraPosition).Magnitude
            if not WithinReach(DistanceCheck, Distance, DistanceLimit) then continue end
            if ObjectOccluded(VisibilityCheck, CameraPosition, BodyPartPosition, Character) then continue end

            local Magnitude = (ScreenPosition - UserInputService:GetMouseLocation()).Magnitude
            if Magnitude >= FieldOfView then continue end

            return {Player, Character, BodyPart, ScreenPosition}
        end

        for Index, BodyPart in ipairs(BodyParts) do
            BodyPart = Character:FindFirstChild(BodyPart)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition,
            BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
            local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(BodyPartPosition)
            ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
            if not OnScreen then continue end

            Distance = (BodyPartPosition - CameraPosition).Magnitude
            if not WithinReach(DistanceCheck, Distance, DistanceLimit) then continue end
            if ObjectOccluded(VisibilityCheck, CameraPosition, BodyPartPosition, Character) then continue end

            local Magnitude = (ScreenPosition - UserInputService:GetMouseLocation()).Magnitude
            if Magnitude >= FieldOfView then continue end

            FieldOfView, Closest = Magnitude, {Player, Character, BodyPart, ScreenPosition}
        end
    end

    return Closest
end
local function AimAt(Hitbox, Sensitivity)
    if not Hitbox then return end
    local MouseLocation = UserInputService:GetMouseLocation()

    mousemoverel(
        (Hitbox[4].X - MouseLocation.X) * Sensitivity,
        (Hitbox[4].Y - MouseLocation.Y) * Sensitivity
    )
end

local function CheckForAdmin(Player)
    if Window.Flags["AR2/StaffJoin"] then
        local Rank = Player:GetRankInGroup(15434910)
        if not Rank then return end

        local Role = AdminRoles[Rank]
        if not Role then return end

        local Message = ("Staff member has joined or is in your game\nName: %s\nUserId: %s\nRole: %s"):format(Player.Name, Player.UserId, Role)
        if Window.Flags["AR2/StaffJoin/List"][1] == "Kick" then
            LocalPlayer:Kick(Message)
        elseif Window.Flags["AR2/StaffJoin/List"][1] == "Server Hop" then
            LocalPlayer:Kick(Message)
            task.wait(5)
            Parvus.Utilities.ServerHop()
        elseif Window.Flags["AR2/StaffJoin/List"][1] == "Notify" then
            UI:Push({Title = Message, Duration = 20})
        end
    end
end
local function GetStates()
    if not NetworkSyncHeartbeat then print("no") return {} end
    --local Character = debug.getupvalue(NetworkSyncHeartbeat, 1)
    local Seed = debug.getupvalue(NetworkSyncHeartbeat, 6)
    --local Camera = debug.getupvalue(NetworkSyncHeartbeat, 7)

    local RandomData = {}
    local SeededRandom = Random.new(Seed)

    local Data = {
        "ServerTime", -- {"ServerTime", workspace:GetServerTimeNow()},
        "RootCFrame", -- {"RootCFrame", Self.RootPart.CFrame},
        "RootVelocity", -- {"RootVelocity", Self.RootPart.AssemblyLinearVelocity},
        "FirstPerson", -- {"FirstPerson", Character.FirstPerson},
        "InstanceCFrame", -- {"InstanceCFrame", Character.Instance.CFrame},
        "LookDirection", -- {"LookDirection", Self.LookDirectionSpring:GetGoal()},
        "MoveState", -- {"MoveState", Self.MoveState},
        "AtEaseInput", -- {"AtEaseInput", Self.AtEaseInput},
        "ShoulderSwapped", -- {"ShoulderSwapped", Self.ShoulderSwapped},
        "Zooming", -- {"Zooming", Self.Zooming},
        "BinocsActive", -- {"BinocsActive", Character.FirstPerson and not Self.BinocsAtEase},
        "Staggered", -- {"Staggered", Self.Staggered},
        "Shoving", -- {"Shoving", Self.Shoving}
    }

    local DataLength = #Data
    while #Data > 0 do
        local ToRemove = SeededRandom:NextInteger(1, DataLength)
        --print(#Data, ToRemove % #Data, ToRemove, ToRemove % #Data == 0)
        ToRemove = ToRemove % #Data == 0 and #Data or ToRemove % #Data
        local Removed = table.remove(Data, ToRemove)
        table.insert(RandomData, Removed)
    end

    return RandomData
end

local function CastLocalBulletInstant(Origin, Direction, SpreadDirection)
    local Velocity = Direction * ProjectileSpeed
    local SpreadVelocity = SpreadDirection * ProjectileSpeed

    local ProjectilePosition = Origin
    local ProjectileSpreadPosition = Origin

    local ProjectileRay = nil
    local ProjectileCastInstance = nil
    local ProjectileCastPosition = Vector3.zero

    local ProjectileSpreadRay = nil

    local Frame = 1 / 60
    local TravelTime = 0
    local TravelDistance = 0
    
    local Exclude = {
        Effects,
        Sounds,
        PlayerClass.Character.Instance
    }
    
    while true do
        TravelTime += Frame

        ProjectileRay = Ray.new(ProjectilePosition, Origin + Velocity * TravelTime + ProjectileGravity * Vector3.yAxis * TravelTime ^ 2 - ProjectilePosition)
        ProjectileSpreadRay = Ray.new(ProjectileSpreadPosition, Origin + SpreadVelocity * TravelTime + ProjectileGravity * Vector3.yAxis * TravelTime ^ 2 - ProjectileSpreadPosition)

        ProjectileCastInstance, ProjectileCastPosition = Raycasting:BulletCast(ProjectileRay, true, Exclude)
        ProjectileSpreadPosition = ProjectileSpreadRay.Origin + ProjectileSpreadRay.Direction

        TravelDistance = TravelDistance + (ProjectilePosition - ProjectileCastPosition).Magnitude
        ProjectilePosition = ProjectileCastPosition

        if ProjectileCastInstance or TravelDistance > ShotMaxDistance then
            break
        end
    end

    if ProjectileCastInstance then
        local Distance = (ProjectileSpreadPosition - ProjectileCastPosition).Magnitude
        local Unit = (ProjectileSpreadPosition - ProjectileSpreadRay.Origin).Unit

        ProjectileSpreadPosition = ProjectileSpreadPosition - Unit * Distance
        Parvus.Utilities.MakeBeam(ProjectileSpreadRay.Origin, ProjectileSpreadPosition, Window.Flags["AR2/BulletTracer/Color"])

        return ProjectileSpreadPosition, {
            ProjectileCastInstance.CFrame:PointToObjectSpace(ProjectileSpreadRay.Origin),
            ProjectileCastInstance.CFrame:VectorToObjectSpace(ProjectileSpreadRay.Direction),
            ProjectileCastInstance.CFrame:PointToObjectSpace(ProjectileSpreadPosition)
        }
    end
end
local function SwingMelee(Enemies)
    local Character = PlayerClass.Character
    if not Character then return end

    local EquippedItem = Character.EquippedItem
    if not EquippedItem then return end

    if EquippedItem.Type ~= "Melee" then return end
    local AttackConfig = EquippedItem.AttackConfig[1]

    local Time = Workspace:GetServerTimeNow()
    Network:Send("Melee Swing", Time, EquippedItem.Id, 1)
    local Stopped = Character.Animator:PlayAnimation(AttackConfig.Animation, 0.05, AttackConfig.PlaybackSpeedMod)
    local Track = Character.Animator:GetTrack(AttackConfig.Animation)

    if Track then
        local Maid = Maids.new()
        Maid:Give(Track:GetMarkerReachedSignal("Swing"):Connect(function(State)
            if State ~= "Begin" then return end
            for Index, Enemy in pairs(Enemies) do
                Network:Send("Melee Hit Register", EquippedItem.Id, Time, Enemy, "Flesh", false)
                if not AttackConfig.CanHitMultipleTargets then break end
            end
            Maid:Destroy()
            Maid = nil
        end))

        Stopped:Wait()
    end
end
local function GetEnemyForMelee(CountPlayers, CountZombies)
    local PlayerCharacter = PlayerClass.Character
    if not PlayerCharacter then return end

    local Distance, Closest = 10, {}

    if CountZombies then
        for Index, Zombie in pairs(Zombies.Mobs:GetChildren()) do
            local PrimaryPart = Zombie.PrimaryPart
            if not PrimaryPart then continue end

            local Magnitude = (PrimaryPart.Position - PlayerCharacter.RootPart.Position).Magnitude
            if Distance > Magnitude then Distance = Magnitude table.insert(Closest, PrimaryPart) end
        end
    end

    if CountPlayers then
        Distance = 10
        for Index, Character in pairs(Characters:GetChildren()) do
            local Player = PlayerService:GetPlayerFromCharacter(Character)

            if Player == LocalPlayer then continue end
            if not InEnemyTeam(true, Player) then continue end

            local PrimaryPart = Character.PrimaryPart
            if not PrimaryPart then continue end

            local Magnitude = (PrimaryPart.Position - PlayerCharacter.RootPart.Position).Magnitude
            if Distance > Magnitude then Distance = Magnitude table.insert(Closest, PrimaryPart) end
        end
    end

    return Closest
end
local function GetCharactersInRadius(Path, Distance)
    local PlayerCharacter = PlayerClass.Character
    if not PlayerCharacter then return end

    local Closest = {}
    for Index, Character in pairs(Path:GetChildren()) do
        if Character == PlayerCharacter.Instance then continue end
        local PrimaryPart = Character.PrimaryPart
        if not PrimaryPart then continue end

        local Magnitude = (PrimaryPart.Position - PlayerCharacter.RootPart.Position).Magnitude
        if Distance >= Magnitude then Distance = Magnitude table.insert(Closest, Character) end
    end

    return Closest
end
local function GetItemsInRadius(Distance)
    local Closest = {}

    for Index, Item in pairs(LootBins:GetChildren()) do
        for Index, Group in pairs(Item:GetChildren()) do
            local Part = Group:FindFirstChild("Part")
            if not Part then continue end

            local Magnitude = (Part.Position - Camera.CFrame.Position).Magnitude
            if Distance >= Magnitude then table.insert(Closest, Group) end
        end
    end

    return Closest
end

local function Length(Table) local Count = 0
    for Index, Value in pairs(Table) do Count += 1 end
    return Count
end
local function CIIC(Data) -- ConcatItemsInContainer
    local Duplicates, Items = {}, {Data.DisplayName}

    for Index, Value in pairs(Data.Occupants) do
        if Duplicates[Value.Name] then
            Duplicates[Value.Name] += 1
        else
            Duplicates[Value.Name] = 1
        end
    end

    for Item, Value in pairs(Duplicates) do
        Items[#Items + 1] = Value == 1 and "[" .. Item .. "]"
        or "[" .. Item .. "] x" .. Value
    end
    return table.concat(Items, "\n")
end

local function HookCharacter(Character)
    for Index, Item in pairs(PlayerClass.Character.Maid.Items) do
        if type(Item) == "table" and rawget(Item, "Action") then
            if table.find(debug.getconstants(Item.Action), "Network sync") then
                NetworkSyncHeartbeat = Item.Action
            end
        end
    end

    local OldEquip = Character.Equip
    Character.Equip = function(Self, Item, ...)
        if Item.FireConfig and Item.FireConfig.MuzzleVelocity then
            ProjectileSpeed = Item.FireConfig.MuzzleVelocity * Globals.MuzzleVelocityMod
        end

        return OldEquip(Self, Item, ...)
    end
    local OldJump = Character.Actions.Jump
    Character.Actions.Jump = function(Self, ...)
        local Args = {...}

        return OldJump(Self, ...)
    end

    local OldToolAction = Character.Actions.ToolAction
    Character.Actions.ToolAction = function(Self, ...)

        return OldToolAction(Self, ...)
    end
end

local OldIndex, OldNamecall = nil, nil
OldIndex = hookmetamethod(game, "__index", function(Self, Index)
    return OldIndex(Self, Index)
end)

OldNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
    local Method = getnamecallmethod()

    if Method == "FireServer" then
        local Args = {...}
        if type(Args[1]) == "table" then
            print("framework check")
            return
        end
    end

    if Method == "GetChildren"
    and (Self == ReplicatedFirst
    or Self == ReplicatedStorage) then
        print("crash bypass")
        wait(383961600) -- 4444 days
    end

    return OldNamecall(Self, ...)
end)

local OldSend = Network.Send
Network.Send = function(Self, Name, ...)
    return OldSend(Self, Name, ...)
end

local OldFetch = Network.Fetch
Network.Fetch = function(Self, Name, ...)
    if table.find(SanityBans, Name) then print("bypassed", Name) return end

    if Name == "Character State Report" then
        local RandomData = GetStates()
        local Args = {...}

        for Index = 1, #Args do
        --for Index, Value in pairs(Args) do
            --print(Index, RandomData[Index][1], Value)
            if Window.Flags["AR2/SSCS"] then
                if RandomData[Index] == "MoveState" then
                    Args[Index] = Window.Flags["AR2/MoveState"][1]
                end
            end
            if Window.Flags["AR2/NoSpread"] then
                if RandomData[Index] == "Zooming" then
                    Args[Index] = true
                elseif RandomData[Index] == "FirstPerson" then
                    Args[Index] = true
                end
            end
        end

        return OldFetch(Self, Name, unpack(Args))
    end

    return OldFetch(Self, Name, ...)
end

setupvalue(CastLocalBullet, 6, function(...)
    if Window.Flags["AR2/BulletTracer/Enabled"] then
        local Args = {...}
        if not Args[7] then return ImpactEffects(...) end
        Parvus.Utilities.MakeBeam(Args[5], Args[3], Window.Flags["AR2/BulletTracer/Color"])
    end

    return ImpactEffects(...)
end)

setupvalue(Bullets.Fire, 6, function(...)
    if Window.Flags["AR2/Recoil/Enabled"] then
        local ReturnArgs = {GetFireImpulse(...)}

        for Index = 1, #ReturnArgs do
            ReturnArgs[Index] *= (Window.Flags["AR2/Recoil/Value"] / 100)
        end

        return unpack(ReturnArgs)
    end

    return GetFireImpulse(...)
end)

local OldFire = Bullets.Fire
Bullets.Fire = function(Self, ...)
    if SilentAim and math.random(100) <= Window.Flags["SilentAim/HitChance"] then
        local Args = {...}
        local BodyPart = SilentAim[3]
        local BodyPartPosition = BodyPart.Position
        local Direction = BodyPartPosition - Args[4]

        if Window.Flags["AR2/MagicBullet/Enabled"] then
            local Distance = math.clamp(Direction.Magnitude, 0, Window.Flags["AR2/MagicBullet/Depth"])
            Args[4] = Args[4] + (Direction.Unit * Distance)
        end

        BodyPartPosition = Window.Flags["AR2/InstantHit"] and BodyPartPosition
        or SolveTrajectory(BodyPartPosition, BodyPart.AssemblyLinearVelocity,
        Direction.Magnitude / ProjectileSpeed, ProjectileGravity)

        --[[local BodyPartPosition2 = Window.Flags["AR2/InstantHit"] and BodyPartPosition
        or SolveTrajectory2(BodyPartPosition, BodyPart.AssemblyLinearVelocity,
        Direction.Magnitude / ProjectileSpeed, ProjectileGravity)]]

        --local BodyPartPosition = Window.Flags["AR2/InstantHit"] and SilentAim[3].Position
        --or Parvus.Utilities.Physics.SolveTrajectory(Args[4], SilentAim[3].Position,
        --SilentAim[3].AssemblyLinearVelocity, ProjectileSpeed, ProjectileGravity, 1)

        ProjectileDirection = (BodyPartPosition - Args[4]).Unit
        --ProjectileDirection2 = (BodyPartPosition2 - Args[4]).Unit
        Args[5] = ProjectileDirection --(BodyPartPosition - Args[4]).Unit

        return OldFire(Self, unpack(Args))
    end

    local Args = {...}
    ProjectileDirection = Args[5]
    --ProjectileDirection2 = Args[5]

    return OldFire(Self, ...)
end


local OldFlinch = CharacterCamera.Flinch
CharacterCamera.Flinch = function(Self, ...)
    if Window.Flags["AR2/NoFlinch"] then return end
    return OldFlinch(Self, ...)
end
local OldCharacterGroundCast = Raycasting.CharacterGroundCast
Raycasting.CharacterGroundCast = function(Self, Position, LengthDown, ...)
    if PlayerClass.Character and Position == PlayerClass.Character.RootPart.CFrame then
        if Window.Flags["AR2/UseInAir"] then
            return GroundPart, CFrame.new(), Vector3.new(0, 1, 0)
            --LengthDown = 1022
        end
    end
    return OldCharacterGroundCast(Self, Position, LengthDown, ...)
end

local OldPlayAnimation = Animators.PlayAnimation
Animators.PlayAnimation = function(Self, Path, ...)
    if Path == "Actions.Fall Impact" and Window.Flags["AR2/NoFallImpact"] then return end
    return OldPlayAnimation(Self, Path, ...)
end


local OldCD = Events["Character Dead"]
if OldCD then
    Events["Character Dead"] = function(...)
        if Window.Flags["AR2/FastRespawn"] then
            task.spawn(function() SetIdentity(2)
                PlayerClass:UnloadCharacter()
                Interface:Hide("Reticle")
                task.wait(0.5)
                PlayerClass:LoadCharacter()
            end)
        end

        return OldCD(...)
    end
end
local OldLSU = Events["Lighting State Update"]
Events["Lighting State Update"] = function(Data, ...)
    LightingState = Data
    OldBaseTime = LightingState.BaseTime
    --print("Lighting State Updated")
    return OldLSU(Data, ...)
end
local OldSquadUpdate = Events["Squad Update"]
Events["Squad Update"] = function(Data, ...)
    SquadData = Data
    --print(repr(SquadData))
    --print("Squad Updated")
    return OldSquadUpdate(Data, ...)
end

if PlayerClass.Character then
    HookCharacter(PlayerClass.Character)
end
PlayerClass.CharacterAdded:Connect(function(Character)
    HookCharacter(Character)
end)

Parvus.Utilities.NewThreadLoop(0, function()
    SilentAim = GetClosest(
        Window.Flags["SilentAim/Enabled"],
        Window.Flags["SilentAim/TeamCheck"],
        Window.Flags["SilentAim/VisibilityCheck"],
        Window.Flags["SilentAim/DistanceCheck"],
        Window.Flags["SilentAim/DistanceLimit"],
        Window.Flags["SilentAim/FOV/Radius"],
        Window.Flags["SilentAim/Priority"][1],
        Window.Flags["SilentAim/BodyParts"]
    )
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)
