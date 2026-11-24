"""
    InternalEnergyReactor(gas; temperature, pressure=one_atm,
                          mole_fractions=nothing, mass_fractions=nothing,
                          rate_multipliers=nothing)
    InternalEnergyReactor(thermal::IdealGasReactor)

Closed, constant-volume, adiabatic ideal-gas reactor with state `[Y; e]`, where
`e` is specific internal energy in J/kg and may be negative. Chemistry uses the
existing temperature-state reactor RHS; temperature is recovered from `e,Y`.
No flows, walls, surfaces or nonideal phases are supported. The existing
`IdealGasReactor` state and defaults are unchanged. Composition and multiplier
arrays are copied; mechanism data remain shared and must be treated as read-only.
Do not mutate configuration through `reactor.thermal` after construction.
"""
struct InternalEnergyReactor{R,T}
    thermal::R
    specific_internal_energy::T
end

function InternalEnergyReactor(thermal::IdealGasReactor)
    thermal.constraint === :constant_volume && thermal.energy === :adiabatic ||
        throw(ArgumentError("internal-energy reactor requires closed constant-volume adiabatic configuration"))
    # Snapshot configuration arrays without normalizing or recomputing state.
    multipliers = isnothing(thermal.rate_multipliers) ? nothing : copy(thermal.rate_multipliers)
    owned = IdealGasReactor(thermal.gas, thermal.temperature, thermal.pressure,
        thermal.density, copy(thermal.mass_fractions), thermal.constraint, thermal.energy, multipliers)
    return InternalEnergyReactor(owned, reactor_properties(owned).internal_energy)
end

function InternalEnergyReactor(gas::Solution; temperature, pressure=one_atm,
                              mole_fractions=nothing, mass_fractions=nothing,
                              rate_multipliers=nothing)
    return InternalEnergyReactor(IdealGasReactor(gas; temperature, pressure,
        mole_fractions, mass_fractions, rate_multipliers,
        constraint=:constant_volume, energy=:adiabatic))
end

reactor_state(r::InternalEnergyReactor) = vcat(r.thermal.mass_fractions, r.specific_internal_energy)

struct InternalEnergyRHS{R,F,T}
    reactor::R
    thermal_rhs::F
    thermal_state::Vector{T}
    mole_per_mass::Vector{T}
    thermal_jacobian::Matrix{T}
end

function reactor_rhs(r::InternalEnergyReactor)
    x = reactor_state(r.thermal)
    return InternalEnergyRHS(r, reactor_rhs(r.thermal), x,
                             zeros(eltype(x), length(x)-1), zeros(eltype(x), length(x), length(x)))
end

# Existing species thermodynamics, with unprojected signed mass fractions.
function _internal_energy_thermo!(rhs::InternalEnergyRHS, temperature, inverse_mw)
    r, w = rhs.reactor.thermal, rhs.thermal_rhs.workspace
    pressure = r.density * R * temperature * inverse_mw
    cal_h_RT!(w.h_mole, r.gas, temperature, pressure, w.X)
    cal_cp_R!(w.cp_R, r.gas, temperature, pressure, w.X)
    @inbounds for k in eachindex(w.h_mole)
        w.h_mole[k] *= R * temperature
    end
    value = dot(rhs.mole_per_mass, w.h_mole) - R * temperature * inverse_mw
    cv = R * (dot(rhs.mole_per_mass, w.cp_R) - inverse_mw)
    isfinite(value) && isfinite(cv) && cv > 0 ||
        throw(DomainError(temperature, "positive finite heat capacity required during internal-energy inversion"))
    return value, cv
end

# Expected inversion failure, distinct from arbitrary programming errors.
struct _InternalEnergyInversionError <: Exception
    reason::String
end
Base.showerror(io::IO, error::_InternalEnergyInversionError) = print(io, error.reason)

function _internal_energy_temperature!(rhs::InternalEnergyRHS, target, inverse_mw)
    isfinite(target) || throw(DomainError(target, "finite specific internal energy required"))
    temperature = rhs.thermal_state[end]
    lo = hi = temperature
    value, cv = _internal_energy_thermo!(rhs, temperature, inverse_mw)
    flo = fhi = value - target
    evaluations = 1
    iszero(flo) && return temperature
    # Cantera 726522be Reactor.cpp: factor 1.2, 48-bit T bracket, 100 iterations.
    # Safeguarded Newton/bisection replaces Boost's bracketed root algorithm.
    while flo > 0 && evaluations < 100
        lo /= 1.2
        value, _ = _internal_energy_thermo!(rhs, lo, inverse_mw)
        flo = value - target
        evaluations += 1
    end
    while fhi < 0 && evaluations < 100
        hi *= 1.2
        value, _ = _internal_energy_thermo!(rhs, hi, inverse_mw)
        fhi = value - target
        evaluations += 1
    end
    flo <= 0 <= fhi || throw(_InternalEnergyInversionError("internal-energy temperature root could not be bracketed"))
    tolerance = max(oftype(temperature, 2.0^-47), 4eps(typeof(temperature)))
    temperature = clamp(temperature, lo, hi)
    while evaluations < 100
        value, cv = _internal_energy_thermo!(rhs, temperature, inverse_mw)
        residual = value - target
        evaluations += 1
        iszero(residual) && return temperature
        if residual > 0
            hi = temperature
        else
            lo = temperature
        end
        hi - lo <= tolerance * min(abs(lo), abs(hi)) && return hi
        next = temperature - residual / cv
        temperature = lo < next < hi ? next : lo + (hi-lo)/2
    end
    throw(_InternalEnergyInversionError("internal-energy temperature inversion did not converge in 100 evaluations"))
end

function _internal_energy_state!(rhs::InternalEnergyRHS, u)
    gas = rhs.reactor.thermal.gas
    ns = gas.n_species
    length(u) == ns+1 || throw(DimensionMismatch("internal-energy state must contain n_species + 1 entries"))
    all(isfinite, u) || throw(DomainError(u, "finite internal-energy state required"))
    inverse_mw = zero(eltype(u))
    @inbounds for k in 1:ns
        rhs.thermal_state[k] = u[k]
        rhs.mole_per_mass[k] = u[k] / gas.MW[k]
        inverse_mw += rhs.mole_per_mass[k]
    end
    inverse_mw > 0 || throw(DomainError(inverse_mw, "positive inverse molecular weight required"))
    @inbounds for k in 1:ns
        rhs.thermal_rhs.workspace.X[k] = rhs.mole_per_mass[k] / inverse_mw
    end
    temperature = _internal_energy_temperature!(rhs, u[end], inverse_mw)
    rhs.thermal_state[end] = temperature
    return temperature, inverse_mw
end

function (rhs::InternalEnergyRHS)(du, u, p, t)
    _internal_energy_state!(rhs, u)
    rhs.thermal_rhs(du, rhs.thermal_state, p, t)
    du[end] = zero(eltype(du)) # Closed, rigid, adiabatic: de/dt = 0.
    return nothing
end
(rhs::InternalEnergyRHS)(du, u) = rhs(du, u, nothing, 0.0)

function reactor_jacobian!(J, u, rhs::InternalEnergyRHS, t=0)
    n = length(rhs.thermal_state)
    size(J) == (n,n) || throw(DimensionMismatch("Jacobian must match internal-energy state"))
    temperature, inverse_mw = _internal_energy_state!(rhs, u)
    reactor_jacobian!(rhs.thermal_jacobian, rhs.thermal_state, rhs.thermal_rhs, t)
    _, cv = _internal_energy_thermo!(rhs, temperature, inverse_mw)
    gas, w = rhs.reactor.thermal.gas, rhs.thermal_rhs.workspace
    @inbounds for j in 1:n-1
        uj = (w.h_mole[j] - R*temperature) / gas.MW[j]
        for k in 1:n-1
            J[k,j] = rhs.thermal_jacobian[k,j] - rhs.thermal_jacobian[k,n] * (uj/cv)
        end
        J[n,j] = zero(eltype(J))
    end
    @inbounds for k in 1:n-1
        J[k,n] = rhs.thermal_jacobian[k,n] / cv
    end
    J[n,n] = zero(eltype(J))
    return nothing
end

function reactor_properties(rhs::InternalEnergyRHS, u)
    _internal_energy_state!(rhs, u)
    props = reactor_properties(rhs.reactor.thermal, rhs.thermal_state)
    # Keep the independent thermodynamic evaluation; do not substitute stored e.
    return (; props..., integrated_internal_energy=u[end])
end
reactor_properties(r::InternalEnergyReactor, u=reactor_state(r)) = reactor_properties(reactor_rhs(r), u)

function reactor_problem(r::InternalEnergyReactor, tspan)
    length(tspan) == 2 && all(isfinite, tspan) && tspan[2] > tspan[1] ||
        throw(ArgumentError("tspan must be finite and strictly increasing"))
    rhs = reactor_rhs(r)
    jac = (J,u,p,t) -> reactor_jacobian!(J,u,rhs,t)
    tgrad = (du,u,p,t) -> (fill!(du,zero(eltype(du))); nothing)
    return (f=rhs,jac=jac,tgrad=tgrad,u0=reactor_state(r),tspan=(float(tspan[1]),float(tspan[2])),p=nothing)
end
solve_reactor(r::InternalEnergyReactor, tspan; integrator, kwargs...) =
    integrator(reactor_problem(r,tspan); kwargs...)

export InternalEnergyReactor, InternalEnergyRHS
