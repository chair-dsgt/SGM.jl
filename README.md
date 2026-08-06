# Sampled Generation Method

[![Build Status](https://github.com/maxined2/SGM.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/maxined2/SGM.jl/actions/workflows/CI.yml?query=branch%3Amain)

SGM.jl is a Julia implementation of the Sampled Generation Method for solving integer programming games, compatible with the solver interface of the IPG.jl package.

## Associated publications
[M. Carvalho, A. Lodi, J. P. Pedroso, "Computing equilibria for integer programming games". 2022. European Journal of Operational Research](https://www.sciencedirect.com/science/article/abs/pii/S0377221722002727?via%3Dihub)

[T. Crönert, S. Minner, "Equilibrium Identification and Selection in Finite Games". 2022. Operations Research](https://pubsonline.informs.org/doi/10.1287/opre.2022.2413)

## Requirements
SGM.jl requires Julia and Gurobi to be installed, as well as a valid Gurobi licence. All Julia package dependencies are automatically downloaded during the installation.

## Installation
```julia
import Pkg
Pkg.add(url = "https://github.com/maxined2/SGM.jl.git")
```

## Solver construction
The SGM solver requires an optimizer for solving the players' best-response problems.

For example, Gurobi can be used as the best-response optimizer:
```julia
using SGM
using Gurobi

equilibrium_solver = SGM.EquilibriumSolver(Gurobi.Optimizer)
```

## Solver interface
SGM.jl implements the full IPG.jl solver interface.

The `supports_enumeration` function returns `true` since SGM.jl supports equilibria enumeration through its implementation of eSGM.

The `search!` function runs the equilibrium computation algorithm. The required arguments are the SGM equilibrium solver and the game model. An iteration limit, a deviation tolerance, and a time limit may also be provided. The `enumeration` keyword argument is `false` by default. When `enumeration` is `false`, the SGM algorithm is used to search for one equilibrium. When it is set to `true`, eSGM is used to enumerate all the equilibria of the game. 

The `get_termination_status` function returns the solver's current `IPG.TerminationStatusCode` describing its current state or why it has stopped.

Computed equilibria can be accessed using `get_equilibrium` and `get_equilibria`. The `get_equilibrium` function returns the computed equilibrium, or the first equilibrium when multiple have been found. An index may be passed to `get_equilibrium` to retrieve a particular equilibrium from an enumerated list. The `get_equilibria` function returns the complete list of equilibria and can only be used after an equilibria enumeration.

## Supported games
The games solved by SGM.jl are modeled with IPG.jl and must therefore satisfy the modeling requirements of IPG.jl. 

In addition, the SGM algorithm requires bounded mixed-integer linear strategy sets and separable Lipschitz continuous payoff functions. 

The eSGM algorithm requires bounded integer strategy sets that can be described by inequalities. Furthermore, our current implementation of eSGM only supports pairwise payoff functions and binary decision variables. Integer decision variables must be reformulated into a binary expansion.