module MDSParser

using Unicode

export MDSMetadata, parse_mds_metadata

mutable struct MDSMetadata
    ndims::Int
    dimlist::Vector{Int}
    dtype::DataType
    nrecords::Int
    nfields::Union{Int, Nothing}
    fieldlist::Union{Vector{Symbol}, Nothing}

    otherinfo::Dict{Symbol, Any}

    function MDSMetadata()
        this = new()
        this.otherinfo = Dict{Symbol, Any}()
        this
    end
end

const fields_set = Dict([field => false for field in fieldnames(MDSMetadata)])

function parse_mds_metadata(file::IO)
    str = read(file)
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
        else
            if symbol in keys(metadata.otherinfo)
                throw(ErrorException(
                     """
                     Multiple specification of extra data field \"$symbol\"
                     """))
            end
            metadata.otherinfo[symbol] = val
        end
        entry, indx = parse_mds_metadata_entry(str)
    end

    metadata
end

struct Token{T}
    ty::Symbol
    contents::T
end

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
