local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local tojson = require("../src")

local args = process.args

if #args == 0 then
    print("Usage: tojson <file.rbxm|file.rbxmx> [output.model.json]")
    process.exit(1)
end

local isSingleFile = #args == 2 and not args[2]:match("%.rbxmx?$")

local failed = false

for index, inputPath in args do
    if not inputPath:match("%.rbxmx?$") then
        if isSingleFile and index == 2 then
            break
        end

        print("skipping " .. inputPath .. ": not an rbxm/rbxmx file")

        continue
    end

    local outputPath = if isSingleFile then args[2] else inputPath:gsub("%.rbxmx?$", ".model.json")

    local roots = roblox.deserializeModel(fs.readFile(inputPath))

    if #roots == 0 then
        print("error: no instances found in " .. inputPath)
        failed = true
        continue
    end

    fs.writeFile(outputPath, tojson.encodeJson(tojson.convert(roots), 0))
end

if failed then
    process.exit(1)
end
