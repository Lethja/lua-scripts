#!/usr/bin/env lua

---Get the operating system the script is running on
---@return string A string that will read: DOS, NT, UNIX or Unknown
function OS()
	if os.getenv("COMSPEC") then
		return os.getenv("OS") and "NT" or "DOS"
	else
		return os.getenv("SHELL") and "UNIX" or "Unknown"
	end
end

---Benchmark start, prints the benchmark name and records the current time
---@param name string The name of the benchmark
---@param it number The number of times the benchmark will loop
---@return number The current clock time
function BS(name, it)
	local t = #tostring(it) > 10 and string.format("%10e", it):gsub("%..-e", "e") or it
	io.write(string.format("%-9s", name) .. "\t" .. string.format("%10s", t) .. "\t")
	io.flush()
	return os.clock()
end

---Benchmark end, prints the benchmarks duration
---@param st number The start time returned by BS
function BE(st)
	local t = os.clock() - st
	local m, s = math.floor(t / 60), t % 60
	io.write(string.format("%7d:%09.6f\n", m, s))
end

---A benchmark for calculating Pi using the Nilkantha's series
local function b_pi()
	local it, pi, si = S, 3, 1
	local b = BS("Nilakantha Pi", it)
	for i = 2, it * 2, 2 do
		pi = pi + si * (4 / (i * (i + 1) * (i + 2)))
		si = -si
	end
	BE(b)
end

---A benchmark for calculating a common divisor
local function b_gcd()
	local function gcd(a, b)
		while b ~= 0 do
			a, b = b, a % b
		end
		return a
	end
	local r, b = 0, BS("Common Divisor", S)
	for i = 1, S do
		local x, y = i, S - i + 1
		r = gcd(x, y)
	end
	BE(b)
end

---A benchmark for calculating multiplication performance
local function b_mul()
	local r, b = 1, BS("Multiplication", B)
	for _ = 1, B do
		r = (r * 1.000000001)
	end
	BE(b)
end

---A benchmark for calculating division performance
local function b_div()
	local m, r = B, 1
	local b = BS("Division", m)
	m = m + 1
	for i = 2, m do
		r = r / i
	end
	BE(b)
end

---A benchmark for calculating addition performance
local function b_add()
	local r, b = 1, BS("Addition", B)
	for i = 1, B do
		r = r + i
	end
	BE(b)
end

---A benchmark for calculating floating point addition performance
local function b_flt()
	local r, b = 1.0, BS("Float Addition", B)
	for _ = 1, B do
		r = r + 0.01
	end
	BE(b)
end

---A benchmark for calculating subtraction performance
local function b_sub()
	local r, b = 1, BS("Subtraction", B)
	for i = B, 1, -1 do
		r = r - i
	end
	BE(b)
end

---A benchmark for calculating array iteration performance
local function b_arr()
	local b, a, s = BS("Array Loop", S), {}, 0
	for i = 1, S do
		a[i] = i % 10
	end
	for i = 1, S do
		a[i] = a[i] * 2
	end
	for i = 1, S do
		s = s + a[i]
	end
	BE(b)
end

---Print a horizontal line on the screen
local function L()
	print(string.rep('_', 49))
end

--Print basic system and Lua information
print("Runtime:", _VERSION)
print("OS Family:", OS())
print("Minimum Int:", math.mininteger or "Unknown")
print("Maximum Int:", math.maxinteger or "Unknown")

--Check what benchmark to run
M = tonumber(arg[1])
if M and M > 1979 then
	print("\nRunning benchmark: " .. M)

	--Make the benchmark do more iterations of every test for each year above 1980
	M = (M - 1955) / 25
	B, S = math.floor(500 ^ M), math.floor(100 ^ M)

	print("\nBenchmark", "Iterations", "Time (min:sec.ms)")
	L()
	--Benchmark Start
	b = os.clock()
	b_add()
	b_flt()
	b_sub()
	b_mul()
	b_div()
	b_pi()
	b_gcd()
	b_arr()

	--Run extended benchmarks if available
	LIB = true
	package.path = package.path .. ";?.LUA" --In case of a case sensitive operating system
	pcall(require, "EXBENCH")

	--Benchmark Finish
	L()
	io.write("Total:\t\t" .. string.format("%8.3fkB", collectgarbage("count")) .. "\t")
	BE(b)
else
	print("\nTo benchmark, run again and specify a year > 1979")
end

--Wait for user input so the benchmark results can be read on operating systems that would automatically close the window
print("Press Enter to Exit...")
io.read()
os.exit()
