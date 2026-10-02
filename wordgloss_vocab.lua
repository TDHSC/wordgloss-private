-- KOReader Vocabulary Builder bridge.
--
-- Reads settings/vocabulary_builder.sqlite3 and exposes a normalized set of
-- user-selected vocabulary words. The DB normally runs in WAL mode, so cache
-- invalidation watches both the main file and its -wal/-shm companions.

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local Lexicon = require("wordgloss_lexicon")

local Vocab = {}

local function file_stamp(path)
    local size = lfs.attributes(path, "size")
    local mtime = lfs.attributes(path, "modification")
    if size == nil and mtime == nil then return "-" end
    return tostring(size or 0) .. ":" .. tostring(mtime or 0)
end

function Vocab:new(o)
    o = o or {}
    o.path = o.path or (DataStorage:getSettingsDir() .. "/vocabulary_builder.sqlite3")
    o._signature = nil
    o._words = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Vocab:signature()
    return table.concat({
        file_stamp(self.path),
        file_stamp(self.path .. "-wal"),
        file_stamp(self.path .. "-shm"),
    }, "|")
end

function Vocab:_load()
    -- Avoid SQ3.open creating a new empty DB when Vocabulary Builder has never
    -- been used on this device.
    if not lfs.attributes(self.path, "mode") then
        return {}
    end

    local ok_sq3, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_sq3 or not SQ3 then
        return nil, "sqlite binding unavailable"
    end

    local ok_open, db = pcall(SQ3.open, self.path)
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
            local raw = row[1]
            local word = raw and Lexicon.normalize_hyphenated(tostring(raw)) or nil
            if word then words[word] = true end
        end
        pcall(function() stmt:close() end)
    end)
    pcall(function() db:close() end)

    if not ok then return nil, tostring(err) end
    return words
end

function Vocab:words(force)
    local signature = self:signature()
    if not force and self._signature == signature then
        return self._words
    end

    local words, err = self:_load()
    if words then
        self._words = words
        self._signature = signature
    else
        -- A concurrent Vocabulary Builder write can make a read fail briefly.
        -- Keep the last good snapshot and retry on the next page/translation.
        logger.warn("wordgloss: cannot read Vocabulary Builder:", tostring(err))
    end
    return self._words
end

function Vocab:contains(word)
    local normalized = Lexicon.normalize_hyphenated(word)
    return normalized ~= nil and self:words()[normalized] == true
end

function Vocab:reset()
    self._signature = nil
end

return Vocab
