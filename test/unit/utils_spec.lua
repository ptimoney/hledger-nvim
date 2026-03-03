local utils = require("hledger.utils")

describe("utils", function()
  describe("get_depth", function()
    it("returns 0 for a root-level line", function()
      assert.equal(0, utils.get_depth("main.journal"))
    end)

    it("counts leading spaces in groups of 4", function()
      assert.equal(1, utils.get_depth("    child.journal"))
    end)

    it("counts multiple levels of indentation", function()
      assert.equal(2, utils.get_depth("        grandchild.journal"))
    end)

    it("floors partial indentation groups", function()
      assert.equal(0, utils.get_depth("  file.journal"))
      assert.equal(0, utils.get_depth("   file.journal"))
    end)

    it("counts ├ box-drawing character", function()
      assert.equal(1, utils.get_depth("├── child.journal"))
    end)

    it("counts └ box-drawing character", function()
      assert.equal(1, utils.get_depth("└── child.journal"))
    end)

    it("counts │ box-drawing character for deeper nesting", function()
      assert.equal(2, utils.get_depth("│   ├── grandchild.journal"))
    end)

    it("handles combined spaces and box-drawing", function()
      assert.equal(3, utils.get_depth("    │   └── deep.journal"))
    end)

    it("returns 0 for empty string", function()
      assert.equal(0, utils.get_depth(""))
    end)

    it("handles only spaces (no filename)", function()
      assert.equal(2, utils.get_depth("        "))
    end)
  end)

  describe("fuzzy_match", function()
    it("matches empty pattern against any string", function()
      local ok, positions = utils.fuzzy_match("anything", "")
      assert.is_true(ok)
      assert.same({}, positions)
    end)

    it("matches exact string", function()
      local ok, positions = utils.fuzzy_match("hello", "hello")
      assert.is_true(ok)
      assert.same({ 0, 1, 2, 3, 4 }, positions)
    end)

    it("matches case-insensitively", function()
      local ok, _ = utils.fuzzy_match("Hello World", "hw")
      assert.is_true(ok)
    end)

    it("returns 0-indexed positions for nvim highlights", function()
      local ok, positions = utils.fuzzy_match("abcdef", "ace")
      assert.is_true(ok)
      assert.same({ 0, 2, 4 }, positions)
    end)

    it("returns false for non-match", function()
      local ok, positions = utils.fuzzy_match("hello", "xyz")
      assert.is_false(ok)
      assert.same({}, positions)
    end)

    it("requires characters in order", function()
      local ok, _ = utils.fuzzy_match("abc", "ca")
      assert.is_false(ok)
    end)

    it("matches pattern longer than possible when no match", function()
      local ok, _ = utils.fuzzy_match("ab", "abc")
      assert.is_false(ok)
    end)

    it("handles single character match", function()
      local ok, positions = utils.fuzzy_match("test", "t")
      assert.is_true(ok)
      assert.same({ 0 }, positions)
    end)

    it("handles single character non-match", function()
      local ok, _ = utils.fuzzy_match("test", "z")
      assert.is_false(ok)
    end)

    it("matches greedily left-to-right", function()
      local ok, positions = utils.fuzzy_match("aaa", "a")
      assert.is_true(ok)
      assert.same({ 0 }, positions)
    end)
  end)

  describe("detect_filetype", function()
    it("detects .journal files", function()
      -- vim.filetype.match returns "ledger" for .journal; the fallback
      -- only fires when vim.filetype.match returns nil
      local ft = utils.detect_filetype("main.journal")
      assert.is_truthy(ft)
    end)

    it("detects .hledger files", function()
      local ft = utils.detect_filetype("accounts.hledger")
      assert.is_truthy(ft)
    end)

    it("falls back to hledger for .journal when vim.filetype returns nil", function()
      -- Test the fallback logic directly
      local orig = vim.filetype.match
      vim.filetype.match = function() return nil end
      assert.equal("hledger", utils.detect_filetype("main.journal"))
      assert.equal("hledger", utils.detect_filetype("test.hledger"))
      vim.filetype.match = orig
    end)

    it("detects .lua files", function()
      assert.equal("lua", utils.detect_filetype("init.lua"))
    end)
  end)

  describe("constants", function()
    it("has WINDOW_WIDTH_PERCENT", function()
      assert.is_number(utils.WINDOW_WIDTH_PERCENT)
    end)

    it("has FOLD_INDICATOR_WIDTH", function()
      assert.equal(4, utils.FOLD_INDICATOR_WIDTH)
    end)
  end)
end)
