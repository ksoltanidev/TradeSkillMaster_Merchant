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
			if data and data.index then
				if IsShiftKeyDown() then
					TSM.BuyDialog:Show(data.index)
				else
					BuyMerchantItem(data.index, 1)
				end
			end
		end,
		OnEnter = function(_, data, self)
			if data and data.index then
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

local function FormatExtendedCost(index)
	local numCosts = GetMerchantItemCostInfo(index)
	if not numCosts or numCosts == 0 then return nil end

	local parts = {}
	for j = 1, numCosts do
		local itemTexture, itemValue, itemLink, currencyName = GetMerchantItemCostItem(index, j)
		if itemTexture and itemValue then
			local name = currencyName or (itemLink and select(2, strsplit("|", itemLink)) or "") or "?"
			tinsert(parts, format("|T%s:14|t %sx%d", itemTexture, name, itemValue))
		end
	end

	if #parts > 0 then
		return table.concat(parts, " + ")
	end
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

	private.frame.st:SetData(stData)
	private.frame.topLabel:SetText(format(L["Showing %d items."], numItems))
end
