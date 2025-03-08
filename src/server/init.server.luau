local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Starting Genetic Algorithm Server initialization...")

-- Load the simulation manager
local SimulationManager
local success, err = pcall(function()
    SimulationManager = require(script.SimulationManager)
end)

if not success then
    warn("Failed to load SimulationManager: " .. tostring(err))
    return
end

print("SimulationManager module loaded")

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

print("Remote events created")

-- Wait for the game to fully load
game.Loaded:Wait()

-- Check if required objects exist in the workspace
local function setupWorkspace()
    print("Setting up workspace...")
    
    -- Create platforms folder if it doesn't exist
    local platforms
    if not workspace:FindFirstChild("Platforms") then
        print("Creating Platforms folder")
        platforms = Instance.new("Folder")
        platforms.Name = "Platforms"
        platforms.Parent = workspace
        
        -- Create a simple platform (baseplate)
        local platform = Instance.new("Part")
        platform.Name = "Platform1"
        platform.Size = Vector3.new(100, 1, 100)
        platform.Position = Vector3.new(0, 0, 0)
        platform.Anchored = true
        platform.Material = Enum.Material.Grass
        platform.Color = Color3.fromRGB(106, 127, 63)
        platform.Parent = platforms
        print("Created baseplate platform")
    else
        platforms = workspace.Platforms
        print("Found existing Platforms folder")
    end
    
    -- Create start position if it doesn't exist
    if not workspace:FindFirstChild("Start") then
        print("Creating Start position")
        local start = Instance.new("Part")
        start.Name = "Start"
        start.Size = Vector3.new(8, 1, 8)
        start.Position = Vector3.new(-40, 0.5, -40) -- At the same level as baseplate
        start.Anchored = true
        start.CanCollide = true
        start.Material = Enum.Material.SmoothPlastic
        start.Transparency = 0.3
        start.Color = Color3.fromRGB(0, 255, 0)
        start.Parent = workspace
        print("Created Start position at " .. tostring(start.Position))
    else
        print("Found existing Start position at " .. tostring(workspace.Start.Position))
    end
    
    -- Create goal position if it doesn't exist
    if not workspace:FindFirstChild("Goal") then
        print("Creating Goal position")
        local goal = Instance.new("Part")
        goal.Name = "Goal"
        goal.Size = Vector3.new(8, 1, 8)
        goal.Position = Vector3.new(40, 0.5, 40) -- At the same level as baseplate
        goal.Anchored = true
        goal.CanCollide = true
        goal.Material = Enum.Material.SmoothPlastic
        goal.Transparency = 0.3
        goal.Color = Color3.fromRGB(255, 0, 0)
        goal.Parent = workspace
        print("Created Goal position at " .. tostring(goal.Position))
    else
        print("Found existing Goal position at " .. tostring(workspace.Goal.Position))
    end
    
    -- Create some obstacles between start and goal
    local obstacles
    if platforms:FindFirstChild("Obstacles") then
        obstacles = platforms.Obstacles
        print("Found existing Obstacles folder")
    else
        print("Creating Obstacles folder")
        obstacles = Instance.new("Folder")
        obstacles.Name = "Obstacles"
        obstacles.Parent = platforms
    end
    
    -- Create a few obstacles if they don't exist
    if #obstacles:GetChildren() == 0 then
        print("Creating obstacle blocks")
        local positions = {
            Vector3.new(0, 1, 0),
            Vector3.new(-20, 1, -20),
            Vector3.new(20, 1, 20),
            Vector3.new(-20, 1, 20),
            Vector3.new(20, 1, -20)
        }
        
        for i, pos in ipairs(positions) do
            local obstacle = Instance.new("Part")
            obstacle.Name = "Obstacle" .. i
            obstacle.Size = Vector3.new(10, 2, 10)
            obstacle.Position = pos
            obstacle.Anchored = true
            obstacle.Material = Enum.Material.Concrete
            obstacle.Color = Color3.fromRGB(120, 120, 120)
            obstacle.Parent = obstacles
            print("Created obstacle " .. i .. " at " .. tostring(pos))
        end
    else
        print("Found " .. #obstacles:GetChildren() .. " existing obstacles")
    end
    
    -- Create dummy template if it doesn't exist
    if not ServerStorage:FindFirstChild("Dummy") then
        print("Creating Dummy template")
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
        print("Created Dummy template in ServerStorage")
    else
        print("Found existing Dummy template in ServerStorage")
    end
    
    print("Workspace setup complete")
    return true
end

-- Set up the workspace with required objects
local workspaceSetupSuccess, workspaceSetupError = pcall(setupWorkspace)
if not workspaceSetupSuccess then
    warn("Failed to set up workspace: " .. tostring(workspaceSetupError))
    return
end

-- Create a simulation manager instance
print("Creating simulation manager")
local simulationManager
local managerSuccess, managerError = pcall(function()
    simulationManager = SimulationManager.new()
    
    -- Check if all required objects exist
    if not workspace:FindFirstChild("Platforms") then
        error("Platforms folder not found in workspace")
    end
    
    if not ServerStorage:FindFirstChild("Dummy") then
        error("Dummy template not found in ServerStorage")
    end
    
    if not workspace:FindFirstChild("Start") then
        error("Start position not found in workspace")
    end
    
    if not workspace:FindFirstChild("Goal") then
        error("Goal position not found in workspace")
    end
    
    simulationManager:initialize(
        workspace.Platforms,
        ServerStorage.Dummy,
        workspace.Start,
        workspace.Goal
    )
end)

if not managerSuccess then
    warn("Failed to create simulation manager: " .. tostring(managerError))
    return
end

-- Connect simulation events to remote events
simulationManager.events.generationCompleted.Event:Connect(function(generation, bestScore, bestGenes)
    print("Generation " .. generation .. " completed. Best score: " .. bestScore)
    remoteEvents.generationCompleted:FireAllClients(generation, bestScore, bestGenes)
end)

simulationManager.events.simulationCompleted.Event:Connect(function(bestScore)
    print("Simulation completed. Final best score: " .. bestScore)
    remoteEvents.simulationCompleted:FireAllClients(bestScore)
end)

simulationManager.events.dummyUpdated.Event:Connect(function(dummy, weights)
    -- We don't want to fire this for every dummy to every client as it would be too much data
    -- Instead, we'll let clients request updates for specific dummies they're interested in
end)

-- Handle remote events
remoteEvents.startSimulation.OnServerEvent:Connect(function(player)
    print("Start simulation requested by " .. player.Name)
    local success, errorMsg = pcall(function()
        return simulationManager:runSimulation()
    end)
    
    if not success then
        warn("Error starting simulation: " .. tostring(errorMsg))
    elseif errorMsg == false then
        warn("Simulation could not be started: " .. (simulationManager.lastError or "Unknown error"))
    else
        print("Simulation started successfully")
    end
end)

remoteEvents.stopSimulation.OnServerEvent:Connect(function(player)
    print("Stop simulation requested by " .. player.Name)
    local success, errorMsg = pcall(function()
        return simulationManager:stopSimulation()
    end)
    
    if not success then
        warn("Error stopping simulation: " .. tostring(errorMsg))
    elseif errorMsg == false then
        warn("Simulation could not be stopped: " .. (simulationManager.lastError or "Unknown error"))
    else
        print("Simulation stopped successfully")
    end
end)

remoteEvents.updateConfig.OnServerEvent:Connect(function(player, newConfig)
    print("Config update requested by " .. player.Name)
    local success, errorMsg = pcall(function()
        return simulationManager:updateConfig(newConfig)
    end)
    
    if not success then
        warn("Error updating config: " .. tostring(errorMsg))
    elseif errorMsg == false then
        warn("Config could not be updated: " .. (simulationManager.lastError or "Unknown error"))
    else
        print("Configuration updated successfully")
    end
end)

remoteEvents.getStatus.OnServerInvoke = function()
    local success, result = pcall(function()
        return simulationManager:getStatus()
    end)
    
    if not success then
        warn("Error getting status: " .. tostring(result))
        return {
            isRunning = false,
            currentGeneration = 0,
            totalGenerations = 0,
            bestScore = 0,
            numDummies = 0,
            error = tostring(result)
        }
    end
    
    return result
end

print("Genetic Algorithm Server initialized!")

-- Force a wait to ensure everything is loaded
task.wait(1)

-- Print a summary of the workspace setup
print("=== WORKSPACE SUMMARY ===")
print("Platforms: " .. (workspace:FindFirstChild("Platforms") and "✓" or "✗"))
print("Start: " .. (workspace:FindFirstChild("Start") and "✓" or "✗"))
print("Goal: " .. (workspace:FindFirstChild("Goal") and "✓" or "✗"))
print("Obstacles: " .. (workspace:FindFirstChild("Platforms") and workspace.Platforms:FindFirstChild("Obstacles") and #workspace.Platforms.Obstacles:GetChildren() > 0 and "✓ (" .. #workspace.Platforms.Obstacles:GetChildren() .. " obstacles)" or "✗"))
print("Dummy Template: " .. (ServerStorage:FindFirstChild("Dummy") and "✓" or "✗"))
print("=========================")