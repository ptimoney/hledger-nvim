local commands = require("hledger.commands")

describe("commands", function()
  describe("_get_setting", function()
    it("returns top-level value", function()
      assert.equal(42, commands._get_setting({ foo = 42 }, "foo"))
    end)

    it("returns nested value via dot path", function()
      assert.equal(true, commands._get_setting(
        { a = { b = { c = true } } }, "a.b.c"
      ))
    end)

    it("returns nil for missing key", function()
      assert.is_nil(commands._get_setting({ foo = 1 }, "bar"))
    end)

    it("returns nil for missing intermediate key", function()
      assert.is_nil(commands._get_setting({ foo = 1 }, "foo.bar.baz"))
    end)

    it("returns nil when intermediate is not a table", function()
      assert.is_nil(commands._get_setting({ foo = "str" }, "foo.bar"))
    end)

    it("returns table values", function()
      local tbl = { x = 1 }
      assert.same(tbl, commands._get_setting({ foo = tbl }, "foo"))
    end)

    it("returns false (not nil) for false values", function()
      assert.equal(false, commands._get_setting({ a = false }, "a"))
    end)
  end)

  describe("_set_setting", function()
    it("sets top-level value", function()
      local t = {}
      commands._set_setting(t, "foo", 42)
      assert.equal(42, t.foo)
    end)

    it("sets nested value creating intermediates", function()
      local t = {}
      commands._set_setting(t, "a.b.c", true)
      assert.equal(true, t.a.b.c)
    end)

    it("preserves sibling keys", function()
      local t = { a = { x = 1 } }
      commands._set_setting(t, "a.y", 2)
      assert.equal(1, t.a.x)
      assert.equal(2, t.a.y)
    end)

    it("overwrites existing value", function()
      local t = { a = { b = "old" } }
      commands._set_setting(t, "a.b", "new")
      assert.equal("new", t.a.b)
    end)

    it("can set value to false", function()
      local t = { a = true }
      commands._set_setting(t, "a", false)
      assert.equal(false, t.a)
    end)
  end)

  describe("statusline", function()
    it("returns empty string when no client is attached", function()
      assert.equal("", commands.statusline())
    end)
  end)

  describe("status", function()
    it("returns attached=false when no client is attached", function()
      local s = commands.status()
      assert.equal(false, s.attached)
      assert.is_nil(s.root)
    end)
  end)
end)
