if not LIB then
    print("Please run bench.lua from the same working directory instead")
    return -- This script shouldn't be run on it's own, it depends on BENCH.LUA
end

---A benchmark for calculating MD5 checksums
local function benchmark_md5sum()
	local s, bm, file = pcall(require, "MD5SUM"), BS("Checksum MD5", T), io.open(arg[0], "rb")

    if not s or not file then
        if file then
            file:close()
        end
        print(string.format("%17s", "Skipped"))
        return
    end

    for _ = 1, T do
        md5_file(file)
        file:seek("set", 0)
    end

    file:close()
    BE(bm)
end

---A benchmark for calculating SHA256 checksums
local function benchmark_sha256()
    local s, bm, file = pcall(require, "S256SUM"), BS("Checksum SHA256", T), io.open(arg[0], "rb")

    if not s or not file then
        if file then
            file:close()
        end
        print(string.format("%17s", "Skipped"))
        return
    end

    for _ = 1, T do
        sha256_file(file)
        file:seek("set", 0)
    end

    file:close()
    BE(bm)
end

--Exponentially increase the amount of iterations based on the set year (from BENCH.LUA)
T = math.floor(2 ^ M)
benchmark_md5sum()
benchmark_sha256()
