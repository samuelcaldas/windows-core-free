# Plan: Configure .NET Environment on `ssh winvm` for `NT` (NinjaTrader / PPO / HalfTick)

## Context
The repository located at `C:\Users\samuelcaldas\repos\NT` on `winvm` contains the .NET 10 / .NET 8 solution `NT.sln` (PPO Core, HalfTick Gym Environment, Trading Plan, TensorFlow.NET submodules, unit tests, and CartPole PPO POC runner). Currently, the Windows Core guest VM lacks the .NET SDK runtime and CLI (`dotnet`), preventing building, testing, and running the project.

## Implementation Steps

### 1. Update `scripts/guest/Install-Tools.ps1` in `windows-core`
- Add an idempotent `Install-DotNet` function using Microsoft official `dotnet-install.ps1`.
- Install .NET SDK 10.0 (and .NET 8.0 runtime/SDK if needed for multi-targeted submodules).
- Register `C:\Program Files\dotnet` in the system `PATH` and refresh session environment variables.
- Add `[switch]$SkipDotNet` to parameter block.

### 2. Provision / Install .NET SDK on `ssh winvm`
- Execute silent installation of .NET 10 SDK on `winvm` (via `dotnet-install.ps1 -InstallDir "C:\Program Files\dotnet" -Channel 10.0`).
- Ensure machine `PATH` includes `C:\Program Files\dotnet`.
- Verify `dotnet --info` outputs valid runtime and SDK environment.

### 3. Build, Test, and Run `NT` on `winvm`
- Restore and build solution: `dotnet build NT.sln -c Release` in `C:\Users\samuelcaldas\repos\NT`.
- Run headless unit tests: `dotnet test NT.sln --verbosity normal`.
- Run sample simulation: `dotnet run --project samples/CartPole.PPO.POC/CartPole.PPO.POC.csproj`.

## Critical Files
- `scripts/guest/Install-Tools.ps1`: Add `Install-DotNet` function and PATH entry.
- `docs/plans/scalable-twirling-donut.md`: Execution plan documentation.

## Verification
1. `ssh winvm "dotnet --info"`: Verify .NET SDK 10.0 is installed and functional.
2. `ssh winvm "cd C:\Users\samuelcaldas\repos\NT && dotnet build NT.sln -c Release"`: Build all projects.
3. `ssh winvm "cd C:\Users\samuelcaldas\repos\NT && dotnet test NT.sln"`: Run all unit tests (PPO.Tests, HalfTick.Tests, TradingPlan.Tests).
4. `ssh winvm "cd C:\Users\samuelcaldas\repos\NT && dotnet run --project samples/CartPole.PPO.POC/CartPole.PPO.POC.csproj"`: Verify execution of the CartPole proof-of-concept.
