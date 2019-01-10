"""
This module exists to encapsulate the exchange routine and helper functions.
Depends on the `LazyCat` module for the underlying AbstractArray that enables exchange
as a view of the underlying data, instead of copying.
"""
module Exchange

using PackedFaces, ..LazyCat

export exchange 

"""
`exchange(A::PackedFaceArray, face::Int; width::Int=1)`

Get an array holding `faces(A)[face]` along with neighboring values to a bandwidth
of `width`. This array is a "view" onto `A`; that is, it does not allocate any extra
storage, and changes to the returned array will be reflected in `A`.
"""
function exchange(A::PackedFaceArray, face::Int; width::Int=1)
    lfaces = get_left_faces(A, face, width)
    tfaces = get_top_faces(A, face, width)
    rfaces = get_right_faces(A, face, width)
    bfaces = get_bottom_faces(A, face, width)
    bodyface = PackedFaces.faces(A)[face]
    
    # Forgive me Father for I have sinned.
    if isempty(lfaces)
        if isempty(rfaces)
            if isempty(tfaces)
                if isempty(bfaces) # No interfaces
                    bodyface
                else # only bottom interface
                    lazy_cat(bodyface, lazy_cat(bfaces..., dim=2))
                end
            else
                if isempty(bfaces) # only top interface
                    lazy_cat(lazy_cat(tfaces..., dim=2), bodyface)
                else # Top and bottom interface
                    lazy_cat(lazy_cat(tfaces..., dim=2), bodyface,
                             lazy_cat(bfaces..., dim=2))
                end
            end
        else
            if isempty(tfaces)
                if isempty(bfaces) # Only the right interface
                    lazy_cat(bodyface, lazy_cat(rfaces...), dim=2)
                else # Right and bottom interfaces
                    bright = get_botright_corner(A, face, width)
                    rarr = lazy_cat(rfaces..., bright)
                    marr = lazy_cat(bodyface, lazy_cat(bfaces..., dim=2))
                    lazy_cat(marr, rarr, dim=2)
                end
            else
                if isempty(bfaces) # Right and top interfaces
                    tright = get_topright_corner(A, face, width)
                    rarr = lazy_cat(tright, rfaces...)
                    marr = lazy_cat(lazy_cat(tfaces..., dim=2), bodyface)
                    lazy_cat(marr, rarr, dim=2)
                else # Right, top, and bottom interfaces.
                    tright = get_topright_corner(A, face, width)
                    bright = get_botright_corner(A, face, width)
                    rarr = lazy_cat(tright, rfaces..., bright)
                    marr = lazy_cat(lazy_cat(tfaces..., dim=2), bodyface,
                                    lazy_cat(bfaces..., dim=2))
                    lazy_cat(marr, rarr, dim=2)
                end
            end
        end
    else
        if isempty(rfaces)
            if isempty(tfaces)
                if isempty(bfaces) # Only the left interface
                    lazy_cat(lazy_cat(lfaces...), bodyface, dim=2)
                else # Left and bottom
                    bleft = get_botleft_corner(A, face, width)
                    larr = lazy_cat(lfaces..., bleft)
                    marr = lazy_cat(bodyface, lazy_cat(bfaces..., dim=2))
                    lazy_cat(larr, marr, dim=2)
                end
            else
                if isempty(bfaces) # Left and top
                    tleft = get_topleft_corner(A, face, width)
                    larr = lazy_cat(tleft, lfaces...)
                    marr = lazy_cat(lazy_cat(tfaces..., dim=2), bodyface)
                    lazy_cat(larr, marr, dim=2)
                else # Left, top, and bottom
                    tleft = get_topleft_corner(A, face, width)
                    bleft = get_botleft_corner(A, face, width)
                    larr = lazy_cat(tleft, lfaces..., bleft)
                    marr = lazy_cat(lazy_cat(tfaces..., dim=2), bodyface,
                                    lazy_cat(bfaces..., dim=2))
                    lazy_cat(larr, marr, dim=2)
                end
            end
        else
            if isempty(tfaces)
                if isempty(bfaces) # Left and right
                    lazy_cat(lazy_cat(lfaces...), bodyface, lazy_cat(rfaces...), dim=2)
                else # Left, right, and bottom
                    bleft = get_botleft_corner(A, face, width)
                    bright = get_botright_corner(A, face, width)
                    larr = lazy_cat(lfaces..., bleft)
                    rarr = lazy_cat(rfaces..., bright)
                    marr = lazy_cat(bodyface, lazy_cat(bfaces..., dim=2))
                    lazy_cat(larr, marr, rarr, dim=2)
                end
            else
                if isempty(bfaces) # Left, right, and top
                    tleft = get_topleft_corner(A, face, width)
                    tright = get_topright_corner(A, face, width)
                    larr = lazy_cat(tleft, lfaces...)
                    rarr = lazy_cat(right, rfaces...)
                    marr = lazy_cat(lazy_cat(tfaces..., dim=2), bodyface)
                    lazy_cat(larr, marr, rarr, dim=2)
                else # Left, right, top, and bottom
                    tleft = get_topleft_corner(A, face, width)
                    bleft = get_botleft_corner(A, face, width)
                    tright = get_topright_corner(A, face, width)
                    bright = get_botright_corner(A, face, width)
                    larr = lazy_cat(tleft, lfaces..., bleft)
                    rarr = lazy_cat(tright, rfaces..., bright)
                    marr = lazy_cat(lazy_cat(tfaces..., dim=2), bodyface,
                                    lazy_cat(bfaces..., dim=2))
                    lazy_cat(larr, marr, rarr, dim=2)
                end
            end
        end
    end
end


###############################################################################
# Internals
###############################################################################
# Reverse the interface passed if the first member's range is not ascending.
function maybe_reverse(interface::FaceInterface{FACES, WHICH, RANGES}) where {FACES, WHICH, RANGES}
    if step(RANGES[1]) < 0
        FaceInterface(FACES, WHICH, reverse(RANGES[1]) => reverse(RANGES[2]))
    else
        interface
    end
end

function check_interface_steps(ints)
    for int in ints
        if abs(step(PackedFaces.ranges(int)[1])) +
            abs(step(PackedFaces.ranges(int)[2])) != 2
            throw(ErrorException("Exchange not implemented for non-unit steps"))
        end
    end
end

function get_left_faces(A, face, width)
    conn = PackedFaces.connectivity(A)[face]
    lint = [int for int in conn if PackedFaces.which(int)[1] == LEFT]
    lint = map(maybe_reverse, lint)
    sort!(lint, by = int -> PackedFaces.ranges(int)[1][1])
    check_interface_steps(lint)

    faces = PackedFaces.faces(A)

    function extract_face(int::FaceInterface{FACES, WHICH, RANGES}) where {FACES, WHICH, RANGES}
        face = faces[FACES[2]]
        trailing = ( (Colon() for i = 3:ndims(A))..., )
        if WHICH[2] == RIGHT
            view(face, RANGES[2], size(face, 2)-width+1:size(face, 2), trailing...)
        elseif WHICH[2] == TOP
            PermutedDimsArray(view(face, width:-1:1, RANGES[2], trailing...),
                              (2, 1, 3:ndims(A)...,))
        elseif WHICH[2] == LEFT
            view(face, RANGES[2], width:-1:1, trailing...)
        else # WHICH[2] == BOTTOM
            PermutedDimsArray(view(face, size(face, 1)-width+1:size(face, 1), RANGES[2],
                                   (Colon() for i = 1:ndims(A))...),
                              (2, 1, 3:ndims(A)...,))
        end
    end

    map(extract_face, lint)
end

function get_right_faces(A, face, width)
    conn = PackedFaces.connectivity(A)[face]
    rint = [int for int in conn if PackedFaces.which(int)[1] == RIGHT]
    rint = map(maybe_reverse, rint)
    sort!(rint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(rint)

    faces = PackedFaces.faces(A)

    function extract_face(int::FaceInterface{FACES, WHICH, RANGES}) where {FACES, WHICH, RANGES}
        face = faces[FACES[2]]
        trailing = ((Colon() for i = 3:ndims(A))...,)

        if WHICH[2] == LEFT
            view(face, RANGES[2], 1:width, trailing...)
        elseif WHICH[2] == TOP
            PermutedDimsArray(view(face, 1:width, RANGES[2], trailing...),
                              (2, 1, 3:ndims(A)...,))
        elseif WHICH[2] == RIGHT
            view(face, RANGES[2], size(face, 2):-1:size(face, 2)-width+1, trailing...)
        else # WHICH[2] == BOTTOM
            PermutedDimsArray(view(face, size(face, 1):-1:size(face, 1)-width+1, 
                                   RANGES[2], trailing...),
                              (2, 1, 3:ndims(A)...,))
        end
    end

    map(extract_face, rint)
end

function get_top_faces(A, face, width)
    conn = PackedFaces.connectivity(A)[face]
    tint = [int for int in conn if PackedFaces.which(int)[1] == TOP]
    tint = map(maybe_reverse, tint)
    sort!(tint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(tint)

    faces = PackedFaces.faces(A)

    function extract_face(int::FaceInterface{FACES, WHICH, RANGES}) where {FACES, WHICH, RANGES}
        face = faces[FACES[2]]
        trailing = ((Colon() for i = 3:ndims(A))...,)

        if WHICH[2] == BOTTOM
            view(face, size(face,1)-width+1:size(face,1), RANGES[2], trailing...)
        elseif WHICH[2] == LEFT
            PermutedDimsArray(view(face, RANGES[2], width:-1:1, trailing...),
                              (2, 1, 3:ndims(A)...,))
        elseif WHICH[2] == TOP
            view(face, width:-1:1, RANGES[2], trailing...)
        else # WHICH[2] = RIGHT
            PermutedDimsArray(view(face, RANGES[2], size(face,2)-width+1:size(face,2),
                                   trailing...),
                              (2, 1, 3:ndims(A)...,))
        end
    end

    map(extract_face, tint)
end

function get_bottom_faces(A, face, width)
    conn = PackedFaces.connectivity(A)[face]
    bint = [int for int in conn if PackedFaces.which(int)[1] == BOTTOM]
    bint = map(maybe_reverse, bint)
    sort!(bint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(bint)

    faces = PackedFaces.faces(A)

    function extract_face(int::FaceInterface{FACES, WHICH, RANGES}) where {FACES, WHICH, RANGES}
        face = faces[FACES[2]]
        trailing = ((Colon() for i = 3:ndims(A))...,)

        if WHICH[2] == TOP
            view(face, 1:width, RANGES[2], trailing...)
        elseif WHICH[2] == RIGHT
            PermutedDimsArray(view(face, RANGES[2], size(face,2):-1:size(face,2)-width+1,
                                   trailing...),
                              (2, 1, 3:ndims(A)...,))
        elseif WHICH[2] == BOTTOM
            view(face, size(face,1):-1:size(face,1)-width+1, RANGES[2], trailing...)
        else # WHICH[2] == LEFT
            PermutedDimsArray(view(face, RANGES[2], 1:width, trailing...),
                              (2, 1, 3:ndims(A)...,))
        end
    end

    map(extract_face, bint)
end

function get_topleft_corner(A, face, width)
    conn = PackedFaces.connectivity(A, face)
    lint = [int for int in conn if PackedFaces.which(int)[1] == LEFT]
    lint = map(maybe_reverse, lint)
    sort!(lint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(lint)

    which_face = PackedFaces.faces(lint[1])[2]
    orientation = PackedFaces.which(lint[1])[2]
    ascending = step(PackedFaces.ranges(lint[1])[2]) > 0


    if (orientation == LEFT || orientation == RIGHT)
        if ascending
            faces = lazy_cat(get_top_faces(A, which_face, width)..., dim=2)
        else
            faces = lazy_cat(get_bottom_faces(A, which_face, width)..., dim=2)
        end

        if orientation == LEFT
            if ascending
                faces = PackedFaces.mirror(faces, 2)
            else
                faces = PackedFaces.mirror(faces, 1, 2)
            end
        else
            if !ascending
                faces = PackedFaces.mirror(faces, 1)
            end
        end
    else
        if ascending
            faces = lazy_cat(get_left_faces(A, which_face, width)..., dim=1)
        else
            faces = lazy_cat(get_right_faces(A, which_face, width)..., dim=1)
        end

        if orientation == TOP
            if ascending
                faces = apply_face_transform(faces, FaceTransform(rotations=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=2,
                                                                  transpose=true))
            end
        else
            if ascending
                faces = apply_face_transform(faces, FaceTransform(transpose=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=-1))
            end
        end
    end

    view(faces, :, size(faces,2)-width+1:size(faces,2), (Colon() for i = 3:ndims(A))...)
end

function get_botleft_corner(A, face, width)
    conn = PackedFaces.connectivity(A, face)
    lint = [int for int in conn if PackedFaces.which(int)[1] == LEFT]
    lint = map(maybe_reverse, lint)
    sort!(lint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(lint)

    which_face = PackedFaces.faces(lint[end])[2]
    orientation = PackedFaces.which(lint[end])[2]
    ascending = step(PackedFaces.ranges(lint[end])[2]) > 0
    
    if (orientation == LEFT || orientation == RIGHT)
        if ascending
            faces = lazy_cat(get_bottom_faces(A, which_face, width)..., dim=2)
        else
            faces = lazy_cat(get_top_faces(A, which_face, width)..., dim=2)
        end

        if orientation == LEFT
            if ascending
                faces = PackedFaces.mirror(faces, 2)
            else
                faces = PackedFaces.mirror(faces, 1, 2)
            end
        else
            if !ascending
                faces = PackedFaces.mirror(faces, 1)
            end
        end
    else
        if ascending
            faces = lazy_cat(get_right_faces(A, which_face, width)..., dim=1)
        else
            faces = lazy_cat(get_left_faces(A, which_face, width)..., dim=1)
        end

        if orientation == TOP
            if ascending
                faces = apply_face_transform(faces, FaceTransform(rotations=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=2,
                                                                  transpose=true))
            end
        else
            if ascending
                faces = apply_face_transform(faces, FaceTransform(transpose=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=-1))
            end
        end
    end

    view(faces, :, size(faces,2)-width+1:size(faces,2), (Colon() for i = 3:ndims(A))...)
end

function get_topright_corner(A, face, width)
    conn = PackedFaces.connectivity(A, face)
    rint = [int for int in conn if PackedFaces.which(int)[1] == RIGHT]
    rint = map(maybe_reverse, rint)
    sort!(rint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(rint)

    which_face = PackedFaces.faces(rint[1])[2]
    orientation = PackedFaces.which(rint[1])[2]
    ascending = step(PackedFaces.ranges(rint[1])[2]) > 0
    
    if (orientation == LEFT || orientation == RIGHT)
        if ascending
            faces = lazy_cat(get_top_faces(A, which_face, width)..., dim=2)
        else
            faces = lazy_cat(get_bottom_faces(A, which_face, width)..., dim=2)
        end

        if orientation == RIGHT
            if ascending
                faces = PackedFaces.mirror(faces, 2)
            else
                faces = PackedFaces.mirror(faces, 1, 2)
            end
        else
            if !ascending
                faces = PackedFaces.mirror(faces, 1)
            end
        end
    else
        if ascending
            faces = lazy_cat(get_left_faces(A, which_face, width)..., dim=1)
        else
            faces = lazy_cat(get_right_faces(A, which_face, width)..., dim=1)
        end

        if orientation == BOTTOM
            if ascending
                faces = apply_face_transform(faces, FaceTransform(rotations=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=2,
                                                                  transpose=true))
            end
        else
            if ascending
                faces = apply_face_transform(faces, FaceTransform(transpose=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=-1))
            end
        end
    end

    view(faces, :, 1:width, (Colon() for i = 3:ndims(A))...)
end

function get_botright_corner(A, face, width)
    conn = PackedFaces.connectivity(A, face)
    rint = [int for int in conn if PackedFaces.which(int)[1] == RIGHT]
    rint = map(maybe_reverse, rint)
    sort!(rint, by = int -> PackedFaces.range(int)[1][1])
    check_interface_steps(rint)

    which_face = PackedFaces.faces(rint[end])[2]
    orientation = PackedFaces.which(rint[end])[2]
    ascending = step(PackedFaces.ranges(rint[end])[2]) > 0
    
    if (orientation == LEFT || orientation == RIGHT)
        if ascending
            faces = lazy_cat(get_bottom_faces(A, which_face, width)..., dim=2)
        else
            faces = lazy_cat(get_top_faces(A, which_face, width)..., dim=2)
        end

        if orientation == RIGHT
            if ascending
                faces = PackedFaces.mirror(faces, 2)
            else
                faces = PackedFaces.mirror(faces, 1, 2)
            end
        else
            if !ascending
                faces = PackedFaces.mirror(faces, 1)
            end
        end
    else
        if ascending
            faces = lazy_cat(get_right_faces(A, which_face, width)..., dim=1)
        else
            faces = lazy_cat(get_left_faces(A, which_face, width)..., dim=1)
        end

        if orientation == BOTTOM
            if ascending
                faces = apply_face_transform(faces, FaceTransform(rotations=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=2,
                                                                  transpose=true))
            end
        else
            if ascending
                faces = apply_face_transform(faces, FaceTransform(transpose=1))
            else
                faces = apply_face_transform(faces, FaceTransform(rotations=-1))
            end
        end
    end

    view(faces, :, 1:width, (Colon() for i = 3:ndims(A))...)
end

end # module
