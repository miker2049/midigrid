-- vials
-- a binary rhythmbox
-- v1.0 @nattog
--
-- - - - - - - - - - - - - - - - -
-- 4x4 decimal vials
-- represented binary
-- create rhythms
-- - - - - - - - - - - - - - - - -
-- hold k1 to start
--
-- k2 change step
-- e1 change tempo
-- e2 change track
-- e3 change decimal
--
-- k1 (hold) + k2 resets
-- k1 (hold) + k3 stops
-- k2 (hold) + k3 mute
-- k2 (hold) + k2 rotates binary sequence
-- k2 (hold) + e3 probability
-- k3 + e3 loads pattern
--
-- GRID (top-left clockwise)
-- sample triggers
-- track mutes
-- reverb sends (y5 kill all)
--
-- 4x4 segment looper
-- nav to left and below
-- param view
--
-- phone pad decimal input
-- hold right next to 3
-- for XX, XXX
--
-- shift sequences up or down
-- rotate sequence left or right
--
-- hold to load (top) or save (bottom)
--
-- seq reset
-- play/stop
--
-- above = reverb
-- rev level
-- random short
-- random mid
-- random long
-- enc edit view - HOLD
-- level, size, damp
-- controlled by encs 1,2,3
--
-- below = echo
-- echo in
-- echo edit view - HOLD
-- level, rate and fbk
-- controlled by encs 1,2,3
-- randomise echo
-- kill echo
--
-- binary input x1-x8, y7
-- row below makes nil
--
-- bug reports to @nattog
-- thanks!
--

engine.name = "Ack"
local ack = require "ack/lib/ack"
local BeatClock = require "beatclock"
local ControlSpec = require "controlspec"
local hs = include "awake/lib/halfsecond"
local vials_utils = include("lib/vials_utils")
-- local g = grid.connect()
local g = include('lib/apcnome_2pages')
local external = false
local clk = BeatClock.new()
local m = midi.connect(2)
local color = 3 -- screen values
local value_color = color + 5
local number = 0
local screen_x = 0
local screen_y = 0
local word_font = 1
local number_font = 23
local key1_hold = false -- key setup
local key2_hold = false
local key3_hold = false
local calc_hold = 0
local calc_input = {}
local rotate_dirty = false
local binary_input = {nil, nil, nil, nil, nil, nil, nil}
local vials = {} -- sequence vars
local note_off_queue = {34, 35, 36, 37}
local vi = {}
for j = 1, 15 do
  vi[j] = {}
  for v = 1, 4 do
    vi[j][v] = {
      pos = 0,
      prob = 100,
      mute = 0,
      seq = {0},
      steps = {0, 0, 0, 0},
      rotations = 0,
      division = 1,
      loop = 0
    }
  end
end
local current_vials = 1
local selected = 0
local decimal_value = 0
local track = 1
local bpm = 120
local playing = false
local reset = false
local meta_position = 0
local div_options = {1, 2, 3, 4, 6, 8, 12, 16}
local param_view = 0
local param_sel = 1
local delay_view = 0
local delay_in = 1
local reverb_view = 0
local ls_view = 0
local mceil = math.ceil
local rand = math.random

local function start()
  playing = true
  just_started = true
  clk:start()
end

local function note_off()
  if params:get("send_midi") == 1 then
    for i = 1, #note_off_queue do
      m:note_off(note_off_queue[i])
    end
  end
end

local function reset_positions()
  meta_position = 0
  just_started = true
  for iter = 1, 4 do
    vials[iter].pos = 0
  end
  note_off()
end

local function stop()
  clk:stop()
  playing = false
  reset_positions()
  print("stop")
  vials_save()
end

local function reset_vials()
  for v = 1, 4 do
    vials[v] = {
      pos = 0,
      prob = 100,
      mute = 0,
      seq = {0},
      steps = {0, 0, 0, 0},
      rotations = 0,
      division = 1,
      loop = 0
    }
  end
  decimal_value = 0
  binary_input = {nil, nil, nil, nil, nil, nil, nil}
  redraw()
  grid_redraw()
end

local function reset_pattern()
  clk:reset()
  external = true
  for iter = 1, 4 do
    vials[iter].pos = 0
  end
  meta_position = 0
  note_off()
end

m.event = function(data)
  clk:process_midi(data)
  if data[1] == 252 and external then
    stop()
  end
end

local function clock_divider(track)
  return vials[track].division
end

function count()
  local midi_send = (params:get("send_midi") == 1)
  meta_position = (meta_position % 16) + 1
  grid_redraw()
  note_off()
  for t = 1, 4 do
    -- check division
    div = clock_divider(t)
    local counter = meta_position % div
    if (counter > 0 and just_started) or counter == 0 then
      -- wrap sequence when reaches length of seq
      if vials[t].pos >= #vials[t].seq then
        vials[t].pos = 0
      end
      -- change position
      vials[t].pos = (vials[t].pos + 1)
      local pos = vials[t].pos
      -- trigger note
      if vials[t].seq[pos] == 1 then
        if rand(100) <= vials[t].prob and vials[t].mute == 0 then
          engine.trig(t - 1)
          if midi_send then
            local note = params:get(t .. ":_midi_note")
            note_off_queue[t] = note
            m:note_on(note, 100, params:get("midi_chan"))
          end
        end
      end
    end
  end
  -- redraw grid
  redraw()
  just_started = false
end

local function binary_string(track)
  local x = ""
  local i
  for i = 1, 4 do
    if vials[track].steps[i] ~= nil and vials[track].steps[i] ~= 0 then
      local y = vials_utils.dec_to_bin(vials[track].steps[i])
      x = x .. y
    end
  end
  return x
end

local function calc_binary_input()
  local bin_rep = tostring(vials_utils.dec_to_bin(decimal_value))
  binary_input = vials_utils.split_str(bin_rep)
end

local function loop_on(t)
  local x
  local track = vials[t]
  bin = vials_utils.dec_to_bin(track.steps[track.loop])
  if vials[t].rotations > #bin then
    vials[t].rotations = 0
  end
  x = tostring(bin)
  vials[t].seq = vials_utils.split_str(x)
  redraw()
end

function generate_sequence(t)
  local seq_string = binary_string(t)
  local seq_tab
  if vials[t].loop == 0 then
    seq_tab = vials_utils.split_str(seq_string)
  else
    local x = vials_utils.dec_to_bin(vials[t].steps[vials[t].loop])
    seq_tab = vials_utils.split_str(x)
  end
  local seq_rotates = vials_utils.rotate(seq_tab, vials[t].rotations)
  return seq_rotates
end

local function change_focus()
  decimal_value = vials[track].steps[selected + 1]
  calc_binary_input()
  calc_input = {}
end

local function loop_off(t)
  vials[t].loop = 0
  vials[t].seq = generate_sequence(t)
  redraw()
end

function change_selected(inp)
  selected = (selected + inp) % 4
  change_focus()
  grid_redraw()
end

function change_decimal(d)
  local vial = vials[track]
  decimal_value = ((vial.steps[selected + 1] + d) % 256)
  vial.steps[selected + 1] = decimal_value
  if vial.loop == 0 then
    vials[track].seq = generate_sequence(track)
  elseif vial.loop == selected + 1 then
    loop_on(track)
  end
  calc_binary_input()
  grid_redraw()
end

local function make_nil(t, ind)
  if ind > 1 then
    for iter = 1, ind - 1 do
      t[iter] = nil
    end
  else
    for iter = 1, #t do
      t[iter] = nil
    end
  end
  decimal_value = 0
  calc_binary_input()
  return t
end

local function position_vis()
  local phase
  if vials[track].loop > 0 then
    phrase = vials_utils.dec_to_bin(vials[track].steps[vials[track].loop])
  else
    phrase = binary_string(track)
  end
  local temp = {} -- rotate

  phrase:gsub(
    ".",
    function(c)
      table.insert(temp, c)
    end
  )
  phrase_rotated = vials_utils.rotate(temp, vials[track].rotations)
  phrase = vials_utils.concatenate_table(phrase_rotated)
  if vials[track].pos > 0 then
    screen.text(string.sub(phrase, 1, vials[track].pos - 1))
  end
  screen.level(value_color)
  screen.text(string.sub(phrase, vials[track].pos, vials[track].pos))
  screen.level(color)
  screen.text(string.sub(phrase, vials[track].pos + 1, #phrase))
end

function redraw()
  screen.clear()
  if delay_view == 0 and reverb_view == 0 and param_view == 0 then
    screen.level(color)
    screen.font_face(word_font)
    screen.font_size(8)
    screen.move(0, 10)
    screen.text("bpm ")
    screen.level(value_color)
    if external then
      screen.font_face(1)
      screen.text("ext")
    else
      screen.font_face(number_font)
      screen.text(params:get("bpm"))
    end
    screen.move(80, 10)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("pattern ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(current_vials)
    screen.move(0, 20)
    screen.font_size(6)
    screen.font_face(15)
    screen.level(color)
    position_vis()
    screen.move((vials[track].rotations + 0.2) * 3.9999, 21)
    screen.text("_")
    screen.font_face(number_font)
    screen.font_size(8)
    screen_y = 32
    screen.move(0, screen_y)
    for i = 1, 4 do
      for j = 1, 4 do
        if i == track then
          screen.level(value_color)
        end
        screen.text(vials[i].steps[j])
        if i == track then
          if j == selected + 1 then
            screen.font_size(6)
            screen.text("*")
            screen.font_size(8)
          end
        end
        screen.level(color)
        screen_x = screen_x + 20
        screen.move(screen_x, screen_y)
      end
      screen_x = 0
      screen_y = screen_y + 10
      screen.move(screen_x, screen_y)
    end
    screen.move(80, 32)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("div ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(vials[track].division)
    if vials[track].mute == 1 then
      screen.font_face(word_font)
      screen.text("   m")
    end
    screen.move(80, 42)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("prob ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(vials[track].prob)
    screen.font_face(word_font)
    screen.text("%")
    screen.move(80, 52)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("binary")
    screen.move(80, 62)
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(vials_utils.dec_to_bin(decimal_value))
    screen.update()
  elseif delay_view > 0 then
    screen_x = (15 * params:get("delay_rate"))
    screen_y = 10
    screenL = mceil(params:get("delay") * 10) + 3
    for i = 1, (params:get("delay_feedback") * 40) + 1 do
      screen.font_face(11)
      screen.level(screenL)
      screen.font_size(15)
      screen.move(screen_x, screen_y)
      screen.text("e c h o ")
      screen_x = screen_x + 10
      screen_y = screen_y + 12 * params:get("delay_rate")
      if screenL > 0 then
        screenL = screenL - 1
      end
    end
    screen.update()
  elseif reverb_view > 0 then
    screen.line_width(2)
    screen.level(15 - (mceil(params:get("reverb_damp") * 15)))
    screen.rect(0, 80, params:get("reverb_room_size") * 125, -80 - params:get("reverb_level"))
    screen.fill()
    screen.update()
  elseif param_view > 0 then
    local sample_name = vials_utils.split(params:get(param_view .. "_sample"), "/")
    screen.font_face(word_font)
    screen.move(5, 20)
    screen.text("track " .. param_view)
    screen.move(60, 20)
    screen.text(sample_name[#sample_name])
    if param_sel == 1 then
      screen.level(value_color)
    else
      screen.level(color)
    end
    screen.move(5, 40)
    screen.text("vol " .. vials_utils.round(params:get(param_view .. "_vol"), 3))
    screen.move(5, 50)
    screen.text("speed " .. vials_utils.round(params:get(param_view .. "_speed"), 3))
    screen.move(5, 60)
    screen.text("dist " .. params:get(param_view .. "_dist"))
    if param_sel == 2 then
      screen.level(value_color)
    else
      screen.level(color)
    end
    screen.move(60, 40)
    screen.text("cutoff " .. mceil(params:get(param_view .. "_filter_cutoff")))
    screen.move(60, 50)
    screen.text("res " .. vials_utils.round(params:get(param_view .. "_filter_res"), 3))
    screen.move(60, 60)
    screen.text("env amt " .. vials_utils.round(params:get(param_view .. "_filter_env_mod"), 2))
    screen.update()
  end
end

function key(n, z)
  if param_view == 0 then
    if n == 1 then --key 1 === START/STOP
      if z == 1 then
        key1_hold = true
        if not playing then
          start()
        end
      else
        key1_hold = false
      end
    end
    if z == 1 and key1_hold then
      if n == 3 then -- stop
        stop()
        reset_positions()
      elseif n == 2 then -- reset
        reset_positions()
      end
    end
    if n == 2 then --key 2 CHANGE SLOT
      if z == 1 and not key1_hold and not key3_hold then
        key2_hold = true
        change_selected(z)
      elseif z == 0 then
        key2_hold = false
      end
    end
    if n == 3 then --key 3 ALT MODE
      if z == 1 then
        key3_hold = true
      else
        key3_hold = false
      end
    end
    if n == 2 and z == 1 and key3_hold then -- ROTATE
      vials[track].rotations = vials[track].rotations + 1
      if vials[track].loop > 0 then
        if vials[track].rotations >= #vials_utils.dec_to_bin(vials[track].steps[vials[track].loop]) then
          vials[track].rotations = 0
        end
      else
        if vials[track].rotations >= #(vials[track].seq) then
          vials[track].rotations = 0
        end
      end
      vials[track].seq = generate_sequence(track)
    end
    if n == 3 and z == 1 and key2_hold then -- MUTE TRACK
      vials[track].mute = 1 - vials[track].mute
    end
  else
    if z == 1 and n > 1 then
      param_sel = n - 1
    end
  end
  redraw()
end

function enc(n, d)
  if delay_view < 1 and reverb_view < 1 and param_view < 1 then
    if n == 2 and not key2_hold then -- change track
      track = util.clamp(track + d, 1, 4)
      change_focus()
    end
    if n == 3 then -- change decimal
      if not key2_hold and not key3_hold then
        change_decimal(d)
      elseif key2_hold then
        vials[track].prob = (vials[track].prob + d) % 101
      elseif key3_hold then
        current_vials = util.clamp(current_vials + d, 1, 15)
        load_save(current_vials, 1)
      end
    end
    if n == 1 then -- change bpm
      params:delta("bpm", d)
    end
    if n == 2 and key2_hold then -- change division
      local div_amt = vials[track].division
      vials[track].division = util.clamp(div_amt + d, 1, 8)
    end
    grid_redraw()
  elseif delay_view > 0 then
    if n == 1 then
      params:delta("delay", d)
    elseif n == 2 then
      params:delta("delay_rate", d)
    elseif n == 3 then
      params:delta("delay_feedback", d)
    end
  elseif reverb_view > 0 then
    if n == 1 then
      params:delta("reverb_level", d)
    elseif n == 2 then
      params:delta("reverb_room_size", d)
    elseif n == 3 then
      params:delta("reverb_damp", d)
    end
  elseif param_view > 0 then
    if param_sel == 1 then
      if n == 1 then
        params:delta(param_view .. "_vol", d)
      elseif n == 2 then
        params:delta(param_view .. "_speed", d)
      elseif n == 3 then
        params:delta(param_view .. "_dist", d)
      end
    else
      if n == 1 then
        params:delta(param_view .. "_filter_cutoff", d)
      elseif n == 2 then
        params:delta(param_view .. "_filter_res", d)
      elseif n == 3 then
        params:delta(param_view .. "_filter_env_mod", d)
      end
    end
  end
  redraw()
end

function vials_save() -- save seq data
  local file = io.open(_path.data .. "vials.data", "w+")
  io.output(file)
  io.write("v1" .. "\n")
  for x = 1, 15 do
    for y = 1, 4 do
      for z = 1, 4 do
        io.write(vi[x][y].steps[z] .. "\n")
      end
      io.write(vi[x][y].rotations .. "\n")
      io.write(vi[x][y].mute .. "\n")
      io.write(vi[x][y].division .. "\n")
      io.write(vi[x][y].prob .. "\n")
      io.write(vi[x][y].loop .. "\n")
    end
  end
  io.write(params:get("bpm") .. "\n")
  io.close(file)
end

function vials_load() -- load seq data
  local file = io.open(_path.data .. "vials.data", "r")
  if file then
    print("datafile found")
    io.input(file)
    if io.read() == "v1" then
      for x = 1, 15 do
        for y = 1, 4 do
          for z = 1, 4 do
            vi[x][y].steps[z] = tonumber(io.read()) or 0
          end
          vi[x][y].rotations = tonumber(io.read()) or 0
          vi[x][y].mute = tonumber(io.read()) or 0
          vi[x][y].division = tonumber(io.read()) or 1
          vi[x][y].prob = tonumber(io.read()) or 100
          vi[x][y].loop = tonumber(io.read()) or 0
        end
      end
      params:set("bpm", tonumber(io.read()) or 100)
    else
      print("invalid data file")
    end
    io.close(file)
  end
end

local function menu_save()
  vi[current_vials] = vials_utils.deepcopy(vials)
end

function load_save(x, y)
  if y == 1 then -- load
    current_vials = x
    vials = vials_utils.deepcopy(vi[current_vials])
    print("loaded: " .. x)
    for i = 1, 4 do
      vials[i].seq = generate_sequence(i)
    end
    redraw()
    grid_redraw()
  else -- save
    vi[x] = vials_utils.deepcopy(vials)
    print("saved: " .. x)
  end
end

-- GRID FUNCTIONS
function grid_redraw()
  if g == nil then
    return
  end
  if ls_view == 1 then
    g:all(0)
    for x = 1, 15 do
      g:led(x, 1, 3)
      g:led(x, 8, 3)
    end
    return
  else
    g:all(0)
    g:led(16, 5, 3)
  end
  for iter = 1, 8 do -- binary pattern leds
    if binary_input[iter] ~= nil and iter <= #binary_input then
      g:led(iter, 7, 7 + 7 * binary_input[iter])
    else
      g:led(iter, 7, 2)
    end
  end
  for t = 1, 4 do
    g:led(1, t, 7) -- sample triggers
    g:led(9, t, 3) -- param view
    g:led(2, t, 5 + vials[t].mute * 10) -- mutes
    g:led(3, t, 3) -- reverb send
    for r = 5, 8 do
      g:led(r, t, 7) -- 4x4 grid
    end
  end
  if meta_position % 4 == 0 then -- clock indicator
    g:led(16, 8, 15)
  else
    g:led(16, 8, 1)
  end
  if not playing then
    g:led(16, 8, 5)
  end
  g:led(16, 7, 5) -- reset
  g:led(11, 8, (3 + delay_view * 10)) -- delay
  g:led(10, 8, (3 + delay_in * 10))
  g:led(12, 8, 3)
  g:led(13, 8, 3)
  for i = 10, 14 do -- reverb
    g:led(i, 7, 3)
  end
  for tr = 1, 4 do -- 4x4 location
    if tr == track then
      g:led(4, tr, 5)
    else
      g:led(4, tr, 0)
    end
  end
  for sel = 0, 3 do
    if sel == selected then
      g:led(sel + 5, 5, 5)
    else
      g:led(sel + 5, 5, 0)
    end
  end
  for y = 1, 4 do -- loop
    if vials[y].loop > 0 then
      g:led(vials[y].loop + 4, y, 15)
    end
  end
  g:led(14, 2, 5) -- rotator
  g:led(16, 2, 5)
  g:led(15, 1, 5)
  g:led(15, 3, 5)
  for u = 1, 3 do --  calculator
    for v = 1, 3 do
      g:led(u + 9, v, 7)
    end
    g:led(11, 4, 7)
  end
  g:led(13, 1, 2 + calc_hold * 10) -- calc_hold
  g:refresh()
end

local function calculate_minus(y)
  if y == 1 then
    return 9
  elseif y == 2 then
    return 6
  else
    return 3
  end
end

local function new_pos_selector()
  calc_input = {}
  decimal_value = vials[track].steps[selected + 1]
  binary_input = vials_utils.split_str(vials_utils.dec_to_bin(decimal_value))
end

g.key = function(x, y, z)
  if ls_view == 1 and x < 16 then
    load_save(x, y)
    return
  end
  if x == 16 and y == 5 then
    ls_view = 1 - ls_view
  end

  if z == 1 then
    if x == 2 and y < 5 then -- mute track
      vials[y].mute = 1 - vials[y].mute
    end
    if x == 16 and y == 8 then -- start/stop
      if not playing then
        start()
      else
        stop()
      end
    end
    if x == 16 and y == 7 then -- reset sequences
      reset_positions()
    end
    if x == 4 and y < 5 then -- track/selec nav
      track = y
      new_pos_selector()
    end
    if y == 5 and x > 4 and x < 9 then
      selected = x - 5
      new_pos_selector()
    end
    if x >= 5 and x < 9 and y < 5 then -- loop
      if vials[y].loop == x - 4 then
        vials[y].loop = 0
        loop_off(y)
      else
        vials[y].loop = x - 4
        loop_on(y)
      end
    end
    if x == 10 and y == 8 then
      delay_in = 1 - delay_in
      audio.level_eng_cut(delay_in)
    end
    if x == 12 and y == 8 then
      params:set("delay_rate", (rand(200)) / 100)
      params:set("delay_feedback", (rand(100)) / 100)
    end
    if x == 13 and y == 8 then
      delay_view = 0
      params:set("delay", delay_view)
    end
    if x == 3 then
      if y < 5 then
        if params:get(y .. "_reverb_send") == -60.0 then
          params:set(y .. "_reverb_send", 0)
        else
          params:set(y .. "_reverb_send", -60.0)
        end
      elseif y == 5 then
        for mute_rev_in = 1, 4 do
          params:set(mute_rev_in .. "_reverb_send", -60.0)
        end
      end
    end
    if y == 7 then
      if x == 10 then -- reverb level
        if params:get("reverb_level") > -20.0 then
          params:set("reverb_level", -80.0)
        else
          params:set("reverb_level", -10.0)
        end
      elseif x == 11 then -- short spaces
        params:set("reverb_room_size", rand(25) / 100)
        params:set("reverb_damp", rand(75, 100) / 100)
      elseif x == 12 then -- mid spaces
        params:set("reverb_room_size", rand(25, 75) / 100)
        params:set("reverb_damp", rand(40, 80) / 100)
      elseif x == 13 then -- long spaces
        params:set("reverb_room_size", rand(75, 100) / 100)
        params:set("reverb_damp", rand(30, 80) / 100)
      end
    end
  end
  if x == 9 and y < 5 then -- param view
    param_view = z * y
  end
  if x == 11 and y == 8 then -- fx
    delay_view = 0 + z
    params:set("delay", delay_view)
    redraw()
  end
  if x == 14 and y == 7 then
    reverb_view = 0 + z
  end
  if x == 16 and y == 5 then
    ls_view = 0 + z
    grid_redraw()
  end
  if x <= 8 and y == 8 and z == 1 then -- make a bit nil
    for iter = x, #binary_input do
      binary_input[iter] = nil
    end
    if not vials_utils.check_nil(binary_input) then
      binary = vials_utils.concatenate_table(binary_input)
      vials[track].steps[selected + 1] = tonumber(binary, 2)
      decimal_value = vials[track].steps[selected + 1]
    else
      vials[track].steps[selected + 1] = 0
      decimal_value = 0
    end
    if vials[track].loop < 1 then
      vials[track].seq = generate_sequence(track)
    elseif selected + 1 == vials[track].loop then
      loop_on(track)
    end
  end
  if x <= 8 and y == 7 and z == 1 then -- binary input
    if vials_utils.check_nil(binary_input) then -- if array of nil
      binary_input[x] = 1
      for bina = x + 1, #binary_input do
        binary_input[bina] = 0
      end
    else
      local index_1 = vials_utils.table_index(binary_input)
      if binary_input[x] == nil or binary_input[x] == 0 then
        if x < index_1 then
          binary_input[x] = 1
          for j_iter = x + 1, index_1 - 1 do
            if binary_input[j_iter] == nil then
              binary_input[j_iter] = 0
            end
          end
        elseif x > index_1 then
          binary_input[x] = 1
          for k_iter = index_1 + 1, x - 1 do
            if binary_input[k_iter] == nil then
              binary_input[k_iter] = 0
            end
          end
        end
      elseif binary_input[x] == 1 then
        local ind1 = vials_utils.first_index(binary_input)
        if x == ind1 then
          if vials_utils.tally(binary_input) == 1 then
            make_nil(binary_input, ind1)
            decimal_value = 0
          else
            binary_input[x] = nil
            local indexx = vials_utils.first_index(binary_input)
            for n_iter = x + 1, indexx - 1 do
              binary_input[n_iter] = nil
            end
          end
        elseif x > ind1 then
          binary_input[x] = 0
        end
      end
    end
    local binary = vials_utils.concatenate_table(binary_input)
    local newNumber = tonumber(binary, 2)
    if newNumber ~= nil then
      vials[track].steps[selected + 1] = newNumber
    else
      vials[track].steps[selected + 1] = 0
    end
    decimal_value = vials[track].steps[selected + 1]
    if vials[track].loop < 1 then
      vials[track].seq = generate_sequence(track)
    elseif selected + 1 == vials[track].loop then
      loop_on(track)
    end
    g:refresh()
  end
  if x == 13 and y == 1 and z == 1 then -- calc hold
    calc_hold = 1 - calc_hold
  end
  if z == 1 and x >= 10 and x < 13 and y <= 4 then -- calculator
    if y == 4 and (x == 10 or x == 12) then
      return
    end
    local y_reducer = calculate_minus(y)
    if calc_hold == 0 then
      calc_input = {}
      final_input = ""
      if y == 4 then
        calc_input[1] = 0
      else
        calc_input[1] = x - y_reducer
      end
    elseif calc_hold == 1 then
      if y == 4 then
        calc_input[#calc_input + 1] = 0
      else
        calc_input[#calc_input + 1] = x - y_reducer
      end
    end
    final_input = final_input .. calc_input[1]
    if #final_input == 3 then
      calc_hold = 0
    end
    if tonumber(final_input) > 255 then
      final_input = calc_input[1]
    end
    calc_input = {}
    vials[track].steps[selected + 1] = tonumber(final_input)
    decimal_value = vials[track].steps[selected + 1]
    if vials[track].loop == 0 then
      vials[track].seq = generate_sequence(track)
    elseif selected + 1 == vials[track].loop then
      loop_on(track)
    end
    calc_binary_input()
  end
  if z == 1 and y == 2 then -- rotator
    if #vials[track].seq > 0 then
      if x == 14 then
        vials[track].rotations = vials[track].rotations - 1
        if vials[track].rotations == -1 then
          vials[track].rotations = #vials[track].seq - 1
        end
      elseif x == 16 then
        vials[track].rotations = vials[track].rotations + 1
        if vials[track].rotations >= #vials[track].seq then
          vials[track].rotations = 0
        end
      end
      vials[track].seq = generate_sequence(track)
    end
  end
  if z == 1 and x == 15 and (y == 1 or y == 3) then -- track shift
    local shift = y - 2
    local rotated_tracks = {}
    local t_rotations = {}
    if shift == 1 then
      rotated_tracks = {vials[4].steps, vials[1].steps, vials[2].steps, vials[3].steps}
      t_rotations = {vials[4].rotations, vials[1].rotations, vials[2].rotations, vials[3].rotations}
    else
      rotated_tracks = {vials[2].steps, vials[3].steps, vials[4].steps, vials[1].steps}
      t_rotations = {vials[2].rotations, vials[3].rotations, vials[4].rotations, vials[1].rotations}
    end
    for iter = 1, 4 do
      vials[iter].steps = rotated_tracks[iter]
      vials[iter].rotations = t_rotations[iter]
      vials[iter].seq = generate_sequence(iter)
    end
    calc_binary_input()
  end
  g:refresh()
  grid_redraw()
  redraw()
  if x == 1 and y < 5 then -- trigger samples
    if z == 1 then
      engine.trig(y - 1)
    end
  end
end

function init()
  clk.on_step = count -- clock setup
  clk.on_select_internal = function()
    clk:start()
    external = false
  end
  clk.on_select_external = reset_pattern
  external = false
  clk:add_clock_params() -- params
  params:add_number("midi_chan", "midi chan", 1, 16, 1)
  params:add_option("send_midi", "send midi", {"yes", "no"}, 1)
  params:add_separator()
  params:add {type = "trigger", id = "Save", name = "save pattern", action = menu_save}
  params:add {type = "trigger", id = "Clear", name = "clear vials", action = reset_vials}
  params:add_separator()
  for channel = 1, 4 do
    params:add_number(channel .. ":_midi_note", channel .. ": midi note", 1, 127, 32 + channel)
    ack.add_channel_params(channel)
    params:add_separator()
  end
  ack.add_effects_params()
  hs.init() -- halfsecond
  params:set("delay", 0)
  vials_load()
  vials = vials_utils.deepcopy(vi[current_vials])
  for init_t = 1, 4 do
    vials[init_t].seq = generate_sequence(init_t)
    track = track + 1
  end
  track = 1
  change_focus()
  grid_redraw()
end

function cleanup()
  clk:stop()
  note_off()
  vials_save()
end
