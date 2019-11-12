-- earthsea: pattern instrument
-- 1.1.0 @tehn
-- llllllll.co/t/21349
--
-- subtractive polysynth
-- controlled by midi or grid
--
-- grid pattern player:
-- 1 1 record toggle
-- 1 2 play toggle
-- 1 8 transpose mode

local tab = require 'tabutil'
local pattern_time = require 'pattern_time'

local polysub = include 'we/lib/polysub'

local g = include('lib/apcnome') 

local mode_transpose = 0
local root = { x=5, y=5 }
local trans = { x=5, y=5 }
local lit = {}

local screen_framerate = 15
local screen_refresh_metro

local ripple_repeat_rate = 1 / 0.3 / screen_framerate
local ripple_decay_rate = 1 / 0.5 / screen_framerate
local ripple_growth_rate = 1 / 0.02 / screen_framerate
local screen_notes = {}

local MAX_NUM_VOICES = 16

local options = {
  OUTPUT = {"audio", "crow out 1+2", "crow ii JF"}
}

engine.name = 'PolySub'

-- pythagorean minor/major, kinda
local ratios = { 1, 9/8, 6/5, 5/4, 4/3, 3/2, 27/16, 16/9 }
local base = 27.5 -- low A

local function getHz(deg,oct)
  return base * ratios[deg] * (2^oct)
end

local function getHzET(note)
  return 55*2^(note/12)
end
-- current count of active voices
local nvoices = 0

function init()
  -- m = midi.connect()
  -- m.event = midi_event

  pat = pattern_time.new()
  pat.process = grid_note_trans

  params:add_option("enc2","enc2", {"shape","timbre","noise","cut"})
  params:add_option("enc3","enc3", {"shape","timbre","noise","cut"}, 2)

  params:add_separator()

  polysub:params()

  params:add_separator()
  
  params:add{type = "option", id = "output", name = "output",
    options = options.OUTPUT,
    action = function(value)
      engine.stopAll()
      stop_all_screen_notes()
      if value == 2 then crow.output[2].action = "{to(5,0),to(0,0.25)}"
      elseif value == 3 then
        crow.ii.pullup(true)
        crow.ii.jf.mode(1)
      end
    end
  }
  
  engine.stopAll()
  stop_all_screen_notes()

  params:bang()

  if g then gridredraw() end

  screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function(stage)
    update()
    redraw()
  end
  screen_refresh_metro:start(1 / screen_framerate)

  local startup_ani_count = 1
  local startup_ani_metro = metro.init()
  startup_ani_metro.event = function(stage)
    start_screen_note(-startup_ani_count)
    stop_screen_note(-startup_ani_count)
    startup_ani_count = startup_ani_count + 1
  end
  startup_ani_metro:start( 0.1, 3 )
  

end

function g.key(x, y, z)
  if x == 1 then
    if z == 1 then
      if y == 1 and pat.rec == 0 then
        mode_transpose = 0
        trans.x = 5
        trans.y = 5
        pat:stop()
        engine.stopAll()
        stop_all_screen_notes()
        pat:clear()
        pat:rec_start()
      elseif y == 1 and pat.rec == 1 then
        pat:rec_stop()
        if pat.count > 0 then
          root.x = pat.event[1].x
          root.y = pat.event[1].y
          trans.x = root.x
          trans.y = root.y
          pat:start()
        end
      elseif y == 2 and pat.play == 0 and pat.count > 0 then
        if pat.rec == 1 then
          pat:rec_stop()
        end
        pat:start()
      elseif y == 2 and pat.play == 1 then
        pat:stop()
        engine.stopAll()
        stop_all_screen_notes()
        nvoices = 0
        lit = {}
      elseif y == 8 then
        mode_transpose = 1 - mode_transpose
      end
    end
  else
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

local function start_note(id, note)
  if params:get("output") == 1 then
    engine.start(id, getHzET(note))
  elseif params:get("output") == 2 then
    crow.output[1].volts = note/12
    crow.output[2].execute()
  elseif params:get("output") == 3 then
    crow.ii.jf.play_note(note/12,5)
  end
end  

local function stop_note(id)
  if params:get("output") == 1 then
    engine.stop(id)
  end      
end

function grid_note(e)
  local note = ((7-e.y)*5) + e.x
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      --engine.start(id, getHz(x, y-1))
      --print("grid > "..id.." "..note)
      start_note(e.id, note)
      start_screen_note(note)
      lit[e.id] = {}
      lit[e.id].x = e.x
      lit[e.id].y = e.y
      -- print(e.x,e.y)
      nvoices = nvoices + 1
    end
  else
    if lit[e.id] ~= nil then
      engine.stop(e.id)
      stop_screen_note(note)
      lit[e.id] = nil
      nvoices = nvoices - 1
    end
  end
  -- gridredraw()
end

function grid_note_trans(e)
  local note = ((7-e.y+(root.y-trans.y))*5) + e.x + (trans.x-root.x)
  if e.state > 0 then
    if nvoices < MAX_NUM_VOICES then
      --engine.start(id, getHz(x, y-1))
      --print("grid > "..id.." "..note)
      start_note(e.id, note)
      start_screen_note(note)
      lit[e.id] = {}
      lit[e.id].x = e.x + trans.x - root.x
      lit[e.id].y = e.y + trans.y - root.y
      nvoices = nvoices + 1
    end
  else
    stop_note(e.id)
    stop_screen_note(note)
    lit[e.id] = nil
    nvoices = nvoices - 1
  end
  gridredraw()
end

function gridredraw()
  g:all(0)
  g:led(1,1,2 + pat.rec * 10)
  g:led(1,2,2 + pat.play * 10)
  g:led(1,8,2 + mode_transpose * 10)

  if mode_transpose == 1 then g:led(trans.x, trans.y, 4) end
  for i,e in pairs(lit) do
    g:led(e.x, e.y,15)
  end

  g:refresh()
end



function enc(n,delta)
  if n == 1 then
    mix:delta("output", delta)
  elseif n == 2 then
    params:delta(params:string("enc2"),delta*4)
  elseif n == 3 then
    params:delta(params:string("enc3"),delta*4)
  end
end

function key(n,z)
end

function start_screen_note(note)
  local screen_note = nil

  -- Get an existing screen_note if it exists
  local count = 0
  for key, val in pairs(screen_notes) do
    if val.note == note then
      screen_note = val
      break
    end
    count = count + 1
    if count > 8 then return end
  end

  if screen_note then
    screen_note.active = true
  else
    screen_note = {note = note, active = true, repeat_timer = 0, x = math.random(128), y = math.random(64), init_radius = math.random(6,18), ripples = {} }
    table.insert(screen_notes, screen_note)
  end

  add_ripple(screen_note)

end

function stop_screen_note(note)
  for key, val in pairs(screen_notes) do
    if val.note == note then
      val.active = false
      break
    end
  end
end

function stop_all_screen_notes()
  for key, val in pairs(screen_notes) do
    val.active = false
  end
end

function add_ripple(screen_note)
  if tab.count(screen_note.ripples) < 6 then
    local ripple = {radius = screen_note.init_radius, life = 1}
    table.insert(screen_note.ripples, ripple)
  end
end

function update()
  for n_key, n_val in pairs(screen_notes) do

    if n_val.active then
      n_val.repeat_timer = n_val.repeat_timer + ripple_repeat_rate
      if n_val.repeat_timer >= 1 then
        add_ripple(n_val)
        n_val.repeat_timer = 0
      end
    end

    local r_count = 0
    for r_key, r_val in pairs(n_val.ripples) do
      r_val.radius = r_val.radius + ripple_growth_rate
      r_val.life = r_val.life - ripple_decay_rate

      if r_val.life <= 0 then
        n_val.ripples[r_key] = nil
      else
        r_count = r_count + 1
      end
    end

    if r_count == 0 and not n_val.active then
      screen_notes[n_key] = nil
    end
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.line_width(1)

  local first_ripple = true
  for n_key, n_val in pairs(screen_notes) do
    for r_key, r_val in pairs(n_val.ripples) do
      if first_ripple then -- Avoid extra line when returning from menu
        screen.move(n_val.x + r_val.radius, n_val.y)
        first_ripple = false
      end
      screen.level(math.max(1,math.floor(r_val.life * 15 + 0.5)))
      screen.circle(n_val.x, n_val.y, r_val.radius)
      screen.stroke()
    end
  end

  screen.update()
end

function note_on(note, vel)
  if nvoices < MAX_NUM_VOICES then
    --engine.start(id, getHz(x, y-1))
    engine.start(note, getHzET(note))
    start_screen_note(note)
    nvoices = nvoices + 1
  end
end

function note_off(note, vel)
  engine.stop(note)
  stop_screen_note(note)
  nvoices = nvoices - 1
end


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


function cleanup()
  stop_all_screen_notes()
  pat:stop()
  pat = nil
end
