# Test-only contract for the two fixed-volume connector fixtures. Fail before
# indexing: length alone cannot detect a same-size coordinate or node reorder.
function check_connector_layout(model, u, species)
    ns = length(species)
    keys(model.nodes) == (:left, :right) &&
        model.offsets == [1, ns+2] && length(u) == 2(ns+1) ||
        throw(ArgumentError("connector fixture node/state layout changed"))
    for (i,node) in enumerate(values(model.nodes))
        node.initial.gas.species_names == species ||
            throw(ArgumentError("connector fixture species order changed"))
        offset = model.offsets[i]
        expected = (node.initial.density*node.volume) .* node.initial.mass_fractions
        u[offset:offset+ns-1] == expected && u[offset+ns] == node.initial.temperature ||
            throw(ArgumentError("connector fixture requires species masses followed by temperature"))
    end
    return nothing
end
