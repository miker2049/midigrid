lu = require("luaunit")
helpers = require("lib/helpers")

TestHelpers = {}

describe("Test helpers", function()
  it("should clone a table", function()
    local input_table = {1, 3, 4}
    local result = helpers.table.clone(input_table)
    assert.are.same(result, input_table)
    input_table[1] = 9
    assert.are_not.same(result, input_table)
  end)

  it("should map a table", function()
    local input_table = {1, 2, 3}
    local expected = {2, 3, 4}
    local result = helpers.table.map(
      function(x) return x + 1 end,
      input_table
    )
    assert.are.same(result, expected)
  end)

  it("should reverse a table", function()
    local input_table = {1, 2, 3}
    local expected = {3, 2, 1}
    local result = helpers.table.reverse(input_table)
    assert.are.same(result, expected)
  end)

  it("should shuffle a table", function()
    local input_table = {1, 2, 3}
    local result = helpers.table.shuffle(input_table, 48156162342)
    assert.are_not.same(result, input_table)
  end)

  it("should clone a board", function()
    local input_board = {
      {1, 2, 3, 4},
      {2, 4, 6, 8},
      {3, 6, 9, 0}
    }
    local result = helpers.clone_board(input_board)
    assert.are.same(result, input_board)
    input_board[1][3] = 19
    assert.are_not.same(result, input_board)
  end)
end)
