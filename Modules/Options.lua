-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             Options: Tooltip options tab (TSM > Options > Tooltip > Merchant)  --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local Options = TSM:NewModule("Options")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

function Options:LoadTooltipOptions(container)
	local page = {
		{
			type = "SimpleGroup",
			layout = "Flow",
			fullHeight = true,
			children = {
				{
					type = "CheckBox",
					label = L["Enable Merchant tooltip info"],
					relativeWidth = 1,
					settingInfo = { TSM.db.global.tooltip, "enabled" },
					tooltip = L["If checked, merchant price data will be displayed in item tooltips."],
					callback = function(_, _, value)
						container:ReloadTab()
					end,
				},
				{
					type = "CheckBox",
					label = L["Show Ethereal Bazaar price"],
					disabled = not TSM.db.global.tooltip.enabled,
					settingInfo = { TSM.db.global.tooltip, "showMerchantPrice" },
					tooltip = L["Display the merchant price (gold or tokens) in the tooltip."],
				},
				{
					type = "CheckBox",
					label = L["Show last seen time in Ethereal Bazaar"],
					disabled = not TSM.db.global.tooltip.enabled,
					settingInfo = { TSM.db.global.tooltip, "showLastSeen" },
					tooltip = L["Display when the item was last seen at a merchant."],
				},
			},
		},
	}
	TSMAPI:BuildPage(container, page)
end
