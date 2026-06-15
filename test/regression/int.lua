-- Regression guard for the Lua 5.1 FFI of Data.Int and Data.Int.Bits.
-- Expected values are taken from the package's own test/Test/Data/Int.purs
-- (the upstream contract) plus the negative bitwise cases from the audit.
--
--   #85 fromNumberImpl: Just only for integral values inside Int32 (was: always Just).
--   #86 fromStringAsImpl: reject floats / out-of-range / illegal digits; sign in any base.
--   #87 toStringAs: lowercase digits for non-decimal bases (was: uppercase).
--   #88 rem: truncated remainder, sign of the dividend (was: Lua floored `%`).
--   #89 pow: integer result truncated toward zero and Int32-wrapped (was: float `math.pow`).
--   #90 and/or/xor: 32-bit two's-complement, correct for negative operands.
--   #91 shl/shr/zshr: JS 32-bit shift semantics (count mod 32, signed/unsigned).
--
-- Run from the repo root: `lua test/regression/int.lua`.
local I = dofile("src/Data/Int.lua")
local B = dofile("src/Data/Int/Bits.lua")

local failures = 0

local function check(name, cond, detail)
  if cond then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name .. ": " .. tostring(detail))
  end
end

-- Maybe helpers for the *Impl functions.
local function just(x) return {tag = "just", value = x} end
local nothing = {tag = "nothing"}
local function isJust(m, v) return type(m) == "table" and m.tag == "just" and m.value == v end
local function isNothing(m) return type(m) == "table" and m.tag == "nothing" end

local fromNumber = I.fromNumberImpl(just)(nothing)
local function fromStringAs(radix, s) return I.fromStringAsImpl(just)(nothing)(radix)(s) end

--------------------------------------------------------------------------------
-- #85 fromNumber: integral & in-range only -----------------------------------

check("fromNumber 1.0 == Just 1", isJust(fromNumber(1.0), 1), tostring(fromNumber(1.0)))
check("fromNumber 42.0 == Just 42", isJust(fromNumber(42.0), 42), "")
check("fromNumber 0.0 == Just 0", isJust(fromNumber(0.0), 0), "")
check("fromNumber 0.9 == Nothing", isNothing(fromNumber(0.9)), "")
check("fromNumber -0.9 == Nothing", isNothing(fromNumber(-0.9)), "")
check("fromNumber 2147483648.0 == Nothing", isNothing(fromNumber(2147483648.0)), "")
check("fromNumber -2147483649.0 == Nothing", isNothing(fromNumber(-2147483649.0)), "")

--------------------------------------------------------------------------------
-- #86 fromStringAs: validate digits, sign, range -----------------------------

check("fromString '0' == Just 0", isJust(fromStringAs(10, "0"), 0), "")
check("fromString '9467' == Just 9467", isJust(fromStringAs(10, "9467"), 9467), "")
check("fromString '-6' == Just -6", isJust(fromStringAs(10, "-6"), -6), "")
check("fromString '+6' == Just 6", isJust(fromStringAs(10, "+6"), 6), "")
check("fromString '0.1' == Nothing", isNothing(fromStringAs(10, "0.1")), "")
check("fromString '42.000000000000001' == Nothing", isNothing(fromStringAs(10, "42.000000000000001")), "")
check("fromString '2147483648' == Nothing", isNothing(fromStringAs(10, "2147483648")), "")
check("fromString '-2147483649' == Nothing", isNothing(fromStringAs(10, "-2147483649")), "")
check("fromString '' == Nothing", isNothing(fromStringAs(10, "")), "")
check("fromString 'a' == Nothing", isNothing(fromStringAs(10, "a")), "")
check("fromString '5a' == Nothing", isNothing(fromStringAs(10, "5a")), "")
check("fromString '42,12' == Nothing", isNothing(fromStringAs(10, "42,12")), "")
check("fromString ' 5 ' (whitespace) == Nothing", isNothing(fromStringAs(10, " 5 ")), "")
check("fromStringAs bin '100' == Just 4", isJust(fromStringAs(2, "100"), 4), "")
check("fromStringAs hex '100' == Just 256", isJust(fromStringAs(16, "100"), 256), "")
check("fromStringAs hex 'EF' == Just 239", isJust(fromStringAs(16, "EF"), 239), "")
check("fromStringAs hex '+ef' == Just 239", isJust(fromStringAs(16, "+ef"), 239), "")
check("fromStringAs hex '-ef' == Just -239", isJust(fromStringAs(16, "-ef"), -239),
      tostring(fromStringAs(16, "-ef") and fromStringAs(16, "-ef").value))
check("fromStringAs hex '+7fffffff' == Just 2147483647", isJust(fromStringAs(16, "+7fffffff"), 2147483647), "")
check("fromStringAs hex '-80000000' == Just -2147483648", isJust(fromStringAs(16, "-80000000"), -2147483648), "")
check("fromStringAs r36 '10' == Just 36", isJust(fromStringAs(36, "10"), 36), "")
check("fromStringAs bin '12' == Nothing", isNothing(fromStringAs(2, "12")), "")
check("fromStringAs oct '8' == Nothing", isNothing(fromStringAs(8, "8")), "")
check("fromStringAs hex '1g' == Nothing", isNothing(fromStringAs(16, "1g")), "")

--------------------------------------------------------------------------------
-- #87 toStringAs: lowercase digits -------------------------------------------

check("toStringAs hex 255 == 'ff'", I.toStringAs(16)(255) == "ff", I.toStringAs(16)(255))
check("toStringAs bin 4 == '100'", I.toStringAs(2)(4) == "100", I.toStringAs(2)(4))
check("toStringAs bin -4 == '-100'", I.toStringAs(2)(-4) == "-100", I.toStringAs(2)(-4))
check("toStringAs hex 2147483647 == '7fffffff'", I.toStringAs(16)(2147483647) == "7fffffff", I.toStringAs(16)(2147483647))

--------------------------------------------------------------------------------
-- #88 rem: truncated remainder + #88/quot law --------------------------------

check("rem -2 3 == -2", I.rem(-2)(3) == -2, tostring(I.rem(-2)(3)))
check("rem 2 -3 == 2", I.rem(2)(-3) == 2, tostring(I.rem(2)(-3)))
for _, p in ipairs({{8, 2}, {-8, 2}, {8, -2}, {-8, -2}, {2, 3}, {-2, 3}, {2, -3}, {-2, -3}}) do
  local a, b = p[1], p[2]
  local q, r = I.quot(a)(b), I.rem(a)(b)
  check("quot/rem law q*b+r==a for (" .. a .. "," .. b .. ")", q * b + r == a, "q=" .. q .. " r=" .. r)
end

--------------------------------------------------------------------------------
-- #89 pow: truncated, Int32-wrapped ------------------------------------------

for _, p in ipairs({
  {2, 2, 4}, {5, 3, 125}, {26, 0, 1}, {0, 32, 0}, {2, -1, 0}, {1, -2, 1}, {2, -2, 0}, {-2, -2, 0}, {-2, 2, 4}, {-2, 3, -8}
}) do check("pow " .. p[1] .. " " .. p[2] .. " == " .. p[3], I.pow(p[1])(p[2]) == p[3], tostring(I.pow(p[1])(p[2]))) end

--------------------------------------------------------------------------------
-- #90 and/or/xor: 32-bit two's-complement ------------------------------------

check("and -1 5 == 5", B["and"](-1)(5) == 5, tostring(B["and"](-1)(5)))
check("and 12 10 == 8", B["and"](12)(10) == 8, tostring(B["and"](12)(10)))
check("or 12 10 == 14", B["or"](12)(10) == 14, tostring(B["or"](12)(10)))
check("or -1 0 == -1", B["or"](-1)(0) == -1, tostring(B["or"](-1)(0)))
check("xor 12 10 == 6", B.xor(12)(10) == 6, tostring(B.xor(12)(10)))
check("xor -1 0 == -1", B.xor(-1)(0) == -1, tostring(B.xor(-1)(0)))

--------------------------------------------------------------------------------
-- #91 shl/shr/zshr: JS 32-bit shifts -----------------------------------------

check("shl 1 31 == -2147483648", B.shl(1)(31) == -2147483648, tostring(B.shl(1)(31)))
check("shl 1 32 == 1 (count mod 32)", B.shl(1)(32) == 1, tostring(B.shl(1)(32)))
check("shl 1 0 == 1", B.shl(1)(0) == 1, tostring(B.shl(1)(0)))
check("shl -1 1 == -2", B.shl(-1)(1) == -2, tostring(B.shl(-1)(1)))
check("shr -8 1 == -4 (arithmetic)", B.shr(-8)(1) == -4, tostring(B.shr(-8)(1)))
check("shr 8 1 == 4", B.shr(8)(1) == 4, tostring(B.shr(8)(1)))
check("shr -1 1 == -1", B.shr(-1)(1) == -1, tostring(B.shr(-1)(1)))
check("zshr -8 1 == 2147483644 (zero-fill)", B.zshr(-8)(1) == 2147483644, tostring(B.zshr(-8)(1)))
check("zshr 8 1 == 4", B.zshr(8)(1) == 4, tostring(B.zshr(8)(1)))
check("complement 5 == -6", B.complement(5) == -6, tostring(B.complement(5)))

--------------------------------------------------------------------------------

if failures > 0 then error(failures .. " regression check(s) failed") end
print("purescript-lua-integers: all FFI regression checks passed")
