-- Applications submenu built from installed .desktop files, grouped by XDG category
local menu_gen = require("menubar.menu_gen")

local uncategorized = { name = "Other", icon = nil }

local function build(entries)
	local buckets = {}
	for _, e in ipairs(entries) do
		local key = e.category or "other"
		buckets[key] = buckets[key] or {}
		table.insert(buckets[key], { e.name, e.cmdline, e.icon })
	end

	local categories = {}
	for key, items in pairs(buckets) do
		local cat = menu_gen.all_categories[key] or uncategorized
		table.sort(items, function(a, b)
			return a[1]:lower() < b[1]:lower()
		end)
		table.insert(categories, { cat.name, items, cat.icon })
	end
	table.sort(categories, function(a, b)
		return a[1] < b[1]
	end)
	return categories
end

-- parsing the .desktop dirs is async, so the submenu is spliced into the parent
-- once it is ready rather than returned
return function(parent, label)
	menu_gen.generate(function(entries)
		parent:add { label, build(entries) }
	end)
end
