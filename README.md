# Roblox Genetic Algorithm Simulator

A Roblox game that demonstrates genetic algorithms through a parkour evolution simulation. NPCs learn to navigate obstacles through generations of evolution, with selection, crossover, and mutation.

## Features

- Simulates multiple generations of NPCs learning to navigate from a start point to a goal
- NPCs use raycasting and weighted decision-making to determine movement
- Genetic algorithm with selection, crossover, and mutation
- User interface to control simulation parameters
- Visual feedback on simulation progress

## How It Works

1. **Raycasting**: NPCs cast rays to detect obstacles in their environment
2. **Weighted Decision-Making**: Each NPC has a unique "genome" that determines how it reacts to its environment
3. **Fitness Calculation**: NPCs are scored based on how close they get to the goal
4. **Selection**: The best-performing NPCs are selected for reproduction
5. **Crossover**: Genetic information is combined to create new NPCs
6. **Mutation**: Random changes are introduced to maintain genetic diversity

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

## Getting Started

1. Open the game in Roblox Studio
2. Press Play to run the simulation
3. Use the UI panel to adjust parameters and control the simulation

## Customization

You can customize the simulation by:

- Adding more complex obstacles in the Platforms folder
- Modifying the dummy template in ServerStorage
- Adjusting algorithm parameters in the GeneticAlgorithm module

## Credits

Based on the genetic algorithm implementation from "Roblox NPC Parkour Evolution".