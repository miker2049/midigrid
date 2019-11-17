-- initial values
local state = {
  keys = {
    key1_down = false,
    key2_down = false,
    key3_down = false
  },
  board = {
    current = {},
    the_past = {} --constructed on init. This linked list will hold ancestral boards so we may visit the past
  },
  seq = {
    position = {}
  },
  crow = {
    cv_offset = 0
  },
  root_note = 36,
  scale_name = "",
  scale = {},
  note_offset = 0,
  playable_cells = {},
  play_pos = 0,
  active_notes = {},
  seq_running = false,
  show_playing_indicator = false,
  beats = {true},
  euclid_seq_len = 1,
  euclid_seq_beats = 1,
  beat_step = 0
}

return state