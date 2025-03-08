local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Starting Genetic Algorithm Client initialization...")

-- Load the UI module
local GeneticAlgorithmUI
local success, err = pcall(function()
    GeneticAlgorithmUI = require(script.GeneticAlgorithmUI)
end)

if not success then
    warn("Failed to load GeneticAlgorithmUI: " .. tostring(err))
    return
end

print("GeneticAlgorithmUI module loaded")

-- Initialize the UI
local ui
success, err = pcall(function()
    ui = GeneticAlgorithmUI.init()
end)

if not success then
    warn("Failed to initialize UI: " .. tostring(err))
    return
end

print("Genetic Algorithm Client initialized!")

-- Wait for the server to be ready
task.spawn(function()
    task.wait(2)
    
    -- Check if the remote events exist
    local remotes = ReplicatedStorage:FindFirstChild("GeneticAlgorithmRemotes")
    if not remotes then
        warn("GeneticAlgorithmRemotes folder not found in ReplicatedStorage")
        return
    end
    
    local getStatus = remotes:FindFirstChild("getStatus")
    if not getStatus then
        warn("getStatus RemoteFunction not found")
        return
    end
    
    -- Try to get the status from the server
    local success, status = pcall(function()
        return getStatus:InvokeServer()
    end)
    
    if not success then
        warn("Failed to get status from server: " .. tostring(status))
        return
    end
    
    print("Successfully connected to server")
    print("Server status: " .. (status.isRunning and "Running" or "Not Running"))
end)