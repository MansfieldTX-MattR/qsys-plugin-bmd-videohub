---@meta

---@module "telescope"

---@param name string
---@param fn function
function context(name, fn) end

---@param name string
---@param fn function
function test(name, fn) end


---@param ... any
function assert_equal(...) end

---@param a any
function assert_true(a) end

---@param a any
function assert_false(a) end

---@param f function
function assert_error(f) end

---@param a number
---@param b number
function assert_close(a, b) end

---@param name string
---@param message string
---@param func function
function make_assertion(name, message, func) end
