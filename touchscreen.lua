local component = require('component')
local computer = require('computer')
local event = require('event')
local thread = require('thread')

local logfile = io.open('/var/log/touchscreen.log', 'w')

local function rawtostring(v)
  local meta = getmetatable(v)
  if type(meta) ~= 'table' then
    return tostring(v)
  end
  local old_tostring = rawget(meta, '__tostring')
  rawset(meta, '__tostring', nil)
  local rawstr = tostring(v)
  rawset(meta, '__tostring', old_tostring)
  return rawstr
end

local function getAddress(v)
  local rawstr = rawtostring(v)
  return rawstr:sub(select(2, rawstr:find(': '))+1)
end

---- API Declaration ----
local lib = {}
local Button = {}
local Container = {}
local Context = {}
local Widget = {}

---- Widget API ----
Widget.__index = Widget
function Widget.__call(_, opts)
  return setmetatable({
    children = {},
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 1,
    h = opts.h or 1,
    bg = opts.bg or 0x000000,
    fg = opts.fg or 0xFFFFFF
  }, Widget)
end
function Widget.__tostring(self)
  local addr = getAddress(self)
  return 'Widget: <'..addr..'>'
end
function Widget:add(self, child)
  self.children
function Widget:fire(event, ...)
end

---- Button API ----
Button.__index = Button
function Button.__call(_, toggle, ...)
  return setmetatable({
    toggle = toggle or false,
    enabled = true,
  }, setmetatable(Button, lib.Widget(...)))
end
function Button.__tostring(self)
  local addr = getAddress(self)
  return 'Button: <'..addr..'>'
end

---- Container API ----
Container.__index = Container
function Container.__call(_, title, ...)
  return setmetatable({
    title = title or ''
  }, setmetatable(Container, lib.Widget(...)))
end
function Container.__tostring(self)
  local addr = getAddress(self)
  return 'Container: <'..addr..'>'
end

---- Context API ----
Context.__index = Context
function Context.__call(_, screen_addr, gpu_addr)
  return setmetatable({
    screen = screen_addr and component.proxy(screen_addr) or component.screen,
    gpu = gpu_addr and component.proxy(gpu_addr) or component.gpu,
    _running = false,
    tick_time = 1/20
  }, Context)
end
function Context.__tostring(self)
  local addr = getAddress(self)
  return 'Context: <'..addr..'>'
end
function Context:start()
  self.thread = thread.create(function()
    event.listen('interrupted', function()
      print('Interrupted '..tostring(self)..' on screen '..self.screen.address)
      self._running = false
    end)
    event.listen('touch', function(addr, ...)
      if addr == self.screen.address then
        self.root:fire('touch', ...)
      end
    end)

    self._running = true
    self.root = lib.Container()
    while self._running do
      self.gpu.setBackground(0x000000)
      local success, msg = self.gpu.fill(1, 1, width, height, ' ')
      self.root:draw(self, computer.uptime())

      os.sleep(self.tick_time)
    end
    logfile:close()
  end)
end
function Context:stop()
  self._running = false
  self.thread:join()
end

lib = {
  Context = setmetatable({}, Context),
  Widget = setmetatable({}, Widget),
  Button = setmetatable({}, Button),
  Container = setmetatable({}, Container)
}

return lib
