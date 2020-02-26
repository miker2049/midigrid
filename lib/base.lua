local supported_devices = {
    apcmini = 'apcmini',
    launchpadmk2 = 'launchpad mk2',
    launchpadpro = 'launchpad pro 2',
    launchpad = 'launchpad',
    launchpadmini = 'launchpad mini'
  }

-- if there's no *monome* grid attached, norns returns a valid but unpopulated grid table
-- so must we
local midigrid = {
    core_grid = grid, --Preserve the core norns grid
    midi_id = nil,
    device = nil,
    rows = 0,
    cols = 0,
    name = "none",
    vports={},
    vgrid=nil
}

function midigrid._find_midigrid_devices()
  local midi_devices = {}
  --TODO should we use midi.vports?
  for _, dev in pairs(midi.devices) do
    local name = string.lower(dev.name)
    for device, device_name in pairs(supported_devices) do
        if name == device_name then
            table.insert(midi_devices, device)
        end
    end
  end

  return midi_devices
end

function midigrid.find_midi_device_id()
    local found_id = nil
    for _, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        if midigrid._name_matches(name) then
            found_id = dev.id
        end
    end
    return found_id
end

function midigrid.connect(dummy_id)
    if midigrid.vgrid == nil then
      -- User is calling connect without calling init, default to 64 button layout
      midigrid.vgrid = vgrid.init('64')  
    end
    
    if config == nil then
        return midigrid
    end
    midigrid.set_midi_handler()
    print('midigrid "' .. device_name .. '" has ' .. midigrid.rows .. " rows, " .. midigrid.cols .. " cols")
    midigrid:all(0)
    midigrid:refresh()

    return midigrid
end

function _light_quad_button(which_quad)
  -- regardless of which quad button we wish to light, we still have to turn
  --     off all the others
    for quad, _ in ipairs(quad_btns) do
        if quad == which_quad then
            _local_midi_dev:note_on(quad_btns[quad], 1)
        else
            _local_midi_dev:note_on(quad_btns[quad], 0)
        end
    end
end

function midigrid.set_key_handler(key_handler)
    midigrid.set_midi_handler()
    midigrid.key = key_handler
end


function midigrid.setup_connect_handling()
    og_dev_add = midi.add
    og_dev_remove = midi.remove
    midi.add = midigrid._handle_dev_add
    midi.remove = midigrid._handle_dev_remove
end

function midigrid._name_matches(name)
    return (name == device_name)
end

function midigrid._handle_dev_add(id, name, dev)
    og_dev_add(id, name, dev)
    midigrid.update_devices()
    if (midigrid._name_matches(name)) and (id ~= midigrid.midi_id) then
        midigrid.midi_id = id
        midigrid.set_midi_handler()
    end
end

function midigrid._handle_dev_remove(id)
    og_dev_remove(id)
    midigrid.update_devices()
end

function midigrid.update_devices()
    midi.update_devices()
    local new_id = midigrid.find_midi_device_id()

    -- Only set id/handler when helpful
    if (midigrid.midi_id ~= new_id) and (new_id ~= nil) then
        midigrid.midi_id = new_id
        return midigrid.set_midi_handler()
    end
    return (midigrid.midi_id ~= nil)
end

function midigrid.cleanup()
    midigrid.key = nil
end

-- this already expects it to have Midi_id
function midigrid.set_midi_handler()
    if midigrid.midi_id == nil then
        return
    end
    local local_grid = midi.devices[midigrid.midi_id]
    if local_grid ~= nil then
        local_grid.event = midigrid.handle_key_midi

        -- need this for checking .device
        midigrid.device = local_grid
        print('`midigrid.device` is:')
        tab.print(midigrid.device)
    else
        midigrid.midi_id = nil
    end
end

function midigrid:rotation(rotate_to)
  -- rotate the grid?
end

return midigrid