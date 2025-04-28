#!/usr/bin/env moonrun
-- bignum.moon

ffi = require "ffi"

load_gmp = ->
  -- first try the GMP_PATH env var
  path = os.getenv("GMP_PATH")
  if path
    success, lib = pcall -> ffi.load(path)
    return lib if success
    error "GMP_PATH was set but ffi.load failed: #{path}"
  -- fallback to default name
  success, lib = pcall -> ffi.load("gmp")
  return lib if success

  error "Could not load GMP: set GMP_PATH or add libgmp to DYLD_LIBRARY_PATH"

ffi.cdef [[
  typedef struct {
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
]]

gmp = load_gmp!

-- Metatype for GC
mpz_wrapper = ffi.metatype("struct { mpz_t value; }", {
  __gc: (self) -> gmp.__gmpz_clear(self.value)
})

class Bignum
  new: (input=0) =>
    if Bignum\is_instance(input)
      return input
    @raw = { value: ffi.new("__mpz_struct[1]") }
    gmp.__gmpz_init(@raw.value)
    if type(input) == "string"
      if input\match("^-?%d+$") or input\match("^-?%d+%.0+$")
        gmp.__gmpz_set_str(@raw.value, input, 10)
      else
        error("Invalid Bignum string: must be integer-like")
    elseif type(input) == "number"
      if input % 1 == 0
        gmp.__gmpz_set_si(@raw.value, input)
      else
        error("Cannot initialize Bignum with non-integer number")
    else
      error("Unsupported Bignum input type")
    setmetatable @, Bignum.__base

  tostring: (self) ->
    unless self
      error("tostring called with nil self")
    cstr = gmp.__gmpz_get_str(nil, 10, self.raw.value)
    if not cstr
      error("GMP failed to convert bignum to string")
    ffi.string(cstr)

  __tostring: (self) -> self\tostring!

  _binop: (other, op) =>
    unless Bignum\is_instance(other)
      other = Bignum(other)
    out = Bignum(0)
    gmp["__gmpz_#{op}"](out.raw.value, @raw.value, other.raw.value)
    out

  __add: (other) => @_binop other, "add"
  __sub: (other) => @_binop other, "sub"
  __mul: (other) => @_binop other, "mul"
  __div: (other) => @_binop other, "tdiv_q"
  __mod: (other) => @_binop other, "tdiv_r"
  __pow: (exp) => @pow(exp)
  __unm: =>
    out = Bignum(0)
    gmp.__gmpz_neg(out.raw.value, @raw.value)
    out

  __eq: (other) =>
    unless Bignum\is_instance(other)
      other = Bignum(other)
    gmp.__gmpz_cmp(@raw.value, other.raw.value) == 0

  __lt: (other) =>
    unless Bignum\is_instance(other)
      other = Bignum(other)
    gmp.__gmpz_cmp(@raw.value, other.raw.value) < 0

  __le: (other) =>
    unless Bignum\is_instance(other)
      other = Bignum(other)
    gmp.__gmpz_cmp(@raw.value, other.raw.value) <= 0

  pow: (self, exponent) ->
    if type(exponent) != "number" or exponent < 0 or exponent % 1 != 0
      error("Exponent must be a non-negative integer")
    out = Bignum(0)
    gmp.__gmpz_pow_ui(out.raw.value, self.raw.value, exponent)
    out

  abs: (self) ->
    out = Bignum(0)
    gmp.__gmpz_abs(out.raw.value, self.raw.value)
    out

  gcd: (self, other) ->
    unless Bignum\is_instance(other)
      other = Bignum(other)
    out = Bignum(0)
    gmp.__gmpz_gcd(out.raw.value, self.raw.value, other.raw.value)
    out

  -- Float conversion (lossy)
  to_number: (self) -> tonumber self\tostring!

  -- Annotated float conversion
  to_number_annotated: (self) ->
    str = self\tostring!
    num = tonumber str
    est_loss = #str > 15 and ("~" .. (#str - 15) .. " digits lost") or "~0 digits lost"
    num, est_loss

  -- Bitwise logic
  band: (other) => @_binop other, "and"
  bor: (other) => @_binop other, "ior"
  bxor: (other) => @_binop other, "xor"
  bnot: (self) ->
    out = Bignum(0)
    gmp.__gmpz_com(out.raw.value, self.raw.value)
    out
  shl: (self, bits) ->
    out = Bignum(0)
    gmp.__gmpz_mul_2exp(out.raw.value, self.raw.value, bits)
    out
  shr: (self, bits) ->
    out = Bignum(0)
    gmp.__gmpz_fdiv_q_2exp(out.raw.value, self.raw.value, bits)
    out
  setbit: (self, i) -> gmp.__gmpz_setbit(self.raw.value, i)
  clrbit: (self, i) -> gmp.__gmpz_clrbit(self.raw.value, i)
  flipbit: (self, i) -> gmp.__gmpz_combit(self.raw.value, i)

  @is_instance: (val) =>
    type(val) == "table" and val.__class == Bignum

-- Test suite trigger
if arg and arg[0] and arg[1] == "--test"
  script_path = debug.getinfo(1, "S").source\match "^@(.*/)"
  package.path = script_path .. "?.lua;" .. script_path .. "?.moon;" .. package.path
  cli_utils = require "cli_utils"
  tf = cli_utils.assert_factory!
  B = Bignum

  tf.assert B("2") + B("3") == B("5"), "2 + 3 == 5"
  tf.assert B("5") - B("3") == B("2"), "5 - 3 == 2"
  tf.assert tostring(B("4") * B("6")) == "24", "4 * 6 == 24"
  tf.assert tostring(B("10") / B("2")) == "5", "10 / 2 == 5"
  tf.assert tostring(B("10") % B("3")) == "1", "10 % 3 == 1"
  tf.assert tostring(B("2") ^ 10) == "1024", "2 ^ 10 == 1024"
  tf.assert tostring(B("-42")\abs!) == "42", "abs(-42) == 42"

  -- Dedicated test for the method form
  tf.assert B("123")\tostring! == "123", "Bignum:tostring! method works"

  f, note = B("12345678901234567890")\to_number_annotated!
  tf.assert type(f) == "number", "float conversion returns number"
  tf.assert type(note) == "string", "conversion note is string"

  tf.assert B("6")\band(B("3")) == B("2"), "6 AND 3 == 2"
  tf.assert B("6")\bor(B("3")) == B("7"), "6 OR 3 == 7"
  tf.assert B("6")\bxor(B("3")) == B("5"), "6 XOR 3 == 5"
  tf.assert B("2")\shl(3) == B("16"), "2 << 3 == 16"
  tf.assert B("16")\shr(2) == B("4"), "16 >> 2 == 4"

  io.stderr\write "Tests completed. Failures: #{tf.fails!}\n"
  os.exit tf.fails!

return Bignum
