module Grids

using PackedFaces

export @llcgrid, LLC90, llc_arctic_face

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

end #module

