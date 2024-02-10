local function trim(s)
  local l = 1
  while string.sub(s, l, l) == ' ' do
    l = l + 1
  end
  local r = string.len(s)
  while string.sub(s, r, r) == ' ' do
    r = r - 1
  end
  return string.sub(s, l, r)
end

local function insert_trimmed_if_nonempty(t, str)
  local str_trimmed = trim(str)
  if str_trimmed ~= "" then
    table.insert(t, str_trimmed)
  end
end

local function tokenize(text)
    local tokens = {}
    for line in string.gmatch(text, "[^\n]+") do
        local comment_start_loccation = string.find(line, "//")
        if comment_start_loccation then
            line = string.sub(line, 1, comment_start_loccation - 1)
        end

        for segment in string.gmatch(line, "[^;]+") do
            local bracket_index = string.find(segment, "[{}]")
            while bracket_index do
                insert_trimmed_if_nonempty(tokens, string.sub(segment, 1, bracket_index - 1))
                table.insert(tokens, string.sub(segment, bracket_index, bracket_index))
                segment = string.sub(segment, bracket_index + 1)
                bracket_index = string.find(segment, "[{}]")
            end
            insert_trimmed_if_nonempty(tokens, segment)
        end
    end
    return tokens
end

-- https://stackoverflow.com/a/27028488
local function table_to_string(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. table_to_string(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local function print_table(o)
  print(table_to_string(o))
end

local function non_bracket_token_to_node(token)
  token = trim(token) -- Should already be handled, but just in case
  if string.match(token, "^-") then
    local _, _, remaining = string.find(token, "-(.*)")
    return {
      token_type = 'nonpattern',
      value = trim(remaining)
    }
  else
    return {
      token_type = 'pattern',
      value = trim(token)
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

function tokens_to_ast_aux(tokens, start_index, terminator)
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
    end
    
    if token == '[' or token == '{' then
      local captured_nodes, index_of_terminator = tokens_to_ast_aux(tokens, i + 1, corresponding_terminator(token))
      table.insert(nodes, {
        token_type = 'list',
        delimiter = token,
        elements = captured_nodes
      })
      i = index_of_terminator
    end

    table.insert(nodes, non_bracket_token_to_node(token))

    i = i + 1
  end

  if terminator == nil then
    return nodes, nil
  else
    error("Did not find closing bracket")
  end
end

local function tokens_to_ast(tokens)
    
end

local sample = [[
The quick brown fox // this is a comment
Jumps; Over { the; Lazy; Dog }
]]

print_table(tokens_to_ast_aux({"asdf", "fbaw", "{", "a", "}", "- qwerty"}, 1, nil))
