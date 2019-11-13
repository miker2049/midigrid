-- FM7 Polyphonic Synthesizer
-- With 6 Operator Frequency 
-- Modulation
-- ///////////////////////////
-- key 2: random phase mods
-- key 3: play a random note
-- ///////////////////////////
-- grid pattern player:
-- 1-16 1 high voice
-- 1-16 8 low voice
-- 16 2 pattern record toggle
-- 16 3 pattern play toggle
-- 16 7 pattern transpose mode
-- ///////////////////////////
-- 1-6 2-7 phase mod matrix
-- 8 2-7 operator audio output
-- 10 2-7 frequency multiplier
-- (enables encoder control)
-- ENC1 coarse, ENC2 fine
-- ///////////////////////////
-- Arc encoders are assigned 
-- when phase mod toggled.
-- Without an arc, ENC3 is 
-- phase mod controller

engine.name = 'FM7'
tau = math.pi * 2
-- table to hold tuples to map phase mod params to grid key
-- {grid index, encoder index, parameter name}
arc_mapping = {{0,0,"none"},{0,0,"none"},{0,0,"none"},{0,0,"none"}}
enc_mapping = {true,false,false} -- table to hold parameter names for Norns encoders
-- g = grid.connect()
g = include('lib/apcnome_2pages') 
a = arc.connect()

-- require params library, why is this local to ~/dust/code and not . ?
local FM7 = include('fm7/lib/fm7')
-- helpers to work with tables
local tab = require 'tabutil'
-- helpers to record and playback patterns on a grid
local pattern_time = require 'pattern_time'
-- helpers for OLED screen
local UI = require 'ui'
-- helpers for MIDI to Hz and scales
local MusicUtil = require "musicutil"
-- pattern player has a transpose mode
local mode_transpose = 0
-- Tables to define the root note and tranposed note (may not be useful right now)
local root = { x=5, y=5 }
local trans = { x=5, y=5 }
-- table of which LEDs on the grid are lit up in the pattern
local lit = {}
-- top right button to start drawing our phase mod grid
local start_pos = {1,2}
-- size of the phase mode grid
local size = {6,6}
-- how many voices allowed for our synth
local MAX_NUM_VOICES = 16
-- current count of active voices
local nvoices = 0
-- table of which phase mod LEDs are toggled on or off
local toggles = {}
-- defaults for phase, frequency and amplitude (i think this is used for the grid OLED page)
local ph_position,hz_position,amp_position = 0,0,0
-- tables for which boxes are selected (this can probably be merged with the toggles table)
local selected = {}
-- table of modulator values (this also might be obsolete by just grabbing the values of the params)
local mods = {}
-- values of which ops output audio
local carriers = {}
-- counter of how many keys in the phase mod grid have been toggled on
local phase_keys_pressed = 0
-- maximum phase mod toggles allowed
local phase_max_keys = 1
-- update the screen at 15 Hz
local screen_framerate = 15
-- a variable for our OLED refresh metronome
local screen_refresh_metro
-- pythagorean minor/major, kinda
local ratios = { 1, 9/8, 6/5, 5/4, 4/3, 3/2, 27/16, 16/9 }
local base = 27.5 -- low A

-- helper functions
local function getHz(deg,oct)
  return base * ratios[deg] * (2^oct)
end

local function getHzET(note)
  hz = 55*2^(note/12)
  return hz
end

local function grid_vector(x,y)
  -- translate x,y coordinates into a vector
  return (x-start_pos[1]+1) + ((y-start_pos[2]) * size[1])
end

local function get_toggles_value(x,y)
  -- getter for toggles table
  idx = grid_vector(x,y)
  return toggles[idx]
end

local function set_toggles_value(x,y,val)
  -- setter for toggles table
  idx = grid_vector(x,y)
  toggles[idx] = val
end

local function bool_to_int(value)
  -- lua doesn't have a type system that understands integers as bolleans
  return value and 1 or 0
end

-- FM parameter grid drawing functions
local function draw_phase_matrix()
  for y = start_pos[2], (start_pos[2] + size[2] - 1) do
    for x = start_pos[1],(start_pos[1] + size[1] - 1) do
      g:led(x,y,3)
    end
  end  
end

local function draw_output_vector()
  local x = start_pos[1] + size[1] + 1
  local y = start_pos[2]
  for i = y,size[2]+1 do
    g:led(x,i,10)
  end
end

local function draw_frequency_vector()
  local x = start_pos[1] + size[1] + 3
  local y = start_pos[2]
  for i = y,size[2]+1 do
    g:led(x,i,3)
  end
end

-- arc helper functions
local function assign_next_arc_enc()
  enc = 0
  for i=1,4 do
    if arc_mapping[i][2] == 0 then
      arc_mapping[i][2] = i
      enc = i
      break
    end
  end
  return enc
end

local function remove_arc_enc(x,y)
  vec = grid_vector(x,y)
  for i=1,4 do
    if vec == arc_mapping[i][1] then
      a:segment(arc_mapping[i][2],0,tau,0)
      arc_mapping[i] = {0,0,"none"}
    end
  end
end

local function arc_encoder_is_assigned(n)
  result = false
  for i=1,4 do
    if arc_mapping[i][2] == n then
      result = true
    end
  end
  return result
end

-- Control the state of the phase modulation grid, get/set toggles, assign arc encoder,
-- draw modulation parameter on arc LED ring, light/dim grid LED
local function grid_phase_state(x,y,z)
  local op_out = x - start_pos[1]+1
  local op_in = y - start_pos[2]+1
  local toggle = get_toggles_value(x,y)
  if z == 1 then
    toggle = not toggle
    set_toggles_value(x,y,toggle)
      if toggle then
        if a.device then
          local arc_enc = assign_next_arc_enc()
          arc_mapping[arc_enc] = {grid_vector(x,y),arc_enc,"hz"..op_out.."_to_hz"..op_in}
          a:segment(arc_mapping[arc_enc][2],0,params:get(arc_mapping[arc_enc][3]),12)
          enc_mapping[3] = false
        else
          enc_mapping[3] = "hz"..op_out.."_to_hz"..op_in
        end
      else
        remove_arc_enc(x,y)
        enc_mapping[3] = false
      end
    local s = bool_to_int(toggle)
    g:led(x,y,3+s*9)
  end
end

-- control the state of the output vector, using the carriers table
local function output_vector_state(x,y,z)
  idx = y - 1
  if carriers[idx] ~= 1 then
    carriers[idx] = 1
  else
    carriers[idx] = 0
  end
  params:set("carrier"..idx, carriers[idx])
  g:led(x,y,3+carriers[idx]*9)
end

-- enable a momentary switch to enable encoder 2 to control the frequency ratio
-- for this operator.
-- TODO: add toggles and limit to one at a time
local function frequency_vector_state(x,y,z)
  if z == 1 then
    enc_mapping[2] = "hz"..y - start_pos[2] + 1
  else
    enc_mapping[2] = false
  end
  --tab.print(enc_mapping)
  g:led(x,y,3+z*12)
end

-- callback function for key presses on the grid
function g.key(x,y,z)
  -- phase mod matrix updates
  if x < (start_pos[1] + size[1]) and y >= start_pos[2] and y < (start_pos[2] + size[2]) then
    if phase_keys_pressed <= phase_max_keys then
      if z == 1 and get_toggles_value(x,y) then
        phase_keys_pressed = phase_keys_pressed -1
        grid_phase_state(x,y,z)
      elseif z == 1 and phase_keys_pressed ~= phase_max_keys then
        phase_keys_pressed = phase_keys_pressed + 1
        grid_phase_state(x,y,z)
      end
    end
  elseif x == (start_pos[1] + size[1] + 1) and y >= start_pos[2] and y < (start_pos[2] + size[2]) then
    if z == 1 then
      output_vector_state(x,y,z)
    end
  elseif x == (start_pos[1] + size[1] + 3) and y >= start_pos[2] and y < (start_pos[2] + size[2]) then
    frequency_vector_state(x,y,z)
  end
  g:refresh()
  a:refresh()
  pattern_control(x,y,z)
end

-- Control parameters when an encoder (arc or norns) is moved.
-- Draw rounded up value to OLED grid, as a visual indicator for the user.
-- This function could be split up a bit.
local function update_phase_matrix(n,d)
  if arc_encoder_is_assigned(n) then
    params:delta(arc_mapping[n][3], d/10)
    local val = params:get(arc_mapping[n][3])
    a:segment(n,0,val,12)
    local screen_val = math.ceil(val)
    local x = (arc_mapping[n][1] % size[1]) == 0 and size[1] or arc_mapping[n][1] % size[1]
    local y = math.ceil(arc_mapping[n][1] / size[2])
    mods[x][y] = screen_val
    redraw()
    a:refresh()
  elseif enc_mapping[3] then
    params:delta(enc_mapping[3],d/2)
    local screen_val = math.ceil(params:get(enc_mapping[3]))
    -- this is a hack to get the first phase mod grid key,
    -- because when there is no arc, we are limited to 1 encoder
    local idx = tab.key(toggles,true)
    local x = (idx % size[1]) == 0 and size[1] or idx % size[1]
    local y = math.ceil(idx / size[2])
    mods[x][y] = screen_val
    redraw()    
  end
end

-- callback function when arc encoder is turned
function a.delta(n,d)
  if n == 1 then
    update_phase_matrix(n,d)
  elseif n == 2 then
    update_phase_matrix(n,d)
  elseif n == 3 then
    update_phase_matrix(n,d)
  elseif n == 4 then
    update_phase_matrix(n,d)
  end
end

function init()
  -- connect to first MIDI device, set callback function
  m = midi.connect(2)
  m.event = midi_event
  
  -- create a new pattern_time object, set callback function
  pat = pattern_time.new()
  pat.process = grid_note_trans

  -- set amplitude to 0.05, stop everything at init
  engine.amp(0.05)
  engine.stopAll()

  -- load all parameters from included library
  FM7.add_params()

  -- if a grid is attached, initialize our grid
  if g then 
    draw_phase_matrix()
    draw_output_vector()
    draw_frequency_vector()
    gridredraw()
  end
  
  -- if we have an arc, set max grid mod toggles to 4
  if a.device then phase_max_keys = 4 end

  -- make a screen refresh metronome, set a callback function
  screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function(stage)
    redraw()
  end
  -- start the metro at 15 Hz
  screen_refresh_metro:start(1 / screen_framerate)

  -- initialize the OLED screen with phase mod values, also carrier values
  -- This should be refactored
  for m = 1,6 do
    selected[m] = {}
    mods[m] = {}
    carriers[m] = 1
    for n = 1,6 do
      selected[m][n] = 0
      mods[m][n] = 0
    end
  end
  -- TODO: what are these variables?
  -- a light?
  light = 0
-- fill up our toggle table with false values
  for i=1,6*6 do
    table.insert(toggles,false)
  end

  -- make a new pages collection, with a single page, starting on the first page
  pages = UI.Pages.new(1, 1)
end

-- copy paste from @tehn earthsea library
function pattern_control(x, y, z)
  if x == 16 and y > 1 and y < 8 then
    if z == 1 then
      if y == 2 and pat.rec == 0 then
        mode_transpose = 0
        trans.x = 5
        trans.y = 5
        pat:stop()
        engine.stopAll()
        pat:clear()
        pat:rec_start()
      elseif y == 2 and pat.rec == 1 then
        pat:rec_stop()
        if pat.count > 0 then
          root.x = pat.event[1].x
          root.y = pat.event[1].y
          trans.x = root.x
          trans.y = root.y
          pat:start()
        end
      elseif y == 3 and pat.play == 0 and pat.count > 0 then
        if pat.rec == 1 then
          pat:rec_stop()
        end
        pat:start()
      elseif y == 3 and pat.play == 1 then
        pat:stop()
        engine.stopAll()
        nvoices = 0
        lit = {}
      elseif y == 7 then
        mode_transpose = 1 - mode_transpose
      end
    end
  -- catch key events outside the control row
  elseif y < 2 or y > 7 then
    if mode_transpose == 0 then
      local e = {}
      e.id = x*8 + y
      e.x = x
      e.y = y
      e.state = z
      pat:watch(e)
      grid_note(e)
    else
      trans.x = x
      trans.y = y
    end
  end
  gridredraw()
end

function grid_note(e)
  local note = ((7-e.y)*5) + e.x
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      engine.start(e.id, getHzET(note))
      lit[e.id] = {}
      lit[e.id].x = e.x
      lit[e.id].y = e.y
      nvoices = nvoices + 1
    end
  else
    if lit[e.id] ~= nil then
      engine.stop(e.id)
      lit[e.id] = nil
      nvoices = nvoices - 1
    end
  end
  gridredraw()
end

function grid_note_trans(e)
  local note = ((7-e.y+(root.y-trans.y))*5) + e.x + (trans.x-root.x)
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      engine.start(e.id, getHzET(note))
      lit[e.id] = {}
      lit[e.id].x = e.x + trans.x - root.x
      lit[e.id].y = e.y + trans.y - root.y
      nvoices = nvoices + 1
    end
  else
    engine.stop(e.id)
    lit[e.id] = nil
    nvoices = nvoices - 1
  end
  gridredraw()
end

function gridredraw()
  -- clear the LEDs on the top and bottom rows
  for i=1,16 do
    g:led(i,1,0)
    g:led(i,8,0)
  end
  g:led(16,2,2 + pat.rec * 10)
  g:led(16,3,2 + pat.play * 10)
  g:led(16,7,2 + mode_transpose * 10)

  if mode_transpose == 1 then g:led(trans.x, trans.y, 4) end
  -- look into our table of lights and light up the notes
  for i,e in pairs(lit) do
    g:led(e.x, e.y,15)
  end
  g:refresh()
end

-- OLED drawing function for phase mod page
local function draw_matrix_outputs()
  for m = 1,6 do
    for n = 1,6 do
      screen.rect(m*9, n*9, 9, 9)

      l = 2
      if selected[m][n] == 1 then
        l = l + 3 + light
      end
      screen.level(l)
      screen.move_rel(2, 6)
      screen.text(math.ceil(mods[m][n]))
      screen.stroke()
    end
  end
  for m = 1,6 do
    screen.rect(75,m*9,9,9)
    screen.move_rel(2, 6)
    screen.text(carriers[m])
    screen.rect(95,m*9,24,9)
    screen.move_rel(2, 6)
    screen.text(params:get("hz"..m))
    screen.stroke()    
  end  
end

-- callbacks for norns encoders
function enc(n,delta)
  if enc_mapping[2] then
    if n == 1 then
      params:delta(enc_mapping[2],delta/8)
      draw_matrix_outputs()
    elseif n == 2 then
      params:delta(enc_mapping[2],delta/16)
      draw_matrix_outputs()
    end
  elseif enc_mapping[3] and n == 3 then
    update_phase_matrix(n,delta)
  end
end

-- function to set random settings when key 2 is pressed
-- TODO: this is broken
local function set_random_phase_mods(n)
    -- clear selected
    for x = 1,6 do
      for y = 1,6 do
        selected[x][y] = 0
        mods[x][y] = 0
        params:set("hz"..x.."_to_hz"..y,mods[x][y])
        g:led(x,y+1,3)
      end
    end
    
    -- choose new random mods
    for i = 1,n do
      x = math.random(6)
      y = math.random(6)
      selected[x][y] = 1
      mods[x][y] = math.random()*tau 
      params:set("hz"..x.."_to_hz"..y,mods[x][y])
      grid_phase_state(x,y+1,1)
    end
end

-- callback for norns key presses
function key(n,z)
  if n == 2 and z== 1 then
    set_random_phase_mods(4)
    redraw()
    gridredraw()
  end
  if n == 3 then
    local note = ((7-math.random(8))*5) + math.random(16)
    if z == 1 then
      if nvoices < MAX_NUM_VOICES then
        engine.start(0, getHzET(note))
        nvoices = nvoices + 1
      end
    else
      engine.stop(0)
      nvoices = nvoices - 1
    end
  end
end

-- callback to redraw the OLED
function redraw()
  screen.clear()
  pages:redraw()
  draw_matrix_outputs()
    
  --[[
  if pages.index == 1 then
    draw_matrix_outputs()
  else
    -- this has been moved to lib/
    draw_algo(pages.index - 1)
  end
  --]]
  
  screen.update()
end

-- note on/off functions for synth engine
-- TODO: pass velocity value to engine amplitude
local function note_on(note, vel)
  if nvoices < MAX_NUM_VOICES then
    --engine.start(id, getHz(x, y-1))
    engine.start(note, MusicUtil.note_num_to_freq(note))
    nvoices = nvoices + 1
  end
end

local function note_off(note, vel)
  engine.stop(note)
  nvoices = nvoices - 1
end

-- callback function for MIDI events
function midi_event(data)
  if #data == 0 then return end
  local msg = midi.to_msg(data)

  -- Note off
  if msg.type == "note_off" then
    note_off(msg.note)

    -- Note on
  elseif msg.type == "note_on" then
    note_on(msg.note, msg.vel / 127)

--[[
    -- Key pressure
  elseif msg.type == "key_pressure" then
    set_key_pressure(msg.note, msg.val / 127)

    -- Channel pressure
  elseif msg.type == "channel_pressure" then
    set_channel_pressure(msg.val / 127)

    -- Pitch bend
  elseif msg.type == "pitchbend" then
    local bend_st = (util.round(msg.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
    local bend_range = params:get("bend_range")
    set_pitch_bend(bend_st * bend_range)

  ]]--
  end
end

-- callback when script is unloaded
function cleanup()
  pat:stop()
  pat = nil
end
