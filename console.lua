local test = false
local version = 0.1
local prefix = ""
local command_list = {}

---@param s string
---@return table
function string.split(s, sep)
    local words = {}
    for word in string.gmatch(s, sep) do
        table.insert(words, word)
    end
    return words
end

local function change_prefix(new_prefix)
    prefix = new_prefix
    if not prefix == new_prefix then
        return false
    end
    return true
end

---@param name string
local function create_command(name)
    assert(command_list, "command_list is nil")
    command_list[name] = {
        callback = nil,
        required_parameters = {}, -- {name = "string"}
    }
    if not command_list[name] then
        return false
    end
    return true
end

---@param name string
local function destroy_command(name)
    assert(command_list, "command_list is nil")
    command_list[name] = nil
    if not command_list[name] then
        return false
    end
    return true
end

---@param name string
---@param key string
---@param value any
local function change_command(name, key, value)
    assert(command_list, "command_list is nil")
    assert((key and value), "error")
    command_list[name][key] = value
    if not command_list[name][key] == value then
        warn(string.format("couldn't change %s's %s to be %s", tostring(name), tostring(key), tostring(value)))
        return false
    end
    return true
end

---@param str StringCmd
local function run_command(str)
    assert(command_list, "command_list is nil")

    local cmd = string.split(str:Get(), "%S+")
    if cmd[1] ~= prefix then return end

    -- Extract the command name and parameters
    local command_name = cmd[1]
    local parameters = {}
    for i = 2, #cmd do
        parameters[i - 1] = cmd[i]
    end

        -- Check if the command exists
    if not command_list[command_name] then
        error("Command '" .. command_name .. "' not found.")
    end
    -- Check if the required parameters are provided and of the correct types
    for k, v in pairs(command_list[command_name].required_parameters) do
        if not parameters[k] then
            error("Missing required parameter '" .. k .. "' for command '" .. command_name .. "'.")
        end
        if type(parameters[k]) ~= v then
            error("Incorrect type for parameter '" .. k .. "' in command '" .. command_name .. "'. Expected " .. v .. ", got " .. type(parameters[k]) .. ".")
        end
    end

    -- Call the command's callback with the parameters
    return pcall(command_list[command_name].callback, parameters)
end

local function unload()
    package.loaded.consolelib = nil
end

-- Example of input
-- prefix command parameters
--[[change_prefix("con")
create_command("test")
change_command("test", "callback", function()
    print("hello world")
end)]]

callbacks.Unregister("SendStringCmd", "console-lib")
callbacks.Register("SendStringCmd", "console_lib", run_command)
callbacks.Register("Unload", unload)
printc(100,255,100,255, string.format("Console lib %.1f loaded", version))

assert(#command_list == 0, "command_list is empty, did you forget to create a command or is this a bug?")

if test then
    local suc, create_result = pcall(create_command, "test")
    local suc, prefix_result = pcall(change_prefix, "test2")
    local suc, change_result1 = pcall(change_command, "test", "callback", function(params)
        if type(params.test_param) == "number" and type(params.test_param2) == "string" then
            return true
        end
        return false
    end)
    local suc, change_result2 = pcall(change_command, "test", "required_parameters", {test_param = "number", test_param2 = "string"})
    local suc, run_result = pcall(run_command, "test2 test 1231234 hello true {helloworld='hi'}")
    local suc, destroy_result = pcall(destroy_command, "test")
    
    print(string.format(
    "create_command result: %s\nchange_prefix result: %s\nchange_command result 1: %s\n"
  .."change_command result 2: %s\nrun_command result: %s\ndestroy_command result: %s",
    tostring(create_result), tostring(prefix_result), tostring(change_result1),
    tostring(change_result2), tostring(run_result), tostring(destroy_result)
    ))
end