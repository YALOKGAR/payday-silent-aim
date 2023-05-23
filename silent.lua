-- Author: YALOKGAR

local target_closest = true
local shoot_through_wall = false
local shoot_through_wall_thickness = 40
local fov_only = 25

-- Activation
active = not active
managers.hud:show_hint({ text = active and "Aimbot Activated" or "Aimbot Deactivated" })

-- Calculate angle between player and enemy head position
local function calculate_angle(player, enemy_head_pos)
    local direction = enemy_head_pos - player
    mvector3.normalize(direction)
    return direction
end

-- Check if enemy is valid
local function is_valid_enemy(enemy_unit)
    return enemy_unit and enemy_unit:movement() and not enemy_unit:brain():surrendered()
        and (not enemy_unit:brain()._logic_data or not enemy_unit:brain()._logic_data.is_converted)
end

-- Get hits between player and target head position
local function get_hits(weapon, player_pos, target_head_pos)
    return shoot_through_wall and
            World:raycast_wall("ray", player_pos, target_head_pos,
                "slot_mask", weapon._bullet_slotmask,
                "ignore_unit", weapon._setup.ignore_units,
                "thickness", shoot_through_wall_thickness,
                "thickness_mask", managers.slot:get_mask("world_geometry", "vehicles"))
            or World:raycast_all("ray", player_pos, target_head_pos,
                "slot_mask", weapon._bullet_slotmask,
                "ignore_unit", weapon._setup.ignore_units)
end

-- Find the best target based on angle and distance
local function find_best_target(weapon, player_pos, current_direction)
    local best_target_dir = nil
    local closest_angle = math.huge

    for _, enemy_data in pairs(managers.enemy:all_enemies()) do
        local enemy_unit = enemy_data.unit
        if is_valid_enemy(enemy_unit) then
            local target_head_pos = enemy_unit:movement():m_head_pos()
            local hits = get_hits(weapon, player_pos, target_head_pos)

            for _, hit in ipairs(hits) do
                if hit.unit:key() == enemy_unit:key() then
                    local target_direction = calculate_angle(player_pos, target_head_pos)
                    local angle_diff = mvector3.angle(current_direction, target_direction)

                    if angle_diff < closest_angle and (not fov_only or angle_diff <= fov_only) then
                        closest_angle = angle_diff
                        best_target_dir = target_direction

                        if not target_closest then
                            return best_target_dir
                        end
                    end

                    break
                end
            end
        end
    end

    return best_target_dir
end

-- Override the fire function to implement aimbot
local old_fire = NewRaycastWeaponBase.fire
function NewRaycastWeaponBase:fire(from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
    if active and self._setup.user_unit == managers.player:player_unit() then
        local player_pos = managers.player:player_unit():camera():position()
        local current_direction = managers.player:player_unit():camera():forward()
        local target_dir = find_best_target(self, player_pos, current_direction)
        
        if target_dir then
            return old_fire(self, from_pos, target_dir, dmg_mul, shoot_player, 0, autohit_mul, suppr_mul, target_unit)
        end
    end

    return old_fire(self, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
end
