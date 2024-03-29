require('util')

HexParsing = {}

local function insert_trimmed_if_nonempty(t, str)
    local str_trimmed = Util.trim(str)
    if str_trimmed ~= "" then
        table.insert(t, str_trimmed)
    end
end

function HexParsing.tokenize(text)
    text = text:gsub('\r\n', '\n')

    -- Replace slanted quotation marks
    text = text:gsub(utf8.char(8216),"'")
    text = text:gsub(utf8.char(8217),"'")
    text = text:gsub(utf8.char(8220),'"')
    text = text:gsub(utf8.char(8221),'"')

    local tokens = {}
    local current_token = ''
    local is_string = false
    local is_comment = false
    local backslash_just_entered = false

    for i = 1, #text do
        local char = text:sub(i, i)

        if backslash_just_entered then
            if is_string then
                if char == 'n' then
                    current_token = current_token .. '\n'
                elseif char == '\\' then
                    current_token = current_token .. '\\'
                else
                    error("Invalid escape sequence")
                end
                backslash_just_entered = false
            else
                -- Enter char literally, without causing special effects for semicolons or brackets
                current_token = current_token .. char
                backslash_just_entered = false
            end
        elseif char == '\n' then
            if is_string then
                error("String wasn't fully closed")
            else
                insert_trimmed_if_nonempty(tokens, current_token)
                current_token = ''
                is_comment = false
            end
        elseif char == ';' and not is_string and not is_comment then
            insert_trimmed_if_nonempty(tokens, current_token)
            current_token = ''
        elseif char:match("^[{}%[%]]$") and not is_string and not is_comment then
            insert_trimmed_if_nonempty(tokens, current_token)
            insert_trimmed_if_nonempty(tokens, char)
            current_token = ''
        elseif not is_string and char == '/' and text:sub(i, i + 1) == '//' then
            is_comment = true
        elseif not is_comment and char == '"' then
            is_string = not is_string
            current_token = current_token .. '"'
        elseif not is_comment and char == '\\' then
            backslash_just_entered = true
        elseif not is_comment then
            current_token = current_token .. char
        end
    end

    insert_trimmed_if_nonempty(tokens, current_token)
    return tokens
end

local function non_bracket_token_to_node(token)
    token = Util.trim(token) -- Should already be handled, but just in case
    if string.match(token, "^#") then
        local _, _, directive_name, argument = string.find(token, "^#([%w_]+)%s+(.*)$")
        if directive_name then
            return {
                token_type = 'directive',
                directive_name = directive_name,
                argument = Util.trim(argument)
            }
        else
            local _, _, directive_name2 = string.find(token, "^#([%w_]+)$")
            if directive_name2 then
                return {
                    token_type = 'directive',
                    directive_name = directive_name2,
                    argument = ""
                }
            else
                error("Invalid directive call")
            end
        end
    elseif string.match(token, "^-") then
        local _, _, remaining = string.find(token, "-(.*)")
        return {
            token_type = 'nonpattern',
            value = Util.trim(remaining)
        }
    else
        return {
            token_type = 'pattern',
            value = Util.trim(token)
        }
    end
end

local function corresponding_terminator(s)
    if s == '[' then
        return ']'
    elseif s == '{' then
        return '}'
    else
        error("Invalid character")
    end
end

local function tokens_to_ast_aux(tokens, start_index, terminator)
    local nodes = {}
    local i = start_index
    while i <= #tokens do
        local token = tokens[i]
        if token == ']' or token == '}' then
            if token == terminator then
                return nodes, i
            else
                error("Incorrect type of closing bracket")
            end
        elseif token == '[' or token == '{' then
            local captured_nodes, index_of_terminator =
                tokens_to_ast_aux(tokens, i + 1, corresponding_terminator(token))
            table.insert(nodes, {
                token_type = 'list',
                delimiter = token,
                elements = captured_nodes
            })
            i = index_of_terminator
        else
            table.insert(nodes, non_bracket_token_to_node(token))
        end

        i = i + 1
    end

    if terminator == nil then
        return nodes, nil
    else
        error("Did not find closing bracket")
    end
end

function HexParsing.tokens_to_ast(tokens)
    return tokens_to_ast_aux(tokens, 1, nil)
end
