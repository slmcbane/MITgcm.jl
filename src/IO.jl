module IOFuncs

using Mmap

export readmds2llc!

function readmdsslice2llc!(A::AbstractArray{T, 2}, slice::AbstractArray{T, 2}) where T
    N = size(A, 1)
    @assert size(A) == (N, 13N)
    A[:, 1:7N] .= slice[:, 1:7N]

    @views A[:, 7N+1:8N] .= slice[:, 7N+1:3:10N]
    @views A[:, 8N+1:9N] .= slice[:, 7N+2:3:10N]
    @views A[:, 9N+1:10N] .= slice[:, 7N+3:3:10N]

    @views A[:, 10N+1:11N] .= slice[:, 10N+1:3:13N]
    @views A[:, 11N+1:12N] .= slice[:, 10N+2:3:13N]
    @views A[:, 12N+1:13N] .= slice[:, 10N+3:3:13N]
end

"""
`readmds2llc!(A::AbstractArray, infile::IO, N)`

Read MDS data into array `A`; `N` is the tile size of the LLC grid that `A` will hold the
data for. `A` has size (N, 13N, ... , nrecords).
"""
function readmds2llc!(A::AbstractArray, infile::AbstractString)
    N = size(A, 1)
    @assert size(A)[1:2] == (N, 13N)
    trailing_indices = CartesianIndices(size(A)[3:end])

    f = open(infile, "r")
    buf = Mmap.mmap(infile, Array{eltype(A), ndims(A)}, size(A))
    for index ∈ trailing_indices
        readmdsslice2llc!(@view(A[:, :, index]), @view(buf[:, :, index]))
    end
    close(f)
    A .= bswap.(A)
end

end # module
