local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Genetic Algorithm Client initialized")
print("The server is running the genetic algorithm simulation automatically.")
print("You should see NPCs learning to navigate from the green platform to the red platform.")
print("Each generation will improve as the algorithm selects the best performers.")
print("Watch the console for progress updates.")

-- Create a simple message on the player's screen
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create a ScreenGui for the message
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GeneticAlgorithmGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Create a frame for the message
local messageFrame = Instance.new("Frame")
messageFrame.Name = "MessageFrame"
messageFrame.Size = UDim2.new(0, 400, 0, 100)
messageFrame.Position = UDim2.new(0.5, -200, 0, 20)
messageFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
messageFrame.BackgroundTransparency = 0.5
messageFrame.BorderSizePixel = 0
messageFrame.Parent = screenGui

-- Create a text label for the message
local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "MessageLabel"
messageLabel.Size = UDim2.new(1, 0, 1, 0)
messageLabel.BackgroundTransparency = 1
messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
messageLabel.TextSize = 18
messageLabel.Font = Enum.Font.SourceSansBold
messageLabel.Text = "Genetic Algorithm Simulation\n\nNPCs are learning to navigate from the green platform to the red platform.\nWatch as they evolve over generations!"
messageLabel.TextWrapped = true
messageLabel.Parent = messageFrame

-- Create a scoreboard frame
local scoreboardFrame = Instance.new("Frame")
scoreboardFrame.Name = "ScoreboardFrame"
scoreboardFrame.Size = UDim2.new(0, 300, 0, 400)
scoreboardFrame.Position = UDim2.new(0, 20, 0.5, -200)
scoreboardFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scoreboardFrame.BackgroundTransparency = 0.5
scoreboardFrame.BorderSizePixel = 0
scoreboardFrame.Parent = screenGui

-- Create a title for the scoreboard
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
titleLabel.BackgroundTransparency = 0.3
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 20
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Text = "Bloodline Performance"
titleLabel.Parent = scoreboardFrame

-- Create a generation label
local genLabel = Instance.new("TextLabel")
genLabel.Name = "GenerationLabel"
genLabel.Size = UDim2.new(1, 0, 0, 30)
genLabel.Position = UDim2.new(0, 0, 0, 40)
genLabel.BackgroundTransparency = 1
genLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
genLabel.TextSize = 16
genLabel.Font = Enum.Font.SourceSans
genLabel.Text = "Generation: 0"
genLabel.Parent = scoreboardFrame

-- Create a scrolling frame for the bloodlines
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "BloodlinesFrame"
scrollFrame.Size = UDim2.new(1, 0, 1, -80)
scrollFrame.Position = UDim2.new(0, 0, 0, 80)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = scoreboardFrame

-- Create a template for bloodline entries
local function createBloodlineEntry(index, bloodline)
    local entry = Instance.new("Frame")
    entry.Name = "Bloodline" .. index
    entry.Size = UDim2.new(1, 0, 0, 60)
    entry.Position = UDim2.new(0, 0, 0, (index - 1) * 65)
    entry.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    entry.BackgroundTransparency = 0.5
    entry.BorderSizePixel = 0
    
    -- Color indicator
    local colorIndicator = Instance.new("Frame")
    colorIndicator.Name = "ColorIndicator"
    colorIndicator.Size = UDim2.new(0, 20, 1, -10)
    colorIndicator.Position = UDim2.new(0, 10, 0, 5)
    colorIndicator.BackgroundColor3 = bloodline.color
    colorIndicator.BorderSizePixel = 0
    colorIndicator.Parent = entry
    
    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0, 100, 0, 20)
    nameLabel.Position = UDim2.new(0, 40, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Text = bloodline.name
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = entry
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0, 150, 0, 20)
    statusLabel.Position = UDim2.new(1, -160, 0, 5)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = bloodline.reachedGoal and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 200, 0)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.Text = bloodline.reachedGoal and "REACHED GOAL" or "IN PROGRESS"
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.Parent = entry
    
    -- Progress bar background
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBackground"
    progressBg.Size = UDim2.new(1, -50, 0, 15)
    progressBg.Position = UDim2.new(0, 40, 0, 30)
    progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = entry
    
    -- Progress bar fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(bloodline.successRate / 100, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg
    
    -- Progress percentage
    local percentLabel = Instance.new("TextLabel")
    percentLabel.Name = "PercentLabel"
    percentLabel.Size = UDim2.new(0, 50, 0, 15)
    percentLabel.Position = UDim2.new(0, 40, 0, 45)
    percentLabel.BackgroundTransparency = 1
    percentLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    percentLabel.TextSize = 14
    percentLabel.Font = Enum.Font.SourceSans
    percentLabel.Text = bloodline.successRate .. "%"
    percentLabel.TextXAlignment = Enum.TextXAlignment.Left
    percentLabel.Parent = entry
    
    return entry
end

-- Function to update the scoreboard
local function updateScoreboard(data)
    -- Update generation label
    genLabel.Text = "Generation: " .. data.generation
    
    -- Clear existing entries
    for _, child in pairs(scrollFrame:GetChildren()) do
        child:Destroy()
    end
    
    -- Create new entries for each bloodline
    for i, bloodline in ipairs(data.bloodlines) do
        if bloodline.dummyCount > 0 then
            local entry = createBloodlineEntry(i, bloodline)
            entry.Parent = scrollFrame
        end
    end
    
    -- Update canvas size
    local count = 0
    for _, bloodline in ipairs(data.bloodlines) do
        if bloodline.dummyCount > 0 then
            count += 1
        end
    end
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, count * 65)
end

-- Connect to the UpdateScoreboard remote event
ReplicatedStorage:WaitForChild("UpdateScoreboard").OnClientEvent:Connect(updateScoreboard)