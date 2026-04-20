-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             ItemList: Scrolling item list, formatting, buy/tooltip             --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local ItemList = TSM:NewModule("ItemList", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

local private = {
	frame = nil,
	searchFilter = "",
	currentMerchantName = nil,
}

-- ============================================================================= --
-- Category Detection (for "Group by category" filter)
-- ============================================================================= --

local CATEGORY_NAME_PREFIX_RULES = {
	{ prefix = "Incarnation:",           category = "Incarnations"  },
	{ prefix = "Beastmaster's Whistle:", category = "Whistles"      },
	{ prefix = "Demon Scroll",           category = "Demon Scrolls" },
	{ prefix = "Altar of",               category = "Altars"        },
	{ prefix = "Illusion:",              category = "Illusions"     },
}

local CATEGORY_WEAPON_SUBCLASS = {
	["One-Handed Swords"] = "Swords",
	["Two-Handed Swords"] = "Swords",
	["One-Handed Axes"]   = "Axes",
	["Two-Handed Axes"]   = "Axes",
	["One-Handed Maces"]  = "Maces",
	["Two-Handed Maces"]  = "Maces",
	["Daggers"]           = "Daggers",
	["Staves"]            = "Staves",
	["Polearms"]          = "Polearms",
	["Fist Weapons"]      = "Fist Weapons",
	["Bows"]              = "Bows",
	["Guns"]              = "Guns",
	["Crossbows"]         = "Crossbows",
	["Wands"]             = "Wands",
	["Thrown"]            = "Thrown",
}

local CATEGORY_ARMOR_EQUIPLOC = {
	["INVTYPE_HEAD"]     = "Head",
	["INVTYPE_SHOULDER"] = "Shoulders",
	["INVTYPE_CHEST"]    = "Chest",
	["INVTYPE_ROBE"]     = "Chest",
	["INVTYPE_WRIST"]    = "Wrist",
	["INVTYPE_HAND"]     = "Gloves",
	["INVTYPE_WAIST"]    = "Waist",
	["INVTYPE_LEGS"]     = "Legs",
	["INVTYPE_FEET"]     = "Feet",
	["INVTYPE_CLOAK"]    = "Back",
}

-- Hidden tooltip scanner for reading description lines (e.g., cosmetic set caches)
local tooltipScanner
local function IsCosmeticSetItem(itemLink)
	if not itemLink then return false end
	if not tooltipScanner then
		tooltipScanner = CreateFrame("GameTooltip", "TSMMerchantTooltipScanner", nil, "GameTooltipTemplate")
		tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	tooltipScanner:ClearLines()
	tooltipScanner:SetHyperlink(itemLink)
	for i = 1, tooltipScanner:NumLines() do
		local line = _G["TSMMerchantTooltipScannerTextLeft" .. i]
		local text = line and line:GetText()
		if text and strfind(text, '^"A [Cc]osmetic [Ss]et') then
			return true
		end
	end
	return false
end

-- Returns (category, subCategory) — subCategory is nil for non-Weapons/non-Armor.
local function DetectCategory(itemLink, itemName)
	if itemName then
		for _, rule in ipairs(CATEGORY_NAME_PREFIX_RULES) do
			if strsub(itemName, 1, #rule.prefix) == rule.prefix then
				return rule.category, nil
			end
		end
	end

	if not itemLink then return "Other", nil end

	-- Cosmetic set caches (grant a full armor set)
	if IsCosmeticSetItem(itemLink) then
		return "Armor", "Armor sets"
	end

	local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemLink)
	if not itemType then return "Other", nil end

	-- Mount detection (Miscellaneous > Mount on 3.3.5)
	if itemType == "Miscellaneous" and itemSubType == "Mount" then
		return "Mounts", nil
	end

	-- Weapons
	local weaponSub = CATEGORY_WEAPON_SUBCLASS[itemSubType]
	if weaponSub then return "Weapons", weaponSub end
	if equipLoc == "INVTYPE_SHIELD"   then return "Weapons", "Shields"  end
	if equipLoc == "INVTYPE_HOLDABLE" then return "Weapons", "Offhands" end

	-- Armor
	local armorSub = CATEGORY_ARMOR_EQUIPLOC[equipLoc]
	if armorSub then return "Armor", armorSub end
	if equipLoc == "INVTYPE_BODY" then return "Armor", "Tabards" end

	return "Other", nil
end

-- Stable sort order for categories
local CATEGORY_ORDER = {
	"Mounts", "Incarnations", "Demon Scrolls", "Whistles", "Altars", "Illusions",
	"Weapons", "Armor", "Other",
}
local CATEGORY_RANK = {}
for i, name in ipairs(CATEGORY_ORDER) do CATEGORY_RANK[name] = i end

local function GetCategoryRank(cat)
	return CATEGORY_RANK[cat] or 999
end

function ItemList:OnEnable()
	ItemList:RegisterEvent("MERCHANT_SHOW")
	TSMAPI:CreateEventBucket("MERCHANT_UPDATE", private.MerchantUpdate, 0.3)
end

function ItemList:MERCHANT_SHOW()
	private.searchFilter = ""
	private.currentMerchantName = UnitName("npc")
	TSMAPI:CreateTimeDelay("merchantItemListDelay", 0.1, private.MerchantUpdate)
end

function ItemList:SetSearchFilter(text)
	private.searchFilter = strlower(strtrim(text or ""))
	private:MerchantUpdate()
end

function ItemList:RefreshDisplay()
	private:MerchantUpdate()
end

function ItemList:CreateTab(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:SetScript("OnShow", private.MerchantUpdate)

	-- Top label: "Showing X items"
	local label = TSMAPI.GUI:CreateLabel(frame, "small")
	label:SetPoint("TOPLEFT", 5, -5)
	label:SetPoint("TOPRIGHT", -5, -5)
	label:SetHeight(15)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("CENTER")
	frame.topLabel = label

	TSMAPI.GUI:CreateHorizontalLine(frame, -25)

	-- ScrollingTable container
	local stContainer = CreateFrame("Frame", nil, frame)
	stContainer:SetPoint("TOPLEFT", 5, -30)
	stContainer:SetPoint("BOTTOMRIGHT", -5, 5)
	TSMAPI.Design:SetFrameColor(stContainer)

	local handlers = {
		OnClick = function(_, data, self, button)
			if data and not data.isSeparator then
				local link = data.itemLink or data.storedItemLink
				if IsControlKeyDown() and link then
					DressUpItemLink(link)
				elseif IsShiftKeyDown() and button == "LeftButton" and link then
					HandleModifiedItemClick(link)
				elseif not data.isOutOfStock and data.index then
					if IsAltKeyDown() then
						TSM.WishlistWindow:AddFromMerchant(data.index)
					elseif button == "RightButton" then
						if IsShiftKeyDown() then
							TSM.BuyDialog:Show(data.index)
						else
							BuyMerchantItem(data.index, 1)
						end
					end
				end
			end
		end,
		OnEnter = function(_, data, self)
			if data and not data.isSeparator then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if data.isOutOfStock and data.storedItemLink then
					GameTooltip:SetHyperlink(data.storedItemLink)
				elseif data.index then
					GameTooltip:SetMerchantItem(data.index)
				end
				GameTooltip:Show()
			end
		end,
		OnLeave = function()
			GameTooltip:Hide()
		end,
	}

	local st = TSMAPI:CreateScrollingTable(stContainer, nil, handlers)
	st:SetData({})
	frame.st = st

	private.frame = frame
	return frame
end

local function IsWishlistMatch(merchantName, merchantLink, wishlist)
	for _, entry in ipairs(wishlist) do
		-- Match by itemId if the wishlist entry has one
		if entry.itemId and merchantLink then
			local merchantItemId = tonumber(strmatch(merchantLink, "|Hitem:(%d+):"))
			if merchantItemId and merchantItemId == entry.itemId then
				return true
			end
		end
		-- Match by name (case-insensitive substring)
		if entry.name and merchantName then
			if strfind(strlower(merchantName), strlower(entry.name), 1, true) then
				return true
			end
		end
	end
	return false
end

local function FormatExtendedCost(index)
	local parts = {}
	for j = 1, 5 do
		local itemTexture, itemValue, itemLink = GetMerchantItemCostItem(index, j)
		if not itemTexture then break end
		if itemValue and itemValue > 0 then
			if itemLink then
				tinsert(parts, format("|T%s:14|t %s x%d", itemTexture, itemLink, itemValue))
			else
				tinsert(parts, format("|T%s:14|t x%d", itemTexture, itemValue))
			end
		end
	end
	if #parts > 0 then return table.concat(parts, " + ") end
	return nil
end

local function FormatStoredPrice(entry)
	local parts = {}
	if entry.extendedCost and entry.costItems then
		local costParts = {}
		for _, cost in ipairs(entry.costItems) do
			if cost.value and cost.value > 0 then
				if cost.link then
					tinsert(costParts, format("|T%s:14|t %s x%d", cost.texture, cost.link, cost.value))
				else
					tinsert(costParts, format("|T%s:14|t x%d", cost.texture, cost.value))
				end
			end
		end
		if #costParts > 0 then
			tinsert(parts, table.concat(costParts, " + "))
		end
		if entry.price and entry.price > 0 then
			tinsert(parts, "+ " .. TSMAPI:FormatTextMoney(entry.price))
		end
	elseif entry.price and entry.price > 0 then
		tinsert(parts, TSMAPI:FormatTextMoney(entry.price))
	end
	return table.concat(parts, " ")
end

local function RecordMerchantData()
	local merchantName = UnitName("npc")
	if not merchantName then return end
	private.currentMerchantName = merchantName

	local db = TSM.db.global.merchants
	if not db[merchantName] then
		db[merchantName] = { items = {}, lastVisited = 0 }
	end
	local merchantData = db[merchantName]
	merchantData.lastVisited = time()

	local numItems = GetMerchantNumItems()
	for i = 1, numItems do
		local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i)
		local itemLink = GetMerchantItemLink(i)
		if name then
			local itemString = itemLink and TSMAPI:GetItemString(itemLink) or nil
			local key = itemString or name

			local entry = {
				name = name,
				itemLink = itemLink,
				itemString = itemString,
				texture = texture,
				price = price or 0,
				quantity = quantity or 1,
				extendedCost = extendedCost or false,
				numAvailable = numAvailable or -1,
				lastSeen = time(),
			}

			if extendedCost then
				entry.costItems = {}
				for j = 1, 5 do
					local costTexture, costValue, costLink = GetMerchantItemCostItem(i, j)
					if not costTexture then break end
					tinsert(entry.costItems, {
						texture = costTexture,
						value = costValue,
						link = costLink,
					})
				end
			end

			merchantData.items[key] = entry
		end
	end
end

function private:MerchantUpdate()
	if not private.frame or not private.frame:IsVisible() then return end

	-- Record persistent merchant data
	RecordMerchantData()
	TSM:InvalidateTooltipCache()

	local numItems = GetMerchantNumItems()
	local yellowColor = "|cffeeff00"
	local greyColor = "|cff999999"
	local searchFilter = private.searchFilter or ""
	local hideUnderEnabled = TSM.db.global.hideUnderTokensEnabled
	local hideThreshold = TSM.db.global.hideUnderTokensThreshold or 0
	local groupByCategory = TSM.db.global.groupByCategory
	local hideOwned = TSM.db.global.hideOwned
	local ItemTracker = hideOwned and LibStub("AceAddon-3.0"):GetAddon("TSM_ItemTracker", true) or nil

	local function IsOwned(itemString)
		if not ItemTracker or not itemString then return false end
		local pt, at = ItemTracker:GetPlayerTotal(itemString)
		local total = (pt or 0) + (at or 0)
			+ (ItemTracker:GetGuildTotal(itemString) or 0)
			+ (ItemTracker:GetAuctionsTotal(itemString) or 0)
			+ (ItemTracker:GetPersonalBanksTotal(itemString) or 0)
			+ (ItemTracker:GetRealmBankTotal(itemString) or 0)
		return total > 0
	end

	-- Build live items and track which keys are live
	local stData = {}
	local liveItemKeys = {}
	local hiddenByTokenCount = 0

	for i = 1, numItems do
		local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i)
		local itemLink = GetMerchantItemLink(i)

		if name then
			local itemString = itemLink and TSMAPI:GetItemString(itemLink) or nil
			local key = itemString or name
			liveItemKeys[key] = true

			-- Apply search filter
			if searchFilter == "" or strfind(strlower(name), searchFilter, 1, true) then
				-- Apply hide-under-tokens filter (strictly less than threshold)
				local hideByToken = false
				if hideUnderEnabled and extendedCost then
					local _, costValue = GetMerchantItemCostItem(i, 1)
					if costValue and costValue < hideThreshold then
						hideByToken = true
					end
				end

				-- Apply hide-owned filter
				local hideByOwned = hideOwned and IsOwned(itemString)

				if hideByToken or hideByOwned then
					if hideByToken then hiddenByTokenCount = hiddenByTokenCount + 1 end
				else
					local parts = {}

					-- Icon
					if texture then
						tinsert(parts, format("|T%s:14|t", texture))
					end

					-- Item link or name
					if itemLink then
						tinsert(parts, itemLink)
					else
						tinsert(parts, name)
					end

					-- Quantity per purchase (if > 1)
					if quantity and quantity > 1 then
						tinsert(parts, format("(x%d)", quantity))
					end

					-- Availability
					if numAvailable and numAvailable ~= -1 then
						tinsert(parts, yellowColor .. format("(%d %s)", numAvailable, L["left"]) .. "|r")
					end

					-- Separator
					tinsert(parts, "|")

					-- Price
					if extendedCost then
						local costStr = FormatExtendedCost(i)
						if costStr then
							tinsert(parts, costStr)
						end
						if price and price > 0 then
							tinsert(parts, "+ " .. TSMAPI:FormatTextMoney(price))
						end
					elseif price and price > 0 then
						tinsert(parts, TSMAPI:FormatTextMoney(price))
					end

					local text = table.concat(parts, " ")

					-- Grey out unusable items
					if not isUsable then
						text = greyColor .. text .. "|r"
					end

					tinsert(stData, {
						cols = { { value = text } },
						index = i,
						itemName = name,
						itemLink = itemLink,
					})
				end
			end
		end
	end

	-- Inject out-of-stock items from persistent data
	local outOfStockCount = 0
	if TSM.db.global.showOutOfStock and private.currentMerchantName then
		local merchantData = TSM.db.global.merchants[private.currentMerchantName]
		if merchantData and merchantData.items then
			for key, entry in pairs(merchantData.items) do
				if not liveItemKeys[key] then
					-- Apply search filter
					if searchFilter == "" or strfind(strlower(entry.name), searchFilter, 1, true) then
						-- Apply hide-under-tokens filter
						local hideByToken = false
						if hideUnderEnabled and entry.extendedCost and entry.costItems and entry.costItems[1] then
							local v = entry.costItems[1].value
							if v and v < hideThreshold then hideByToken = true end
						end

						-- Apply hide-owned filter
						local hideByOwned = hideOwned and IsOwned(entry.itemString or key)

						if hideByToken or hideByOwned then
							if hideByToken then hiddenByTokenCount = hiddenByTokenCount + 1 end
						else
							local parts = {}
							if entry.texture then
								tinsert(parts, format("|T%s:14|t", entry.texture))
							end
							tinsert(parts, entry.itemLink or entry.name)
							if entry.quantity and entry.quantity > 1 then
								tinsert(parts, format("(x%d)", entry.quantity))
							end
							tinsert(parts, greyColor .. "(" .. L["Out of Stock"] .. ")" .. "|r")
							tinsert(parts, "|")
							local priceStr = FormatStoredPrice(entry)
							if priceStr ~= "" then
								tinsert(parts, priceStr)
							end

							local text = greyColor .. table.concat(parts, " ") .. "|r"
							tinsert(stData, {
								cols = { { value = text } },
								isOutOfStock = true,
								storedItemLink = entry.itemLink,
								itemName = entry.name,
								itemLink = entry.itemLink,
							})
							outOfStockCount = outOfStockCount + 1
						end
					end
				end
			end
		end
	end

	-- Partition into wishlist matches and non-matches
	local wishlist = TSM.db and TSM.db.global and TSM.db.global.wishlist
	local matchedItems = {}
	local normalItems = {}

	if wishlist and #wishlist > 0 then
		for _, rowData in ipairs(stData) do
			if IsWishlistMatch(rowData.itemName, rowData.itemLink, wishlist) then
				tinsert(matchedItems, rowData)
			else
				tinsert(normalItems, rowData)
			end
		end
	else
		normalItems = stData
	end

	-- Build final data: matched items, separator, then normal items
	local finalData = {}
	for _, row in ipairs(matchedItems) do
		tinsert(finalData, row)
	end

	if #matchedItems > 0 and #normalItems > 0 then
		local sepColor = TSMAPI.Design:GetInlineColor("link2")
		local sepText = sepColor .. "--- " .. format(L["%d wishlist matches"], #matchedItems) .. " ---|r"
		tinsert(finalData, { cols = { { value = sepText } }, isSeparator = true })
	end

	if groupByCategory then
		-- Tag each item with its category, then sort and inject separators
		for _, row in ipairs(normalItems) do
			local cat, subCat = DetectCategory(row.itemLink, row.itemName)
			row._category = cat
			row._subCategory = subCat
		end
		table.sort(normalItems, function(a, b)
			local ra, rb = GetCategoryRank(a._category), GetCategoryRank(b._category)
			if ra ~= rb then return ra < rb end
			local sa, sb = a._subCategory or "", b._subCategory or ""
			if sa ~= sb then return sa < sb end
			return (a.itemName or "") < (b.itemName or "")
		end)

		local sepColor = TSMAPI.Design:GetInlineColor("link2")
		local lastCat, lastSub = nil, nil
		for _, row in ipairs(normalItems) do
			if row._category ~= lastCat then
				local label = L[row._category] or row._category
				tinsert(finalData, {
					cols = { { value = sepColor .. "--- " .. label .. " ---|r" } },
					isSeparator = true,
				})
				lastCat = row._category
				lastSub = nil
			end
			if row._subCategory and row._subCategory ~= lastSub then
				local subLabel = L[row._subCategory] or row._subCategory
				tinsert(finalData, {
					cols = { { value = sepColor .. "--- " .. subLabel .. " ---|r" } },
					isSeparator = true,
				})
				lastSub = row._subCategory
			end
			tinsert(finalData, row)
		end
	else
		for _, row in ipairs(normalItems) do
			tinsert(finalData, row)
		end
	end

	private.frame.st:SetData(finalData)

	-- Update top label with counts
	local totalShown = #matchedItems + #normalItems
	if #matchedItems > 0 and outOfStockCount > 0 then
		private.frame.topLabel:SetText(format(L["Showing %d items (%d wishlist matches, %d out of stock)."], totalShown, #matchedItems, outOfStockCount))
	elseif #matchedItems > 0 then
		private.frame.topLabel:SetText(format(L["Showing %d items (%d wishlist matches)."], totalShown, #matchedItems))
	elseif outOfStockCount > 0 then
		private.frame.topLabel:SetText(format(L["Showing %d items (%d out of stock)."], totalShown, outOfStockCount))
	else
		private.frame.topLabel:SetText(format(L["Showing %d items."], totalShown))
	end
end
