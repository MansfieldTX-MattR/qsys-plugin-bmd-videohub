PageNames = {"Setup", "Input Labels", "Output Labels", "Route"}

---@param props Properties
---@return {name: string}[]
function GetPages(props)
  local showRoutingControls = props["Show Routing Controls"].Value
  local pages = {}
  for i, name in ipairs(PageNames) do
    if name == "Route" and not showRoutingControls then
      goto continue
    end
    table.insert(pages, {name = PageNames[i]})
    ::continue::
  end
  return pages
end
