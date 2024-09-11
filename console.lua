local prefixes = {}

local keys = {callback = "callback", required_parameters = "required_parameters"}

---@param s string
---@return table
function string.split(s, sep)
    local words = {}
    for word in string.gmatch(s, sep) do
        table.insert(words, word)
    end
    return words
end

---@param new_prefix string
local function create_prefix(new_prefix)
    prefixes[new_prefix] = {
        command_list = {}
    }

    if prefixes[new_prefix] then
        printc(100,255,100,255, string.format("created prefix %s", tostring(new_prefix)))
        return true
    end
    return false
end

---@param prefix string
---@param name string
local function create_command(prefix, name)
    --assert(prefixes[prefix], "prefix is nil")
    --assert(prefixes[prefix].command_list, "command_list is nil")
    prefixes[prefix].command_list[name] = {
        callback = nil,
        required_parameters = {}, -- {name = "string"},
        description = "",
    }

    if not prefixes[prefix].command_list[name] then
        printc(255,100,100,255, "couldn't create command %s at prefix %s", name, prefix)
    else
        printc(100,255,100,255, string.format("create command %s at prefix %s", name, prefix))
    end

end

---@param prefix string
---@param name string
local function destroy_command(prefix, name)
    assert(prefixes[prefix], "prefix is nil")
    assert(prefixes[prefix].command_list, "command_list is nil")
    prefixes[prefix].command_list[name] = nil
    if prefixes[prefix].command_list[name] then
        printc(255,100,100,255, string.format("command %s at prefix %s wasn't destroyed somehow", name, prefix))
        return false
    end
    printc(100,255,100,255, string.format("destroyed command %s at prefix %s", name, prefix))
    return true
end

---@param prefix string
---@param name string
---@param key string
---@param value any
local function change_command(prefix, name, key, value)
    assert(prefixes[prefix], "prefix is nil")
    assert(prefixes[prefix].command_list, "command_list is nil")
    prefixes[prefix].command_list[name][key] = value
    if not prefixes[prefix].command_list[name][key] == value then
        warn(string.format("couldn't change %s's %s to be %s", tostring(name), tostring(key), tostring(value)))
        return false
    end
    printc(100,255,100,255, string.format("changed command %s's %s at prefix %s", name, key, prefix))
    return true
end

local function command_exists(prefix, name)
    if prefixes[prefix].command_list[name] then
        return true
    end
    return false
end

---@param str StringCmd
local function run_command(str)
    local cmd = string.split(str:Get(), "%S+")

    local prefix
    for k,v in pairs (prefixes) do
        if k == tostring(cmd[1]) then
            prefix = v
            print("found prefix " .. k)
        end
    end

    if prefix == nil then return end
    table.remove(cmd, 1)

    -- Extract the command name and parameters
    local command_name = cmd[1]
    print(command_name)
    table.remove(cmd, 1)

    -- Check if the command exists
    if not prefix.command_list[command_name] then
        error("Command '" .. command_name .. "' not found.")
    end

    local parameters = {}

    -- convert parameters[key] to the desired type
    for k, v in pairs (prefix.command_list[command_name].required_parameters) do
        if tostring(v) == "string" then
            parameters[k] = tostring(cmd[1])
            table.remove(cmd, 1)
        elseif tostring(v) == "number" then
            parameters[k] = tonumber(cmd[1])
            table.remove(cmd, 1)
        elseif tostring(v) == "bool" then
            if tostring(cmd[1]) == "true" then
                parameters[k] = true
                table.remove(cmd, 1)
            else
                parameters[k] = false
                table.remove(cmd, 1)
            end
        elseif tostring(v) == "function" then
            local func_body = load(table.concat(cmd, " "))
            parameters[k] = func_body
            cmd = {}
            break
        elseif tostring(v) == "table" then
            if string.sub(cmd[1], 1, 1) ~= "{" then
                error("This parameter needs to start with a {, but it doesn't")
                break
            end
            local concated = table.concat(cmd, " ")
            local new_table = load(concated)()
            if type(new_table) ~= "table" then
                error(string.format("the new table %s is NOT a table", concated))
            end
            parameters[k] = new_table
            cmd = {}
            break
        end
    end

    if #cmd > 0 then
        printc(255,100,100,255, "Too many parameters")
    end

    -- Call the command's callback with the parameters
    return pcall(prefix.command_list[command_name].callback, parameters)
end

local function unload()
    prefixes = nil
    package.loaded.consolelib = nil
end

local lib = {}
lib.version = 0.2
lib.create_command = create_command
lib.change_command = change_command
lib.destroy_command = destroy_command
lib.create_prefix = create_prefix
lib.unload = unload

callbacks.Unregister("SendStringCmd", "console-lib")
callbacks.Register("SendStringCmd", "console_lib", run_command)
printc(100,255,100,255, string.format("Console lib %.1f loaded", lib.version))

printc(255,255,255,255, "Adding 'con' prefix and default commands")
create_prefix("con")

create_command("con", "create-command")
change_command("con", "create-command", keys.required_parameters, {prefix = "string", cmd_name = "string"})
change_command("con", "create-command", keys.callback, function(params)
    create_command(params.prefix, params.cmd_name)
end)

create_command("con", "destroy-command")
change_command("con", "destroy-command", keys.required_parameters, {prefix = "string", cmd_name = "string"})
change_command("con", "destroy-command", keys.callback, function(params)
    destroy_command(params.prefix, params.cmd_name)
end)

create_command("con", "change-command-callback")
change_command("con", "change-command-callback", keys.required_parameters, {prefix = "string", cmd_name = "string", callback = "function"})
change_command("con", "change-command-callback", keys.callback, function(params)
    change_command(params.prefix, params.cmd_name, keys.callback, params.callback)
end)

create_command("con", "change-command-parameters")
change_command("con", "change-command-parameters", keys.required_parameters, {prefix = "string", cmd_name = "string", new_params = "table"})
change_command("con", "change-command-parameters", keys.callback, function(params)
    change_command(params.prefix, params.cmd_name, keys.required_parameters, params.new_params)
end)

create_command("con", "create-prefix")
change_command("con", "create-prefix", keys.required_parameters, {new_prefix = "string"})
change_command("con", "create-prefix", keys.callback, function(params)
    create_prefix(params.new_prefix)
end)

create_command("con", "command-exist")
change_command("con", "command-exist", keys.required_parameters, {prefix = "string", cmd_name = "string"})
change_command("con", "command-exist", keys.callback, function(params)
    print(command_exists(params.prefix, params.cmd_name))
end)

return lib