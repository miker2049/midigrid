function create_buffer(width,height)
  local new_buffer = {}

  for r = 1,width do
    new_buffer[r] = {}
    for c = 1,height do
      new_buffer[r][c] = 0
    end
  end

  return new_buffer
end

local Vgrid = {
  width=8,
  height=8,
  quads = {},
  devices = {},
  key=nil
}

function Vgrid:attach_devices(devices)
  print('attaching devices:')
  tab.print(devices)
  for _, dev in pairs(devices) do
    self:attach_device(dev)
  end
end

function Vgrid:attach_device(dev)

  -- Assign to quads based on number of currently attached devices
  -- e.g. dev1 = quad1, dev2 = quad2, ...
  dev.current_quad = ((tab.count(self.devices)-1) % tab.count(self.quads))+1
  table.insert(self.devices,dev)
  
  -- Create reverse lookup tables for device
  dev:create_rev_lookups()

  -- Set call back for real device events to become virtual grid events
  midi.devices[dev.midi_id].event = function(e) dev.event(dev,self,e) end
  
  dev._key_callback = function(dev_quad,dev_x,dev_y,state) 
    self:_handle_grid_key(dev_quad,dev_x,dev_y,state) 
  end

  -- Call device init if set
  if dev._init then
    dev:_init()
  end
  -- Reset the device
  dev:_reset()
end

function Vgrid:_handle_grid_key(quad_id,qx,qy,state)
  -- Send device event to quad
  --print('q:'..quad_id..' x:'.. qx ..' y:'..qy..' s:'..state)
  self.quads[quad_id]:key(qx,qy,state,self.key)
end

function Vgrid:find_quad(x,y)
  local qid = 1
  if self.locate_in_layout then qid = self.locate_in_layout(self,x,y) end
  return self.quads[qid]
end

function Vgrid:set(x,y,z)
  local q = self:find_quad(x,y)
  if q then
    q:_relative_set(x,y,z)
  else
    print('Coords '..x..', '..y..' (x,y) outside Virtual Grid!')
  end
end

function Vgrid:set_all(z)
  for qid = 1, #Vgrid.quads do
    q = self.quads[qid]
    for x = 1,q.width do
      for y = 1,q.height do
        q:_set(x,y,z)
      end
    end
  end
end

function Vgrid:refresh(device_id)
  if device_id then
    self.devices[device_id]:refresh(self)
  else
    for _,device in pairs(self.devices) do
      device:refresh(self)
    end
  end
end

function Vgrid.new_quad(id,width,height,offset_x,offset_y)
  q = {
    id=id,
    width=width,
    height=height,
    offset_x=offset_x,
    offset_y=offset_y,
    buffer = create_buffer(width,height),
    updates_x = {}, -- list of changed x values for delta updates
    updates_y = {}, -- list of changed y values for delta updates
    update_count = 0,
    force_full_redraw = false
  }
  function q:_set(qx,qy,qz)
    if (self.buffer[qx][qy] ~= qz) then
      self.update_count = self.update_count + 1
      table.insert(self.updates_x,qx)
      table.insert(self.updates_y,qy)
      self.buffer[qx][qy] = qz
    end
  end
  
  function q:reset_updates()
    self.update_count = 0
    self.updates_x = {}
    self.updates_y = {}
  end

  function q:_relative_set(rx,ry,qz)
    local qx = rx - self.offset_x
    local qy = ry - self.offset_y

    self:_set(qx,qy,qz)
  end

  function q:each_with(device,callback)
    for x = 1,self.width do
      for y = 1,self.height do
        callback(device,x,y,self.buffer[x][y])
      end
    end
  end

  function q:updates_with(device,callback)
    if self.update_count > 0 then
      for u = 1,self.update_count do
        local x = self.updates_x[u]
        local y = self.updates_y[u]
        callback(device,x,y,self.buffer[x][y])
      end
    end
  end
  
  function q:key(qx,qy,state,callback)
    local rx = qx + self.offset_x
    local ry = qy + self.offset_y
    callback(rx,ry,state)
  end

  table.insert(Vgrid.quads,q)

  return q
end

function Vgrid.init(layout)
  layout = layout or '128'
  print("vgrid init with layout: "..layout)
  if layout == '128' or '256' then
    Vgrid.locate_in_layout = function(self,x,y)
      if (x > Vgrid.width or y > Vgrid.height) then return nil end
      if (y <= self.quads[1].height) then
        if (x <= self.quads[1].width) then return 1 else return 2 end
      end
      if (x <= self.quads[1].width) then return 3 else return 4 end
    end

    Vgrid.new_quad(1,8,8,0,0)
    Vgrid.new_quad(2,8,8,8,0)
    Vgrid.width = 16
    if layout == '256' then
      Vgrid.new_quad(3,8,8,0,8)
      Vgrid.new_quad(4,8,8,8,8)
      Vgrid.height = 16
    end

  elseif layout == 'cheat_codes' then
    -- TODO check this is correct
    Vgrid.new_quad(1,5,8,0,0)
    Vgrid.new_quad(2,5,8,5,0)
    Vgrid.new_quad(3,5,8,10,0)
    Vgrid.new_quad(4,1,8,15,0) -- Aux row
    -- TODO cheat codes layout still needs work to mirror "AUX" row
    Vgrid.locate_in_layout = function(self,x,y)
      if (x > Vgrid.width or y > Vgrid.height) then return nil end
      -- 3 grids of 5x8 + 1x8 Aux
      return (x//6)+1
    end

  else
    print("ERROR: Unknown layout " .. layout)
  end
end

return Vgrid
