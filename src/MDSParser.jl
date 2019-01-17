module MDSParser

using Unicode

export MDSMetadata, parse_mds_metadata

mutable struct MDSMetadata
    nDims::Int
    dimList::Vector{Int}
    dataprec::String
    nrecords::Int
    nFlds::Union{Int, Nothing}
    fldList::Union{Vector{String}, Nothing}

    otherinfo::Dict{Symbol, Any}

    function MDSMetadata()
        this = new()
        this.otherinfo = Dict{Symbol, Any}()
        this.nFlds = nothing
        this.fldList = nothing
        this
    end
end

const fields_set = Dict([field => false for field in fieldnames(MDSMetadata)])

parse_mds_metadata(file::IO) = file |> read |> String |> parse_mds_metadata

function parse_mds_metadata(str::String)
    indx = 1
    # No fields are set at the beginning of parsing.
    foreach(key -> fields_set[key] = false, keys(fields_set))
    metadata = MDSMetadata()

    entry, indx = parse_mds_metadata_entry(str, indx)
    while entry !== nothing
        symbol, val = entry
        if symbol in fieldnames(MDSMetadata)
            fields_set[symbol] && throw(ErrorException(
                "Multiple specification of field \"$symbol\""))
                
            expect_type = fieldtype(MDSMetadata, symbol)
            val isa expect_type || throw(ErrorException(
                """
                Bad data type for field \"$(symbol)\":
                expected $expect_type but received $(typeof(val))
                """))
            setfield!(metadata, symbol, val)
            fields_set[symbol] = true
        else
            if symbol in keys(metadata.otherinfo)
                throw(ErrorException(
                     """
                     Multiple specification of extra data field \"$symbol\"
                     """))
            end
            metadata.otherinfo[symbol] = val
        end
        token, indx = get_token(str, indx)
        if token.ty == :WHITESPACE
            token, indx = get_token(str, indx)
        end

        if token.ty != :SEMICOLON && token.ty != :EOF
            """
            parse_mds_metadata: Missing semicolon delimiter between entries
            """ |> ErrorException |> throw
        end
        entry, indx = parse_mds_metadata_entry(str, indx)
    end

    for fld in (:nDims, :dimList, :dataprec, :nrecords)
        if !(fields_set[fld])
            """
            parse_mds_metadata: Required field $fld was not found in the metadata
            file
            """ |> ErrorException |> throw
        end
    end

    if length(metadata.dimList) != 3 * metadata.nDims
        """
        parse_mds_metadata: Length of dimList does not match expected; list
        has length $(length(metadata.dimList)) but should be $(3 * metadata.nDims) =
        3 * nDims
        """ |> ErrorException |> throw
    end

    if metadata.nFlds !== nothing && metadata.nrecords % metadata.nFlds != 0
        """
        parse_mds_metadata: nrecords is not evenly divisible by nFlds; invalid
        mds file specification.
        """ |> ErrorException |> throw
    end

    metadata
end

function parse_mds_metadata_entry(str, indx)
    token, indx = get_token(str, indx)
    if token.ty == :WHITESPACE
        token, indx = get_token(str, indx)
    end

    if token.ty == :EOF
        return nothing, indx
    elseif token.ty != :SYMBOL
        """
        parse_mds_metadata_entry: Entry should begin with a name of the
        field (alphabetical character + 1 or more alphanumeric characters)
        """ |> ErrorException |> throw
    end

    sym = token.contents

    token, indx = get_token(str, indx)
    if token.ty == :WHITESPACE
        token, indx = get_token(str, indx)
    end

    if token.ty != :EQUALS
        """
        parse_mds_metadata_entry: Entry should have the format NAME = [ ... ];
        did not find '='.
        """ |> ErrorException |> throw
    end

    entry_val, indx = parse_mds_entry_list(str, indx)

    (sym => entry_val), indx
end

function parse_mds_entry_list(str, indx)
    token, indx = get_token(str, indx)
    if token.ty == :WHITESPACE
        token, indx = get_token(str, indx)
    end

    if token.ty != :OPENBRACKET
        """
        parse_mds_entry_list: Expected an open bracket to begin the entry
        argument.
        """ |> ErrorException |> throw
    end

    token, indx = get_token(str, indx)
    if token.ty == :WHITESPACE
        token, indx = get_token(str, indx)
    end

    value_type = token_datatype(token)::DataType
    list = value_type[token.contents]

    while true
        token, indx = get_token(str, indx)
        if token.ty == :WHITESPACE
            token, indx = get_token(str, indx)
        end
        if token.ty == :COMMA
            token, indx = get_token(str, indx)
        end
        if token.ty == :WHITESPACE
            token, indx = get_token(str, indx)
        end

        if token.ty == :CLOSEBRACKET
            break
        elseif token_datatype(token) != value_type
            """
            parse_mds_entry_list: Datatype of element ($(token.contents)) is
            not inferred data type from first element: $value_type
            """ |> ErrorException |> throw
        else
            push!(list, token.contents)
        end
    end

    if isempty(list)
        nothing, indx
    elseif length(list) == 1
        list[1], indx
    else
        list, indx
    end
end


struct Token{T}
    ty::Symbol
    contents::T
end

token_datatype(::Token{T}) where T = T

function get_token(str::String, i)
    if i > length(str)
        return Token(:EOF, nothing), i
    end

    c = str[i]
    if isletter(c)
        get_symbol_token(str, i)
    elseif c == '\''
        get_string_token(str, i)
    elseif c == '[' || c == '{'
        Token(:OPENBRACKET, nothing), i+1
    elseif c == ']' || c == '}'
        Token(:CLOSEBRACKET, nothing), i+1
    elseif c == ';'
        Token(:SEMICOLON, nothing), i+1
    elseif c == ','
        Token(:COMMA, nothing), i+1
    elseif c == '='
        Token(:EQUALS, nothing), i+1
    elseif isspace(c)
        skip_whitespace(str, i)
    else
        get_number_token(str, i)
    end
end

function get_symbol_token(str, i)
    sym = "$(str[i])"
    i += 1

    while i <= length(str) && (isletter(str[i]) || isnumeric(str[i]))
        sym *= str[i]
        i += 1
    end
    Token(:SYMBOL, Symbol(sym)), i
end

function get_string_token(str, i)
    parsed = ""
    @assert str[i] == '\''
    i += 1
    while i <= length(str) && str[i] != '\''
        if str[i] == '\n'
            """
            get_string_token: Got newline before reaching terminating
            single quote. So far parsed: "$parsed"
            """ |> ErrorException |> throw
        end
        parsed *= str[i]
        i += 1
    end
    if str[i] != '\''
        """
        get_string_token: Reached EOF before termination of string.
        """ |> ErrorException |> throw
    end
    Token(:STRING, parsed), i+1
end

function skip_whitespace(str, i)
    while i <= length(str) && isspace(str[i])
        i += 1
    end
    Token(:WHITESPACE, nothing), i
end

function get_number_token(str, i)
    j = i+1
    while j <= length(str) && (isnumeric(str[j]) || str[j] in "eE.-+")
        j += 1
    end

    n = tryparse(Int, str[i:j-1])
    if n !== nothing
        return Token(:INTEGER, n), j
    end

    n = tryparse(Float64, str[i:j-1])
    if n === nothing
        "Error parsing number from string \"$(str[i:j-1])\"" |>
            ErrorException |> throw
    end
    Token(:FLOATING, n), j
end

end # module
