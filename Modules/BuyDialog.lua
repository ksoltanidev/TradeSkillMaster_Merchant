-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             BuyDialog: Quantity input popup for buying items                   --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local BuyDialog = TSM:NewModule("BuyDialog")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

local private = {}

function BuyDialog:Show(merchantIndex)
	private.dialog = private.dialog or private:CreateDialog()

	local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(merchantIndex)
	local itemLink = GetMerchantItemLink(merchantIndex)

	if not name then return end

	local dialog = private.dialog
	dialog.merchantIndex = merchantIndex
	dialog.unitPrice = price
	dialog.extendedCost = extendedCost
	dialog.stackSize = quantity or 1

	-- Item display
	local displayText = format("|T%s:20|t %s", texture or "", itemLink or name)
	dialog.itemLabel:SetText(displayText)

	-- Reset quantity to 1
	dialog.editBox:SetText("1")
	private:UpdateCost(dialog)

	dialog:Show()
	dialog.editBox:SetFocus()
end

function BuyDialog:Hide()
	if private.dialog then
		private.dialog:Hide()
	end
end

function private:CreateDialog()
	local dialog = CreateFrame("Frame", "TSMMerchantBuyDialog", UIParent)
	dialog:SetSize(280, 140)
	dialog:SetPoint("CENTER")
	dialog:SetFrameStrata("DIALOG")
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:Hide()
	TSMAPI.Design:SetFrameBackdropColor(dialog)

	-- Title
	local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", dialog, "TOP", 0, -10)
	title:SetText(L["Buy Item"])
	dialog.title = title

	-- Item display (icon + link)
	local itemLabel = dialog:CreateFontString(nil, "OVERLAY")
	itemLabel:SetFont(TSMAPI.Design:GetContentFont("normal"))
	itemLabel:SetPoint("TOPLEFT", 15, -32)
	itemLabel:SetPoint("TOPRIGHT", -15, -32)
	itemLabel:SetHeight(20)
	itemLabel:SetJustifyH("LEFT")
	dialog.itemLabel = itemLabel

	-- Quantity row
	local qtyLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	qtyLabel:SetPoint("TOPLEFT", 15, -60)
	qtyLabel:SetText(L["Quantity:"])

	local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
	editBox:SetSize(60, 20)
	editBox:SetPoint("LEFT", qtyLabel, "RIGHT", 10, 0)
	editBox:SetAutoFocus(false)
	editBox:SetNumeric(true)
	editBox:SetMaxLetters(6)
	editBox:SetScript("OnTextChanged", function()
		private:UpdateCost(dialog)
	end)
	editBox:SetScript("OnEnterPressed", function()
		private:ExecutePurchase(dialog)
	end)
	editBox:SetScript("OnEscapePressed", function()
		dialog:Hide()
	end)
	dialog.editBox = editBox

	-- Total cost display
	local costLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	costLabel:SetPoint("LEFT", editBox, "RIGHT", 15, 0)
	costLabel:SetPoint("RIGHT", dialog, "RIGHT", -15, 0)
	costLabel:SetJustifyH("RIGHT")
	dialog.costLabel = costLabel

	-- OK button
	local okBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	okBtn:SetSize(80, 22)
	okBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -5, 10)
	okBtn:SetText(L["OK"])
	okBtn:SetScript("OnClick", function()
		private:ExecutePurchase(dialog)
	end)
	dialog.okBtn = okBtn

	-- Cancel button
	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, 10)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function()
		dialog:Hide()
	end)
	dialog.cancelBtn = cancelBtn

	return dialog
end

function private:UpdateCost(dialog)
	local quantity = tonumber(dialog.editBox:GetText()) or 0
	if quantity <= 0 then
		dialog.costLabel:SetText("")
		return
	end

	if dialog.extendedCost then
		local costStr = private:FormatExtendedCostTotal(dialog.merchantIndex, quantity)
		if costStr then
			dialog.costLabel:SetText(L["Total:"] .. " " .. costStr)
		else
			dialog.costLabel:SetText("")
		end
		-- Also show gold if applicable
		if dialog.unitPrice and dialog.unitPrice > 0 then
			local goldStr = TSMAPI:FormatTextMoney(dialog.unitPrice * quantity)
			local current = dialog.costLabel:GetText()
			if current and current ~= "" then
				dialog.costLabel:SetText(current .. " + " .. goldStr)
			else
				dialog.costLabel:SetText(L["Total:"] .. " " .. goldStr)
			end
		end
	elseif dialog.unitPrice and dialog.unitPrice > 0 then
		dialog.costLabel:SetText(L["Total:"] .. " " .. TSMAPI:FormatTextMoney(dialog.unitPrice * quantity))
	else
		dialog.costLabel:SetText("")
	end
end

function private:FormatExtendedCostTotal(index, quantity)
	local parts = {}
	for j = 1, 5 do
		local itemTexture, itemValue, itemLink = GetMerchantItemCostItem(index, j)
		if not itemTexture then break end
		if itemValue and itemValue > 0 then
			local totalValue = itemValue * quantity
			if itemLink then
				tinsert(parts, format("|T%s:14|t %s x%d", itemTexture, itemLink, totalValue))
			else
				tinsert(parts, format("|T%s:14|t x%d", itemTexture, totalValue))
			end
		end
	end
	if #parts > 0 then return table.concat(parts, " + ") end
	return nil
end

function private:ExecutePurchase(dialog)
	local quantity = tonumber(dialog.editBox:GetText()) or 0
	if quantity <= 0 then return end

	local index = dialog.merchantIndex
	local maxStack = GetMerchantItemMaxStack(index)
	local remaining = quantity

	while remaining > 0 do
		BuyMerchantItem(index, math.min(remaining, maxStack))
		remaining = remaining - maxStack
	end

	dialog:Hide()
end
