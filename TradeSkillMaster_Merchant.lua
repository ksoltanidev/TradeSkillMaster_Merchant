-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             A TradeSkillMaster Addon for Ascension WoW                        --
--    Replaces the default merchant window with a compact TSM-styled interface   --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
TSM = LibStub("AceAddon-3.0"):NewAddon(TSM, "TSM_Merchant", "AceEvent-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

TSM._version = GetAddOnMetadata("TradeSkillMaster_Merchant", "Version")

local savedDBDefaults = {
	global = {
		defaultMerchantTab = true,
		wishlist = {},
	},
}

function TSM:OnEnable()
	TSM.db = LibStub("AceDB-3.0"):New("AscensionTSM_MerchantDB", savedDBDefaults, true)

	for moduleName, module in pairs(TSM.modules) do
		TSM[moduleName] = module
	end

	TSM:RegisterModule()
end

function TSM:RegisterModule()
	TSM.icons = {
		{
			side = "module",
			desc = "Merchant",
			slashCommand = "merchant",
			callback = function() TSM:Print("TSM_Merchant v" .. TSM._version .. " loaded.") end,
			icon = "Interface\\Icons\\INV_Misc_Coin_01",
		},
	}

	TSM.slashCommands = {
		{
			key = "merchantwish",
			label = L["Toggle Wishlist window"],
			callback = function() TSM:ToggleWishlistWindow() end,
		},
	}

	TSMAPI:NewModule(TSM)
end

function TSM:ToggleWishlistWindow()
	if TSM.WishlistWindow then
		TSM.WishlistWindow:Toggle()
	end
end
