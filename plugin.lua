-- Base Plugin
-- by
-- Month 20YY

--[[ #include "info.lua" ]]

function GetColor(props)
  return PluginInfo.Color
end

function GetPrettyName(props)
  return PluginInfo.PrettyName .. " " .. PluginInfo.Version
end

--[[ #include "src/lib/geometry.lua" ]]

--[[ #include "src/pages.lua" ]]

function GetModel(props) --optional function to define model if plugin supports more than one model
  local model = {}
  --[[ #include "src/model.lua" ]]
  return model
end


--[[ #include "src/properties.lua" ]]

--[[ #include "src/controls.lua" ]]

--[[ #include "src/layout.lua" ]]


--Start event based logic
if Controls then
  --[[ #include "src/lib/util.lua" ]]
  --[[ #include "src/lib/events.lua" ]]
  --[[ #include "src/lib/telnet.lua" ]]
  --[[ #include "src/lib/commandqueue.lua" ]]
  --[[ #include "src/runtime.lua" ]]
end
