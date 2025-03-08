# Roblox Genetic Algorithm

A genetic algorithm implementation in Roblox that teaches NPCs to navigate around obstacles.

## Overview

This project demonstrates a genetic algorithm that evolves a population of NPCs (dummies) to navigate from a start position to a goal position while avoiding obstacles. The NPCs learn to move and jump based on their "genes," which are evolved over multiple generations through selection, crossover, and mutation.

## Features

- **Genetic Algorithm**: Implements selection, crossover, and mutation to evolve NPC behavior
- **Multi-directional Movement**: NPCs can move forward, left, right, and jump
- **Obstacle Avoidance**: Red obstacles destroy NPCs on contact, encouraging evolution of avoidance behavior
- **Fitness Tracking**: Detailed fitness scoring based on distance to goal and progress made
- **Visual Feedback**: NPCs change color based on their genes and glow green when reaching the goal
- **Progress Markers**: Small markers show the best position each NPC reached

## How It Works

1. **Initialization**: Creates a population of NPCs with random genes
2. **Simulation**: Each NPC tries to navigate to the goal using its genes to make movement decisions
3. **Fitness Calculation**: NPCs are scored based on how close they get to the goal
4. **Selection**: The best-performing NPCs are selected for reproduction
5. **Crossover**: Genes from selected NPCs are combined to create offspring
6. **Mutation**: Random mutations are introduced to maintain genetic diversity
7. **Repeat**: The process repeats for multiple generations, with NPCs evolving better navigation strategies

## Implementation Details

- **Raycasting**: NPCs use raycasts to sense the environment
- **Gene Structure**: Each NPC has genes that determine how it responds to environmental inputs
- **Fitness Function**: NPCs are rewarded for getting closer to the goal and penalized for hitting obstacles
- **Collision Detection**: Obstacles destroy NPCs on contact, encouraging evolution of avoidance behavior

## Usage

1. Open the project in Roblox Studio
2. Run the game
3. Watch as the NPCs evolve over generations to navigate to the goal
4. Check the output window for detailed fitness scores and progress reports

## Controls

- **Start Simulation**: Begins the genetic algorithm simulation
- **Stop Simulation**: Halts the current simulation
- **Population Size**: Number of NPCs in each generation (must be divisible by 4)
- **Generations**: Total number of generations to simulate
- **Generation Time**: How long each generation runs (in seconds)

## Technical Details

The project is structured into several components:

- **GeneticAlgorithm**: Core algorithm implementation (shared module)
- **SimulationManager**: Server-side simulation controller
- **GeneticAlgorithmUI**: Client-side user interface

## Customization

You can customize the simulation by:

- Adding more complex obstacles in the Platforms folder
- Modifying the dummy template in ServerStorage
- Adjusting algorithm parameters in the GeneticAlgorithm module

## Credits

Based on the genetic algorithm implementation from "Roblox NPC Parkour Evolution".