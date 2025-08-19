#!/usr/bin/env lua

---Print the current state of the board to the screen
---@param board table The board to print
local function printBoard(board)
	local d = "\n---------\n" io.write(d)
	for i = 1, 9 do io.write(board[i] .. (i % 3 ~= 0 and " | " or d)) end
	print()
end

---Check a player has won the game
---@param board table The board to check
---@param player string The player to check a win for
---@return boolean true if the player has won, otherwise false
local function checkWin(board, player)
	if (board[5] == player) and ((board[1] == player and board[9] == player) or (board[3] == player and board[7] == player)) then
		return true
	end
	for i = 1, 7, 3 do
		if board[i] == player and board[i + 1] == player and board[i + 2] == player then
			return true
		end
	end
	for i = 1, 3 do
		if board[i] == player and board[i + 3] == player and board[i + 6] == player then
			return true
		end
	end
	return false
end

---Check if the board is completely full
---@param board table The board to check
---@return boolean true if the board is full otherwise false
local function boardFull(board)
	for i = 1, 9 do
		if tonumber(board[i]) then return false end
	end
	return true
end

---Give a human player their turn
---@param board table The board to make a move on
local function humanMove(board)
	while true do io.write("User number: ") io.flush()
		local n = tonumber(io.read())
		if n and n < 10 and n > 0 then
			local i
			if n < 4 then
				i = n + 6
			elseif n > 6 then
				i = n - 6
			else
				i = n
			end
			if tonumber(board[i]) then
				board[i] = "U"
				break
			end
			print(n .. " is taken")
		else
			print("Choose between 1 and 9")
		end
	end
end

---Give a computer player their turn
---@param board table The board to make a move on
local function computerMove(board)
	local function oppositeOf(i)
		return i == 1 and 9 or i == 3 and 7 or i == 7 and 3 or i == 9 and 1 or i == 2 and 8 or i == 4 and 6 or i == 6 and 4 or 2
	end
	local function SelectAnything()
		for j = 1, 9 do
			if tonumber(board[j]) then
				return j
			end
		end
	end
	local i
	if tonumber(board[5]) then
		i = 5
	else
		local r, map, c = math.floor(math.random(1, 4)), {1,3,7,9} c = board[map[r]]
		if tonumber(c) then
			i = map[r]
		elseif c ~= "C" and tonumber(board[oppositeOf(map[r])]) then
			i = oppositeOf(map[r])
		else
			map = {2,4,6,8} c = board[map[r]]
			if tonumber(c) then
				i = map[r]
			elseif c ~= "C" and tonumber(board[oppositeOf(map[r])]) then
				i = oppositeOf(map[r])
			else
				i = SelectAnything()
			end
		end
	end
	print("CPU chose: " .. board[i])
	board[i] = "C"
end

---Game state machine
local function game()
	local b = {"7","8","9","4","5","6","1","2","3"}
	printBoard(b)

	while true do
		humanMove(b)
		if checkWin(b, "U") then
			print("User wins!")
			printBoard(b)
			break
		elseif boardFull(b) then
			print("It's a tie!")
			printBoard(b)
			break
		end
		computerMove(b)
		if checkWin(b, "C") then
			print("CPU wins!")
			printBoard(b)
			break
		elseif boardFull(b) then
			print("It's a tie!")
			printBoard(b)
			break
		end
		printBoard(b)
	end
end

while true do -- Main Loop
	game()
	io.write("Play again? (y/N) ")
	io.flush()

	if string.upper(io.read()) ~= "Y" then
		break
	end
end
