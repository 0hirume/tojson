local roblox = require("@lune/roblox")

local SKIP_TYPES: { [string]: boolean } = {
    BinaryString = true,
    Ref = true,
    SecurityCapabilities = true,
    UniqueId = true,
}

local SKIP_PROPS: { [string]: boolean } = {
    Name = true,
    AttributesSerialize = true,
    SourceAssetId = true,
    NeedsPivotMigration = true,
    DefinesCapabilities = true,
    ModelMeshData = true,
    ModelMeshCFrame = true,
    ModelMeshSize = true,
    ModelStreamingMode = true,
    WorldPivotData = true,
    HistoryId = true,
    AudioCanCollide = true,
}

local function buildClassPropertyMap(xml: string): { [string]: { [string]: string } }
    local classProperties: { [string]: { [string]: string } } = {}
    local classStack: { string } = {}

    for line in xml:gmatch("[^\n]+") do
        local openClass = line:match('<Item class="([^"]+)"')

        if openClass ~= nil then
            table.insert(classStack, openClass)

            if classProperties[openClass] == nil then
                classProperties[openClass] = {}
            end
        end

        if line:match("</Item>") then
            table.remove(classStack)
        end

        local currentClass = classStack[#classStack]

        if currentClass ~= nil then
            local xmlType, propertyName = line:match('^%s*<(%a[%w]*) name="([^"]+)"')

            if xmlType ~= nil and propertyName ~= nil and SKIP_TYPES[xmlType] == nil and SKIP_PROPS[propertyName] == nil then
                classProperties[currentClass][propertyName] = xmlType
            end
        end
    end

    return classProperties
end

local function serializeValue(value: unknown, xmlType: string): unknown
    if typeof(value) == "boolean" or typeof(value) == "number" or typeof(value) == "string" then
        return value
    elseif typeof(value) == "Vector3" then
        return { value.X, value.Y, value.Z }
    elseif typeof(value) == "Vector2" then
        return { value.X, value.Y }
    elseif typeof(value) == "Vector3int16" then
        return { value.X, value.Y, value.Z }
    elseif typeof(value) == "Vector2int16" then
        return { value.X, value.Y }
    elseif typeof(value) == "CFrame" then
        local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
        return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
    elseif typeof(value) == "Color3" then
        return { value.R, value.G, value.B }
    elseif typeof(value) == "ColorSequence" then
        local keypoints = {}

        for _, keypoint in value.Keypoints do
            table.insert(keypoints, { time = keypoint.Time, color = { keypoint.Value.R, keypoint.Value.G, keypoint.Value.B } })
        end

        return keypoints
    elseif typeof(value) == "NumberSequence" then
        local keypoints = {}

        for _, keypoint in value.Keypoints do
            table.insert(keypoints, { time = keypoint.Time, value = keypoint.Value, envelope = keypoint.Envelope })
        end

        return keypoints
    elseif typeof(value) == "EnumItem" then
        return value.Name
    elseif typeof(value) == "BrickColor" then
        return value.Number
    elseif typeof(value) == "UDim2" then
        return { { value.X.Scale, value.X.Offset }, { value.Y.Scale, value.Y.Offset } }
    elseif typeof(value) == "UDim" then
        return { value.Scale, value.Offset }
    elseif typeof(value) == "NumberRange" then
        return { value.Min, value.Max }
    elseif typeof(value) == "Rect" then
        return { value.Min.X, value.Min.Y, value.Max.X, value.Max.Y }
    elseif typeof(value) == "Ray" then
        return {
            { value.Origin.X, value.Origin.Y, value.Origin.Z },
            { value.Direction.X, value.Direction.Y, value.Direction.Z },
        }
    elseif typeof(value) == "Region3" then
        local min = value.CFrame.Position - value.Size / 2
        local max = value.CFrame.Position + value.Size / 2
        return { { min.X, min.Y, min.Z }, { max.X, max.Y, max.Z } }
    elseif typeof(value) == "Region3int16" then
        return { { value.Min.X, value.Min.Y, value.Min.Z }, { value.Max.X, value.Max.Y, value.Max.Z } }
    elseif typeof(value) == "Font" then
        return { family = value.Family, weight = value.Weight.Name, style = value.Style.Name }
    elseif typeof(value) == "PhysicalProperties" then
        return {
            density = value.Density,
            friction = value.Friction,
            elasticity = value.Elasticity,
            frictionWeight = value.FrictionWeight,
            elasticityWeight = value.ElasticityWeight,
        }
    elseif typeof(value) == "Content" then
        return value.Uri
    else
        return nil
    end
end

local function applyOverrides(instance: Instance, properties: { [string]: unknown }): { [string]: unknown }
    local overridden = table.clone(properties)

    if instance:IsA("UICorner") then
        local scale, offset =
            roblox.serializeModel({ instance }, true):match('<UDim name="TopLeftRadius">%s*<S>([^<]+)</S>%s*<O>([^<]+)</O>')

        if scale ~= nil and offset ~= nil then
            overridden.CornerRadius = { tonumber(scale), tonumber(offset) }
        end
    end

    return overridden
end

local function serializeInstance(instance: Instance, classProperties: { [string]: { [string]: string } }): { [string]: unknown }
    local result: { [string]: unknown } = {
        ClassName = instance.ClassName,
        Name = instance.Name,
    }

    local propertyMap = classProperties[instance.ClassName]
    local properties: { [string]: unknown } = {}

    if propertyMap ~= nil then
        for propertyName, xmlType in propertyMap do
            local ok, value = pcall(function()
                return instance[propertyName]
            end)

            if ok and value ~= nil then
                local serialized = serializeValue(value, xmlType)

                if serialized ~= nil then
                    properties[propertyName] = serialized
                end
            end
        end
    end

    properties = applyOverrides(instance, properties)

    if next(properties) ~= nil then
        result.Properties = properties
    end

    local children: { { [string]: unknown } } = {}

    for _, child in instance:GetChildren() do
        table.insert(children, serializeInstance(child, classProperties))
    end

    if #children > 0 then
        result.Children = children
    end

    return result
end

local function convert(roots: { Instance }): { [string]: unknown } | { { [string]: unknown } }
    local classProperties = buildClassPropertyMap(roblox.serializeModel(roots, true))

    if #roots == 1 then
        local result = serializeInstance(roots[1], classProperties)
        result.Name = nil
        return result
    else
        local array: { { [string]: unknown } } = {}

        for _, root in roots do
            table.insert(array, serializeInstance(root, classProperties))
        end

        return array
    end
end

local INSTANCE_KEY_ORDER: { [string]: number } = {
    ClassName = 1,
    Name = 2,
    Properties = 3,
    Children = 4,
}

local function escapeString(string: string): string
    local escaped = string:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return escaped
end

local function encodeJson(value: unknown, depth: number): string
    if value == nil then
        return "null"
    elseif typeof(value) == "boolean" or typeof(value) == "number" then
        return tostring(value)
    elseif typeof(value) == "string" then
        return '"' .. escapeString(value) .. '"'
    elseif typeof(value) == "table" then
        local isArray = value[1] ~= nil
        local indent = string.rep("   ", depth)
        local inner = string.rep("   ", depth + 1)

        if isArray then
            local parts = {}

            for _, item in value do
                table.insert(parts, inner .. encodeJson(item, depth + 1))
            end

            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
        else
            local keys: { string } = {}

            for key: string in value do
                table.insert(keys, key)
            end

            table.sort(keys, function(a, b)
                local orderA = INSTANCE_KEY_ORDER[a]
                local orderB = INSTANCE_KEY_ORDER[b]

                if orderA ~= nil and orderB ~= nil then
                    return orderA < orderB
                elseif orderA ~= nil then
                    return true
                elseif orderB ~= nil then
                    return false
                end

                return a < b
            end)

            local parts = {}

            for _, key in keys do
                local keyValue = value[key]
                if keyValue ~= nil then
                    table.insert(parts, inner .. '"' .. escapeString(key) .. '": ' .. encodeJson(keyValue, depth + 1))
                end
            end

            if #parts == 0 then
                return "{}"
            end

            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
    else
        return "null"
    end
end

export type ConvertResult = { [string]: unknown } | { { [string]: unknown } }

return {
    convert = convert,
    encodeJson = encodeJson,
}
