# tojson

Converts `.rbxm` and `.rbxmx` files to [Argon](https://argon.wiki) `model.json` format.

## Installation

```sh
pesde add ohirume/tojson
```

## CLI usage

```sh
tojson path/to/model.rbxm
# writes path/to/model.model.json

tojson path/to/model.rbxmx output.model.json
# explicit output path

tojson assets/**/*.rbxm
# glob — each file gets its own .model.json alongside it
```

## Library usage

```lua
local tojson = require("@ohirume/tojson")
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local roots = roblox.deserializeModel(fs.readFile("model.rbxm"))
local result = tojson.convert(roots)
```

`convert` returns a single object when the file has one root instance, or an array when it has multiple.

## License

MIT
