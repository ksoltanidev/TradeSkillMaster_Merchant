-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             ItemList: Scrolling item list, formatting, buy/tooltip             --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local ItemList = TSM:NewModule("ItemList", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

local private = {}

function ItemList:OnEnable()
	ItemList:RegisterEvent("MERCHANT_SHOW")
	TSMAPI:CreateEventBucket("MERCHANT_UPDATE", private.MerchantUpdate, 0.3)
end

function ItemList:MERCHANT_SHOW()
	TSMAPI:CreateTimeDelay("merchantItemListDelay", 0.1, private.MerchantUpdate)
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
		OnClick = function(_, data)
			if data and data.index and not data.isSeparator then
				if IsShiftKeyDown() then
					TSM.BuyDialog:Show(data.index)
				else
					BuyMerchantItem(data.index, 1)
				end
			end
		end,
		OnEnter = function(_, data, self)
			if data and data.index and not data.isSeparator then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetMerchantItem(data.index)
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

function private:MerchantUpdate()
	if not private.frame or not private.frame:IsVisible() then return end

	local numItems = GetMerchantNumItems()
	local yellowColor = "|cffeeff00"
	local greyColor = "|cff999999"

	local stData = {}
	for i = 1, numItems do
		local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(i)
		local itemLink = GetMerchantItemLink(i)

		if name then
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
				-- Some items have both gold and extended cost
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

			tinsert(stData, { cols = { { value = text } }, index = i })
		end
	end

	-- Partition into wishlist matches and non-matches
	local wishlist = TSM.db and TSM.db.global and TSM.db.global.wishlist
	local matchedItems = {}
	local normalItems = {}

	if wishlist and #wishlist > 0 then
		for _, rowData in ipairs(stData) do
			local mName = GetMerchantItemInfo(rowData.index)
			local mLink = GetMerchantItemLink(rowData.index)
			if IsWishlistMatch(mName, mLink, wishlist) then
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

	for _, row in ipairs(normalItems) do
		tinsert(finalData, row)
	end

	private.frame.st:SetData(finalData)

	if #matchedItems > 0 then
		private.frame.topLabel:SetText(format(L["Showing %d items (%d wishlist matches)."], numItems, #matchedItems))
	else
		private.frame.topLabel:SetText(format(L["Showing %d items."], numItems))
	end
end
