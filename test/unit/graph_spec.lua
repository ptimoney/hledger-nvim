local graph = require("hledger.graph")

-- Realistic tree-structured display lines (as produced by the LSP server)
local tree_lines = {
  "main.journal",                  -- 1: depth 0
  "├── accounts.journal",         -- 2: depth 1
  "├── expenses.journal",         -- 3: depth 1
  "│   ├── food.journal",         -- 4: depth 2
  "│   └── rent.journal",         -- 5: depth 2
  "└── income.journal",           -- 6: depth 1
}

local tree_paths = {
  [1] = "/home/user/main.journal",
  [2] = "/home/user/accounts.journal",
  [3] = "/home/user/expenses.journal",
  [4] = "/home/user/food.journal",
  [5] = "/home/user/rent.journal",
  [6] = "/home/user/income.journal",
}

describe("graph", function()
  describe("build_depths", function()
    it("assigns depth 0 to root", function()
      local depths = graph.build_depths(tree_lines)
      assert.equal(0, depths[1])
    end)

    it("assigns depth 1 to direct children", function()
      local depths = graph.build_depths(tree_lines)
      assert.equal(1, depths[2])
      assert.equal(1, depths[3])
      assert.equal(1, depths[6])
    end)

    it("assigns depth 2 to grandchildren", function()
      local depths = graph.build_depths(tree_lines)
      assert.equal(2, depths[4])
      assert.equal(2, depths[5])
    end)

    it("returns empty table for empty input", function()
      assert.same({}, graph.build_depths({}))
    end)

    it("handles single line", function()
      local depths = graph.build_depths({ "root.journal" })
      assert.same({ 0 }, depths)
    end)

    it("handles flat list (all same depth)", function()
      local depths = graph.build_depths({ "a.journal", "b.journal", "c.journal" })
      assert.same({ 0, 0, 0 }, depths)
    end)
  end)

  describe("build_parent_map", function()
    it("maps children to their parent", function()
      local depths = graph.build_depths(tree_lines)
      local pm = graph.build_parent_map(depths)
      assert.equal(1, pm[2])  -- accounts -> main
      assert.equal(1, pm[3])  -- expenses -> main
      assert.equal(1, pm[6])  -- income -> main
    end)

    it("maps grandchildren to their parent (not grandparent)", function()
      local depths = graph.build_depths(tree_lines)
      local pm = graph.build_parent_map(depths)
      assert.equal(3, pm[4])  -- food -> expenses
      assert.equal(3, pm[5])  -- rent -> expenses
    end)

    it("has no parent for root", function()
      local depths = graph.build_depths(tree_lines)
      local pm = graph.build_parent_map(depths)
      assert.is_nil(pm[1])
    end)

    it("returns empty map for single line", function()
      assert.same({}, graph.build_parent_map({ 0 }))
    end)

    it("returns empty map for flat list", function()
      local pm = graph.build_parent_map({ 0, 0, 0 })
      assert.is_nil(pm[1])
      assert.is_nil(pm[2])
      assert.is_nil(pm[3])
    end)

    it("handles deep nesting", function()
      local depths = { 0, 1, 2, 3, 2 }
      local pm = graph.build_parent_map(depths)
      assert.equal(1, pm[2])
      assert.equal(2, pm[3])
      assert.equal(3, pm[4])
      assert.equal(2, pm[5])  -- sibling of line 3, not child of line 4
    end)
  end)

  describe("has_children", function()
    local depths = graph.build_depths(tree_lines)

    it("returns true for root with children", function()
      assert.is_true(graph.has_children(1, depths))
    end)

    it("returns true for parent node", function()
      assert.is_true(graph.has_children(3, depths))  -- expenses has food, rent
    end)

    it("returns false for leaf node", function()
      assert.is_false(graph.has_children(2, depths))  -- accounts is leaf
      assert.is_false(graph.has_children(4, depths))  -- food is leaf
    end)

    it("returns false for last line", function()
      assert.is_false(graph.has_children(6, depths))
    end)

    it("returns false for single-element list", function()
      assert.is_false(graph.has_children(1, { 0 }))
    end)
  end)

  describe("filter_entries", function()
    it("removes entries without paths", function()
      local entries = {
        { display = "main.journal", path = "/main.journal" },
        { display = "(cycle)", path = "" },
        { display = "other.journal", path = "/other.journal" },
      }
      local filtered, lines, paths = graph.filter_entries(entries)
      assert.equal(2, #filtered)
      assert.equal(2, #lines)
      assert.equal("/main.journal", paths[1])
      assert.equal("/other.journal", paths[2])
    end)

    it("removes entries with nil path", function()
      local entries = {
        { display = "cycle entry" },
        { display = "main.journal", path = "/main.journal" },
      }
      local filtered, lines, paths = graph.filter_entries(entries)
      assert.equal(1, #filtered)
      assert.equal("main.journal", lines[1])
      assert.equal("/main.journal", paths[1])
    end)

    it("returns empty results for all-invalid entries", function()
      local filtered, lines, paths = graph.filter_entries({
        { display = "x", path = "" },
        { display = "y" },
      })
      assert.equal(0, #filtered)
      assert.equal(0, #lines)
      assert.same({}, paths)
    end)

    it("preserves all entries when all valid", function()
      local entries = {
        { display = "a", path = "/a" },
        { display = "b", path = "/b" },
      }
      local filtered, lines, _ = graph.filter_entries(entries)
      assert.equal(2, #filtered)
      assert.same({ "a", "b" }, lines)
    end)
  end)

  describe("compute_display", function()
    local depths = graph.build_depths(tree_lines)
    local parent_map = graph.build_parent_map(depths)

    describe("no filter", function()
      it("shows all lines", function()
        local display, _, _, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "", tree_paths
        )
        assert.equal(#tree_lines, #display)
      end)

      it("adds fold indicators for parent nodes", function()
        local display, _, _, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "", tree_paths
        )
        -- main.journal has children -> ▼
        assert.truthy(display[1]:match("^▼"))
        -- expenses.journal has children -> ▼
        assert.truthy(display[3]:match("^▼"))
      end)

      it("adds space prefix for leaf nodes", function()
        local display, _, _, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "", tree_paths
        )
        -- accounts.journal is a leaf
        assert.truthy(display[2]:match("^  "))
      end)

      it("preserves path mapping", function()
        local _, paths, _, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "", tree_paths
        )
        assert.equal(tree_paths[1], paths[1])
        assert.equal(tree_paths[4], paths[4])
      end)

      it("builds display-to-original mapping", function()
        local _, _, d2o, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "", tree_paths
        )
        for i = 1, #tree_lines do
          assert.equal(i, d2o[i])
        end
      end)

      it("returns empty matches table", function()
        local _, _, _, matches = graph.compute_display(
          tree_lines, depths, parent_map, {}, "", tree_paths
        )
        assert.same({}, matches)
      end)
    end)

    describe("with folding", function()
      it("hides children of folded node", function()
        local folded = { [3] = true }  -- fold expenses
        local display, _, d2o, _ = graph.compute_display(
          tree_lines, depths, parent_map, folded, "", tree_paths
        )
        -- Should show: main, accounts, expenses(folded), income = 4 lines
        assert.equal(4, #display)
        -- Expenses should have ▶ indicator
        assert.truthy(display[3]:match("^▶"))
      end)

      it("preserves path mapping after folding", function()
        local folded = { [3] = true }
        local _, paths, d2o, _ = graph.compute_display(
          tree_lines, depths, parent_map, folded, "", tree_paths
        )
        -- Line 4 in display is income (original line 6)
        assert.equal(tree_paths[6], paths[4])
      end)

      it("hides deeply nested descendants", function()
        local folded = { [1] = true }  -- fold root
        local display, _, _, _ = graph.compute_display(
          tree_lines, depths, parent_map, folded, "", tree_paths
        )
        -- Only root should be visible
        assert.equal(1, #display)
        assert.truthy(display[1]:match("^▶"))
      end)
    end)

    describe("with search", function()
      it("includes matching lines", function()
        local _, _, d2o, matches = graph.compute_display(
          tree_lines, depths, parent_map, {}, "food", tree_paths
        )
        -- "food" matches line 4, ancestors are lines 3 and 1
        assert.is_table(matches[4])
      end)

      it("includes ancestors of matches", function()
        local _, _, d2o, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "food", tree_paths
        )
        -- Should include: main (ancestor), expenses (ancestor), food (match)
        local originals = {}
        for _, orig in pairs(d2o) do
          originals[orig] = true
        end
        assert.is_true(originals[1])   -- main (ancestor)
        assert.is_true(originals[3])   -- expenses (ancestor)
        assert.is_true(originals[4])   -- food (match)
      end)

      it("excludes non-matching non-ancestor lines", function()
        local _, _, d2o, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "food", tree_paths
        )
        local originals = {}
        for _, orig in pairs(d2o) do
          originals[orig] = true
        end
        assert.is_nil(originals[2])   -- accounts (not ancestor of food)
        assert.is_nil(originals[5])   -- rent (not a match)
        assert.is_nil(originals[6])   -- income (not ancestor)
      end)

      it("returns match positions", function()
        local _, _, _, matches = graph.compute_display(
          tree_lines, depths, parent_map, {}, "food", tree_paths
        )
        assert.is_table(matches[4])
        assert.truthy(#matches[4] > 0)
      end)

      it("returns no results for non-matching search", function()
        local display, _, _, _ = graph.compute_display(
          tree_lines, depths, parent_map, {}, "zzzzz", tree_paths
        )
        assert.equal(0, #display)
      end)
    end)

    describe("fold + search combined", function()
      it("excludes folded descendants even when they match search", function()
        local folded = { [3] = true }  -- fold expenses
        local _, _, d2o, _ = graph.compute_display(
          tree_lines, depths, parent_map, folded, "food", tree_paths
        )
        -- food.journal (line 4) matches but is child of folded expenses
        -- Should show: main (ancestor), expenses (folded, ancestor)
        local originals = {}
        for _, orig in pairs(d2o) do
          originals[orig] = true
        end
        assert.is_true(originals[1])   -- main
        assert.is_true(originals[3])   -- expenses (folded, shown)
        assert.is_nil(originals[4])    -- food (hidden by fold)
      end)
    end)

    describe("edge cases", function()
      it("handles single line", function()
        local lines = { "root.journal" }
        local d = graph.build_depths(lines)
        local pm = graph.build_parent_map(d)
        local paths = { [1] = "/root.journal" }
        local display, _, _, _ = graph.compute_display(lines, d, pm, {}, "", paths)
        assert.equal(1, #display)
        assert.truthy(display[1]:match("^  "))  -- no children = space prefix
      end)

      it("handles empty lines", function()
        local display, _, _, _ = graph.compute_display({}, {}, {}, {}, "", {})
        assert.equal(0, #display)
      end)
    end)
  end)
end)
