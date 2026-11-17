--!strict
-- Robux support shop (spec 23). NOTHING here changes gameplay or the economy: tips + a cosmetic "Supporter" mark only (no pay-to-win).
-- assetId = Developer Product id (kind = "Product") or Game Pass id (kind = "GamePass"), created via Open Cloud 2026-11-16 (universe 10776882597).
-- assetId = 0 would mean "not configured": the card is shown disabled and NO purchase prompt can be opened (no fake purchases).
local Donate = {}

export type Item = { id: string, kind: string, assetId: number, price: number, icon: string, name: string, desc: string, tag: string, color: string }

-- Price ladder (Robux): 25 / 100 / 500 tips (x4, x5 steps: an easy first yes, a comfortable middle, a rare big thank-you) + a 49 R$ entry pass.
-- `price` is the price the product is CREATED with; the card always shows the live price read from Roblox (GetProductInfo), never this number.
-- The Supporter mark (cosmetic) unlocks at SupporterMin total tipped Robux OR with the pass (49 < 50 on purpose: the pass is the cheapest way to the mark).
Donate.SupporterMin = 50

Donate.Items = {
	{ id = "tip_small", kind = "Product", assetId = 3732195535, price = 25, icon = "rbxassetid://138516205083995", name = "Small tip", desc = "A thank-you to the creator. Tips add up: R$ 50 in total unlocks the Supporter mark.", tag = "TIP", color = "teal" },
	{ id = "tip_medium", kind = "Product", assetId = 3732195569, price = 100, icon = "rbxassetid://104195432322290", name = "Medium tip", desc = "A bigger thank-you. Unlocks the Supporter mark.", tag = "TIP", color = "green" },
	{ id = "tip_big", kind = "Product", assetId = 3732195584, price = 500, icon = "rbxassetid://76551350873005", name = "Big tip", desc = "The biggest thank-you. Unlocks the Supporter mark.", tag = "TIP", color = "orange" },
	{ id = "pass_supporter", kind = "GamePass", assetId = 2088370955, price = 49, icon = "rbxassetid://80647395673534", name = "Supporter pass", desc = "A permanent Supporter mark next to your name. Cosmetic only.", tag = "PASS", color = "purple" },
} :: { Item }

Donate.ById = {} :: { [string]: Item }
for _, it in Donate.Items do Donate.ById[it.id] = it end

function Donate.findByAsset(kind: string, assetId: number): Item?
	if assetId == 0 then return nil end
	for _, it in Donate.Items do
		if it.kind == kind and it.assetId == assetId then return it end
	end
	return nil
end

Donate.Note = "Purchases never give a gameplay advantage - everything in TRAP LAB can be earned with Coins."

return Donate
