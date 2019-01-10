module LazyCat

using Base: @propagate_inbounds, setindex

import Base: getindex, setindex!, size

export lazy_cat

function lazy_cat(arrs::AbstractArray{T}...; dim::Int=1) where T
    if length(arrs) == 1
        arrs[1]
    else
        # Pad arrays with smaller size out to the size of the largest dimension.
        N = maximum(ndims.(arrs))
        LazyCatArray{dim}(
                          (arr -> ndims(arr) < N ?
                           view(arr, (Colon() for i = 1:ndims(arr))...,
                                (1:1 for i = ndims(arr)+1:N)...) :
                           arr).(arrs)...
                         )
    end
end

struct NotImplementedError <: Exception
    msg::String
end

struct LazyCatArray{T, N, D, RANGES, MEMBERS} <: AbstractArray{T, N}
    members::MEMBERS
    ranges::RANGES

    function LazyCatArray{D}(members::AbstractArray{T, N}...) where {D, T, N}
        if !(D <= N && D > 0)
            throw(NotImplementedError("LazyCatArray{D}: Not implemented for D > dim of member arrays"))
        end
        
        members = (members...,)
        ranges = UnitRange[]
        
        for i ∈ 1:length(members)
            for d in 1:N
                if d != D
                    i != length(members) && (size(members[i], d) != size(members[i+1], d)) &&
                        throw(ErrorException("LazyCatArray{$D}: size in dimension $d does not match"))
                end
            end
            if isempty(ranges)
                push!(ranges, 1:size(members[i], D))
            else
                push!(ranges, ranges[end][end]+1:ranges[end][end]+size(members[i], D))
            end
        end
        ranges = (ranges...,)

        new{T, N, D, typeof(ranges), typeof(members)}(members, ranges)
    end

    function LazyCatArray{D}(arr::LazyCatArray{T, N, D}, next::Vararg{AbstractArray, M}
                            ) where {T, N, D, M}
        for d in 1:N
            if d != D
                if size(arr, d) != size(next[1], d)
                    throw(ErrorException("LazyCatArray{$D}: size in dimension $d does not match"))
                end
            end
        end
        
        if length(next) == 1
            range = arr.ranges[end][end]+1:arr.ranges[end][end] + size(next[1], D)
            ranges = (arr.ranges..., range)
            members = (arr.members..., next[1])
            new{T, N, D, typeof(ranges), typeof(members)}(members, ranges)
        else
            LazyCatArray{D}(LazyCatArray{D}(arr, next[1]), next[2:end]...)
        end
    end
end

# Binary search for the proper array.
@propagate_inbounds function get_arrindex(ranges::NTuple{N, UnitRange},
                                          inds::NTuple{M, Int}, i) where {M, N}
    if M == 1
        i ∈ ranges[inds[1]] ? inds[1] : 0
    elseif M == 0
        0
    else
        half1, half2 = divide_inds(inds)
        if ranges[half2[1]][1] > i
            get_arrindex(ranges, half1, i)
        else
            get_arrindex(ranges, half2, i)
        end
    end
end

@generated function indrange(::Val{N}) where N
    exprs = [:($i) for i in 1:N]
    :(tuple($(exprs...)))
end

@propagate_inbounds function get_arrindex(ranges::NTuple{N, UnitRange}, i) where N
    get_arrindex(ranges, indrange(Val(N)), i)
end

@generated function divide_inds(INDS::NTuple{N, Int}) where N
    exprs1 = [:(INDS[$i]) for i in  1:N÷2]
    exprs2 = [:(INDS[$i]) for i in N÷2+1:N]
    quote
        tuple($(exprs1...)), tuple($(exprs2...))
    end
end

function get_subarr_index(A::LazyCatArray{T, N, D}, I::NTuple{N, Int}, arrindex
                         ) where {T, N, D}
    setindex(I, I[D] - A.ranges[arrindex][1] + 1, D)
end

@propagate_inbounds function getindex(A::LazyCatArray{T, N, D}, I::Vararg{Int, N}
                                     ) where {T, N, D}
    arrindex = get_arrindex(A.ranges, I[D])
    
    @boundscheck begin
        if arrindex == 0
            throw(BoundsError(A, I))
        end
    end
    I = get_subarr_index(A, I, arrindex)
    A.members[arrindex][I...]
end

@propagate_inbounds function setindex!(A::LazyCatArray{T, N, D}, v, 
                                       I::Vararg{Int, N}) where {T, N, D}
    arrindex = get_arrindex(A.ranges, I[D])
    @boundscheck begin
        if arrindex == 0
            throw(BoundsError(A, I))
        end
    end

    I = get_subarr_index(A, I, arrindex)
    A.members[arrindex][I...] = v
end


@inline function size(A::LazyCatArray{T, N, D}) where {T, N, D}
    sz = size(A.members[1])
    setindex(sz, A.ranges[end][end], D)
end

end #module
