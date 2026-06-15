-- Shared helpers for the Data.Int.Bits FFI. JS bitwise/shift operators work on
-- 32-bit two's-complement integers (operands via ToInt32/ToUint32, shift counts
-- masked to 5 bits); Lua 5.1 has no bit library, so emulate that here.
-- Unsigned 32-bit value of n, in [0, 2^32).
local function toUint32(n)
  n = math.modf(n)
  return n % 0x100000000
end

-- Signed 32-bit value of n: wrap the unsigned representation back to signed.
local function toInt32(n)
  n = toUint32(n)
  if n >= 0x80000000 then n = n - 0x100000000 end
  return n
end

-- Bitwise op over the 32 bits of a and b; f(bitA, bitB) -> 0 | 1.
local function bitwise(a, b, f)
  a, b = toUint32(a), toUint32(b)
  local result, bitval = 0, 1
  for _ = 1, 32 do
    if f(a % 2, b % 2) == 1 then result = result + bitval end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bitval = bitval * 2
  end
  return toInt32(result)
end

-- Left-shift the unsigned 32-bit value u by count (0..31), low 32 bits only.
-- Keeping just the bits that survive avoids the precision loss a plain
-- `u * 2^count` would hit once the product exceeds 2^53.
local function shiftLeftU(u, count)
  local low = u % (2 ^ (32 - count))
  return low * (2 ^ count)
end

return {
  ["and"] = (function(a)
    return function(b)
      return bitwise(a, b, function(x, y)
        if x == 1 and y == 1 then return 1 end
        return 0
      end)
    end
  end),
  ["or"] = (function(a)
    return function(b)
      return bitwise(a, b, function(x, y)
        if x == 1 or y == 1 then return 1 end
        return 0
      end)
    end
  end),
  xor = (function(a)
    return function(b)
      return bitwise(a, b, function(x, y)
        if x ~= y then return 1 end
        return 0
      end)
    end
  end),
  shl = (function(a) return function(b) return toInt32(shiftLeftU(toUint32(a), b % 32)) end end),
  shr = (function(a)
    return function(b)
      -- Arithmetic (sign-propagating) shift, JS `>>`: floor-divide the signed
      -- value, which rounds toward negative infinity like an arithmetic shift.
      return toInt32(math.floor(toInt32(a) / (2 ^ (b % 32))))
    end
  end),
  zshr = (function(a)
    return function(b)
      -- Logical (zero-fill) shift, JS `>>>`: operate on the unsigned value and
      -- do NOT re-sign the result, so e.g. `zshr (-8) 1 == 2147483644`.
      return math.floor(toUint32(a) / (2 ^ (b % 32)))
    end
  end),
  complement = (function(a) return math.floor(-a - 1) end)
}
