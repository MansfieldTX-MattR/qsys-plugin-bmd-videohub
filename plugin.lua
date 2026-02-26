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

--[[ #include "geometry.lua" ]]

--[[ #include "pages.lua" ]]

function GetModel(props) --optional function to define model if plugin supports more than one model
  local model = {}
  --[[ #include "model.lua" ]]
  return model
end


--[[ #include "properties.lua" ]]

--[[ #include "controls.lua" ]]

--[[ #include "layout.lua" ]]


--Start event based logic
if Controls then
  --[[ #include "util.lua" ]]
  --[[ #include "events.lua" ]]
  --[[ #include "telnet.lua" ]]
  --[[ #include "runtime.lua" ]]
end
