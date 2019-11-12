-- scriptname: step
-- v1.1.4 @jah

engine.name = 'Ack'

local Ack = require 'ack/lib/ack'
-- local UI =include('lib/ui-apcnome') 
local UI = include('lib/ui')

local ControlSpec = require 'controlspec'

local NUM_PATTERNS = 99
local MAX_GRID_WIDTH = 8
local HEIGHT = 8

local PATTERN_FILE = "step.data"

local TRIG_LEVEL = 15
local PLAYPOS_LEVEL = 7
local CLEAR_LEVEL = 0

local tempo_spec = ControlSpec.new(20, 300, ControlSpec.WARP_LIN, 0, 120, "BPM")
local swing_amount_spec = ControlSpec.new(0, 100, ControlSpec.WARP_LIN, 0, 0, "%")

local playing = false
local queued_playpos
local playpos = -1
local sequencer_metro

local ppqn = 24 
local ticks_to_next
local odd_ppqn
local even_ppqn

local trigs = {}

local function cutting_is_enabled()
  return params:get("last_row_cuts") == 2
end

local function set_trig(patternno, x, y, value)
  trigs[patternno*MAX_GRID_WIDTH*HEIGHT + y*MAX_GRID_WIDTH + x] = value
end

local function trig_is_set(patternno, x, y)
  return trigs[patternno*MAX_GRID_WIDTH*HEIGHT + y*MAX_GRID_WIDTH + x]
end

local function init_trigs()
  for patternno=1,NUM_PATTERNS do
    for x=1,MAX_GRID_WIDTH do
      for y=1,HEIGHT do
        set_trig(patternno, x, y, false)
      end
    end
  end
end

local function get_pattern_length()
  if params:get("pattern_length") == 1 then
    return 8
  else
    return 16
  end
end

local function set_pattern_length(pattern_length)
  local opt
  if pattern_length == 8 then
    opt = 1
  else
    opt = 2
  end
  params:set("pattern_length", opt)
end

local function save_patterns()
  local fd=io.open(norns.state.data .. PATTERN_FILE,"w+")
  io.output(fd)
  for patternno=1,NUM_PATTERNS do
    for y=1,HEIGHT do
      for x=1,MAX_GRID_WIDTH do
        local int
        if trig_is_set(patternno, x, y) then
          int = 1
        else
          int = 0
        end
        io.write(int .. "\n")
      end
    end
  end
  io.close(fd)
end

local function load_patterns()
  local fd=io.open(norns.state.data .. PATTERN_FILE,"r")
  if fd then
    io.input(fd)
    for patternno=1,NUM_PATTERNS do
      for y=1,HEIGHT do
        for x=1,MAX_GRID_WIDTH do
          set_trig(patternno, x, y, tonumber(io.read()) == 1)
        end
      end   
    end
    io.close(fd)
  end
end  

local function is_even(number)
  return number % 2 == 0
end

local function tick()
  if queued_playpos and params:get("cut_quant") == 1 then
    ticks_to_next = 0
  end

  if (not ticks_to_next) or ticks_to_next == 0 then
    local previous_playpos = playpos
    if queued_playpos then
      playpos = queued_playpos
      queued_playpos = nil
    else
      playpos = (playpos + 1) % get_pattern_length()
    end
    local ts = {}
    for y=1,8 do
      if trig_is_set(params:get("pattern"), playpos+1, y) and not (cutting_is_enabled() and y == 8) then
        ts[y] = 1
      else
        ts[y] = 0
      end
    end
    engine.multiTrig(ts[1], ts[2], ts[3], ts[4], ts[5], ts[6], ts[7], ts[8])

    if previous_playpos ~= -1 then
      UI.grid_dirty = true
    end
    if playpos ~= -1 then
      UI.grid_dirty = true
    end
    if is_even(playpos) then
      ticks_to_next = even_ppqn
    else
      ticks_to_next = odd_ppqn
    end
    UI.screen_dirty = true
  end
  ticks_to_next = ticks_to_next - 1
end

local function update_sequencer_metro_time()
  sequencer_metro.time = 60/params:get("tempo")/ppqn/params:get("beats_per_pattern")
end

local function update_swing(swing_amount)
  local swing_ppqn = ppqn*swing_amount/100*0.75
  even_ppqn = util.round(ppqn+swing_ppqn)
  odd_ppqn = util.round(ppqn-swing_ppqn)
end

local function init_sequencer_metro()
  sequencer_metro = metro.init()
  update_sequencer_metro_time()
  sequencer_metro.event = tick
end

local function init_params()
  params:add {
    type="option",
    id="pattern_length",
    name="Pattern Length",
    options={8, 16},
    default=8
  }

  params:add {
    type="number",
    id="pattern",
    name="Pattern",
    min=1,
    max=NUM_PATTERNS,
    default=1,
    action=function()
      UI.grid_dirty = true
    end
  }

  params:add {
    type="option",
    id="last_row_cuts",
    name="Last Row Cuts",
    options={"No", "Yes"},
    default=1
  }

  params:add {
    type="option",
    id="cut_quant",
    name="Quantize Cutting",
    options={"No", "Yes"},
    default=1
  }

  params:add {
    type="number",
    id="beats_per_pattern",
    name="Beats Per Pattern",
    min=1,
    max=8,
    default=4,
    action=update_sequencer_metro_time
  }

  params:add {
    type="control",
    id="tempo",
    name="Tempo",
    controlspec=tempo_spec,
    action=function(val)
      update_sequencer_metro_time(val)
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }

  params:add {
    type="control",
    id="swing_amount",
    name="Swing Amount",
    controlspec=swing_amount_spec,
    action=function(val)
      update_swing(val)
      UI.screen_dirty = true
      UI.arc_dirty = true
    end
  }

  params:add_separator()

  Ack.add_params()
end

local function init_60_fps_ui_refresh_metro()
  local ui_refresh_metro = metro.init()
  ui_refresh_metro.event = UI.refresh
  ui_refresh_metro.time = 1/60
  ui_refresh_metro:start()
end

local function init_ui()
  UI.init_arc {
    device = arc.connect(),
    delta_callback = function(n, delta)
      if n == 1 then
        local val = params:get_raw("tempo")
        params:set_raw("tempo", val+delta/500)
      elseif n == 2 then
        local val = params:get_raw("swing_amount")
        params:set_raw("swing_amount", val+delta/500)
      end
    end,
    refresh_callback = function(my_arc)
      my_arc:all(0)
      my_arc:led(1, util.round(params:get_raw("tempo")*64), 15)
      my_arc:led(2, util.round(params:get_raw("swing_amount")*64), 15)
    end
  }

  UI.init_grid {
    device = include('lib/apcnome'),
    key_callback = function(x,y,state)
      print(state)
      if state == 1 then
        if cutting_is_enabled() and y == 8 then
          queued_playpos = x-1
          UI.screen_dirty = true
        else
          set_trig(
            params:get("pattern"),
            x,
            y,
            not trig_is_set(params:get("pattern"), x, y)
          )
          UI.grid_dirty = true
          --flag
        end
      end
      UI.flash_event()
    end,
    refresh_callback = function(my_grid)
      local function refresh_grid_button(x, y)
        if cutting_is_enabled() and y == 8 then
          if x-1 == playpos then
            my_grid:led(x, y, PLAYPOS_LEVEL)
          else
            my_grid:led(x, y, CLEAR_LEVEL)
          end
        else
          if trig_is_set(params:get("pattern"), x, y) then
            my_grid:led(x, y, TRIG_LEVEL)
          elseif x-1 == playpos then
            my_grid:led(x, y, PLAYPOS_LEVEL)
          else
            my_grid:led(x, y, CLEAR_LEVEL)
          end
        end
      end

      local function refresh_grid_column(x)
        for y=1,HEIGHT do
          refresh_grid_button(x, y)
        end
      end

      local function refresh_grid()
        for x=1,MAX_GRID_WIDTH do
          refresh_grid_column(x)
        end
      end

      refresh_grid()
    end,
    width_changed_callback = function(new_width)
      set_pattern_length(new_width)
    end
  }

  UI.init_screen {
    refresh_callback = function()
      redraw()
    end
  }

  init_60_fps_ui_refresh_metro()
end

function init()
  init_trigs()
  init_params()
  init_sequencer_metro()
  load_patterns()
  init_ui()
  playing = true
  sequencer_metro:start()

  params:read()
  params:bang()
end

function cleanup()
  params:write()

  save_patterns()

  if my_grid.device then
    my_grid:all(0)
    my_grid:refresh()
  end
end

function redraw()

  local hi_level = 15
  local lo_level = 4

  local enc1_x = 0
  local enc1_y = 12

  local enc2_x = 16
  local enc2_y = 32

  local enc3_x = enc2_x+45
  local enc3_y = enc2_y

  local key2_x = 0
  local key2_y = 63

  local key3_x = key2_x+45
  local key3_y = key2_y

  local function redraw_enc1_widget()
    screen.move(enc1_x, enc1_y)
    screen.level(lo_level)
    screen.text("LEVEL")
    screen.move(enc1_x+45, enc1_y)
    screen.level(hi_level)
    screen.text(util.round(mix:get_raw("output")*100, 1))
  end

  local function redraw_event_flash_widget()
    screen.level(lo_level)
    screen.rect(122, enc1_y-7, 5, 5)
    screen.fill()
  end

  local function redraw_enc2_widget()
    screen.move(enc2_x, enc2_y)
    screen.level(lo_level)
    screen.text("BPM")
    screen.move(enc2_x, enc2_y+12)
    screen.level(hi_level)
    screen.text(util.round(params:get("tempo"), 1))
  end

  local function redraw_enc3_widget()
    screen.move(enc3_x, enc3_y)
    screen.level(lo_level)
    screen.text("SWING")
    screen.move(enc3_x, enc3_y+12)
    screen.level(hi_level)
    screen.text(util.round(params:get("swing_amount"), 1))
    screen.text("%")
  end

  local function redraw_key2_widget()
    screen.move(key2_x, key2_y)
    if playing then
      screen.level(lo_level)
    else
      screen.level(hi_level)
    end
    screen.text("STOP")
  end

  local function redraw_key3_widget()
    screen.move(key3_x, key3_y)
    if playing then
      screen.level(hi_level)
    else
      screen.level(lo_level)
    end
    screen.text("PLAY")

    if playing then
      screen.move(key3_x+44, key3_y)
      screen.level(hi_level)
      screen.text(playpos+1)
    end
  end

  screen.font_size(16)
  screen.clear()

  redraw_enc1_widget()

  if UI.show_event_indicator then
    redraw_event_flash_widget()
  end

  redraw_enc2_widget()
  redraw_enc3_widget()
  redraw_key2_widget()
  redraw_key3_widget()

  screen.update()
end

function enc(n, delta)
  if n == 1 then
    mix:delta("output", delta)
    UI.screen_dirty = true
  elseif n == 2 then
    params:delta("tempo", delta)
  elseif n == 3 then
    params:delta("swing_amount", delta)
  end
end

function key(n, s)
  if n == 2 and s == 1 then
    if playing == false then
      playpos = -1
      queued_playpos = 0
      UI.grid_dirty = true
      UI.screen_dirty = true
    else
      playing = false
      sequencer_metro:stop()
    end
  elseif n == 3 and s == 1 then
    playing = true
    sequencer_metro:start()
  end
  UI.screen_dirty = true
end
