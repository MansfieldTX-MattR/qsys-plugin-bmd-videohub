PageNames = {"Control", "Setup"}

function GetPages(props)
  local pages = {}
  for i, name in ipairs(PageNames) do
    table.insert(pages, {name = PageNames[i]})
  end
  return pages
end
