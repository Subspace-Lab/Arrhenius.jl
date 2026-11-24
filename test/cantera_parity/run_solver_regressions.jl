# Optional integration regressions. Run from the repository root:
# julia --project=example/reactors test/cantera_parity/run_solver_regressions.jl
# Append one or more case names listed in README.md to select a group.
# No arguments (or all) runs all registered verified cases, including the repaired
# mass-flow pulse. Historical failures remain in their dated verification records.
for dependency in ("SciMLBase", "OrdinaryDiffEqBDF")
    Base.find_package(dependency) === nothing && error(
        "Use julia --project=example/reactors " *
        "test/cantera_parity/run_solver_regressions.jl; " *
        "prepare that environment with Pkg.instantiate() first.")
end

include("reactor.jl")
