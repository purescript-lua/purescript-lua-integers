return {
  fromNumberImpl = (function(just)
    return function(nothing)
      return function(n)
        local i = math.modf(n)
        return just(i)
      end
    end
  end),
  toNumber = (function(n) return n end),
  fromStringAsImpl = (function(just)
    return function(nothing)
      return function(radix)
        return function(s)
          local n = tonumber(s, radix)
          if n == nil then return nothing end
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
      local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
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
  rem = (function(x) return function(y) return x % y end end),
  pow = (function(x) return function(y) return math.pow(x, y) end end)
}
