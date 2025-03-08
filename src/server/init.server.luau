local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load the simulation manager
local SimulationManager = require(script.Parent.SimulationManager)

-- Create remote events for client-server communication
local remotes = Instance.new("Folder")
remotes.Name = "GeneticAlgorithmRemotes"
remotes.Parent = ReplicatedStorage

local remoteEvents = {
    startSimulation = Instance.new("RemoteEvent"),
    stopSimulation = Instance.new("RemoteEvent"),
    updateConfig = Instance.new("RemoteEvent"),
    getStatus = Instance.new("RemoteFunction"),
    generationCompleted = Instance.new("RemoteEvent"),
    simulationCompleted = Instance.new("RemoteEvent"),
    dummyUpdated = Instance.new("RemoteEvent")
}

-- Set up remote events
for name, event in pairs(remoteEvents) do
    event.Name = name
    event.Parent = remotes
end

-- Wait for the game to fully load
game.Loaded:Wait()

-- Check if required objects exist in the workspace
local function setupWorkspace()
    -- Create platforms folder if it doesn't exist
    if not workspace:FindFirstChild("Platforms") then
        local platforms = Instance.new("Folder")
        platforms.Name = "Platforms"
        platforms.Parent = workspace
        
        -- Create a simple platform
        local platform = Instance.new("Part")
        platform.Name = "Platform1"
        platform.Size = Vector3.new(20, 1, 20)
        platform.Position = Vector3.new(0, 0, 0)
        platform.Anchored = true
        platform.Parent = platforms
    end
    
    -- Create start position if it doesn't exist
    if not workspace:FindFirstChild("Start") then
        local start = Instance.new("Part")
        start.Name = "Start"
        start.Size = Vector3.new(4, 1, 4)
        start.Position = Vector3.new(-8, 1, -8)
        start.Anchored = true
        start.CanCollide = false
        start.Transparency = 0.5
        start.Color = Color3.fromRGB(0, 255, 0)
        start.Parent = workspace
    end
    
    -- Create goal position if it doesn't exist
    if not workspace:FindFirstChild("Goal") then
        local goal = Instance.new("Part")
        goal.Name = "Goal"
        goal.Size = Vector3.new(4, 1, 4)
        goal.Position = Vector3.new(8, 1, 8)
        goal.Anchored = true
        goal.CanCollide = false
        goal.Transparency = 0.5
        goal.Color = Color3.fromRGB(255, 0, 0)
        goal.Parent = workspace
    end
    
    -- Create dummy template if it doesn't exist
    if not ServerStorage:FindFirstChild("Dummy") then
        -- Create a simple dummy template
        local dummy = Instance.new("Model")
        dummy.Name = "Dummy"
        
        local humanoid = Instance.new("Humanoid")
        humanoid.Parent = dummy
        
        local torso = Instance.new("Part")
        torso.Name = "HumanoidRootPart"
        torso.Size = Vector3.new(2, 2, 1)
        torso.Position = Vector3.new(0, 3, 0)
        torso.Parent = dummy
        
        humanoid.RootPart = torso
        
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(1, 1, 1)
        head.Position = Vector3.new(0, 4.5, 0)
        head.Parent = dummy
        
        -- Create a weld to connect the head to the torso
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torso
        weld.Part1 = head
        weld.Parent = torso
        
        dummy.Parent = ServerStorage
    end
end

-- Set up the workspace with required objects
setupWorkspace()

-- Create a simulation manager instance
local simulationManager = SimulationManager.new()
simulationManager:initialize(
    workspace.Platforms,
    ServerStorage.Dummy,
    workspace.Start,
    workspace.Goal
)

-- Connect simulation events to remote events
simulationManager.events.generationCompleted.Event:Connect(function(generation, bestScore, bestGenes)
    remoteEvents.generationCompleted:FireAllClients(generation, bestScore, bestGenes)
end)

simulationManager.events.simulationCompleted.Event:Connect(function(bestScore)
    remoteEvents.simulationCompleted:FireAllClients(bestScore)
end)

simulationManager.events.dummyUpdated.Event:Connect(function(dummy, weights)
    -- We don't want to fire this for every dummy to every client as it would be too much data
    -- Instead, we'll let clients request updates for specific dummies they're interested in
end)

-- Handle remote events
remoteEvents.startSimulation.OnServerEvent:Connect(function(player)
    local success, errorMsg = simulationManager:runSimulation()
    if not success then
        warn(errorMsg)
    end
end)

remoteEvents.stopSimulation.OnServerEvent:Connect(function(player)
    local success, errorMsg = simulationManager:stopSimulation()
    if not success then
        warn(errorMsg)
    end
end)

remoteEvents.updateConfig.OnServerEvent:Connect(function(player, newConfig)
    local success, errorMsg = simulationManager:updateConfig(newConfig)
    if not success then
        warn(errorMsg)
    end
end)

remoteEvents.getStatus.OnServerInvoke = function()
    return simulationManager:getStatus()
end

print("Genetic Algorithm Server initialized!")