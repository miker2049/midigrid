-- talking to crow

local CrowService = {}
CrowService.__index = CrowService

function CrowService:new(my_own_private_crow)
  local cs = {}
  cs.crow = my_own_private_crow
  setmetatable(cs, self)
  return cs
end

function CrowService:set_cv(output, voltage)
  self.crow.output[output].volts = voltage
end

function CrowService:set_action(output, action)
  self.crow.output[output].action = action
end

function CrowService:execute_action(output)
  self.crow.output[output].execute()
end

function CrowService:set_trigger_input(input, change_fn)
  self.crow.input[input].change = change_fn
  self.crow.input[input].mode("change", 2.0, 0.1, "rising")
end

function CrowService:set_cv_input(input, stream_fn)
  self.crow.input[input].stream = stream_fn
  self.crow.input[input].mode("stream", 0.1)
end

return CrowService
