#!/usr/bin/env lua

-- sides = The amount of sides a dice has
-- dice  = The amount of dice to roll
-- roll  = Table to store the roll information
sides, dice, roll = tonumber(arg[2]) or 6, tonumber(arg[1]) or 1, {}

for _ = 1, dice do -- Roll all the dice
    table.insert(roll, math.floor(math.random(1, sides)))
end

print("Dice rolled: " .. table.concat(roll, ", "))
