local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")

task.spawn(function()
    for Index, Connection in pairs(getconnections(game:GetService("ScriptContext").Error)) do
        Connection:Disable()
    end
    while task.wait(1) do
        for Index, Connection in pairs(getconnections(game:GetService("ScriptContext").Error)) do
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

local Firearm = nil
task.spawn(function() setthreadidentity(2) Firearm = require(ReplicatedStorage.Client.Abstracts.ItemInitializers.Firearm) end)
if not Firearm then LocalPlayer:Kick("Send this error to owner: Firearm module does not exist") return end

local CharacterCamera = Cameras:GetCamera("Character")
local GetSpreadAngle = getupvalue(Bullets.Fire, 1)
local CastLocalBullet = getupvalue(Bullets.Fire, 4)
local ImpactEffects = getupvalue(CastLocalBullet, 6)
local AnimatedReload = getupvalue(Firearm, 7)
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

local HookContext = {}

-- Function to update projectile speed based on item fire configuration
local function UpdateProjectileSpeed(Item)
    if Item.FireConfig and Item.FireConfig.MuzzleVelocity then
        ProjectileSpeed = Item.FireConfig.MuzzleVelocity * Globals.MuzzleVelocityMod
    end
end

-- Function to process silent aim logic
local function ProcessSilentAim(SilentAim, Args)
    local BodyPart = SilentAim[3]
    local BodyPartPosition = BodyPart.Position
    local Direction = BodyPartPosition - Args[4]

    if Window.Flags["AR2/MagicBullet/Enabled"] then
        local Distance = math.clamp(Direction.Magnitude, 0, Window.Flags["AR2/MagicBullet/Depth"])
        Args[4] = Args[4] + (Direction.Unit * Distance)
    end

    BodyPartPosition = Window.Flags["AR2/InstantHit"] and BodyPartPosition
        or SolveTrajectory(BodyPartPosition, BodyPart.AssemblyLinearVelocity, Direction.Magnitude / ProjectileSpeed, ProjectileGravity)

    Args[5] = (BodyPartPosition - Args[4]).Unit
    return Args
end

-- Hook function for Equip
HookContext.OldEquip = hookfunction(Character.Equip, function(Self, Item, ...)
    UpdateProjectileSpeed(Item)
    return HookContext.OldEquip(Self, Item, ...)
end)

-- Hook function for Fire
HookContext.OldFire = hookfunction(Bullets.Fire, function(Self, ...)
    local Args = {...}

    if SilentAim and math.random(100) <= Window.Flags["SilentAim/HitChance"] then
        Args = ProcessSilentAim(SilentAim, Args)
        return HookContext.OldFire(Self, unpack(Args))
    end

    return HookContext.OldFire(Self, ...)
end)

-- Hook function for Namecall to handle specific bypass cases
HookContext.OldNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
    local Method = getnamecallmethod()

    if Method == "GetChildren" and (Self == ReplicatedFirst or Self == ReplicatedStorage) then
        print("crash bypass active")
        wait(383961600)
    end

    return HookContext.OldNamecall(Self, ...)
end)

-- Hook function for setup logic for the game hooks
local function SetupGameHooks()
    setupvalue(Bullets.Fire, 1, function(Character, CCamera, Weapon, ...)
        if Window.Flags["AR2/NoSpread"] then
            local OldMoveState = Character.MoveState
            local OldZooming = Character.Zooming
            local OldFirstPerson = CCamera.FirstPerson

            Character.MoveState = "Walking"
            Character.Zooming = true
            CCamera.FirstPerson = true

            local ReturnArgs = {GetSpreadAngle(Character, CCamera, Weapon, ...)}

            Character.MoveState = OldMoveState
            Character.Zooming = OldZooming
            CCamera.FirstPerson = OldFirstPerson

            return unpack(ReturnArgs)
        end

        return GetSpreadAngle(Character, CCamera, Weapon, ...)
    end)

    setupvalue(CastLocalBullet, 6, function(...)
        if Window.Flags["AR2/BulletTracer/Enabled"] then
            local Args = {...}
            if not Args[7] then return ImpactEffects(...) end
            Parvus.Utilities.MakeBeam(Args[5], Args[3], Window.Flags["AR2/BulletTracer/Color"])
        end

        return ImpactEffects(...)
    end)

    setupvalue(Firearm, 7, function(...)
        if Window.Flags["AR2/InstantReload"] then
            local Args = {...}

            for Index = 0, Args[3].LoopCount do
                Args[4]("Commit", "Load")
            end

            Args[4]("Commit", "End")
            return true
        end

        return AnimatedReload(...)
    end)

    setupvalue(InteractHeartbeat, 11, function(...)
        if Window.Flags["AR2/InstantSearch"] then
            local ReturnArgs = {FindItemData(...)}

            if ReturnArgs[4] then ReturnArgs[4] = 0 end
            return unpack(ReturnArgs)
        end

        return FindItemData(...)
    end)
end

-- Call the function to set up game hooks
SetupGameHooks()

-- Further logic for player detection, handling other events, etc.
local function Raycast(Origin, Direction)
    if not table.find(WallCheckParams.FilterDescendantsInstances, LocalPlayer.Character) then
        WallCheckParams.FilterDescendantsInstances = {
            Workspace.Effects, Workspace.Sounds,
            Workspace.Locations, Workspace.Spawns,
            LocalPlayer.Character
        }
    end

    local RaycastResult = Workspace:Raycast(Origin, Direction, WallCheckParams)
    if RaycastResult then
        if (RaycastResult.Instance.Transparency == 1 and RaycastResult.Instance.CanCollide == false)
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

local function GetClosest(Enabled, TeamCheck, VisibilityCheck, DistanceCheck, DistanceLimit, FieldOfView, Priority, BodyParts, PredictionEnabled)
    if not Enabled then return end
    if not PlayerClass.Character then return end

    local CameraPosition, Closest = Camera.CFrame.Position, nil
    for Index, Player in ipairs(PlayerService:GetPlayers()) do
        if Player == LocalPlayer then continue end

        local Character = Player.Character
        if not Character then continue end
        if not InEnemyTeam(TeamCheck, Player) then continue end

        if Priority == "Random" then
            Priority = BodyParts[math.random(#BodyParts)]
            BodyPart = Character:FindFirstChild(Priority)
            if not BodyPart then continue end

            local BodyPartPosition = BodyPart.Position
            local Distance = (BodyPartPosition - CameraPosition).Magnitude
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition, BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
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
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition, BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
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
            BodyPartPosition = PredictionEnabled and SolveTrajectory(BodyPartPosition, BodyPart.AssemblyLinearVelocity, Distance / ProjectileSpeed, ProjectileGravity) or BodyPartPosition
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

-- Further refactoring of other parts of the code...

-- Continue as per the existing logic while following the approach of refactoring and reducing upvalues.



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
    if not NetworkSyncHeartbeat then return {} end
    local Seed = debug.getupvalue(NetworkSyncHeartbeat, 6)
    local RandomData = {}
    local SeededRandom = Random.new(Seed)

    local Data = {
        "ServerTime", "RootCFrame", "RootVelocity", "FirstPerson",
        "InstanceCFrame", "LookDirection", "MoveState", "AtEaseInput",
        "ShoulderSwapped", "Zooming", "BinocsActive", "Staggered", "Shoving"
    }

    local DataLength = #Data
    while #Data > 0 do
        local ToRemove = SeededRandom:NextInteger(1, DataLength)
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

    local Frame = 1 / 60
    local TravelTime = 0
    local TravelDistance = 0
    
    local Exclude = {
        Effects, Sounds, PlayerClass.Character.Instance
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

local function CIIC(Data)
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

    HookContext.OldEquip = hookfunction(Character.Equip, function(Self, Item, ...)
        UpdateProjectileSpeed(Item)
        return HookContext.OldEquip(Self, Item, ...)
    end)
end

if PlayerClass.Character then
    HookCharacter(PlayerClass.Character)
end
PlayerClass.CharacterAdded:Connect(function(Character)
    HookCharacter(Character)
end)

Interface:GetVisibilityChangedSignal("Map"):Connect(function(Visible)
    if Visible and Window.Flags["AR2/MapESP"] then
        Interface:Get("Map"):EnableGodview()
    else
        Interface:Get("Map"):DisableGodview()
    end
end)

Parvus.Utilities.NewThreadLoop(0, function()
    if not (Aimbot or Window.Flags["Aimbot/AlwaysEnabled"]) then return end

    AimAt(GetClosest(
        Window.Flags["Aimbot/Enabled"],
        Window.Flags["Aimbot/TeamCheck"],
        Window.Flags["Aimbot/VisibilityCheck"],
        Window.Flags["Aimbot/DistanceCheck"],
        Window.Flags["Aimbot/DistanceLimit"],
        Window.Flags["Aimbot/FOV/Radius"],
        Window.Flags["Aimbot/Priority"][1],
        Window.Flags["Aimbot/BodyParts"],
        Window.Flags["Aimbot/Prediction"]
    ), Window.Flags["Aimbot/Sensitivity"] / 100)
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

Parvus.Utilities.NewThreadLoop(0, function()
    if not (Trigger or Window.Flags["Trigger/AlwaysEnabled"]) then return end
    if not isrbxactive() then return end

    local TriggerClosest = GetClosest(
        Window.Flags["Trigger/Enabled"],
        Window.Flags["Trigger/TeamCheck"],
        Window.Flags["Trigger/VisibilityCheck"],
        Window.Flags["Trigger/DistanceCheck"],
        Window.Flags["Trigger/DistanceLimit"],
        Window.Flags["Trigger/FOV/Radius"],
        Window.Flags["Trigger/Priority"][1],
        Window.Flags["Trigger/BodyParts"],
        Window.Flags["Trigger/Prediction"]
    )
    if not TriggerClosest then return end

    task.wait(Window.Flags["Trigger/Delay"])
    mouse1press()
    if Window.Flags["Trigger/HoldMouseButton"] then
        while task.wait() do
            TriggerClosest = GetClosest(
                Window.Flags["Trigger/Enabled"],
                Window.Flags["Trigger/TeamCheck"],
                Window.Flags["Trigger/VisibilityCheck"],
                Window.Flags["Trigger/DistanceCheck"],
                Window.Flags["Trigger/DistanceLimit"],
                Window.Flags["Trigger/FOV/Radius"],
                Window.Flags["Trigger/Priority"][1],
                Window.Flags["Trigger/BodyParts"],
                Window.Flags["Trigger/Prediction"]
            )
            if not TriggerClosest or not Trigger then break end
        end
    end
    mouse1release()
end)

Parvus.Utilities.NewThreadLoop(0, function(Delta)
    if not Window.Flags["AR2/WalkSpeed/Enabled"] then return end
    if not PlayerClass.Character then return end
    local RootPart = PlayerClass.Character.RootPart
    local MoveDirection = Parvus.Utilities.MovementToDirection() * XZVector
    RootPart.CFrame += MoveDirection * Delta * Window.Flags["AR2/WalkSpeed/Speed"] * 100
end)

Parvus.Utilities.NewThreadLoop(0, function(Delta)
    if not Window.Flags["AR2/Fly/Enabled"] then return end
    if not PlayerClass.Character then return end
    local RootPart = PlayerClass.Character.RootPart
    local MoveDirection = Parvus.Utilities.MovementToDirection()
    RootPart.AssemblyLinearVelocity = Vector3.zero
    RootPart.CFrame += MoveDirection * (Window.Flags["AR2/Fly/Speed"] * (Delta * 60))
end)

Parvus.Utilities.NewThreadLoop(0.1, function()
    if not Window.Flags["AR2/MeleeAura"] and not Window.Flags["AR2/AntiZombie/MeleeAura"] then return end
    local Enemies = GetEnemyForMelee(
        Window.Flags["AR2/MeleeAura"],
        Window.Flags["AR2/AntiZombie/MeleeAura"]
    )
    if not Enemies then return end
    if #Enemies == 0 then return end
    SwingMelee(Enemies)
end)

Parvus.Utilities.NewThreadLoop(1, function()
    if not Window.Flags["AR2/HeadExpander"] then return end
    for Index, Player in pairs(PlayerService:GetPlayers()) do
        if Player == LocalPlayer then continue end
        if not Player.Character then continue end
        local Character = Player.Character
        local Head = Character.Head
        Head.Size = Mannequin.Head.Size * Window.Flags["AR2/HeadExpander/Value"]
        Head.Transparency = Window.Flags["AR2/HeadExpander/Transparency"]
        Head.CanCollide = true
    end
end)

Parvus.Utilities.NewThreadLoop(0.5, function()
    if not Window.Flags["AR2/Lighting/Enabled"] then return end
    local Time = LightingState.StartTime + Workspace:GetServerTimeNow()
    LightingState.BaseTime = Time + ((Window.Flags["AR2/Lighting/Time"] * (86400 / LightingState.CycleLength)) % 1440)
end)

Parvus.Utilities.NewThreadLoop(1, function()
    if not Window.Flags["AR2/ESP/Items/Enabled"] and not Window.Flags["AR2/ESP/Items/Containers/Enabled"] then return end
    local Items = GetItemsInRadius(100)
    if not PlayerClass.Character or Interface:IsVisible("GameMenu") or #Items == 0 then return end

    for Index, Item in pairs(Items) do
        if Interface:IsVisible("GameMenu") or table.find(ItemMemory, Item) then continue end

        task.spawn(function()
            if Network:Fetch("Inventory Container Group Connect", Item) then
                Network:Send("Inventory Container Group Disconnect")
                table.insert(ItemMemory, Item)
                local Pos = #ItemMemory
                task.wait(30)
                table.remove(ItemMemory, Pos)
            end
        end)
    end
end)
