-- shfts
-- 2 voice double binary shift register
-- + midi + dual quantizers
--
-- enc1: bpm
-- enc2: voice 1 pitch offset
-- enc3: voice 2 pitch offset
-- key2: start/stop voice 1
-- key3: start/stop voice 2
-- 
-- Midi device/channel output can be set per voice in params
-- Crow support - clock in on input 2
-- gate/pitch out on cv pairs 1/2, 3/4
-- 
-- GRID UI
-- 2 identical voices, 8 columns each
-- row 1 - pitch register bit display
-- row 2 - trigger register bit display
-- row 3 - clock division
-- row 4 - trigger bias (more triggers to the right)
-- row 5 - pitch rate of change (more change to the right)
-- row 6 - trigger rate of change (more change to the right)
-- row 7 - quantizer presets - hold a button and press keys from row 1-6; 
-- layout is perfect fourths vertical, chromatic scale horizontal
-- a nice pentatonic scale:
--    0 X 0 0 0 0 0 0
--    0 X 0 X 0 0 0 0
--    0 X 0 0 X 0 0 0
--    0 0 0 0 0 0 0 0
-- row 8 :
-- -- col 1: 1 start/stop clock
-- -- col 2: single-step register 
-- -- col 3: reduce loop length
-- -- col 4: increase loop length
-- -- col 5-8: pitch range (1-4 octaves)
-- all controls repeated on columns 9-16 for voice 2
-- this should work with a 8x8 grid I think?

beatclock = require 'beatclock'

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local bpm = 108

local clk = beatclock.new()
clk.ticks_per_step = 1
clk.steps_per_beat = 24
clk:bpm_change(bpm)
-- local clk_midi = midi.connect(1)
-- clk_midi.event = function(data)
--   print("clock got midi " .. dump(data))
--   clk:process_midi(data)
-- end

local midi_chan = {
  {1,6,nil},
  {1,8,nil}
}

function midi_panic()
  for ch = 1,#midi_chan do
    local chan= midi_chan[ch]
    if chan[3] ~= nil then
      print("stopping all midi notes on device " .. chan[1] .. ", channel " .. chan[2] .. " : " .. tostring(chan[3]))
      chan[3]:cc(123,chan[2] - 1,1)
    end
  end
end

function midi_setup()
  for ch = 1,#midi_chan do
    midi_chan[ch][3] = midi.connect(midi_chan[ch][1])
    if ch == 1 then
      -- print("enabling midi clock on channel " .. ch)
      midi_chan[ch][3].event = function(data) 
        -- print("processing midi clock")
        clk:process_midi(data)
      end
    else 
      -- print("disabling midi clock on channel " .. ch)
      if midi_chan[ch][1] ~= midi_chan[1][1] then
        midi_chan[ch][3].event = function(data) 
          -- print("ignoring midi clock")
        end
      end
    end
  end
  midi_panic()
end

local g

local r11 = {12,0,0,12,0,0,0,0,0,0,0,0,0,0,0,0}
local r12 = {9,2,11,6,15,0,0,0,0,0,0,0,0,0,0,0}
local r21 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local r22 = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

r1_len = 6
r2_len = 6

r1_prob_p = 5
r1_prob_t = 5
r2_prob_p = 11
r2_prob_t = 11

r1_rate = 6
r2_rate = 12

r1_bias_p = 8
r1_bias_t = 5
r2_bias_p = 8
r2_bias_t = 11

r1_offset_p = 48
r2_offset_p = 60

r1_pitch_range = 1
r2_pitch_range = 3

local last_note_1 = 0
local last_note_2 = 0
local last_notes = {0,0}

local note_duration_stacks = {
  {},
  {}
}

local pulse_off = {
  metro.init(),
  metro.init()
}

pulse_off[1].count = 1
pulse_off[2].count = 1

pulse_off[1].event = function() 
  local now = util.time()
  print("pulse off 1 fired at " .. now)
  if #note_duration_stacks[1] > 0 then 
    local expired_note = note_duration_stacks[1][1][1]
    print("note off: " .. expired_note)
    local chan = midi_chan[1]
    chan[3]:note_off(expired_note,1,chan[2])
    table.remove(note_duration_stacks[1],1)
  end
  if #note_duration_stacks[1] > 0 then 
    local nxt = note_duration_stacks[1][1][2]
    local expires = nxt - now
    print("next note: " .. note_duration_stacks[1][1][1] .. " in " .. expires .. " now: " .. now .. " next: " .. (nxt - now))
    pulse_off[1].time = nxt - now
    pulse_off[1]:start()
  end
end

pulse_off[2].event = function() 
  local now = util.time()
  print("pulse off 2 fired at " .. now)
  if #note_duration_stacks[2] > 0 then
    local expired_note = note_duration_stacks[2][1][1]
    print("note off: " .. expired_note)
    local chan = midi_chan[2]
    chan[3]:note_off(expired_note,1,chan[2])
    table.remove(note_duration_stacks[2],1)
  end
  if #note_duration_stacks[2] > 0 then 
    local next = note_duration_stacks[2][1][2]
    local expires = next - now
    print("next note: " .. note_duration_stacks[2][1][1] .. " in " .. expires)
    pulse_off[2].time = next - now
    pulse_off[2]:start()
  end
end

local note_dur_1_ms = 0
local note_dur_2_ms = 0

local note_duration_1 = 16
local note_duration_2 = 16

local base_velocity_1 = 50
local random_velocity_1 = 40
local base_velocity_2 = 20
local random_velocity_2 = 75

local tick = 0

local pulse_on = metro.init()
pulse_on.time = 0.1

local ch1_tog = false
local ch2_tog = false
local ch1_trig = false
local ch2_trig = false

local b1_held = false

function make_quant_tab(state, lower_bound, upper_bound)
  held_notes = {}
  for i=0,11 do
    held_notes[i] = 0
  end
  for x=lower_bound,upper_bound do
    for y = 1,6 do
      local v = (5 * (7 - y) + x) % 12
      if state[x][y] > 0 then 
        held_notes[v] = 1 
      end
    end
  end
  print("held_notes " .. dump(held_notes))
  local qt = {}
  for i = 0,11 do
    local delta = 0
    for j = 0,11 do
      if held_notes[(i - j) % 12] > 0 then
        delta = j * -1
        break
      elseif held_notes[(i + j) % 12] > 0 then
        delta = j
        break
      end
    end
    qt[i] = delta
  end
  print("quant_tab" .. dump(qt))
  return qt
end

local quant_channels = 1

local quant_state = {}

for i = 1,16 do
  quant_state[i] = {}
  for x = 1,16 do
    quant_state[i][x] = {}
    for y = 1,6 do
      quant_state[i][x][y] = 0
    end
  end
end

local quant_held = nil
local quant_selected = 1

local quant_tab = make_quant_tab(quant_state[quant_selected],1,16)
local quant_tab1 = make_quant_tab(quant_state[quant_selected],1,8)
local quant_tab2 = make_quant_tab(quant_state[quant_selected],9,16)

function step_channel_1()
  r11 = shift(r11,r1_len, r1_prob_p)
  r12 = shift(r12,r1_len, r1_prob_t)
  redraw()
  grid_draw()
  if quant_channels == 1 then
    step(r11,r12, 1,r1_bias_p,r1_bias_t, r1_offset_p,r1_pitch_range,note_dur_1_ms,base_velocity_1,random_velocity_1, quant_tab,1)
  else
    step(r11,r12, 1,r1_bias_p,r1_bias_t, r1_offset_p,r1_pitch_range,note_dur_1_ms,base_velocity_1,random_velocity_1, quant_tab_1,1)
  end
end

function step_channel_2()
  r21 = shift(r21,r2_len, r2_prob_p)
  r22 = shift(r22,r2_len, r2_prob_t)
  redraw()
  grid_draw()
  if quant_channels == 1 then
    step(r21,r22, 2, r2_bias_p,r2_bias_t, r2_offset_p,r2_pitch_range,note_dur_2_ms,base_velocity_2,random_velocity_2, quant_tab,3)
  else
    step(r21,r22, 2, r2_bias_p,r2_bias_t, r2_offset_p,r2_pitch_range,note_dur_2_ms,base_velocity_2,random_velocity_2, quant_tab_2,3)
  end
end

function on_pulse()
  if (r1_rate ~= 0 and tick % r1_rate == 0) and ch1_tog then
    step_channel_1()
  end
  if (r2_rate ~= 0 and tick % r2_rate == 0) and ch2_tog then
    step_channel_2()
  end
  tick = tick + 1
end

pulse_on.event = function()
end

function step(r1, r2, id, p_bias, t_bias, off, range, duration, base_velocity, random_velocity, quant, crow_output_n)
  local chan = midi_chan[id]
  local now = util.time()
  if r2[1] > (16 - t_bias) then
    local raw_note = off + dac(r1,p_bias,range)
    print("quant_tab " .. dump(quant))
    local note = quantize(raw_note,quant)
    local velocity = base_velocity + math.random(random_velocity)
    print("raw_note: " .. raw_note .. " quant: " .. note)
    chan[3]:note_on(note,100,chan[2])
    crow.output[crow_output_n].volts = (note - 48) / 12
    crow.output[crow_output_n+1].execute()

    local expires = now + (duration / 1000)
    local insert_point = 1
    while insert_point <= #note_duration_stacks[id] do
      if expires < note_duration_stacks[id][insert_point][2] then
        break
      end
      insert_point = insert_point + 1      
    end

    table.insert(note_duration_stacks[id],insert_point,{note,expires})
    if insert_point == 1 then
      pulse_off[id].time = duration / 1000
      pulse_off[id]:start()
    end
  end
end

function bit_at(reg,step,bias)
  -- print(tostring(reg) .. " " .. tostring(step) .. " " .. tostring(bias))
  if reg[step] > (16 - bias) then
    return 1
  else 
    return 0
  end
end

function dac(reg,bias,range)
  if range == 0 then
    return 0
  elseif range == 1 then
    return 6*bit_at(reg,1,bias) + 3*bit_at(reg,2,bias) + 2*bit_at(reg,3,bias) + bit_at(reg,4,bias)
  elseif range == 2 then
    return 8*bit_at(reg,1,bias) + 4*bit_at(reg,2,bias) + 2*bit_at(reg,3,bias) + bit_at(reg,4,bias)
  elseif range == 3 then
    return 12*bit_at(reg,1,bias) + 6*bit_at(reg,2,bias) + 3*bit_at(reg,3,bias) + 2*bit_at(reg,4,bias) + bit_at(reg,5,bias)
  else
    return 16*bit_at(reg,1,bias) + 8*bit_at(reg,2,bias) + 4*bit_at(reg,3,bias) + 2*bit_at(reg,4,bias) + bit_at(reg,5,bias)
  end
end

function shift(reg,len,prob,bias)
  out = {}
  for i = 1,15 do
    out[i + 1] = reg[i]
  end
  p = math.random(16)
  if p <= prob then
    out[1] = math.random(16)
  else
    out[1] = reg[len]
  end
  return out
end

function draw_reg(r,bias)
  local out = ""
  for i = 1,8 do
    if r[i] > (16 - bias) then
      out = out .. "*"
    else
      out = out .. " "
    end
  end
  return out
end

local prbsteps = {2,5,11,13}
local prbsteps_lrg = {1,2,3,5,6,8,10,12}
local biassteps_lrg = {1,2,4,6,9,12,14,16}
local biassteps = {2,5,11,15}
local lensteps = {3,4,5,6,7,8,12,16}

local clksteps = {3,4,6,8,12,24,48,96}
local clksteps_name = {
  [0]="0",
  [3]="1/32",
  [4]="1/24",
  [6]="1/16",
  [8]="1/12",
  [12]="1/8",
  [24]="1/4",
  [48]="1/2",
  [72]="3/4",
  [96]="1",
  [192]="2"
}

function redraw()
  screen.clear()
  screen.move(0,6)
  screen.text(draw_reg(r11,r1_bias_p) .. " LN:" .. r1_len)
  screen.move(60,6)
  screen.text(draw_reg(r21,r2_bias_p) .. " LN:" .. r2_len)
  screen.move(0,13)
  screen.text(draw_reg(r12,r1_bias_t) .. " LN:" .. r1_len)
  screen.move(60,13)
  screen.text(draw_reg(r22,r2_bias_t) .. " LN:" .. r2_len)
  screen.move(0,20)

  screen.text("RATE " .. clksteps_name[r1_rate])
  screen.move(60,20)
  screen.text("RATE " .. clksteps_name[r2_rate])
  screen.move(0,27)

  screen.text("PTCH P:"..r1_prob_p.." R:"..r1_pitch_range)
  screen.move(60,27)
  screen.text("PTCH P:"..r2_prob_p.." R:"..r2_pitch_range)
  screen.move(0,34)
  screen.text("TRIG P:"..r1_prob_t.." B:"..r1_bias_t)
  screen.move(60,34)
  screen.text("TRIG P:"..r2_prob_t.." B:"..r2_bias_t)
  screen.move(0,41)

  screen.text("OFST "..r1_offset_p)
  screen.move(60,41)
  screen.text("OFST "..r2_offset_p)
  screen.move(0,48)

  screen.text(ch1_tog and "RUN" or "STOP")
  screen.move(60,48)
  screen.text(ch2_tog and "RUN" or "STOP")
  screen.text("   BPM " .. bpm)

  screen.update()
  grid_draw()
end

function grid_draw_quant()
  g:all(0)
  local this_quant = quant_state[quant_selected]
  for x = 1,16 do
    for y = 1,6 do
      local z = this_quant[x][y]
      g:led(x,y,z)
    end
  end
end

function grid_draw_normal()
  for i = 1,8 do 
    
    g:led(i,1,5*bit_at(r11,i,r1_bias_p))
    g:led(i+8,1,5*bit_at(r21,i,r2_bias_p))
    g:led(i,2,5*bit_at(r12,i,r1_bias_t))
    g:led(i+8,2,5*bit_at(r22,i,r2_bias_t))

    if clksteps[i] == r1_rate then
      g:led(i,3,3)
    else
      g:led(i,3,0)
    end
    
    if clksteps[i] == r2_rate then
      g:led(i+8,3,3)
    else
      g:led(i+8,3,0)
    end
    
    if biassteps_lrg[i] < r1_bias_t then
      g:led(i,4,1)
    elseif biassteps_lrg[i] == r1_bias_t then
      g:led(i,4,3)
    else
      g:led(i,4,0)
    end
    if biassteps_lrg[i] < r2_bias_t then
      g:led(i+8,4,1)
    elseif biassteps_lrg[i] == r2_bias_t then
      g:led(i+8,4,3)
    else
      g:led(i+8,4,0)
    end
    
    if prbsteps_lrg[i] < r1_prob_p then
      g:led(i,5,1)
    elseif prbsteps_lrg[i] == r1_prob_p then
      g:led(i,5,3)
    else
      g:led(i,5,0)
    end
    if prbsteps_lrg[i] < r2_prob_p then
      g:led(i+8,5,1)
    elseif prbsteps_lrg[i] == r2_prob_p then
      g:led(i+8,5,3)
    else
      g:led(i+8,5,0)
    end
    
    if prbsteps_lrg[i] < r1_prob_t then
      g:led(i,6,1)
    elseif prbsteps_lrg[i] == r1_prob_t then
      g:led(i,6,3)
    else
      g:led(i,6,0)
    end
    if prbsteps_lrg[i] < r2_prob_t then
      g:led(i+8,6,1)
    elseif prbsteps_lrg[i] == r2_prob_t then
      g:led(i+8,6,3)
    else
      g:led(i+8,6,0)
    end    
  end
end

function grid_draw()
  if quant_held then
    grid_draw_quant()
  else 
    grid_draw_normal()
  end

  for x = 1,16 do
    if x == quant_selected then
      g:led(x,7,2)
    else
      g:led(x,7,0)
    end
    if x >= 5 and x <= 8 then
      if (x - 4) == r1_pitch_range then
        g:led(x,8,3)
      else
        g:led(x,8,0)
      end
    end
    if x >= 13 and x <= 16 then
      if (x - 12) == r2_pitch_range then
        g:led(x,8,3)
      else
        g:led(x,8,0)
      end
    end
  end
  if ch1_tog then
    g:led(1,8,4)
  else 
    g:led(1,8,0)
  end
  if ch1_trig then
    g:led(2,8,4)
  else
    g:led(2,8,0)
  end
  if ch2_tog then 
    g:led(9,8,4)
  else 
    g:led(9,8,0)
  end
  if ch2_trig then
    g:led(10,8,4)
  else
    g:led(10,8,0)
  end

  g:refresh()
end
  
function key(n,z)
  if n == 1 and z == 1 then
    b1_held = true
  elseif n == 1 and z == 0 then 
    b1_held = false
  elseif n == 2 and z == 1 then
    print("toggling ch1_tog to " .. tostring(ch1_tog))
    ch1_tog = not ch1_tog
  elseif n == 3 and z == 1 then
    print("toggling ch2_tog to " .. tostring(ch2_tog))
    ch2_tog = not ch2_tog
  end
  redraw()
end

function enc(n,d)
  if n == 1 then
    bpm = bpm + d
    clk:bpm_change(bpm)
  elseif n == 2 and b1_held then
    if r1_bias_t < 16 and d > 0 then
      r1_bias_t = r1_bias_t + 1
    elseif r1_bias_t > 0 and d < 0 then
      r1_bias_t = r1_bias_t - 1 
    end
  elseif n == 2 then
    r1_offset_p = r1_offset_p + d
  elseif n == 3 and b1_held then
    if r2_bias_t < 16 and d > 0 then 
      r2_bias_t = r2_bias_t + 1
    elseif r2_bias_t > 0 and d < 0 then
      r2_bias_t = r2_bias_t - 1
    end
  elseif n == 3 then
    r2_offset_p = r2_offset_p + d
  end
  redraw()
end

function grid_key_normal(x,y,z)
    print("normal grid event: " .. x .. " " .. y .. " " .. z)

    if y == 3 and z == 1 and x <= 8 then
      if r1_rate == clksteps[x] then r1_rate = 0
      else r1_rate = clksteps[x] end
    elseif y == 3 and z == 1 and x > 8 then
      if r2_rate == clksteps[x - 8] then r2_rate = 0
      else r2_rate = clksteps[x - 8] end
    elseif y == 4 and z == 1 and x <= 8 then
      if r1_bias_t == biassteps_lrg[x] then r1_bias_t = 0
      else r1_bias_t = biassteps_lrg[x] end
    elseif y == 4 and z == 1 and x > 8 then
      if r2_bias_t == biassteps_lrg[x - 8] then r2_bias_t = 0
      else r2_bias_t = biassteps_lrg[x - 8] end
    elseif y == 5 and z == 1 and x <= 8 then
      if r1_prob_p == prbsteps_lrg[x] then r1_prob_p = 0
      else r1_prob_p = prbsteps_lrg[x] end
    elseif y == 5 and z == 1 and x > 8 then
      if r2_prob_p == prbsteps_lrg[x - 8] then r2_prob_p = 0
      else r2_prob_p = prbsteps_lrg[x - 8] end
    elseif y == 6 and z == 1 and x <= 8 then
      if r1_prob_t == prbsteps_lrg[x] then r1_prob_t = 0
      else r1_prob_t = prbsteps_lrg[x] end
    elseif y == 6 and z == 1 and x > 8 then
      if r2_prob_t == prbsteps_lrg[x - 8] then r2_prob_t = 0
      else r2_prob_t = prbsteps_lrg[x - 8] end

    elseif y == 7 and z == 1 then
      quant_held = x
      quant_selected = x
      print("making quant_tab")
      quant_tab = make_quant_tab(quant_state[quant_selected],1,16)
      print("making quant_tab_1")
      quant_tab1 = make_quant_tab(quant_state[quant_selected],1,8)
      print("making quant_tab_2")
      quant_tab2 = make_quant_tab(quant_state[quant_selected],9,16)
    elseif y == 7 and z == 0 and x == quant_held then
      quant_held = nil
    end
    
    if y == 8 and z == 1 then
      if x == 1 then
        ch1_tog = not ch1_tog
        -- r11[r1_len] = 0
      elseif x == 2 then
        ch1_trig = true
        step_channel_1()
        -- r11[r1_len] = 1
      elseif x == 3 then
        r1_len = math.max(1, r1_len - 1)
      elseif x == 4 then
        r1_len = math.min(16, r1_len + 1)
      elseif x <= 8 then
        if r1_pitch_range == x - 4 then r1_pitch_range = 0
        else r1_pitch_range = x - 4 end
      elseif x == 9 then
        ch2_tog = not ch2_tog
        -- r21[r2_len] = 0
      elseif x == 10 then
        ch2_trig = true
        step_channel_2()
        -- r21[r2_len] = 1
      elseif x == 11 then
        r2_len = math.max(1, r2_len - 1)
      elseif x == 12 then
        r2_len = math.min(16, r2_len + 1)
      elseif x <= 16 then
        if r2_pitch_range == x - 12 then r2_pitch_range = 0
        else r2_pitch_range = x - 12 end
      end
    elseif y == 8 and z == 0 then
      if x == 2 then
        ch1_trig = false
      elseif x == 10 then
        ch2_trig = false
      end
    end
  
end

function grid_key_quant(x,y,z)
  print("(quant) grid event: " .. x .. " " .. y .. " " .. z)
  local this_quant = quant_state[quant_selected]
  if (y <= 6) and (z == 1) then
    if quant_state[quant_selected][x][y] == 0 then
      quant_state[quant_selected][x][y] = 5
    else 
      quant_state[quant_selected][x][y] = 0
    end
    print("setting quant_tab to " .. quant_selected)
    quant_tab = make_quant_tab(quant_state[quant_selected],1,16)
    -- TODO enable and check that this works
    -- quant_tab1 = make_quant_tab(quant_state[quant_selected],1,8)
    -- quant_tab2 = make_quant_tab(quant_state[quant_selected],9,16)
  end
  -- if (y == 7) and (z == 1) then
  --   quant_held = x
  --   quant_selected = x
  --   print("setting quant_tab to " .. quant_selected)
  --   quant_tab = make_quant_tab(quant_state[quant_selected])
  -- elseif y == 7 and z == 0 and x == quant_held then
  --     print("setting quant_tab to nil?")
  --   quant_held = nil
  -- end
  if y == 7 and z == 0 and x == quant_held then
    quant_held = nil
  end
end

function quantize(note,tab)
  local n = note % 12
  local delta = tab[n]
  return note + delta
end

function init()
  g = include('lib/apcnome_2pages')
  g.key = function(x,y,z)
    if quant_held then
      grid_key_quant(x,y,z)
    else
      grid_key_normal(x,y,z)
    end
    redraw()
  end
  params:add_number("midi device vox 1", "midi device vox 1", 1,4,1)
  params:set_action("midi device vox 1", function (x) midi_chan[1][1] = x; midi_setup() end)
  params:add_number("midi device vox 2", "midi device vox 2", 1,4,1)
  params:set_action("midi device vox 2", function (x) midi_chan[2][1] = x; midi_setup() end)

  params:add_number("midi ch vox 1", "midi ch vox 1", 1,16,1)
  params:set_action("midi ch vox 1", function (x) midi_chan[1][2] = x; midi_setup()  end)
  params:add_number("midi ch vox 2", "midi ch vox 2", 1,16,1)
  params:set_action("midi ch vox 2", function (x) midi_chan[2][2] = x; midi_setup()  end)
  
  params:add_number("quant channels", "quant channels",1,2,1)
  params:set_action("quant channels",function(x) quant_channels = x end)
  
  params:add_number("duration vox 1", "duration vox 1", 0, 100, 4)
  params:set_action("duration vox 1", function (x) note_duration_1 = x end)
  params:add_number("duration vox 2", "duration vox 2", 0, 100, 4)
  params:set_action("duration vox 2", function (x) note_duration_2 = x end)
  params:add_number("duration (ms) vox 1", "duration (ms) vox 1", 0, 2000, 0)
  params:set_action("duration (ms) vox 1", function (x) note_dur_1_ms = x end)
  params:add_number("duration (ms) vox 2", "duration (ms) vox 2", 0, 2000, 0)
  params:set_action("duration (ms) vox 2", function (x) note_dur_2_ms = x end)

  params:add_number("base velocity vox 1", "base velocity vox 1", 0, 128, 20)
  params:set_action("base velocity vox 1", function (x) base_velocity_1 = x end)
  params:add_number("base velocity vox 2", "base velocity vox 2", 0, 128, 50)
  params:set_action("base velocity vox 2", function (x) base_velocity_2 = x end)
  params:add_number("random velocity vox 1", "random velocity vox 1", 0, 128, 70)
  params:set_action("random velocity vox 1", function (x) random_velocity_1 = x end)
  params:add_number("random velocity vox 2", "random velocity vox 2", 0, 128, 30)
  params:set_action("random velocity vox 2", function (x) random_velocity_2 = x end)
  
  midi_setup()
  midi_panic()
  print(dump(m))
  clk.on_step = on_pulse
  clk.on_stop = function() 
    midi_panic()
  end
  clk:add_clock_params()
  clk:start()
  -- disabled until this is fixed upstream
  -- crow.input[1].mode('change',1.0,0.1,'rising')
  -- crow.input[1].change = function(s)
  --   step_channel_1()
  -- end

  -- should just step channel 2 here, but clocking both channels instead
  crow.input[2].mode('change',1.0,0.1,'rising')
  crow.input[2].change = function(s)
    step_channel_1()
    step_channel_2()
    tick = tick + 1
    -- on_pulse()
  end
  
  crow.output[2].action = "{to(5,0),to(0,0.25)}"
  crow.output[4].action = "{to(5,0),to(0,0.25)}"
end
