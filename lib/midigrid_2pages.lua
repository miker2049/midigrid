--[[ cheapskate library for midi grid devices, 2 pages.
     contains within itself a full 128 grid table, which can be viewed and played by pressing
     the 'leftpage'/'rightpage' buttons as defined in the relevant config file.
]]

local supported_devices = {apcmini = 'apcmini',
                           launchpadmk2 = 'launchpad mk2',
                           launchpadpro = 'launchpad pro 2',
                           launchpad = 'launchpad'}
local config_name = 'none'
for _, dev in pairs(midi.devices) do
    local name = string.lower(dev.name)
    for device, device_name in pairs(supported_devices) do
        if name == device_name then
            config_name = 'midigrid/config/' .. device .. '_config'
        end
    end
end
if config_name == 'none' then
    print('No supported device found')
end
local config = include(config_name)
local gridnotes = config.grid
local brightness_handler = config.brightness_handler
local device_name = config.device_name
local og_dev_add, og_dev_remove
local leftpage = config.leftpage_button
local rightpage = config.rightpage_button

-- adding midi device call backs
local midigrid = {midi_id = nil}
midigrid.ledbuf = {}
midigrid.rows = #gridnotes[1]
midigrid.cols = #gridnotes

-- start on "page" 1
local apcpage = 1

-- make the grid buf
local gridbuf = {}
for i = 1, 16 do
    gridbuf[i] = {}
    for j = 1, 8 do
        gridbuf[i][j] = 0
    end
end

-- getting the two pages set up
apcnotecoords1 = {}
apcnotecoords2 = {}
for i, v in ipairs(gridnotes) do
    for j, k in ipairs(v) do
        apcnotecoords1[k] = {j, i}
    end
end
for i, v in ipairs(gridnotes) do
    for j, k in ipairs(v) do
        apcnotecoords2[k] = {j + 8, i}
    end
end
apcnotecoords = {apcnotecoords1, apcnotecoords2}


function midigrid.find_midi_device_id()
    local found_id = nil
    for i, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        if midigrid.name_matches(name) then
            found_id = dev.id
        end
    end
    return found_id
end


function midigrid.connect(dummy_id)
    midigrid.set_midi_handler()

    --init on page 1
    midi.devices[midigrid.midi_id]:send({144, leftpage, 1})
    midi.devices[midigrid.midi_id]:send({144, rightpage, 0})
    return midigrid
end


function midigrid.set_key_handler(key_handler)
    midigrid.set_midi_handler()
    midigrid.key = key_handler
end


function midigrid.setup_connect_handling()
    og_dev_add = midi.add
    og_dev_remove = midi.remove
    midi.add = midigrid.handle_dev_add
    midi.remove = midigrid.handle_dev_remove
end


function midigrid.name_matches(name)
    return (name == device_name)
end


function midigrid.handle_dev_add(id, name, dev)
    og_dev_add(id, name, dev)
    midigrid.update_devices()
    if (midigrid.name_matches(name)) and (id ~= midigrid.midi_id) then
        midigrid.midi_id = id
        midigrid.device = dev
        midigrid.set_midi_handler()
    end
end


function midigrid.handle_dev_remove(id)
    og_dev_remove(id)
    midigrid.update_devices()
end


-- this already expects it to have Midi_id
function midigrid.set_midi_handler()
    if midigrid.midi_id == nil then return end
    if midi.devices[midigrid.midi_id] ~= nil then
        midi.devices[midigrid.midi_id].event = midigrid.handle_key_midi

        -- need this for checking .device
        midigrid.device = midi.devices[midigrid.midi_id]
    else
        midigrid.midi_id = nil
    end
end


function midigrid.cleanup()
    midigrid.key = nil
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


-- led handling. *generally speaking*; first we clear the unchanged led buffer...
function midigrid:all(z)
    vel = brightness_handler(z)
    if self.device then
        for x = 1, 16 do
            for y = 1, 8 do
                local oldvel = gridbuf[x][y]
                gridbuf[x][y] = z
                if gridbuf[x][y] ~= oldvel then    -- this led needs to be set
                    if (apcpage == 1 and x < 9) then
                        note = gridnotes[y][x]
                        table.insert(self.ledbuf, 0x90)
                        table.insert(self.ledbuf, note)
                        table.insert(self.ledbuf, vel)
                    elseif (apcpage == 2 and x > 8) then
                        note = gridnotes[y][x - 8]
                        table.insert(self.ledbuf, 0x90)
                        table.insert(self.ledbuf, note)
                        table.insert(self.ledbuf, vel)
                    end
                end
            end
        end
    end
end


-- ...then we update the led buf at our leisure...
function midigrid:led(x, y, z)
    if x < 17 and y < 9 and x > 0 and y > 0 then
        vel = brightness_handler(z)
        gridbuf[x][y] = z

        -- if we aint on the right page dont bother
        if x > 8 and apcpage == 1 then
            return
        end
        if x < 8 and apcpage == 2 then
            return
        end
        if self.device then
            if apcpage == 1 then
                note = gridnotes[y][x]
            elseif apcpage == 2 then
                note = gridnotes[y][x - 8]
            end
            if note then
                table.insert(self.ledbuf, 0x90)
                table.insert(self.ledbuf, note)
                table.insert(self.ledbuf, vel)
            else
                print(
                    "no note found! coordinates....  x:" .. x .. "  y:" .. y .. "  z:" .. z)
            end
        end
    end
end


-- ...then we send the whole buf at once
function midigrid:refresh()
    if self.device then
        midi.devices[midigrid.midi_id]:send(self.ledbuf)

        -- ...and clear the buffer again.
        self.ledbuf = {}
    end
end


-- sure there is more elegant way!
function midigrid:changepage(page)
    midigrid.ledbuf = {}
    if page == 1 then
        for i = 1, 8 do
            for j = 1, 8 do
                midigrid:led(i, j, gridbuf[i][j])
            end
        end
    elseif page == 2 then
        for i = 9, 16 do
            for j = 1, 8 do
                midigrid:led(i, j, gridbuf[i][j])
            end
        end
    end
    midigrid:refresh()
end


function midigrid.handle_key_midi(data)
    note = data[2]

    -- first, intercept page selectors
    if note == leftpage or note == rightpage then
        if note == leftpage and data[1] == 0x90 and apcpage ~= 1 then
            apcpage = 1
            midi.devices[midigrid.midi_id]:send({144, rightpage, 0})
            midi.devices[midigrid.midi_id]:send({144, leftpage, 1})
            midigrid:changepage(apcpage)
        elseif note == rightpage and data[1] == 0x90 and apcpage ~= 2 then
            apcpage = 2
            midi.devices[midigrid.midi_id]:send({144, rightpage, 1})
            midi.devices[midigrid.midi_id]:send({144, leftpage, 0})
            midigrid:changepage(apcpage)
        else
            -- possibly note_off
        end

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    elseif note > -1 and note < 64 then
        local coords = apcnotecoords[apcpage][note]
        local x, y
        if coords then
            x, y = coords[1], coords[2]
            local s = data[1] == 0x90 and 1 or 0
            midigrid.key(x, y, s)
        else
            local coords = apcnotecoords[apcpage][note]
            local x, y
            print("missing coords!", x, y, s)
        end
    else
        print("unmapped key")
    end
end

-- init on page 1
midigrid.setup_connect_handling()
midigrid.update_devices()

return midigrid
