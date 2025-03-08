local Players = game:GetService("Players")

print("Genetic Algorithm Client initialized")
print("The server is running the genetic algorithm simulation automatically.")
print("You should see NPCs learning to navigate from the green platform to the red platform.")
print("Each generation will improve as the algorithm selects the best performers.")
print("Watch the console for progress updates.")

-- Create a simple message in the player's screen
local player = Players.LocalPlayer
if player then
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GeneticAlgorithmInfo"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create info frame
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(0, 300, 0, 100)
    infoFrame.Position = UDim2.new(0.5, -150, 0, 20)
    infoFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    infoFrame.BackgroundTransparency = 0.3
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = screenGui
    
    -- Add info text
    local infoText = Instance.new("TextLabel")
    infoText.Name = "InfoText"
    infoText.Size = UDim2.new(1, -20, 1, -20)
    infoText.Position = UDim2.new(0, 10, 0, 10)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Genetic Algorithm Simulation Running\nNPCs are learning to navigate from the green platform to the red platform.\nWatch as they improve with each generation!"
    infoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoText.TextSize = 14
    infoText.Font = Enum.Font.SourceSans
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.Parent = infoFrame
end