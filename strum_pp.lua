--
-- The strum of your chords,
--   Sways my soul 
--     back and fourth. 
--
--
-- scriptname: Strum
-- v1.0.0 @carvingcode
-- https://llllllll.co/t/strum/21025

--
-- vars
--
engine.name = 'PolyPerc'

local UI = require "ui"
local cs = require 'controlspec'
local music = require 'musicutil'
local beatclock = require 'beatclock'

local playmode = {"Onward","Aft", "Sway", "Joy"}
local out_options = {"Audio", "MIDI", "Audio + MIDI"}
local grid_display_options = {"Normal", "180 degrees"}
local DATA_FILE_PATH = _path.data .. "ccode/strum/strum_pp.data"

-- vars for UI
local SCREEN_FRAMERATE = 15
local screen_dirty = true
local GRID_FRAMERATE = 30
local grid_dirty = true
local pages
local alt = false

local app_title = "STRUM"

-- pattern vars
local steps = {}
local playchoice = 1
local pattern_len = 8
local position = 1

local note_playing = nil
local prev_note = 0
local next_step = 0
local direction = 1
local k3_state = 1

-- device vars
local grid_device = include('lib/apcnome') 
-- local midi_in_device = midi.connect(2)
--add the apc as midi in device for cc mapping
local midi_in_device = grid_device
local midi_out_device = midi.connect(2)
local midi_out_channel

-- scale vars
local root_num = 60
local tonic = music.note_num_to_name(root_num, 1)
local mode = 5 -- set to dorian
local scale = music.generate_scale_of_length(root_num,music.SCALES[mode].name,8)

-- clock vars
local beat_clock = beatclock.new()
local beat_clock_midi = midi.connect(2)
beat_clock_midi.event = beat_clock.process_midi

-- load/save/delete
local save_data = {version = 1, patterns = {}}
local save_menu_items = {"Load", "Save", "Delete"}
local save_slot_list
local save_menu_list
local last_edited_slot = 0
local confirm_message
local confirm_function


------------------------------------------
-- load/save/delete functions @markeats --
------------------------------------------
local function copy_object(object)
  if type(object) ~= 'table' then return object end
  local result = {}
  for k, v in pairs(object) do result[copy_object(k)] = copy_object(v) end
  return result
end

local function update_save_slot_list()
  local entries = {}
  for i = 1, math.min(#save_data.patterns + 1, 999) do
    local entry
    if i <= #save_data.patterns then
      entry = save_data.patterns[i].name
    else
      entry = "-"
    end
    if i == last_edited_slot then entry = entry .. "*" end
    entries[i] = i .. ". " .. entry
  end
  save_slot_list.entries = entries
end

local function read_data()
  local disk_data = tab.load(DATA_FILE_PATH)
  if disk_data then
    if disk_data.version then
      if disk_data.version == 1 then
        save_data = disk_data
      else
        print("Unrecognized data, version " .. disk_data.version)
      end
    end
  end
  update_save_slot_list()
end

local function write_data()
  tab.save(save_data, DATA_FILE_PATH)
end

local function load_pattern(index)
  if index > #save_data.patterns then return end
  
  local pattern = copy_object(save_data.patterns[index])
    params:set("bpm", pattern.bpm)
    params:set("amp", pattern.amp)
    params:set("pw", pattern.pw)
    params:set("release", pattern.release)
    params:set("cutoff", pattern.cutoff)
    params:set("gain", pattern.gain)

    grid_display = pattern.grid_display
    root_num = pattern.root_num
    mode = pattern.mode
    pattern_len = pattern.pattern_len
    playchoice = pattern.playchoice
    steps = pattern.steps
    scale = pattern.scale
  
    tonic = music.note_num_to_name(root_num, 1)

  last_edited_slot = index
  update_save_slot_list()
  grid_dirty = true
end

local function save_pattern(index)
  local pattern = {
    name = os.date("%b %d %H:%M"),
    bpm = params:get("bpm"),
    amp = params:get("amp"),
    pw = params:get("pw"),
    release = params:get("release"),
    cutoff = params:get("cutoff"),
    gain = params:get("gain"),

    grid_display = grid_display,
    root_num = root_num,
    mode = mode,
    pattern_len = pattern_len,
    playchoice = playchoice,
    steps = steps,
    scale = scale
  }
  
  save_data.patterns[index] = copy_object(pattern)
  last_edited_slot = index
  update_save_slot_list()
  
  write_data()
end

local function delete_pattern(index)
  if index > 0 and index <= #save_data.patterns then
    table.remove(save_data.patterns, index)
    if index == last_edited_slot then
      last_edited_slot = 0
    elseif index < last_edited_slot then
      last_edited_slot = last_edited_slot - 1
    end
  end
  update_save_slot_list()
  
  write_data()
end


----------------
-- stop notes -- 
----------------
local function all_notes_kill()
    
  -- MIDI out
  midi_out_device:note_off(note_playing, nil)
  note_playing = nil
end

-------------------
-- reset pattern --
-------------------
local function reset_pattern()
    
    if playmode[playchoice] == "Aft"  then
    	position = 17
    elseif playmode[playchoice] == "Sway"  then
    	position = 8
    else
    	position = 0
    end
    all_notes_kill()
    beat_clock:reset()
end

----------------------
-- handle each step --
----------------------
function handle_step()

    if playmode[playchoice] == "Onward" then
        position = (position % pattern_len) + 1
        
    elseif playmode[playchoice] == "Aft" then
        position = position - 1
        if position == 0 then
            position = pattern_len
        end
        
    elseif playmode[playchoice] == "Sway" then
        if direction == 1 then
            position = (position % pattern_len) + 1
            if position == pattern_len then
                direction = 0
            end
        else
             if pattern_len > 1 then
                position = position - 1
            end
            if position == 1 then
                direction = 1
            end
        end

    else -- random step position
        position = math.random(1,pattern_len)
    end

    if steps[position] ~= 0 then
        vel = math.random(1,100) / 100 -- random velocity values
        
          -- Audio engine out
        if params:get("output") == 1 or params:get("output") == 3 then
                engine.amp(vel)
                engine.hz(music.note_num_to_freq(scale[steps[position]]))
        end
        
            -- MIDI out
        if (params:get("output") == 2 or params:get("output") == 3) then
            if note_playing ~= nil then
                midi_out_device:note_off(note_playing,nil)
            end
            note_playing = music.freq_to_note_num(music.note_num_to_freq(scale[steps[position]]),1)
            midi_out_device:note_on(note_playing,vel*100)
        end
        
    end
    grid_dirty = true
end

-------------------------
-- handle grid presses --
-------------------------
 function grid_device.key(x,y,z)
   print(x,y,z)
    if z == 1 then
        if steps[x] == y then
            steps[x] = 0
        else
            steps[x] = y
        end
        grid_dirty = true
    end
    screen_dirty = true
end

---------------------
-- redraw the grid --
---------------------
function grid_redraw()
    grid_device:all(0)
    for i=1, pattern_len do
         if grid_display == 1 then
            if steps[i] ~= 0 then
                for j=0,7 do
                  local lit=steps[i]<=j and 0 or 9
                  grid_device:led(i,j+1,i==position and 12 or lit)
                    -- grid_device:led(i,steps[i]+j,i==position and 12 or (2+j))
                end
            end
        else
            grid_device:led(i,steps[i],i==position and 12 or 4)
        end
    end
    grid_device:refresh()
end

-----------------------
-- handle norns keys --
-----------------------
function key(n,z)
	
  if n==1 then
    alt = z==1
  end

  if z == 1 then
  
    if alt and n == 2 then 

      steps = {}
      for i=1,8 do
        table.insert(steps,math.random(0,8))
      end

    elseif n == 2 then
      
      if confirm_message then
        confirm_message = nil
        confirm_function = nil
      end

    elseif n == 3 then
      if pages.index == 1 or pages.index == 2 then

        if k3_state == 0 then
          beat_clock:stop()
          k3_state = 1
            
          -- MIDI out
          if (params:get("output") == 2 or params:get("output") == 3) then
            all_notes_kill()
          end
          -- clear grid lights
          grid_device:all(0)
          grid_device:refresh()
        else
          reset_pattern()
          beat_clock:start()
          k3_state = 0
        end

    
      -- Load/Save
      elseif pages.index == 3 then
          
        if confirm_message then
          confirm_function()
          confirm_message = nil
          confirm_function = nil

        else
          -- Load
          if save_menu_list.index == 1 then
            load_pattern(save_slot_list.index)
          
          -- Save
          elseif save_menu_list.index == 2 then
            if save_slot_list.index < #save_slot_list.entries then
              confirm_message = UI.Message.new({"Replace saved pattern?"})
              confirm_function = function() save_pattern(save_slot_list.index) end
            else
              save_pattern(save_slot_list.index)
            end
            
          -- Delete
          elseif save_menu_list.index == 3 then
            if save_slot_list.index < #save_slot_list.entries then
              confirm_message = UI.Message.new({"Delete saved pattern?"})
              confirm_function = function() delete_pattern(save_slot_list.index) end
            end
          end     
        end
      end
    end
	screen_dirty = true
  end
end

---------------------------
-- handle norns encoders --
---------------------------
function enc(n,delta)
	
  -- handle UI paging
  if n == 1 then
  -- Page scroll
    pages:set_index_delta(util.clamp(delta, -1, 1), false)
  end
  
  if pages.index == 1 then
        
    if n == 2 then       -- scale
      mode = util.clamp(mode + delta, 1, #music.SCALES)
      scale = music.generate_scale_of_length(root_num,music.SCALES[mode].name,8)

    elseif n == 3 then	-- tonic
	        
      root_num = util.clamp(root_num + delta, 24, 96)
      tonic = music.note_num_to_name(root_num, 1)
      scale = music.generate_scale_of_length(root_num,music.SCALES[mode].name,8)
                
    end
        
        
  elseif pages.index == 2 then

    if alt and n == 2 then  
      -- pattern length
      pattern_len = util.clamp(pattern_len + delta, 2, 16)

		elseif n == 2 then           -- sequence direction
      playchoice = util.clamp(playchoice + delta, 1, #playmode)
    
    elseif alt and n == 3 then       

    elseif n == 3 then      -- tempo
      params:delta("bpm",delta)
            
    end
    

-- Load/Save
    elseif pages.index == 3 then
      
      if n == 2 then
        save_slot_list:set_index_delta(util.clamp(delta, -1, 1))
        
      elseif n == 3 then
        save_menu_list:set_index_delta(util.clamp(delta, -1, 1))
        
      end
        
  end
    
  screen_dirty = true
end

-------------------------
-- handle norns screen --
-------------------------
function redraw()
	
  screen.clear()
    
  if confirm_message then
    confirm_message:redraw()
    
  else
  
    pages:redraw()
    
    if beat_clock.playing then
      playback_icon.status = 1
    else
      playback_icon.status = 3
    end
    if pages.index ~= 3 then
      playback_icon:redraw()
    end
    
    screen.line_width(1)
    screen.move(63,10)
    screen.level(10)
    screen.font_size(12)
    screen.font_face(14)
    screen.text_center(app_title)

    if pages.index == 1 then
	    
      screen.font_size(8)
      screen.font_face(1)

	    screen.move(5,30)
      screen.level(5)
      screen.text("Scale: ")
      screen.move(35,30)
      screen.level(15)
      screen.text(music.SCALES[mode].name)
      screen.move(5,40)
      screen.level(5)
      screen.text("Key: ")
      screen.move(35,40)
      screen.level(15)
      screen.text(tonic)

    elseif pages.index == 2 then      

      screen.font_size(8)
      screen.font_face(1)

      screen.move(5,30)
      screen.level(5)
      screen.text("Path: ")
      screen.move(35,30)
      screen.level(15)
      screen.text(playmode[playchoice])
      screen.move(5,40)
      screen.level(5)
      screen.text("Tempo: ")
      screen.move(35,40)
      if beat_clock.external then
      	screen.level(3)
        screen.text("External")
      else
      	screen.level(15)
        screen.text(params:get("bpm").." bpm")
      end
      screen.move(80,30)
      screen.level(5)
      screen.text("Len: ")
      screen.move(100,30)
      screen.level(15)
      screen.text(pattern_len)
                
    elseif pages.index == 3 then
	    
      screen.font_size(8)
      screen.font_face(1)

      save_slot_list:redraw()
      save_menu_list:redraw()

    end
  end  
  screen.update()
end


-----------
-- setup --
-----------
function init()
	
	screen.aa(1)
  
	-- initialize pattern with random notes
  for i=1,8 do
      table.insert(steps,math.random(0,8))
  end

	-- set clock functions
  beat_clock.on_step = handle_step
  beat_clock.on_stop = reset_pattern
  beat_clock.on_select_internal = function() beat_clock:start() end
  beat_clock.on_select_external = reset_pattern

  local screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function()
    if screen_dirty then
      screen_dirty = false
      redraw()
    end
  end
  
  local grid_redraw_metro = metro.init()
  grid_redraw_metro.event = function()
    if grid_dirty and grid_device.device then
      grid_dirty = false
      grid_redraw()
    end
  end

	-- set up parameter menu

  params:add_number("bpm", "BPM", 1, 480, beat_clock.bpm)
  params:set_action("bpm", function(x) beat_clock:bpm_change(x) end)
  params:set("bpm", 72)
    
  params:add_separator()
    
  params:add{type = "number", id = "grid_device", name = "Grid Device", min = 1, max = 4, default = 1, 
    action = function(value)
      grid_device:all(0)
      grid_device:refresh()
      -- grid_device = grid.connect(value)
  end}
    
  params:add_option("grid_display", "Grid Display", { "Bar", "Scatter" }, grid_display or 2 and 1)
  params:set_action("grid_display", function(x) if x == 1 then grid_display = 1 else grid_display = 2 end end)

	params:add_option("grid_rotation", "Grid Rotation", grid_display_options)
	params:set_action("grid_rotation", function(x) 
    local val
    if x == 1 then val = 0 else val = 2 end
		grid_device:all(0)
		-- grid_device:rotation(val)
		grid_device:refresh()
	end) 

  params:add_separator()
    
  params:add{type = "option", id = "output", name = "Output", options = out_options, 
    action = function()all_notes_kill()end}
        
  params:add{type = "number", id = "midi_out_device", name = "MIDI Out Device", min = 1, max = 4, default = 2,
    action = function(value)
    midi_out_device = midi.connect(value)
  end}
  
  params:add{type = "number", id = "midi_out_channel", name = "MIDI Out Channel", min = 1, max = 16, default = 2,
    action = function(value)
      all_notes_kill()
      midi_out_channel = value
  end}
    
	params:add{type = "number", id = "clock_midi_in_device", name = "Clock MIDI In Device", min = 1, max = 4, default = 2,
  	action = function(value)
		midi_in_device = midi.connect(value)
  end}
    
	params:add_option("clock", "Clock Source", {"Internal", "External"}, beat_clock.external or 2 and 1)
	params:set_action("clock", function(x) beat_clock:clock_source_change(x) end)
	
	params:add{type = "option", id = "clock_out", name = "Clock Out", options = {"Off", "On"}, default = beat_clock.send or 2 and 1,
  	action = function(value)
		if value == 1 then beat_clock.send = false
		else beat_clock.send = true end
  end}
  
  params:add_separator()

  cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
  params:add{type="control",id="amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,555,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}

  params:bang()

	-- set up MIDI in
  midi_in_device.event = function(data)
	beat_clock:process_midi(data)
    if not beat_clock.playing then
  	  screen_dirty = true
  	end
	end
    
	-- UI
  pages = UI.Pages.new(1, 3)
  save_slot_list = UI.ScrollingList.new(5, 20, 1, {})
  save_slot_list.num_visible = 3
  save_slot_list.num_above_selected = 0
  save_menu_list = UI.List.new(92, 20, 1, save_menu_items)
  playback_icon = UI.PlaybackIcon.new(121, 55)
  
  screen.aa(1)

  screen_refresh_metro:start(1 / SCREEN_FRAMERATE)
  grid_redraw_metro:start(1 / GRID_FRAMERATE)

	beat_clock:stop()

  -- Data
  read_data()
end


function cleanup ()
  beat_clock:stop()
end
