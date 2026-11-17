--!strict
-- Player-facing error / reason texts of the client controllers in ONE place (audit 2.4, session 8). Texts unchanged - only moved.
-- Shop teleport (ShopController), manual run result reasons (RunController), course save slots (CourseSlotsController), decorations (DecorController).
local Strings = {}

Strings.Teleport = {
	InRun = "Finish or cancel your run first", Rate = "One moment...", NoCharacter = "You can't teleport right now",
	NoShop = "The shop isn't available", NoPlot = "Your plot is not ready yet",
}

Strings.RunReasons = {
	repeat_ = "Already cleared this version - no new reward", tooFast = "Too fast to be real - no reward", noProfile = "Data still loading - no reward",
	suspicious = "Run cancelled: suspicious movement", changed = "The owner changed the course", ownerLeft = "The owner left the game", timeout = "Out of time",
}

Strings.CourseSlots = {
	Empty = "Your course is empty - nothing to save or clear", EmptySlot = "This slot is empty", NothingFits = "Nothing from this save fits your plot now",
	NoPlot = "Your plot is not ready yet", Rate = "One moment...",
}

Strings.Decor = {
	OutOfBounds = "Decorations go on your land, not on the course area", Crowded = "Too close to another decoration", NoCoins = "Not enough Coins",
	LimitReached = "Decoration limit reached - Rebirth for more", Rate = "One moment...",
}

return Strings
