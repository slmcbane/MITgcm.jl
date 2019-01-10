module MITgcm

include("LazyCat.jl")
include("Grids.jl")
include("Exchange.jl")
include("IO.jl")

using .Grids, .IOFuncs
export @llcgrid, LLC90, readmds2llc!

end # module
