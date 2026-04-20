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
		hideUnderTokensEnabled = false,
		hideUnderTokensThreshold = 1500,
		groupByCategory = false,
		hideOwned = false,
		tooltip = {
			enabled = true,
			showMerchantPrice = true,
			showLastSeen = true,
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

	TSM.priceSources = {
		{ key = "BazaarPrice", label = L["Merchant - Bazaar Token Price"], callback = "GetBazaarPrice" },
	}

	TSMAPI:NewModule(TSM)
end

function TSM:ToggleWishlistWindow()
	if TSM.WishlistWindow then
		TSM.WishlistWindow:Toggle()
	end
end

-- ===================================================================================== --
-- Price Source: BazaarPrice (1 token = 1g = 10000 copper)
-- ===================================================================================== --

local COPPER_PER_TOKEN = 10000

function TSM:GetBazaarPrice(itemLink)
	local itemString = TSMAPI:GetItemString(itemLink)
	if not itemString then return nil end
	local entry = TSM:GetMerchantEntry(itemString)
	if not entry then return nil end
	if not entry.extendedCost or not entry.costItems or #entry.costItems == 0 then return nil end
	local tokenCount = entry.costItems[1].value
	if not tokenCount or tokenCount <= 0 then return nil end
	return tokenCount * COPPER_PER_TOKEN
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

	if TSM.db.global.tooltip.showLastSeen then
		if entry.lastSeen then
			local elapsed = time() - entry.lastSeen
			local timeStr
			if elapsed < 3600 then
				timeStr = format("%dm ago", floor(elapsed / 60))
			elseif elapsed < 86400 then
				timeStr = format("%dh ago", floor(elapsed / 3600))
			else
				timeStr = format("%dd ago", floor(elapsed / 86400))
			end
			tinsert(text, { left = "  Last seen:", right = timeStr })
		end
	end

	if #text > 0 then
		tinsert(text, 1, "|cffffff00TSM Merchant:")
		return text
	end
end

-- ===================================================================================== --
-- Public API for other addons (e.g., ChatSeller)
-- ===================================================================================== --

-- Look up merchant data for an itemString.
-- Returns entry table and merchantName, or nil if not found.
function TSM:GetMerchantEntry(itemString)
	if not itemString then return nil end
	local cache = GetItemMerchantCache()
	local match = cache[itemString]
	if not match then return nil end
	return match.entry, match.merchantName
end
