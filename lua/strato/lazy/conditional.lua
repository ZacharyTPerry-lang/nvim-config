-- lua/strato/lazy/conditional.lua
if vim.g.has_extra_lazy_specs then
  local ok, specs = pcall(require, "leetcode_inject")
  if ok then
    return specs
  end
end

return {}
