-- Base Plugin
-- by
-- Month 20YY

--[[ #include "info.lua" ]]

function GetColor(props)
  return { 102, 102, 102 }
end

function GetPrettyName(props)
  return "Base Plugin " .. PluginInfo.Version
end



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
  --[[ #include "runtime.lua" ]]
end
