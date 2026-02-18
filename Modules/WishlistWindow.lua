-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             WishlistWindow: Standalone movable/resizable wishlist window       --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

-- ============================================================================= --
-- Module Setup
-- ============================================================================= --

TSM.WishlistWindow = {}
local WW = TSM.WishlistWindow

local private = {
	frame = nil,
	rows = {},
	scrollFrame = nil,
	NUM_ROWS = 10,
	ROW_HEIGHT = 24,
}
WW._private = private

local FRAME_WIDTH = 350
local FRAME_HEIGHT = 320

-- ============================================================================= --
-- Public API
-- ============================================================================= --

function WW:Toggle()
	if not private.frame then
		WW:CreateFrame()
	end
	if private.frame:IsShown() then
		private.frame:Hide()
	else
		private.frame:Show()
		WW:Refresh()
	end
end

function WW:Show()
	if not private.frame then
		WW:CreateFrame()
	end
	private.frame:Show()
	WW:DrawRows()
end

function WW:Refresh()
	if not private.frame or not private.frame:IsShown() then return end
	WW:DrawRows()
end

function WW:AddFromMerchant(merchantIndex)
	local name = GetMerchantItemInfo(merchantIndex)
	local itemLink = GetMerchantItemLink(merchantIndex)
	if not name then return end

	local entry = { name = name }
	if itemLink then
		entry.itemLink = itemLink
		entry.itemId = tonumber(strmatch(itemLink, "|Hitem:(%d+):"))
	end

	-- Duplicate check (case-insensitive name)
	local lowerName = strlower(name)
	for _, existing in ipairs(TSM.db.global.wishlist) do
		if strlower(existing.name) == lowerName then
			TSM:Print(format(L["'%s' is already in your wishlist."], name))
			return
		end
	end

	tinsert(TSM.db.global.wishlist, entry)
	TSM:Print(format(L["Added '%s' to wishlist."], itemLink or name))
	WW:Refresh()
end

-- ============================================================================= --
-- Frame Creation
-- ============================================================================= --

function WW:CreateFrame()
	local frameDefaults = {
		x = 300,
		y = 300,
		width = FRAME_WIDTH,
		height = FRAME_HEIGHT,
		scale = 1,
	}
	local frame = TSMAPI:CreateMovableFrame("TSMMerchantWishlistFrame", frameDefaults)
	frame:SetFrameStrata("HIGH")
	TSMAPI.Design:SetFrameBackdropColor(frame)
	frame:SetResizable(true)
	frame:SetMinResize(300, 200)
	frame:SetMaxResize(600, 500)

	-- Title
	local title = TSMAPI.GUI:CreateLabel(frame)
	title:SetText(L["Wishlist"])
	title:SetPoint("TOPLEFT")
	title:SetPoint("TOPRIGHT")
	title:SetHeight(20)

	-- Vertical line before close button
	local line = TSMAPI.GUI:CreateVerticalLine(frame, 0)
	line:ClearAllPoints()
	line:SetPoint("TOPRIGHT", -25, -1)
	line:SetWidth(2)
	line:SetHeight(22)

	-- Close button
	local closeBtn = TSMAPI.GUI:CreateButton(frame, 18)
	closeBtn:SetPoint("TOPRIGHT", -3, -3)
	closeBtn:SetWidth(19)
	closeBtn:SetHeight(19)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", function() frame:Hide() end)

	-- Horizontal separator below title
	TSMAPI.GUI:CreateHorizontalLine(frame, -23)

	-- Content container (between title and bottom area)
	local stContainer = CreateFrame("Frame", nil, frame)
	stContainer:SetPoint("TOPLEFT", 0, -25)
	stContainer:SetPoint("BOTTOMRIGHT", 0, 30)
	TSMAPI.Design:SetFrameColor(stContainer)
	private.stContainer = stContainer

	-- Create FauxScrollFrame
	local scrollFrame = CreateFrame("ScrollFrame", "TSMMerchantWishlistScrollFrame", stContainer, "FauxScrollFrameTemplate")
	scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, private.ROW_HEIGHT, function() WW:DrawRows() end)
	end)
	scrollFrame:SetAllPoints(stContainer)
	private.scrollFrame = scrollFrame

	-- Style scroll bar
	local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("BOTTOMRIGHT", stContainer, -2, 0)
	scrollBar:SetPoint("TOPRIGHT", stContainer, -2, -4)
	scrollBar:SetWidth(12)
	local thumbTex = scrollBar:GetThumbTexture()
	thumbTex:SetPoint("CENTER")
	TSMAPI.Design:SetContentColor(thumbTex)
	thumbTex:SetHeight(50)
	thumbTex:SetWidth(scrollBar:GetWidth())
	_G[scrollBar:GetName() .. "ScrollUpButton"]:Hide()
	_G[scrollBar:GetName() .. "ScrollDownButton"]:Hide()

	-- Create rows
	WW:CreateRows(stContainer)

	-- Resize handle (bottom-right corner)
	local resizeHandle = CreateFrame("Frame", nil, frame)
	resizeHandle:SetSize(16, 16)
	resizeHandle:SetPoint("BOTTOMRIGHT", -1, 1)
	resizeHandle:EnableMouse(true)
	resizeHandle:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	resizeHandle:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		frame:SavePositionAndSize()
		WW:UpdateLayout()
	end)
	-- Resize grip texture
	local gripTex = resizeHandle:CreateTexture(nil, "OVERLAY")
	gripTex:SetAllPoints()
	gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeHandle:SetScript("OnEnter", function()
		gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	end)
	resizeHandle:SetScript("OnLeave", function()
		gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	end)

	-- Hook OnSizeChanged for live resize
	frame:SetScript("OnSizeChanged", function(self)
		self:SavePositionAndSize()
		WW:UpdateLayout()
	end)

	-- Bottom: Add Item button
	local addItemBtn = TSMAPI.GUI:CreateButton(frame, 14)
	addItemBtn:SetPoint("BOTTOMLEFT", 3, 3)
	addItemBtn:SetWidth(100)
	addItemBtn:SetHeight(20)
	addItemBtn:SetText(L["Add Item"])
	addItemBtn:SetScript("OnClick", function()
		WW:ShowAddItemModal()
	end)

	private.frame = frame
	frame:Hide()
end

-- ============================================================================= --
-- Row Creation
-- ============================================================================= --

function WW:CreateSingleRow(parent, index)
	local row = CreateFrame("Frame", "TSMMerchantWishlistRow" .. index, parent)
	row:SetHeight(private.ROW_HEIGHT)
	if index == 1 then
		row:SetPoint("TOPLEFT", 0, 0)
		row:SetPoint("TOPRIGHT", -15, 0)
	else
		row:SetPoint("TOPLEFT", private.rows[index - 1], "BOTTOMLEFT")
		row:SetPoint("TOPRIGHT", private.rows[index - 1], "BOTTOMRIGHT")
	end

	-- Highlight
	local highlight = row:CreateTexture()
	highlight:SetAllPoints()
	highlight:SetTexture(1, 0.9, 0, 0.3)
	highlight:Hide()
	row.highlight = highlight

	-- Alternating background
	if index % 2 == 0 then
		local bgTex = row:CreateTexture(nil, "BACKGROUND")
		bgTex:SetAllPoints()
		bgTex:SetTexture("Interface\\WorldStateFrame\\WorldStateFinalScore-Highlight")
		bgTex:SetTexCoord(0.017, 1, 0.083, 0.909)
		bgTex:SetAlpha(0.3)
	end

	-- Item text (takes most of the row width)
	local itemText = row:CreateFontString(nil, "OVERLAY")
	itemText:SetFont(TSMAPI.Design:GetContentFont("small"))
	itemText:SetJustifyH("LEFT")
	itemText:SetJustifyV("CENTER")
	itemText:SetPoint("TOPLEFT", 4, 0)
	itemText:SetPoint("BOTTOMRIGHT", -28, 0)
	TSMAPI.Design:SetWidgetTextColor(itemText)
	row.itemText = itemText

	-- Delete button (right side)
	local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	deleteBtn:SetSize(22, private.ROW_HEIGHT - 4)
	deleteBtn:SetPoint("RIGHT", -2, 0)
	deleteBtn:SetText("X")
	deleteBtn:SetNormalFontObject(GameFontNormalSmall)
	deleteBtn:SetHighlightFontObject(GameFontHighlightSmall)
	row.deleteBtn = deleteBtn

	-- Hover handlers
	row:EnableMouse(true)
	row:SetScript("OnEnter", function() highlight:Show() end)
	row:SetScript("OnLeave", function() highlight:Hide() end)

	row:Hide()
	return row
end

function WW:CreateRows(parent)
	private.rows = {}
	for i = 1, private.NUM_ROWS do
		local row = WW:CreateSingleRow(parent, i)
		tinsert(private.rows, row)
	end
end

-- ============================================================================= --
-- Dynamic Layout Update (on resize)
-- ============================================================================= --

function WW:UpdateLayout()
	if not private.frame then return end

	-- Dynamic row count based on container height
	local containerHeight = private.stContainer:GetHeight()
	local newNumRows = math.floor(containerHeight / private.ROW_HEIGHT)
	if newNumRows < 1 then newNumRows = 1 end

	-- Create additional rows if window grew
	if newNumRows > #private.rows then
		for i = #private.rows + 1, newNumRows do
			local row = WW:CreateSingleRow(private.stContainer, i)
			tinsert(private.rows, row)
		end
	end

	private.NUM_ROWS = newNumRows
	WW:DrawRows()
end

-- ============================================================================= --
-- Row Drawing
-- ============================================================================= --

function WW:DrawRows()
	local wishlist = TSM.db and TSM.db.global and TSM.db.global.wishlist
	if not wishlist then return end

	FauxScrollFrame_Update(private.scrollFrame, #wishlist, private.NUM_ROWS, private.ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(private.scrollFrame)

	for i = 1, #private.rows do
		local row = private.rows[i]

		if i > private.NUM_ROWS then
			row:Hide()
		else
			local dataIndex = i + offset
			local entry = wishlist[dataIndex]

			if entry then
				row:Show()
				-- Display item link if available, otherwise name + note in grey
				local display = entry.itemLink or entry.name
				if entry.note then
					display = display .. " |cff999999(" .. entry.note .. ")|r"
				end
				row.itemText:SetText(display)

				-- Setup delete button
				row.deleteBtn:SetScript("OnClick", function()
					tremove(TSM.db.global.wishlist, dataIndex)
					WW:Refresh()
				end)
			else
				row:Hide()
			end
		end
	end
end
