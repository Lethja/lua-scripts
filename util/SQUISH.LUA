#!/usr/bin/env lua

local function Squish(fileName)
    local f, e = io.open(fileName, "r")
    if not f then
        print(e)
        return
    end
    local function tokenizeFile(file)
        local data, tokens, pos = file:read("all"), {}, 1

        if data:sub(1, 2) == "#!" then
            local lineEnd = data:find("\n", 1) or #data + 1
            table.insert(tokens, {type = "shebang", value = data:sub(1, lineEnd - 1)})
            pos = lineEnd
        end

        while pos <= #data do
            local c = data:sub(pos, pos)

            -- Handle comments
            if c == "-" and data:sub(pos, pos + 1) == "--" then
                local commentStart = pos
                -- Check for multi-line comment
                if data:sub(pos + 2, pos + 3) == "[[" then
                    local commentEnd = data:find("]]", pos + 4, true)
                    if commentEnd then
                        table.insert(tokens, {type = "comment", value = data:sub(commentStart, commentEnd + 1)})
                        pos = commentEnd + 2
                    else
                        -- Unclosed comment, treat as single line
                        local lineEnd = data:find("\n", pos) or #data + 1
                        table.insert(tokens, {type = "comment", value = data:sub(commentStart, lineEnd - 1)})
                        pos = lineEnd
                    end
                    -- Standard single-line comment
                else
                    local lineEnd = data:find("\n", pos) or #data + 1
                    table.insert(tokens, {type = "comment", value = data:sub(commentStart, lineEnd - 1)})
                    pos = lineEnd
                end

            -- Handle quoted strings
            elseif c == '"' or c == "'" then
                local stringStart = pos
                pos = pos + 1
                while pos <= #data do
                    if data:sub(pos, pos) == c then
                        break
                    elseif data:sub(pos, pos) == "\\" and pos < #data then
                        pos = pos + 2  -- Skip escaped character
                    else
                        pos = pos + 1
                    end
                end
                if pos <= #data then
                    table.insert(tokens, {type = "string", value = data:sub(stringStart, pos)})
                    pos = pos + 1
                else
                    -- Unclosed string, treat as code (this is an error in Lua)
                    table.insert(tokens, {type = "code", value = data:sub(stringStart, pos - 1)})
                end

            -- Handle bracket strings
            elseif c == "[" and data:sub(pos, pos + 1):match("%[=*%[") then
                local stringStart = pos
                local openBracket = data:match("%[=*%[", pos)
                local closeBracket = openBracket:gsub("%[", "]")
                local stringEnd = data:find(closeBracket, pos + #openBracket, true)

                if stringEnd then
                    table.insert(tokens, {type = "string", value = data:sub(stringStart, stringEnd + #closeBracket - 1)})
                    pos = stringEnd + #closeBracket
                else
                    -- Unclosed long bracket, treat as code (this is an error in Lua)
                    table.insert(tokens, {type = "code", value = data:sub(stringStart, pos)})
                    pos = pos + 1
                end

            -- Handle normal code
            else
                local codeStart = pos
                while pos <= #data do
                    local next_char = data:sub(pos, pos)
                    if next_char == "-" and data:sub(pos, pos + 1) == "--" or
                            next_char == '"' or next_char == "'" or
                            (next_char == "[" and data:sub(pos, pos + 1):match("%[=*%[")) then
                        break
                    end
                    pos = pos + 1
                end

                if codeStart < pos then
                    table.insert(tokens, {type = "code", value = data:sub(codeStart, pos - 1)})
                end
            end
        end
        return tokens
    end

    local function removeWhiteSpace(tokens)
        for _, token in ipairs(tokens) do
            if token.type == "code" then
                token.value = token.value:gsub("%s+", " ")  -- Replace multiple spaces with a single space
                token.value = token.value:gsub("%s*([%(%){}<>.,:;=%+%-%*/%^])%s*", "%1")  -- Remove spaces around operators and punctuation
                token.value = token.value:gsub("^%s+", "")  -- Remove leading whitespace
                token.value = token.value:gsub("%s+$", "")  -- Remove trailing whitespace
            end
        end
    end

    local tokens = tokenizeFile(f)

    -- Get the size of the script before any squishing
    local beforeSize = f:seek()
    f:close()
    removeWhiteSpace(tokens)

    -- Include the shebang on its own line if there is one
    local data = #tokens > 0 and tokens[1].type == "shebang" and table.remove(tokens, 1).value .. '\n' or ""

    -- Concatenate data together
    for _, token in ipairs(tokens) do
        if token.type ~= "comment" then
            local function pad()
                local last, start = #data > 1 and data:sub(-1, -1), #token.value > 1 and token.value:sub(1, 1)
                if (last and (last:find("%a") or last:find("%d")))
                and (start and (start:find("%a") or start:find("%d"))) then
                    return " "
                end
                return ""
            end
            local sep = pad()
            data = data .. sep .. token.value
        end
    end

    f, e = io.open(fileName, "w")
    if not f then
        print(e)
        return
    end

    f:write(data)

    -- Print the size of the file in bytes before and after the squish
    print(string.format("%9d -> %9d:\t %s", beforeSize, f:seek(), fileName))
    f:close()
end

if #arg < 1 then
    print(arg[0],[[[LUA SCRIPT...]

Removes comments, lines and whitespace from Lua scripts to save disk space.
Always backup any script before running it with ]] .. arg[0])
    os.exit(1)
end

for _,v in ipairs(arg) do Squish(v) end
