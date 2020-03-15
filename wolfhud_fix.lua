--Icon fix for WolfHUD
--WolfHUD-master/lua/Utils/LoadoutPanel.lua
--WolfHUD-master/lua/CustomHUD.lua

--Use vanilla weapon with rarity icon for swapped skins
local orig_LoadoutImageItem_get_outfit_data = LoadoutImageItem.get_outfit_data
function LoadoutImageItem:get_outfit_data(type, id, weapon_id)
	if type == "weapon_skin" then
		local weapon_skin = tweak_data.blackmarket.weapon_skins[id]
		if weapon_skin then
			local found_weapon = (weapon_skin.weapon_ids and table.contains(weapon_skin.weapon_ids, weapon_id)) or (weapon_skin.weapon_id and weapon_skin.weapon_id == weapon_id)
			if weapon_skin.use_blacklist then
				found_weapon = not found_weapon
			end
			if not found_weapon then
				local texture = managers.blackmarket:get_weapon_icon_path(weapon_id, nil)
				
				local name_id = tweak_data.weapon[weapon_id].name_id
				local name_text = managers.localization:text(name_id)
				
				local rarity = weapon_skin.rarity
				local rarity_texture = tweak_data.economy.rarities[rarity] and tweak_data.economy.rarities[rarity].bg_texture
				
				return texture, name_text, rarity_texture
			end
		end
	end
	
	return orig_LoadoutImageItem_get_outfit_data(self, type, id)
end

--Modify get_outfit_data call
function LoadoutWeaponItem:update_weapon(outfit)
	local weapon_id = managers.weapon_factory:get_weapon_id_by_factory_id(outfit[self._name].factory_id)
	if weapon_id then
		self:set_enabled("outfit", true)
		if self._loadout ~= weapon_id then
			self._loadout = weapon_id
			local cosmetic_id = outfit[self._name].cosmetics and outfit[self._name].cosmetics.id
			local weapon_skin = tweak_data.blackmarket.weapon_skins[cosmetic_id] and not tweak_data.blackmarket.weapon_skins[cosmetic_id].is_a_color_skin or false
			--Changed this line
			local texture, name, rarity = self:get_outfit_data(weapon_skin and "weapon_skin" or "weapon", weapon_skin and cosmetic_id or weapon_id, weapon_id)
			
			self:set_text(name)
			self:set_image(texture)
			self:set_rarity(rarity)
			
			return true
		end
	else
		self:set_enabled("outfit", false)
	end
end

--Modify get_outfit_data call
function LoadoutMeleeItem:set_outfit(outfit)
	if outfit.melee_weapon then
		if outfit.melee_weapon == "weapon" then
			self:set_enabled("outfit", true)
			
			local loadout_id = outfit.melee_weapon
			local weapon_textures = {}
			for i, name in ipairs({"primary", "secondary"}) do
				local weapon_id = outfit[name].cosmetics and outfit[name].cosmetics.id or managers.weapon_factory:get_weapon_id_by_factory_id(outfit[name].factory_id)
				local skinned = tweak_data.blackmarket.weapon_skins[weapon_id] and true
				--Changed this line
				local texture, name, rarity = self:get_outfit_data(skinned and "weapon_skin" or "weapon", weapon_id, managers.weapon_factory:get_weapon_id_by_factory_id(outfit[name].factory_id))
				table.insert(weapon_textures, texture)
				loadout_id = string.format("%s_%s", loadout_id, weapon_id)
			end
			
			if loadout_id ~= self._loadout then
				self._loadout = loadout_id
				local _, name, _ = self:get_outfit_data("melee_weapon", outfit.melee_weapon)
				self:set_text(name)
				
				self:set_image(nil)
				for i, panel in ipairs(self._weapon_stock or {}) do
					if alive(panel) then
						local texture = weapon_textures[i]
						if texture then
							panel:set_image(texture)
							panel:set_visible(true)
						else
							panel:set_visible(false)
						end
					end
				end
				
				self:arrange()
			end
		else
			for i, panel in ipairs(self._weapon_stock or {}) do
				if alive(panel) then
					panel:set_visible(false)
				end
			end
			
			LoadoutMeleeItem.super.set_outfit(self, outfit)
		end
	else
		self:set_enabled("outfit", false)
	end
end

--HUD weapon fix (local peer)
Hooks:PostHook(HUDManager, "add_weapon", "sdss_post_HUDManager_add_weapon", function(self, data, ...)
	local wbase = data.unit:base()
	local weapon_id = wbase.name_id
	if wbase._cosmetics_data and wbase._cosmetics_data.name_id then
		local skin_id = wbase._cosmetics_data.name_id:gsub("bm_wskn_", "")
		if tweak_data.blackmarket.weapon_skins[skin_id] and not tweak_data.blackmarket.weapon_skins[skin_id].is_a_color_skin then
			local weapon_skin = tweak_data.blackmarket.weapon_skins[skin_id]
			local found_weapon = (weapon_skin.weapon_ids and table.contains(weapon_skin.weapon_ids, weapon_id)) or (weapon_skin.weapon_id and weapon_skin.weapon_id == weapon_id)
			if weapon_skin.use_blacklist then
				found_weapon = not found_weapon
			end
			if not found_weapon then
				--Wrong weapon, use default
				self:set_teammate_weapon(HUDManager.PLAYER_PANEL, data.inventory_index, weapon_id, wbase:got_silencer())
			end
		end
	end
end)

--HUD weapon fix (other peers)
Hooks:PostHook(HUDManager, "_parse_outfit_string", "sdss_post_HUDManager__parse_outfit_string", function(self, panel_id, peer_id)
	local outfit
	local local_peer = managers.network:session():local_peer()
	if peer_id ~= local_peer:id() then
		local peer = managers.network:session():peer(peer_id)
		outfit = peer and peer:blackmarket_outfit()
		if outfit then
			for selection, data in ipairs({ outfit.secondary, outfit.primary }) do
				local weapon_id = managers.weapon_factory:get_weapon_id_by_factory_id(data.factory_id)
				local cosmetic_id = data.cosmetics and data.cosmetics.id
				--Mistake in original, should be cosmetic_id not weapon_id
				--Original will never display skins because of this
				local has_weapon_skin = tweak_data.blackmarket.weapon_skins[cosmetic_id] and not tweak_data.blackmarket.weapon_skins[cosmetic_id].is_a_color_skin or false
				local found_weapon
				if has_weapon_skin then
					--Check if right weapon
					local weapon_skin = tweak_data.blackmarket.weapon_skins[cosmetic_id]
					found_weapon = (weapon_skin.weapon_ids and table.contains(weapon_skin.weapon_ids, weapon_id)) or (weapon_skin.weapon_id and weapon_skin.weapon_id == weapon_id)
					if weapon_skin.use_blacklist then
						found_weapon = not found_weapon
					end
				end
				local silencer = managers.weapon_factory:has_perk("silencer", data.factory_id, data.blueprint)
				self:set_teammate_weapon(panel_id, selection, found_weapon and cosmetic_id or weapon_id, silencer)
			end
		end
	end
end)
