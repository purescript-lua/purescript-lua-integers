-- Shared helpers for the Data.Int FFI. PureScript Int is 32-bit two's
-- complement; these mirror the JS semantics the upstream FFI relies on.
-- JS ToInt32: truncate toward zero, then wrap to signed 32-bit.
local function toInt32(n)
  n = math.modf(n)
  n = n % 0x100000000
  if n >= 0x80000000 then n = n - 0x100000000 end
  return n
end

-- Value of a single base-36 digit (0-9, a-z / A-Z), or nil if not a digit.
local function digitValue(c)
  local b = c:byte()
  if b >= 48 and b <= 57 then return b - 48 end
  if b >= 97 and b <= 122 then return b - 97 + 10 end
  if b >= 65 and b <= 90 then return b - 65 + 10 end
  return nil
end

return {
  fromNumberImpl = (function(just)
    return function(nothing)
      return function(n)
        -- Just only for an integral value inside the Int32 range (JS:
        -- `(n | 0) === n ? just(n) : nothing`); otherwise Nothing.
        local i = math.modf(n)
        if i == n and n >= -2147483648 and n <= 2147483647 then return just(n) end
        return nothing
      end
    end
  end),
  toNumber = (function(n) return n end),
  fromStringAsImpl = (function(just)
    return function(nothing)
      return function(radix)
        return function(s)
          -- Mirror the JS regex `^[+-]?<digits>+$` + Int32 range check:
          -- parse the sign ourselves (Lua 5.1 `tonumber` mishandles a leading
          -- '-' in non-decimal bases) and reject any illegal digit, fractional
          -- point, or surrounding whitespace that `tonumber` would tolerate.
          local sign, body = 1, s
          local first = s:sub(1, 1)
          if first == "-" then
            sign, body = -1, s:sub(2)
          elseif first == "+" then
            body = s:sub(2)
          end
          if #body == 0 then return nothing end
          local n = 0
          for i = 1, #body do
            local d = digitValue(body:sub(i, i))
            if d == nil or d >= radix then return nothing end
            n = n * radix + d
          end
          n = sign * n
          if n < -2147483648 or n > 2147483647 then return nothing end
          return just(n)
        end
      end
    end
  end),
  toStringAs = (function(radix)
    return function(i)
      local floor, insert = math.floor, table.insert
      local n = floor(i)
      if radix == 10 then return tostring(n) end
      -- JS Number.prototype.toString(radix) uses lowercase digits.
      local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
      local t = {}
      local sign = ""
      if n < 0 then
        sign = "-"
        n = -n
      end
      repeat
        local d = (n % radix) + 1
        n = floor(n / radix)
        insert(t, 1, digits:sub(d, d))
      until n == 0
      return sign .. table.concat(t, "")
    end
  end),
  quot = (function(x)
    return function(y)
      if y == 0 then return 0 end
      local q, _ = math.modf(x / y)
      return q
    end
  end),
  rem = (function(x)
    return function(y)
      -- Truncated remainder with the sign of the dividend (JS `x % y`),
      -- consistent with `quot`; Lua's `%` is floored and differs in sign.
      if y == 0 then return 0 end
      local q = math.modf(x / y)
      return x - q * y
    end
  end),
  pow = (function(x)
    return function(y)
      -- JS `Math.pow(x, y) | 0`: truncate toward zero and wrap to Int32.
      return toInt32(math.pow(x, y))
    end
  end)
}
