-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             WishlistModal: Add item dialog for the wishlist                    --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")
local WW = TSM.WishlistWindow
local private = WW._private

-- ============================================================================= --
-- Add Item Modal
-- ============================================================================= --

function WW:ShowAddItemModal()
	if private.addItemModal then
		private.addItemModal:Show()
		private.modalItemBox:SetText("")
		private.modalItemBox:SetFocus()
		return
	end

	-- Create modal frame
	local modal = CreateFrame("Frame", "TSMMerchantWishlistAddModal", UIParent)
	modal:SetSize(320, 120)
	modal:SetPoint("CENTER")
	modal:SetFrameStrata("DIALOG")
	modal:SetFrameLevel(110)
	modal:EnableMouse(true)
	modal:SetMovable(true)
	modal:RegisterForDrag("LeftButton")
	modal:SetScript("OnDragStart", function(self) self:StartMoving() end)
	modal:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	TSMAPI.Design:SetFrameBackdropColor(modal)
	private.addItemModal = modal

	-- Title
	local title = modal:CreateFontString(nil, "OVERLAY")
	title:SetFont(TSMAPI.Design:GetContentFont("normal"))
	title:SetText(L["Add Wishlist Item"])
	title:SetPoint("TOP", 0, -8)
	TSMAPI.Design:SetWidgetTextColor(title)

	-- Close X button
	local closeBtn = TSMAPI.GUI:CreateButton(modal, 18)
	closeBtn:SetPoint("TOPRIGHT", -3, -3)
	closeBtn:SetWidth(19)
	closeBtn:SetHeight(19)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", function()
		WW:HideAddItemModal()
	end)

	-- Item label + EditBox
	local itemLabel = modal:CreateFontString(nil, "OVERLAY")
	itemLabel:SetFont(TSMAPI.Design:GetContentFont("small"))
	itemLabel:SetText(L["Item name or link (Shift+Click)"])
	itemLabel:SetPoint("TOPLEFT", 15, -30)
	TSMAPI.Design:SetWidgetTextColor(itemLabel)

	local itemBox = CreateFrame("EditBox", "TSMMerchantWishlistModalItemBox", modal, "InputBoxTemplate")
	itemBox:SetPoint("TOPLEFT", 18, -43)
	itemBox:SetPoint("TOPRIGHT", -18, -43)
	itemBox:SetHeight(22)
	itemBox:SetAutoFocus(false)
	itemBox:SetFont(TSMAPI.Design:GetContentFont("small"))
	itemBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	itemBox:SetScript("OnEnterPressed", function()
		WW:AddWishlistItem()
	end)
	private.modalItemBox = itemBox

	-- Add button
	local addBtn = TSMAPI.GUI:CreateButton(modal, 14)
	addBtn:SetPoint("BOTTOMLEFT", 15, 10)
	addBtn:SetWidth(130)
	addBtn:SetHeight(24)
	addBtn:SetText(L["Add"])
	addBtn:SetScript("OnClick", function()
		WW:AddWishlistItem()
	end)

	-- Cancel button
	local cancelBtn = TSMAPI.GUI:CreateButton(modal, 14)
	cancelBtn:SetPoint("BOTTOMRIGHT", -15, 10)
	cancelBtn:SetWidth(130)
	cancelBtn:SetHeight(24)
	cancelBtn:SetText(L["Cancel"])
	cancelBtn:SetScript("OnClick", function()
		WW:HideAddItemModal()
	end)

	-- Hook ChatEdit_InsertLink so Shift+Click item linking works in the editbox
	local origChatEditInsertLink = ChatEdit_InsertLink
	ChatEdit_InsertLink = function(text)
		if private.modalItemBox and private.modalItemBox:HasFocus() then
			private.modalItemBox:Insert(text)
			return true
		end
		return origChatEditInsertLink(text)
	end

	-- Escape key closes modal
	tinsert(UISpecialFrames, "TSMMerchantWishlistAddModal")

	itemBox:SetFocus()
end

function WW:HideAddItemModal()
	if private.addItemModal then
		private.addItemModal:Hide()
	end
end

-- ============================================================================= --
-- Add Wishlist Item
-- ============================================================================= --

function WW:AddWishlistItem()
	local input = private.modalItemBox and strtrim(private.modalItemBox:GetText()) or ""
	if input == "" then return end

	local entry = {}

	-- Try to resolve as item link first
	local itemName, itemLink = GetItemInfo(input)
	if itemName and itemLink then
		entry.name = itemName
		entry.itemLink = itemLink
		entry.itemId = tonumber(strmatch(itemLink, "|Hitem:(%d+):"))
	else
		-- Plain text name entry
		entry.name = input
	end

	-- Check for duplicates (by name, case-insensitive)
	local lowerName = strlower(entry.name)
	for _, existing in ipairs(TSM.db.global.wishlist) do
		if strlower(existing.name) == lowerName then
			TSM:Print(format(L["'%s' is already in your wishlist."], entry.name))
			return
		end
	end

	tinsert(TSM.db.global.wishlist, entry)
	TSM:Print(format(L["Added '%s' to wishlist."], entry.itemLink or entry.name))

	WW:HideAddItemModal()
	WW:Refresh()
end
