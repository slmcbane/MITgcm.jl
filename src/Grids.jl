module Grids

using PackedFaces

export @llcgrid, LLC90, llc_arctic_face, reorder2llc!

"The index of the face containing the arctic, which is an exception to a lot of rules"
const llc_arctic_face = 7

"""
Generate the type definition of a `PackedArray` type to hold the LLC grid with tile
size `n × n`.
"""
macro llcgrid(tpname::Symbol, n)
    quote
        let N = $(esc(n)), xybounds=(N, 13*N),
            facebounds = (
                          ((1:N, (i-1)*N+1:i*N) for i ∈ 1:13)...,
                         ),
            transforms = (
                          FaceTransform(rotations=-1),
                          FaceTransform(rotations=-1),
                          FaceTransform(rotations=-1),
                          FaceTransform(rotations=-1),
                          FaceTransform(rotations=-1),
                          FaceTransform(rotations=-1),
                          FaceTransform(rotations=-1),
                          FaceTransform(),
                          FaceTransform(),
                          FaceTransform(),
                          FaceTransform(),
                          FaceTransform(),
                          FaceTransform()
                         ),
            interfaces = (
                          FaceInterface(1 => 2, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(1 => 4, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(4 => 5, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(4 => 10, RIGHT => LEFT, 1:N => 1:N),
                          # Arctic interfaces reversed where needed...
                          FaceInterface(7 => 11, TOP => TOP, N:-1:1 => 1:N),
                          FaceInterface(7 => 8, RIGHT => TOP, N:-1:1 => 1:N),
                          FaceInterface(2 => 3, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(2 => 5, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(5 => 6, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(5 => 9, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(8 => 11, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(8 => 9, BOTTOM => TOP, 1:N => 1:N),
                          FaceInterface(3 => 6, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(3 => 7, TOP => LEFT, 1:N => 1:N),
                          FaceInterface(6 => 8, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(6 => 7, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(9 => 12, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(9 => 10, BOTTOM => TOP, 1:N => 1:N),
                          FaceInterface(10 => 13, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(10 => 1, BOTTOM => BOTTOM, N:-1:1 => 1:N),
                          FaceInterface(12 => 2, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(12 => 11, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(11 => 3, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(13 => 1, RIGHT => LEFT, 1:N => 1:N),
                          FaceInterface(13 => 12, TOP => BOTTOM, 1:N => 1:N),
                          FaceInterface(13 => 4, BOTTOM => BOTTOM, N:-1:1 => 1:N)
                         )

            @packed_array(
                          $tpname, nfaces=13,
                          xybounds=xybounds, facebounds=facebounds, transforms=transforms,
                          interfaces=interfaces
                         )
        end
    end
end

# Generate the LLC90 type definition.
@llcgrid LLC90 90

@generated function reorder2llc!(dst::AbstractArray{T, N},
                                 src::AbstractArray{T, N}
                                ) where {T, N}
    if N > 2
        trailing = [Colon() for i = 3:N]
    else
        trailing = ()
    end

    quote
        @assert size(dst) == size(src)
        n = size(dst, 1)
        @assert size(dst, 2) == 13n
        
        dst[:, 1:7*n, $trailing...] .= @view src[:, 1:7*n, $trailing...]
        dst[:, 7*n+1:8*n, $trailing...] .= @view src[:, 7*n+1:3:10*n, $trailing...]
        dst[:, 8*n+1:9*n, $trailing...] .= @view src[:, 7*n+2:3:10*n, $trailing...]
        dst[:, 9*n+1:10*n, $trailing...] .= @view src[:, 7*n+3:3:10*n, $trailing...]
        dst[:, 10*n+1:11*n, $trailing...] .= @view src[:, 10*n+1:3:13*n, $trailing...]
        dst[:, 11*n+1:12*n, $trailing...] .= @view src[:, 10*n+2:3:13*n, $trailing...]
        dst[:, 12*n+1:13*n, $trailing...] .= @view src[:, 10*n+3:3:13*n, $trailing...]
        dst
    end
end

end #module

