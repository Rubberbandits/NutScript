nut.bar = nut.bar or {}
nut.bar.list = {}
nut.bar.delta = nut.bar.delta or {}
nut.bar.actionText = ""
nut.bar.actionStart = 0
nut.bar.actionEnd = 0

function nut.bar.add(getValue, color, priority)
	priority = priority or table.Count(nut.bar.list) + 1

	
	local info = nut.bar.list[priority]

	nut.bar.list[priority] = {
		getValue = getValue,
		color = color or info.color or Color(math.random(150, 255), math.random(150, 255), math.random(150, 255)),
		priority = priority,
		lifeTime = 0
	}

	return priority
end

local color_dark = Color(0, 0, 0, 225)
local gradient = nut.util.getMaterial("vgui/gradient-u")
local gradient2 = nut.util.getMaterial("vgui/gradient-d")

function nut.bar.draw(x, y, w, h, value, color)
	surface.SetDrawColor(25, 25, 25, 240)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(255, 255, 255, 5)
	surface.SetMaterial(gradient2)
	surface.DrawTexturedRect(x, y, w, h)

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawOutlinedRect(x, y, w, h)

	x, y, w, h = x + 2, y + 2, (w - 4) * value, h - 4

	surface.SetDrawColor(color.r, color.g, color.b, 250)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(255, 255, 255, 8)
	surface.SetMaterial(gradient)
	surface.DrawTexturedRect(x, y, w, h)
end	

local TEXT_COLOR = Color(240, 240, 240)
local SHADOW_COLOR = Color(20, 20, 20)

function nut.bar.drawAction()
	local start, finish = nut.bar.actionStart, nut.bar.actionEnd
	local curTime = CurTime()
	local scrW, scrH = ScrW(), ScrH()

	if (finish > curTime) then
		local fraction = 1 - math.TimeFraction(start, finish, curTime)
		local alpha = fraction * 255

		if (alpha > 0) then
			local w, h = scrW * 0.35, 28
			local x, y = (scrW * 0.5) - (w * 0.5), (scrH * 0.725) - (h * 0.5)

			surface.SetDrawColor(35, 35, 35, 240)
			surface.DrawRect(x, y, w, h)

			surface.SetDrawColor(0, 0, 0, 200)
			surface.DrawOutlinedRect(x, y, w, h)

			surface.SetDrawColor(0, 0, 0, 100)
			surface.SetMaterial(gradient)
			surface.DrawTexturedRect(x, y, w, h)

			surface.SetDrawColor(nut.config.get("color"))
			surface.DrawRect(x + 4, y + 4, (w * fraction) - 8, h - 8)

			surface.SetDrawColor(200, 200, 200, 20)
			surface.SetMaterial(gradient2)
			surface.DrawTexturedRect(x + 4, y + 4, (w * fraction) - 8, h - 8)

			draw.SimpleText(nut.bar.actionText, "nutMediumFont", x + 2, y - 22, SHADOW_COLOR)
			draw.SimpleText(nut.bar.actionText, "nutMediumFont", x, y - 24, TEXT_COLOR)
		end
	end
end

local Approach = math.Approach

function nut.bar.drawAll()
	local w, h = surface.ScreenWidth() * 0.35, 10
	local x, y = 4, 4
	local deltas = nut.bar.delta
	local frameTime = FrameTime()
	local curTime = CurTime()

	for k, v in ipairs(nut.bar.list) do
		local realValue = v.getValue()
		local value = Approach(deltas[k] or 0, realValue, frameTime * 0.6)

		deltas[k] = value

		if (deltas[k] != realValue) then
			v.lifeTime = curTime + 5
		end

		if (v.lifeTime >= curTime) then
			nut.bar.draw(x, y, w, h, value, v.color)
			y = y + (h + 2)
		end
	end

	nut.bar.drawAction()
end

do
	nut.bar.add(function()
		return LocalPlayer():Health() / LocalPlayer():GetMaxHealth()
	end, Color(200, 50, 40))

	nut.bar.add(function()
		return math.min(LocalPlayer():Armor() / 100, 1)
	end, Color(30, 70, 180))
end

netstream.Hook("actBar", function(start, finish, text)
	if (!text) then
		nut.bar.actionStart = 0
		nut.bar.actionEnd = 0
	else
		if (text:sub(1, 1) == "@") then
			text = L2(text:sub(2)) or text
		end

		nut.bar.actionStart = start
		nut.bar.actionEnd = finish
		nut.bar.actionText = text:upper()
	end
end)