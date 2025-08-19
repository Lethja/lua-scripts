#!/usr/bin/env lua

-- sides = The amount of sides a dice has
-- dice  = The amount of dice to roll
-- roll  = The amount of times to roll the dice
sides, dice, roll = tonumber(arg[2]) or 6, tonumber(arg[1]) or 1, {}
for _ = 1, dice do
    table.insert(roll, math.floor(math.random(1, sides)))
end
print("Dice rolled: " .. table.concat(roll, ", "))
