-- User vocabulary state for WordGloss.
--
-- One module owns both external and internal word state:
--   * Vocabulary Builder (KOReader): read-only forced words.
--   * known_words (WordGloss DB): words the user explicitly says they know.
--
-- Priority is applied by wordgloss_lexicon.lua:
--   known > forced vocabulary > normal frequency/name rules.

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Lexicon = require("wordgloss_lexicon")

local Words = {}

local function file_stamp(path)
    local size = lfs.attributes(path, "size")
    local mtime = lfs.attributes(path, "modification")
    if size == nil and mtime == nil then return "-" end
    return tostring(size or 0) .. ":" .. tostring(mtime or 0)
end

local function add_unique(out, seen, value)
    if value and value ~= "" and not seen[value] then
        seen[value] = true
        out[#out + 1] = value
    end
end

function Words:new(o)
    o = o or {}
    o.vocab_path = o.vocab_path
        or (DataStorage:getSettingsDir() .. "/vocabulary_builder.sqlite3")
    o._vocab_signature = nil
    o._vocabulary = {}
    o._known = nil
    setmetatable(o, self)
    self.__index = self
    return o
end

function Words:_resolve(raw)
    local word = Lexicon.normalize_hyphenated(raw)
    if not word then return nil, nil, nil end
    if not self.lexicon or not self.lexicon.resolve then
        return word, nil, nil
    end
    local ok, _, base, lemma = pcall(self.lexicon.resolve, self.lexicon, word)
    if not ok then
        logger.warn("wordgloss: cannot resolve user word:", tostring(base))
        return word, nil, nil
    end
    return word, base, lemma
end

-- A form that already redirects its gloss to a base can safely share one
-- "known" state with that base. Ranked forms with their own gloss keep their
-- exact word as the stored key, even when they have a difficulty lemma.
function Words:known_key(raw)
    local word, base = self:_resolve(raw)
    if not word then return nil end
    if base and base ~= "" and base ~= word then return base end
    return word
end

function Words:_match_keys(raw)
    local word, base, lemma = self:_resolve(raw)
    if not word then return {} end
    local out, seen = {}, {}
    add_unique(out, seen, word)
    add_unique(out, seen, base)
    add_unique(out, seen, lemma)
    return out
end

-- ---------------------------------------------------------------------------
-- KOReader Vocabulary Builder (read-only)
-- ---------------------------------------------------------------------------

function Words:vocabulary_signature()
    return table.concat({
        file_stamp(self.vocab_path),
        file_stamp(self.vocab_path .. "-wal"),
        file_stamp(self.vocab_path .. "-shm"),
    }, "|")
end

function Words:_load_vocabulary()
    -- SQ3.open would create an empty DB. Avoid doing that when Vocabulary
    -- Builder has never been used.
    if not lfs.attributes(self.vocab_path, "mode") then return {} end

    local ok_sq3, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_sq3 or not SQ3 then
        return nil, "sqlite binding unavailable"
    end

    local ok_open, db = pcall(SQ3.open, self.vocab_path)
    if not ok_open or not db then
        return nil, tostring(db or "cannot open vocabulary builder db")
    end

    local words = {}
    local ok, err = pcall(function()
        local stmt = db:prepare("select word from vocabulary")
        if not stmt then error("cannot prepare vocabulary query") end
        while true do
            local row = stmt:step()
            if not row then break end
            local word = row[1] and Lexicon.normalize_hyphenated(tostring(row[1])) or nil
            if word then words[word] = true end
        end
        pcall(function() stmt:close() end)
    end)
    pcall(function() db:close() end)

    if not ok then return nil, tostring(err) end
    return words
end

function Words:vocabulary(force)
    local signature = self:vocabulary_signature()
    if not force and self._vocab_signature == signature then
        return self._vocabulary
    end

    local words, err = self:_load_vocabulary()
    if words then
        self._vocabulary = words
        self._vocab_signature = signature
    else
        -- Vocabulary Builder writes concurrently in WAL mode. Keep the last
        -- good snapshot and retry on the next page/task.
        logger.warn("wordgloss: cannot read Vocabulary Builder:", tostring(err))
    end
    return self._vocabulary
end

-- ---------------------------------------------------------------------------
-- WordGloss known words (read/write)
-- ---------------------------------------------------------------------------

function Words:_ensure_known_table()
    if not self.cache then return false end
    local db = self.cache:open()
    if not db then return false end
    local ok, err = pcall(function()
        db:exec([[
            CREATE TABLE IF NOT EXISTS known_words (
                word TEXT PRIMARY KEY,
                ts INTEGER NOT NULL
            );
        ]])
    end)
    if not ok then
        logger.warn("wordgloss: cannot initialize known_words:", tostring(err))
        return false
    end
    return true
end

function Words:_load_known()
    if not self:_ensure_known_table() then
        return nil, "known_words table unavailable"
    end
    local db = self.cache:open()
    local words = {}
    local ok, err = pcall(function()
        local stmt = db:prepare("select word from known_words")
        if not stmt then error("cannot prepare known_words query") end
        while true do
            local row = stmt:step()
            if not row then break end
            local word = row[1] and tostring(row[1]) or nil
            if word and word ~= "" then words[word] = true end
        end
        pcall(function() stmt:close() end)
    end)
    if not ok then
        return nil, tostring(err)
    end
    return words
end

function Words:known(force)
    if not force and self._known ~= nil then return self._known end
    local words, err = self:_load_known()
    if words then
        self._known = words
    else
        logger.warn("wordgloss: cannot read known_words:", tostring(err))
    end
    return self._known or {}
end

function Words:known_match(raw)
    local known = self:known()
    for _, key in ipairs(self:_match_keys(raw)) do
        if known[key] then return key end
    end
    return nil
end

function Words:isKnown(raw)
    return self:known_match(raw) ~= nil
end

function Words:addKnown(raw)
    local key = self:known_key(raw)
    if not key or not self:_ensure_known_table() then return false end
    if not self.cache:_execute(
        "insert or replace into known_words(word, ts) values(?, ?)", key, os.time()) then
        return false
    end
    self:known()[key] = true
    return true, key
end

function Words:removeKnown(raw)
    if not self:_ensure_known_table() then return false end
    local known = self:known()
    local removed = false
    for _, key in ipairs(self:_match_keys(raw)) do
        if known[key] then
            if self.cache:_execute("delete from known_words where word = ?", key) then
                known[key] = nil
                removed = true
            end
        end
    end
    return removed
end

function Words:listKnown()
    local out = {}
    for word in pairs(self:known()) do out[#out + 1] = word end
    table.sort(out)
    return out
end

function Words:clearKnown()
    if not self:_ensure_known_table() then return false end
    if not self.cache:_execute("delete from known_words") then return false end
    self._known = {}
    return true
end

function Words:resetVocabulary()
    self._vocab_signature = nil
end

return Words
