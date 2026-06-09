local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local tojson = require("../src/init")

local inputPath = process.args[1]

if inputPath == nil or not inputPath:match("%.rbxmx?$") then
	print("Usage: tojson <file.rbxm|file.rbxmx> [output.model.json]")
	process.exit(1)
end

local outputPath = if #process.args >= 2
	then process.args[2]
	else inputPath:gsub("%.rbxmx?$", ".model.json")

local roots = require("@lune/roblox").deserializeModel(fs.readFile(inputPath))

if #roots == 0 then
	print("error: no instances found in " .. inputPath)
	process.exit(1)
end

fs.writeFile(outputPath, serde.encode("json", tojson.convert(roots), true))
