-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             MerchantTab: Frame creation, hooking, Default UI toggle            --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local MerchantTab = TSM:NewModule("MerchantTab", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

local private = {}

-- Default MerchantFrame elements to hide/show when toggling
local defaultElements = {
	-- Item slots
	"MerchantItem1", "MerchantItem2", "MerchantItem3", "MerchantItem4",
	"MerchantItem5", "MerchantItem6", "MerchantItem7", "MerchantItem8",
	"MerchantItem9", "MerchantItem10", "MerchantItem11", "MerchantItem12",
	-- Navigation
	"MerchantNextPageButton", "MerchantPrevPageButton",
	-- Repair
	"MerchantRepairItemButton", "MerchantRepairAllIcon", "MerchantGuildBankRepairButton",
	-- Buyback
	"MerchantBuyBackItem",
	-- Text/UI
	"MerchantPageText", "MerchantNameText", "MerchantRepairText",
	-- Money
	"MerchantMoneyFrame",
	-- Close button
	"MerchantFrameCloseButton",
	-- Portrait
	"MerchantFramePortrait",
}

function MerchantTab:OnEnable()
	MerchantTab:RegisterEvent("MERCHANT_SHOW", function()
		TSMAPI:CreateTimeDelay("merchantShowDelay", 0, private.OnMerchantShow)
	end)
end

function private:OnMerchantShow()
	private.frame = private.frame or private:CreateMerchantTab()
	if TSM.db.global.defaultMerchantTab then
		for i = 1, MerchantFrame.numTabs do
			if _G["MerchantFrameTab" .. i] and _G["MerchantFrameTab" .. i].isTSMTab then
				_G["MerchantFrameTab" .. i]:Click()
				break
			end
		end
	end
end

function private:HideDefaultElements()
	for _, name in ipairs(defaultElements) do
		local element = _G[name]
		if element then element:Hide() end
	end
end

function private:ShowDefaultElements()
	for _, name in ipairs(defaultElements) do
		local element = _G[name]
		if element then element:Show() end
	end
end

function private:CreateMerchantTab()
	local frame = CreateFrame("Frame", nil, MerchantFrame)
	TSMAPI.Design:SetFrameBackdropColor(frame)
	frame:Hide()
	frame:SetPoint("TOPLEFT")
	frame:SetPoint("BOTTOMRIGHT")
	frame:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
	frame:EnableMouse(true)

	-- Tab switching callbacks
	local function OnTabClick(self)
		PanelTemplates_SetTab(MerchantFrame, self:GetID())
		-- Hide default merchant content
		MerchantFrameTab1:Hide()
		MerchantFrameTab2:Hide()
		self:Hide()
		private:HideDefaultElements()
		private.frame:Show()
	end

	local function OnOtherTabClick()
		if not private.frame then return end
		private.frame:Hide()
		private.frame.tab:Show()
		MerchantFrameTab1:Show()
		MerchantFrameTab2:Show()
		private:ShowDefaultElements()
		MerchantFrameTab1:Click()
	end

	-- Add TSM tab to MerchantFrame
	local n = MerchantFrame.numTabs + 1
	local tab = CreateFrame("Button", "MerchantFrameTab" .. n, MerchantFrame, "FriendsFrameTabTemplate")
	tab:Hide()
	tab:SetID(n)
	tab:SetText(TSMAPI.Design:GetInlineColor("link2") .. "TSM_Merchant|r")
	tab:SetNormalFontObject(GameFontHighlightSmall)
	tab.isTSMTab = true
	tab:SetPoint("LEFT", _G["MerchantFrameTab" .. (n - 1)], "RIGHT", -8, 0)
	tab:Show()
	tab:SetScript("OnClick", OnTabClick)
	PanelTemplates_SetNumTabs(MerchantFrame, n)
	PanelTemplates_EnableTab(MerchantFrame, n)
	frame.tab = tab

	-- Header: Title
	local title = TSMAPI.GUI:CreateLabel(frame)
	title:SetPoint("TOPLEFT", 5, -5)
	title:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -5, -25)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("CENTER")
	title:SetText("TSM_Merchant - v" .. TSM._version)

	-- Header: Close button (X)
	local closeBtn = TSMAPI.GUI:CreateButton(frame, 19)
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetWidth(20)
	closeBtn:SetHeight(20)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", CloseMerchant)

	-- Header: Default UI switch button
	local switchBtn = TSMAPI.GUI:CreateButton(frame, 15)
	switchBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, 0)
	switchBtn:SetHeight(20)
	switchBtn:SetWidth(85)
	switchBtn:SetText(L["Default UI"])
	switchBtn:SetScript("OnClick", OnOtherTabClick)
	frame.switchBtn = switchBtn

	-- Header decorative lines
	local line = TSMAPI.GUI:CreateVerticalLine(frame, 0)
	line:ClearAllPoints()
	line:SetPoint("TOPRIGHT", -30, -1)
	line:SetWidth(2)
	line:SetHeight(30)
	TSMAPI.GUI:CreateHorizontalLine(frame, -30)

	-- Placeholder buttons
	private:CreatePlaceholderButtons(frame)

	return frame
end

function private:CreatePlaceholderButtons(frame)
	local btn1 = TSMAPI.GUI:CreateButton(frame, 15)
	btn1:SetPoint("TOPLEFT", 5, -40)
	btn1:SetHeight(20)
	btn1:SetWidth(100)
	btn1:SetText(L["Open Wishlist"])
	btn1:SetScript("OnClick", function() TSM:ToggleWishlistWindow() end)
	frame.btn1 = btn1

	local btn2 = TSMAPI.GUI:CreateButton(frame, 15)
	btn2:SetPoint("TOPLEFT", btn1, "TOPRIGHT", 5, 0)
	btn2:SetHeight(20)
	btn2:SetWidth(100)
	btn2:SetText(L["Placeholder 2"])
	frame.btn2 = btn2

	local btn3 = TSMAPI.GUI:CreateButton(frame, 15)
	btn3:SetPoint("TOPLEFT", btn2, "TOPRIGHT", 5, 0)
	btn3:SetPoint("TOPRIGHT", -5, -40)
	btn3:SetHeight(20)
	btn3:SetText(L["Placeholder 3"])
	frame.btn3 = btn3

	TSMAPI.GUI:CreateHorizontalLine(frame, -70)

	-- Content area for the item list
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 0, -70)
	content:SetPoint("BOTTOMRIGHT")

	frame.itemListTab = TSM.ItemList:CreateTab(content)
end
