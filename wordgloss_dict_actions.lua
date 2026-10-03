-- Dictionary popup integration for user word state.

local _ = require("gettext")

local DictActions = {}

local function lookup_word(dict_popup)
    return dict_popup and (dict_popup.lookupword or dict_popup.word) or nil
end

function DictActions.register(plugin)
    if not plugin or not plugin.ui or not plugin.ui.dictionary or not plugin.words then
        return false
    end
    if plugin._wordgloss_dict_actions_registered then return true end

    plugin.ui.dictionary:addToDictButtons({
        id = "wordgloss_known",
        conditional = true,
        row_group = "wordgloss",
        text_func = function(dict_popup)
            local word = lookup_word(dict_popup)
            if word and plugin.words:isKnown(word) then
                return _("WordGloss：取消已掌握")
            end
            return _("WordGloss：我已掌握")
        end,
        show_func = function(dict_popup)
            return lookup_word(dict_popup) ~= nil
                and plugin.words:known_key(lookup_word(dict_popup)) ~= nil
        end,
        callback = function(dict_popup)
            local word = lookup_word(dict_popup)
            if not word then return end

            if plugin.words:isKnown(word) then
                plugin.words:removeKnown(word)
            else
                plugin.words:addKnown(word)
            end

            if dict_popup and dict_popup.onClose then
                dict_popup:onClose()
            end
            plugin:scheduleGlossRefresh()
        end,
    })

    plugin._wordgloss_dict_actions_registered = true
    return true
end

return DictActions
