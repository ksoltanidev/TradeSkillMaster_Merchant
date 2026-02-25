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
		merchants = {},
		showOutOfStock = false,
		tooltip = {
			enabled = true,
			showMerchantPrice = true,
		},
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

	TSM.tooltipOptions = { callback = "Options:LoadTooltipOptions" }

	TSMAPI:NewModule(TSM)
end

function TSM:ToggleWishlistWindow()
	if TSM.WishlistWindow then
		TSM.WishlistWindow:Toggle()
	end
end

-- ===================================================================================== --
-- Tooltip Integration
-- ===================================================================================== --

local itemMerchantCache = nil
local itemMerchantCacheVersion = 0

local function GetItemMerchantCache()
	local merchants = TSM.db.global.merchants
	local version = 0
	for _ in pairs(merchants) do version = version + 1 end
	if itemMerchantCache and itemMerchantCacheVersion == version then
		return itemMerchantCache
	end
	itemMerchantCache = {}
	for merchantName, merchantData in pairs(merchants) do
		if merchantData.items then
			for key, entry in pairs(merchantData.items) do
				local itemStr = entry.itemString or key
				if not itemMerchantCache[itemStr] then
					itemMerchantCache[itemStr] = { entry = entry, merchantName = merchantName }
				end
			end
		end
	end
	itemMerchantCacheVersion = version
	return itemMerchantCache
end

-- Invalidate cache when merchant data changes (called from ItemList after recording)
function TSM:InvalidateTooltipCache()
	itemMerchantCache = nil
end

local function FormatTooltipPrice(entry)
	if entry.extendedCost and entry.costItems and #entry.costItems > 0 then
		local parts = {}
		for _, cost in ipairs(entry.costItems) do
			if cost.value and cost.value > 0 then
				tinsert(parts, format("|T%s:14|t x%d", cost.texture, cost.value))
			end
		end
		local result = table.concat(parts, " + ")
		if entry.price and entry.price > 0 then
			result = result .. " + " .. TSMAPI:FormatTextMoneyIcon(entry.price, "|cffffffff", true)
		end
		return result
	elseif entry.price and entry.price > 0 then
		return TSMAPI:FormatTextMoneyIcon(entry.price, "|cffffffff", true)
	end
	return nil
end

function TSM:GetTooltip(itemString, quantity)
	if not TSM.db.global.tooltip.enabled then return end
	if not itemString then return end

	local cache = GetItemMerchantCache()
	local match = cache[itemString]
	if not match then return end

	local entry = match.entry
	local merchantName = match.merchantName
	local text = {}

	if TSM.db.global.tooltip.showMerchantPrice then
		local priceStr = FormatTooltipPrice(entry)
		if priceStr and priceStr ~= "" then
			tinsert(text, { left = "  " .. merchantName .. ":", right = priceStr })
		end
	end

	if #text > 0 then
		tinsert(text, 1, "|cffffff00TSM Merchant:")
		return text
	end
end
