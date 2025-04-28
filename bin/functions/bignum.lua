local ffi = require("ffi")
local load_gmp
load_gmp = function()
  local path = os.getenv("GMP_PATH")
  if path then
    local success, lib = pcall(function()
      return ffi.load(path)
    end)
    if success then
      return lib
    end
    error("GMP_PATH was set but ffi.load failed: " .. tostring(path))
  end
  local success, lib = pcall(function()
    return ffi.load("gmp")
  end)
  if success then
    return lib
  end
  return error("Could not load GMP: set GMP_PATH or add libgmp to DYLD_LIBRARY_PATH")
end
ffi.cdef([[  typedef struct {
    int _mp_alloc, _mp_size;
    void *_mp_d;
  } __mpz_struct;
  typedef __mpz_struct mpz_t[1];

  void __gmpz_init(mpz_t);
  void __gmpz_clear(mpz_t);
  void __gmpz_set_str(mpz_t, const char *, int);
  void __gmpz_set_si(mpz_t, long);
  void __gmpz_set(mpz_t, const mpz_t);
  void __gmpz_add(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_sub(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_mul(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_tdiv_q(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_tdiv_r(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_pow_ui(mpz_t, const mpz_t, unsigned long);
  void __gmpz_abs(mpz_t, const mpz_t);
  void __gmpz_neg(mpz_t, const mpz_t);
  void __gmpz_gcd(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_and(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_ior(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_xor(mpz_t, const mpz_t, const mpz_t);
  void __gmpz_com(mpz_t, const mpz_t);
  void __gmpz_mul_2exp(mpz_t, const mpz_t, unsigned long);
  void __gmpz_fdiv_q_2exp(mpz_t, const mpz_t, unsigned long);
  void __gmpz_setbit(mpz_t, unsigned long);
  void __gmpz_clrbit(mpz_t, unsigned long);
  void __gmpz_combit(mpz_t, unsigned long);
  int __gmpz_cmp(const mpz_t, const mpz_t);
  char* __gmpz_get_str(char *, int, const mpz_t);
]])
local gmp = load_gmp()
local mpz_wrapper = ffi.metatype("struct { mpz_t value; }", {
  __gc = function(self)
    return gmp.__gmpz_clear(self.value)
  end
})
local Bignum
do
  local _class_0
  local _base_0 = {
    tostring = function(self)
      if not (self) then
        error("tostring called with nil self")
      end
      local cstr = gmp.__gmpz_get_str(nil, 10, self.raw.value)
      if not cstr then
        error("GMP failed to convert bignum to string")
      end
      return ffi.string(cstr)
    end,
    __tostring = function(self)
      return self:tostring()
    end,
    _binop = function(self, other, op)
      if not (Bignum:is_instance(other)) then
        other = Bignum(other)
      end
      local out = Bignum(0)
      gmp["__gmpz_" .. tostring(op)](out.raw.value, self.raw.value, other.raw.value)
      return out
    end,
    __add = function(self, other)
      return self:_binop(other, "add")
    end,
    __sub = function(self, other)
      return self:_binop(other, "sub")
    end,
    __mul = function(self, other)
      return self:_binop(other, "mul")
    end,
    __div = function(self, other)
      return self:_binop(other, "tdiv_q")
    end,
    __mod = function(self, other)
      return self:_binop(other, "tdiv_r")
    end,
    __pow = function(self, exp)
      return self:pow(exp)
    end,
    __unm = function(self)
      local out = Bignum(0)
      gmp.__gmpz_neg(out.raw.value, self.raw.value)
      return out
    end,
    __eq = function(self, other)
      if not (Bignum:is_instance(other)) then
        other = Bignum(other)
      end
      return gmp.__gmpz_cmp(self.raw.value, other.raw.value) == 0
    end,
    __lt = function(self, other)
      if not (Bignum:is_instance(other)) then
        other = Bignum(other)
      end
      return gmp.__gmpz_cmp(self.raw.value, other.raw.value) < 0
    end,
    __le = function(self, other)
      if not (Bignum:is_instance(other)) then
        other = Bignum(other)
      end
      return gmp.__gmpz_cmp(self.raw.value, other.raw.value) <= 0
    end,
    pow = function(self, exponent)
      if type(exponent) ~= "number" or exponent < 0 or exponent % 1 ~= 0 then
        error("Exponent must be a non-negative integer")
      end
      local out = Bignum(0)
      gmp.__gmpz_pow_ui(out.raw.value, self.raw.value, exponent)
      return out
    end,
    abs = function(self)
      local out = Bignum(0)
      gmp.__gmpz_abs(out.raw.value, self.raw.value)
      return out
    end,
    gcd = function(self, other)
      if not (Bignum:is_instance(other)) then
        other = Bignum(other)
      end
      local out = Bignum(0)
      gmp.__gmpz_gcd(out.raw.value, self.raw.value, other.raw.value)
      return out
    end,
    to_number = function(self)
      return tonumber(self:tostring())
    end,
    to_number_annotated = function(self)
      local str = self:tostring()
      local num = tonumber(str)
      local est_loss = #str > 15 and ("~" .. (#str - 15) .. " digits lost") or "~0 digits lost"
      return num, est_loss
    end,
    band = function(self, other)
      return self:_binop(other, "and")
    end,
    bor = function(self, other)
      return self:_binop(other, "ior")
    end,
    bxor = function(self, other)
      return self:_binop(other, "xor")
    end,
    bnot = function(self)
      local out = Bignum(0)
      gmp.__gmpz_com(out.raw.value, self.raw.value)
      return out
    end,
    shl = function(self, bits)
      local out = Bignum(0)
      gmp.__gmpz_mul_2exp(out.raw.value, self.raw.value, bits)
      return out
    end,
    shr = function(self, bits)
      local out = Bignum(0)
      gmp.__gmpz_fdiv_q_2exp(out.raw.value, self.raw.value, bits)
      return out
    end,
    setbit = function(self, i)
      return gmp.__gmpz_setbit(self.raw.value, i)
    end,
    clrbit = function(self, i)
      return gmp.__gmpz_clrbit(self.raw.value, i)
    end,
    flipbit = function(self, i)
      return gmp.__gmpz_combit(self.raw.value, i)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, input)
      if input == nil then
        input = 0
      end
      if Bignum:is_instance(input) then
        return input
      end
      self.raw = {
        value = ffi.new("__mpz_struct[1]")
      }
      gmp.__gmpz_init(self.raw.value)
      if type(input) == "string" then
        if input:match("^-?%d+$") or input:match("^-?%d+%.0+$") then
          gmp.__gmpz_set_str(self.raw.value, input, 10)
        else
          error("Invalid Bignum string: must be integer-like")
        end
      elseif type(input) == "number" then
        if input % 1 == 0 then
          gmp.__gmpz_set_si(self.raw.value, input)
        else
          error("Cannot initialize Bignum with non-integer number")
        end
      else
        error("Unsupported Bignum input type")
      end
      return setmetatable(self, Bignum.__base)
    end,
    __base = _base_0,
    __name = "Bignum"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.is_instance = function(self, val)
    return type(val) == "table" and val.__class == Bignum
  end
  Bignum = _class_0
end
if arg and arg[0] and arg[1] == "--test" then
  local script_path = debug.getinfo(1, "S").source:match("^@(.*/)")
  package.path = script_path .. "?.lua;" .. script_path .. "?.moon;" .. package.path
  local cli_utils = require("cli_utils")
  local tf = cli_utils.assert_factory()
  local B = Bignum
  tf.assert(B("2") + B("3") == B("5"), "2 + 3 == 5")
  tf.assert(B("5") - B("3") == B("2"), "5 - 3 == 2")
  tf.assert(tostring(B("4") * B("6")) == "24", "4 * 6 == 24")
  tf.assert(tostring(B("10") / B("2")) == "5", "10 / 2 == 5")
  tf.assert(tostring(B("10") % B("3")) == "1", "10 % 3 == 1")
  tf.assert(tostring(B("2") ^ 10) == "1024", "2 ^ 10 == 1024")
  tf.assert(tostring(B("-42"):abs()) == "42", "abs(-42) == 42")
  tf.assert(B("123"):tostring() == "123", "Bignum:tostring! method works")
  local f, note = B("12345678901234567890"):to_number_annotated()
  tf.assert(type(f) == "number", "float conversion returns number")
  tf.assert(type(note) == "string", "conversion note is string")
  tf.assert(B("6"):band(B("3")) == B("2"), "6 AND 3 == 2")
  tf.assert(B("6"):bor(B("3")) == B("7"), "6 OR 3 == 7")
  tf.assert(B("6"):bxor(B("3")) == B("5"), "6 XOR 3 == 5")
  tf.assert(B("2"):shl(3) == B("16"), "2 << 3 == 16")
  tf.assert(B("16"):shr(2) == B("4"), "16 >> 2 == 4")
  io.stderr:write("Tests completed. Failures: " .. tostring(tf.fails()) .. "\n")
  os.exit(tf.fails())
end
return Bignum
