module IOFuncs

include("MDSParser.jl")

using Mmap, .MDSParser

export readmds, readmds!, MDSParser, parse_mds_metadata

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

function readmds!(dests::Vector{T}, prefix::AbstractString,
                  metadata::Union{Nothing, MDSMetadata} = nothing) where T <: AbstractArray
    if metadata === nothing
        metadata = try
            open(prefix * ".meta") do f
                parse_mds_metadata(f)
            end
        catch exc
            """
            readmds!: Caught exception while parsing metadata file; contents: "$(exc.msg)".
            """ |> ErrorException |> throw
        end
    end

    if metadata.nFlds === nothing
        readmds_nofldlist!(dests, prefix, metadata)
    else
        readmds_withfldlist!(dests, prefix, metadata)
    end
end

function readmds(prefix::AbstractString)
    metadata = try
        open(prefix * ".meta") do f
            parse_mds_metadata(f)
        end
    catch exc
        """
        readmds!: Caught exception while parsing metadata file; contents: "$(exc.msg)".
        """ |> ErrorException |> throw
    end

    if metadata.dataprec == "float32"
        dtype = Float32
    elseif metadata.dataprec == "float64"
        dtype = Float64
    else
        """
        readmds: Unrecognized data type $(metadata.dataprec) in metadata
        """ |> ErrorException |> throw
    end

    if metadata.nFlds === nothing || metadata.nFlds == 1
        if metadata.nrecords == 1
            sz = ( (metadata.dimList[(i-1)*3+1] for i in 1:metadata.nDims)..., )
        else
            sz = ( (metadata.dimList[(i-1)*3+1] for i in 1:metadata.nDims)...,
                   metadata.nrecords )
        end
        readmds!([Array{dtype}(undef, sz...)], prefix, metadata)
    else
        if metadata.nrecords == metadata.nFlds
            sz = ( (metadata.dimList[(i-1)*3+1] for i in 1:metadata.nDims)..., )
        else
            sz = ( (metadata.dimList[(i-1)*3+1] for i in 1:metadata.nDims)...,
                   metadata.nrecords ÷ metadata.nFlds)
        end
        readmds!([Array{dtype}(undef, sz...) for i in 1:metadata.nFlds], prefix, metadata)
    end
end

function mds_check_compatibility(dests::Vector{T}, metadata) where T <: AbstractArray
    if (metadata.nFlds === nothing && length(dests) != 1) || 
        (metadata.nFlds != nothing && length(dests) != metadata.nFlds)
        """
        readmds!: length(dests) does not match metadata.nFlds or if no field list was
        specified, there is not exactly 1 destination array.
        """ |> ErrorException |> throw
    end

    if metadata.nFlds === nothing || metadata.nFlds == 1
        if ! all(==(metadata.nDims + (metadata.nrecords > 1)), map(ndims, dests))
            """
            readmds!: One or more destination array has ndims differing from metadata.nDims
            """ |> ErrorException |> throw
        end
    elseif ! all(==(metadata.nDims + ((metadata.nrecords ÷ metadata.nFlds) > 1)),
                 map(ndims, dests))
        """
        readmds!: One or more destination arrays has ndims differing from metadata.nDims
        """ |> ErrorException |> throw
    end

    function dims_match(arr)
        for dim in 1:metadata.nDims
            if size(arr, dim) != metadata.dimList[(dim-1)*3+1]
                return false
            end
        end
        if metadata.nFlds == nothing || metadata.nFlds == 1
            if metadata.nrecords > 1 && size(arr, metadata.nDims+1) != metadata.nrecords
                return false
            end
        else
            if (metadata.nrecords ÷ metadata.nFlds) > 1 &&
                size(arr, metadata.nDims+1) != metadata.nrecords ÷ metadata.nFlds
                return false
            end
        end
        return true
    end

    if ! all(dims_match, dests)
        """
        readmds!: One or more destination array has incompatible size according to
        metadata.dimList
        """ |> ErrorException |> throw
    end

    if metadata.dataprec == "float32"
        dtype = Float32
    elseif metadata.dataprec == "float64"
        dtype = Float64
    else
        """
        readmds!: metadata.dataprec not recognized ("$(metadata.dataprec)")
        """ |> ErrorException |> throw
    end

    if ! all(==(dtype), map(eltype, dests))
        """
        readmds!: One or more destination array has different datatype than specified
        in metadata.
        """ |> ErrorException |> throw
    end
    nothing
end

function readmds_nofldlist!(dests::Vector{T}, prefix::AbstractString,
                            metadata::MDSMetadata) where T <: AbstractArray
    mds_check_compatibility(dests, metadata)
    arr = dests[1]

    filepath = prefix * ".data"
    if filesize(filepath) != sizeof(arr)
        """
        readmds!: The data file at $filepath does not have expected binary size
        (file size is $(filesize(filepath)) B vs. expected $(sizeof(arr)))
        """ |> ErrorException |> throw
    end

    filename = basename(filepath)
    separator = findfirst(==('.'), filename)
    field = Symbol(filename[1:separator-1])

    open(filepath) do infile
        dict = Dict(field => read!(infile, arr))
        dict[field] .= bswap.(dict[field])
        dict, metadata.otherinfo
    end
end

function readmds_withfldlist!(dests::Vector{T}, prefix::AbstractString,
                              metadata::MDSMetadata) where T <: AbstractArray
    mds_check_compatibility(dests, metadata)
    filepath = prefix * ".data"
    
    if filesize(filepath) != sum(sizeof(arr) for arr in dests)
        """
        readmds!: The data file at $filepath does not have expected binary size
        (file size is $(filesize(filepath)) B vs. expected $(sum(sizeof(arr) for arr in dests)))
        """ |> ErrorException |> throw
    end

    open(filepath) do infile
        fields = Dict{Symbol, T}()
        for i in 1:metadata.nFlds
            field = metadata.fldList[i] |> strip |> Symbol
            fields[field] = read!(infile, dests[i])
            fields[field] .= bswap.(fields[field])
        end
        fields, metadata.otherinfo
    end
end

end # module
