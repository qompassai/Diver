-- pqc.lua — Post-quantum / hybrid / classic cryptography for recon tooling.
--
-- What it is: key generation, digital signatures, and KEM key exchange in
-- three strengths, picked by the caller:
--   classic : RSA-4096 everywhere (floor: never anything weaker than RSA-4096)
--   hybrid  : ML-DSA-65 + RSA-4096 dual signatures (both must verify),
--             X25519 + ML-KEM-768 hybrid KEM
--   quantum : ML-DSA-87 signatures, ML-KEM-1024 KEM (pure NIST PQC)
--
-- Backends: liboqs 0.14.0 through LuaJIT FFI for the PQC parts (built from
-- source; see the audit notes for the build recipe), and the openssl CLI for
-- the classic parts. When liboqs is absent only `classic` is available and
-- every hybrid/quantum call fails loudly instead of silently downgrading.
--
-- Key tables are plain data (JSON-serializable) so the keystore can persist
-- them. Secrets never hit logs: errors name the operation, not the bytes.

local M = {}

---@type string[] Strengths from weakest to strongest. Never add RSA < 4096.
M.STRENGTHS = { 'classic', 'hybrid', 'quantum' }

local OQS_CANDIDATES = {
    vim.fn.expand('~/workspace/tools/liboqs/install/lib/liboqs.so'),
}

local ffi_lib = nil ---@type any|nil
local ffi_tried = false

---Locate and load liboqs. Cached after the first attempt.
---@return any|nil lib FFI handle, or nil when unavailable
---@return string|nil err
local function liboqs()
    if ffi_tried then
        return ffi_lib, ffi_lib == nil and 'liboqs unavailable' or nil
    end
    ffi_tried = true
    local ok, ffi = pcall(require, 'ffi')
    if not ok then
        return nil, 'LuaJIT FFI unavailable'
    end
    ffi.cdef([[
typedef struct OQS_KEM {
    const char *method_name; const char *alg_version;
    uint8_t claimed_nist_level; bool ind_cca;
    size_t length_public_key; size_t length_secret_key;
    size_t length_ciphertext; size_t length_shared_secret;
    size_t length_keypair_seed;
} OQS_KEM;
typedef struct OQS_SIG {
    const char *method_name; const char *alg_version;
    uint8_t claimed_nist_level; bool euf_cma;
    size_t length_public_key; size_t length_secret_key;
    size_t length_signature; size_t length_sig_seed; size_t length_sig_opt_seed;
} OQS_SIG;
typedef enum { OQS_SUCCESS = 0, OQS_ERROR = -1 } OQS_STATUS;
OQS_KEM *OQS_KEM_new(const char *m); void OQS_KEM_free(OQS_KEM *k);
OQS_STATUS OQS_KEM_keypair(const OQS_KEM *k, uint8_t *pk, uint8_t *sk);
OQS_STATUS OQS_KEM_encaps(const OQS_KEM *k, uint8_t *ct, uint8_t *ss, const uint8_t *pk);
OQS_STATUS OQS_KEM_decaps(const OQS_KEM *k, uint8_t *ss, const uint8_t *ct, const uint8_t *sk);
OQS_SIG *OQS_SIG_new(const char *m); void OQS_SIG_free(OQS_SIG *s);
OQS_STATUS OQS_SIG_keypair(const OQS_SIG *s, uint8_t *pk, uint8_t *sk);
OQS_STATUS OQS_SIG_sign(const OQS_SIG *s, uint8_t *sg, size_t *sl,
    const uint8_t *m, size_t ml, const uint8_t *sk);
OQS_STATUS OQS_SIG_verify(const OQS_SIG *s, const uint8_t *m, size_t ml,
    const uint8_t *sg, size_t sl, const uint8_t *pk);
]])
    local paths = {}
    if vim.g.recon_liboqs_path ~= nil then
        paths[#paths + 1] = vim.g.recon_liboqs_path
    end
    local env_path = vim.fn.getenv('LIBOQS_PATH')
    if env_path ~= vim.NIL and env_path ~= '' then
        paths[#paths + 1] = env_path
    end
    for _, p in ipairs(OQS_CANDIDATES) do
        paths[#paths + 1] = p
    end
    for _, p in ipairs(paths) do
        local lok, lib = pcall(ffi.load, p)
        if lok and lib ~= nil then
            local kok, kem = pcall(lib.OQS_KEM_new, 'ML-KEM-768')
            if kok and kem ~= nil then
                lib.OQS_KEM_free(kem)
                ffi_lib = lib
                M._ffi = ffi
                return lib, nil
            end
        end
    end
    return nil, 'liboqs not found (set vim.g.recon_liboqs_path or $LIBOQS_PATH)'
end

---Which crypto backend is active.
---@return string 'liboqs+openssl' when PQC is present, else 'openssl'
function M.backend()
    local lib = liboqs()
    if lib ~= nil then
        return 'liboqs+openssl'
    end
    return 'openssl'
end

---@param strength string
---@return boolean
function M.supports(strength)
    if strength == 'classic' then
        return vim.fn.executable('openssl') == 1
    end
    if strength == 'hybrid' or strength == 'quantum' then
        return liboqs() ~= nil and vim.fn.executable('openssl') == 1
    end
    return false
end

---Run openssl with an argv array. Bounded, no shell.
---@param args string[]
---@param input string|nil stdin bytes
---@return boolean ok
---@return string out_or_err stdout on success, stderr excerpt on failure
local function openssl(args, input)
    assert(type(args) == 'table', 'args must be a table')
    if vim.fn.executable('openssl') ~= 1 then
        return false, 'openssl not found in PATH'
    end
    local cmd = { 'openssl' }
    for _, a in ipairs(args) do
        assert(type(a) == 'string', 'openssl arg must be a string')
        cmd[#cmd + 1] = a
    end
    local res = vim.system(cmd, { stdin = input, timeout = 30000 }):wait()
    if res.code ~= 0 then
        return false, 'openssl ' .. args[1] .. ' failed: ' .. (res.stderr or ''):sub(1, 200)
    end
    return true, res.stdout or ''
end

---Write raw bytes to a file. NUL-safe: vim.fn mangles embedded NULs
---(they surface as Blobs), so binary material always goes through libuv.
---@param path string
---@param data string
local function write_raw(path, data)
    local fd = vim.uv.fs_open(path, 'w', 384)
    assert(fd ~= nil, 'open for write failed: ' .. path)
    vim.uv.fs_write(fd, data)
    vim.uv.fs_close(fd)
end

---Read a whole file as raw bytes. NUL-safe (see write_raw).
---@param path string
---@return string|nil data
local function read_raw(path)
    local fd = vim.uv.fs_open(path, 'r', 384)
    if fd == nil then
        return nil
    end
    local stat = vim.uv.fs_fstat(fd)
    local data = stat ~= nil and vim.uv.fs_read(fd, stat.size, 0) or nil
    vim.uv.fs_close(fd)
    if type(data) ~= 'string' then
        return nil
    end
    return data
end

---CSPRNG bytes. /dev/urandom first, openssl rand as fallback.
---@param n integer
---@return string|nil bytes
local function random_bytes(n)
    assert(type(n) == 'number' and n > 0 and n <= 1024, 'n out of range')
    local fd = vim.uv.fs_open('/dev/urandom', 'r', 384)
    if fd ~= nil then
        local data = vim.uv.fs_read(fd, n, 0)
        vim.uv.fs_close(fd)
        if type(data) == 'string' and #data == n then
            return data
        end
    end
    -- Fallback keeps bytes out of Lua: rand writes binary to a file.
    local tmp = vim.fn.tempname()
    local ok = openssl({ 'rand', '-out', tmp, tostring(n) })
    local data = ok and read_raw(tmp) or nil
    os.remove(tmp)
    if type(data) == 'string' and #data == n then
        return data
    end
    return nil
end

---Write a PEM string to a temp file, one line per list item (binary).
---@param path string
---@param pem string
local function write_pem(path, pem)
    vim.fn.writefile(vim.split(pem, '\n', { plain = true }), path, 'b')
end

---SHA256 of raw bytes as lowercase hex. Hex keeps everything ASCII-safe.
---@param data string
---@return string|nil hex
---@return string|nil err
local function sha256_hex(data)
    local tmpin = vim.fn.tempname()
    local tmpout = vim.fn.tempname()
    write_raw(tmpin, data)
    local ok, err = openssl({ 'dgst', '-sha256', '-hex', '-out', tmpout, tmpin })
    os.remove(tmpin)
    if not ok then
        os.remove(tmpout)
        return nil, err
    end
    local out = read_raw(tmpout)
    os.remove(tmpout)
    if out == nil then
        return nil, 'could not read digest'
    end
    local hex = out:match('= (%x+)')
    if hex == nil then
        return nil, 'could not parse digest'
    end
    return hex:lower()
end

---Generate an RSA-4096 keypair via openssl. Nothing weaker, ever.
---@return table|nil key { private_pem, public_pem }
---@return string|nil err
local function rsa4096_keypair()
    local tmp = vim.fn.tempname()
    local ok, err = openssl({ 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:4096', '-out', tmp })
    if not ok then
        return nil, err
    end
    local ok2, pubout = openssl({ 'pkey', '-in', tmp, '-pubout' })
    local priv = table.concat(vim.fn.readfile(tmp, 'b'), '\n')
    os.remove(tmp)
    if not ok2 then
        return nil, pubout
    end
    return { private_pem = priv .. '\n', public_pem = pubout }
end

---@param priv_pem string
---@param msg string
---@return string|nil sig raw signature bytes
local function rsa_sign(priv_pem, msg)
    if type(priv_pem) ~= 'string' or type(msg) ~= 'string' then
        return nil, 'bad sign args'
    end
    local tmpk = vim.fn.tempname()
    local tmpm = vim.fn.tempname()
    local tmps = vim.fn.tempname()
    write_pem(tmpk, priv_pem)
    write_raw(tmpm, msg)
    -- pkeyutl with digest:sha512 expects the pre-hashed digest as input.
    -- Binary digests travel via temp files: vim.system may hand back a Blob.
    local tmpd = vim.fn.tempname()
    local okh, herr = openssl({ 'dgst', '-sha512', '-binary', '-out', tmpd }, msg)
    if not okh then
        os.remove(tmpk)
        os.remove(tmpm)
        os.remove(tmps)
        os.remove(tmpd)
        return nil, herr
    end
    os.remove(tmpm)
    os.rename(tmpd, tmpm)
    local ok, err = openssl({
        'pkeyutl',
        '-sign',
        '-inkey',
        tmpk,
        '-in',
        tmpm,
        '-out',
        tmps,
        '-pkeyopt',
        'digest:sha512',
        '-pkeyopt',
        'rsa_padding_mode:pkcs1',
    })
    local sig = nil
    if ok then
        sig = read_raw(tmps)
    end
    os.remove(tmpk)
    os.remove(tmpm)
    os.remove(tmps)
    os.remove(tmpd)
    if not ok then
        return nil, err
    end
    return sig
end

---@param pub_pem string
---@param msg string
---@param sig string
---@return boolean
local function rsa_verify(pub_pem, msg, sig)
    if type(pub_pem) ~= 'string' or type(msg) ~= 'string' or type(sig) ~= 'string' then
        return false
    end
    local tmpk = vim.fn.tempname()
    local tmpm = vim.fn.tempname()
    local tmps = vim.fn.tempname()
    write_pem(tmpk, pub_pem)
    local tmpd = vim.fn.tempname()
    local okh = openssl({ 'dgst', '-sha512', '-binary', '-out', tmpd }, msg)
    if not okh then
        os.remove(tmpk)
        os.remove(tmpm)
        os.remove(tmps)
        os.remove(tmpd)
        return false
    end
    os.remove(tmpm)
    os.rename(tmpd, tmpm)
    write_raw(tmps, sig)
    local ok = openssl({
        'pkeyutl',
        '-verify',
        '-pubin',
        '-inkey',
        tmpk,
        '-in',
        tmpm,
        '-sigfile',
        tmps,
        '-pkeyopt',
        'digest:sha512',
        '-pkeyopt',
        'rsa_padding_mode:pkcs1',
    })
    os.remove(tmpk)
    os.remove(tmpm)
    os.remove(tmps)
    return ok
end

---ML-DSA sign/verify through liboqs FFI.
---@param alg string 'ML-DSA-65' or 'ML-DSA-87'
---@param secret_b64 string|nil base64 secret key (nil for verify)
---@param public_b64 string base64 public key
---@param msg string
---@param sig string|nil raw signature bytes (nil for sign)
---@return string|boolean out signature bytes when signing, bool when verifying
local function mldsa(alg, secret_b64, public_b64, msg, sig)
    local lib, err = liboqs()
    if lib == nil then
        return nil, err
    end
    local ffi = M._ffi
    local s = lib.OQS_SIG_new(alg)
    if s == nil then
        return nil, alg .. ' not available in this liboqs build'
    end
    local function b64d(x)
        local padded = x:gsub('-', '+'):gsub('_', '/')
        local rem = #padded % 4
        if rem == 2 then
            padded = padded .. '=='
        elseif rem == 3 then
            padded = padded .. '='
        end
        return vim.base64.decode(padded)
    end
    local pk = ffi.new('uint8_t[?]', s.length_public_key)
    if type(public_b64) ~= 'string' then
        lib.OQS_SIG_free(s)
        return nil, 'bad public key'
    end
    local pub_raw = b64d(public_b64)
    if #pub_raw ~= tonumber(s.length_public_key) then
        lib.OQS_SIG_free(s)
        return nil, 'public key length mismatch'
    end
    ffi.copy(pk, pub_raw, #pub_raw)
    local result, rerr = nil, nil
    if sig == nil then
        if type(secret_b64) ~= 'string' then
            lib.OQS_SIG_free(s)
            return nil, 'bad secret key'
        end
        local sk = ffi.new('uint8_t[?]', s.length_secret_key)
        local sec_raw = b64d(secret_b64)
        if #sec_raw ~= tonumber(s.length_secret_key) then
            lib.OQS_SIG_free(s)
            return nil, 'secret key length mismatch'
        end
        ffi.copy(sk, sec_raw, #sec_raw)
        local sg = ffi.new('uint8_t[?]', s.length_signature)
        local sl = ffi.new('size_t[1]')
        if lib.OQS_SIG_sign(s, sg, sl, msg, #msg, sk) ~= 0 then
            rerr = 'ML-DSA sign failed'
        else
            result = ffi.string(sg, tonumber(sl[0]))
        end
    else
        result = lib.OQS_SIG_verify(s, msg, #msg, sig, #sig, pk) == 0
    end
    lib.OQS_SIG_free(s)
    return result, rerr
end

---Generate a signing key for a strength.
---@param strength string 'classic' | 'hybrid' | 'quantum'
---@return table|nil key opaque key table (JSON-serializable)
---@return string|nil err
function M.sig_keygen(strength)
    assert(type(strength) == 'string', 'strength must be a string')
    if not M.supports(strength) then
        return nil, 'strength unavailable on this backend: ' .. strength .. ' (backend=' .. M.backend() .. ')'
    end
    local ffi = M._ffi
    if strength == 'classic' then
        local key, err = rsa4096_keypair()
        if key == nil then
            return nil, err
        end
        key.strength = 'classic'
        key.kind = 'rsa4096'
        return key
    end
    local lib = liboqs()
    assert(lib ~= nil, 'liboqs required')
    local alg = strength == 'quantum' and 'ML-DSA-87' or 'ML-DSA-65'
    local s = lib.OQS_SIG_new(alg)
    if s == nil then
        return nil, alg .. ' not available in this liboqs build'
    end
    local pk = ffi.new('uint8_t[?]', s.length_public_key)
    local sk = ffi.new('uint8_t[?]', s.length_secret_key)
    local rc = lib.OQS_SIG_keypair(s, pk, sk)
    local function b64e(raw)
        return vim.base64.encode(raw):gsub('+', '-'):gsub('/', '_'):gsub('=+$', '')
    end
    local key = nil
    local key_err = nil
    if rc == 0 then
        key = {
            strength = strength,
            kind = alg == 'ML-DSA-87' and 'mldsa87' or 'mldsa65',
            public = b64e(ffi.string(pk, tonumber(s.length_public_key))),
            secret = b64e(ffi.string(sk, tonumber(s.length_secret_key))),
        }
        if strength == 'hybrid' then
            local rsa, rerr = rsa4096_keypair()
            if rsa == nil then
                key = nil
                key_err = rerr
            else
                key.kind = 'mldsa65+rsa4096'
                key.rsa_private_pem = rsa.private_pem
                key.rsa_public_pem = rsa.public_pem
            end
        end
    end
    lib.OQS_SIG_free(s)
    if key == nil then
        return nil, key_err or ('key generation failed for ' .. strength)
    end
    return key
end

---Sign a message with a key from sig_keygen.
---@param key table
---@param msg string
---@return string|nil sig raw bytes
---@return string|nil err
function M.sig_sign(key, msg)
    assert(type(key) == 'table' and type(msg) == 'string', 'bad args')
    if key.strength == 'classic' then
        return rsa_sign(key.private_pem, msg)
    end
    if key.strength == 'quantum' then
        return mldsa('ML-DSA-87', key.secret, key.public, msg, nil)
    end
    if key.strength == 'hybrid' then
        local s1, err = mldsa('ML-DSA-65', key.secret, key.public, msg, nil)
        if s1 == nil then
            return nil, err
        end
        -- ML-DSA-65 signatures are fixed 3309 bytes: no length prefix needed.
        assert(#s1 == 3309, 'unexpected ML-DSA-65 signature length')
        local s2, err2 = rsa_sign(key.rsa_private_pem, msg)
        if s2 == nil then
            return nil, err2
        end
        return s1 .. s2
    end
    return nil, 'unknown strength: ' .. tostring(key.strength)
end

---Verify a signature. Both halves must pass for hybrid.
---@param key table
---@param msg string
---@param sig string raw bytes
---@return boolean
function M.sig_verify(key, msg, sig)
    assert(type(key) == 'table' and type(msg) == 'string' and type(sig) == 'string', 'bad args')
    if key.strength == 'classic' then
        return rsa_verify(key.public_pem, msg, sig)
    end
    if key.strength == 'quantum' then
        local ok = mldsa('ML-DSA-87', nil, key.public, msg, sig)
        return ok == true
    end
    if key.strength == 'hybrid' then
        if #sig < 3309 then
            return false
        end
        local s1 = sig:sub(1, 3309)
        local s2 = sig:sub(3310)
        local ok1 = mldsa('ML-DSA-65', nil, key.public, msg, s1)
        local ok2 = rsa_verify(key.rsa_public_pem, msg, s2)
        return ok1 == true and ok2 == true
    end
    return false
end

---Generate a KEM keypair for a strength.
---@param strength string
---@return table|nil key
---@return string|nil err
function M.kem_keygen(strength)
    assert(type(strength) == 'string', 'strength must be a string')
    if not M.supports(strength) then
        return nil, 'strength unavailable: ' .. strength
    end
    if strength == 'classic' then
        local key, err = rsa4096_keypair()
        if key == nil then
            return nil, err
        end
        key.strength = 'classic'
        key.kind = 'rsa4096-oaep'
        return key
    end
    local lib = liboqs()
    assert(lib ~= nil, 'liboqs required')
    local ffi = M._ffi
    local alg = strength == 'quantum' and 'ML-KEM-1024' or 'ML-KEM-768'
    local k = lib.OQS_KEM_new(alg)
    assert(k ~= nil, alg .. ' unavailable')
    local pk = ffi.new('uint8_t[?]', k.length_public_key)
    local sk = ffi.new('uint8_t[?]', k.length_secret_key)
    local rc = lib.OQS_KEM_keypair(k, pk, sk)
    local function b64e(ptr, len)
        return vim.base64.encode(ffi.string(ptr, tonumber(len))):gsub('+', '-'):gsub('/', '_'):gsub('=+$', '')
    end
    local key = nil
    if rc == 0 then
        key = {
            strength = strength,
            kind = alg == 'ML-KEM-1024' and 'mlkem1024' or 'mlkem768',
            public = b64e(pk, k.length_public_key),
            secret = b64e(sk, k.length_secret_key),
        }
    end
    lib.OQS_KEM_free(k)
    if key == nil then
        return nil, 'KEM keygen failed for ' .. strength
    end
    if strength == 'hybrid' then
        -- Hybrid KEX adds a classic X25519 ECDH share beside ML-KEM-768.
        local tmp = vim.fn.tempname()
        local ok, err = openssl({ 'genpkey', '-algorithm', 'X25519', '-out', tmp })
        if not ok then
            return nil, err
        end
        local ok2, pubout = openssl({ 'pkey', '-in', tmp, '-pubout' })
        local priv = table.concat(vim.fn.readfile(tmp, 'b'), '\n')
        os.remove(tmp)
        if not ok2 then
            return nil, pubout
        end
        key.kind = 'x25519+mlkem768'
        key.x_private_pem = priv .. '\n'
        key.x_public_pem = pubout
    end
    return key
end

---KEM encapsulate against a public key. Returns ciphertext + shared secret.
---@param x string base64url
---@return string raw bytes
local function b64d_url(x)
    local padded = x:gsub('-', '+'):gsub('_', '/')
    local rem = #padded % 4
    if rem == 2 then
        padded = padded .. '=='
    elseif rem == 3 then
        padded = padded .. '='
    end
    return vim.base64.decode(padded)
end

---Classic KEM: random 32-byte secret, RSA-OAEP-4096 wrapped.
---@param key table
---@return table|nil out { ct: string, ss: string }
---@return string|nil err
local function kem_encaps_classic(key)
    if type(key.public_pem) ~= 'string' then
        return nil, 'bad RSA public key'
    end
    local ss = random_bytes(32)
    if ss == nil then
        return nil, 'CSPRNG failure'
    end
    local tmpk = vim.fn.tempname()
    local tmps = vim.fn.tempname()
    local tmpc = vim.fn.tempname()
    write_pem(tmpk, key.public_pem)
    write_raw(tmps, ss)
    local ok, err = openssl({
        'pkeyutl',
        '-encrypt',
        '-pubin',
        '-inkey',
        tmpk,
        '-in',
        tmps,
        '-out',
        tmpc,
        '-pkeyopt',
        'rsa_padding_mode:oaep',
        '-pkeyopt',
        'rsa_oaep_md:sha256',
        '-pkeyopt',
        'rsa_mgf1_md:sha256',
    })
    local ct = nil
    if ok then
        ct = read_raw(tmpc)
    end
    os.remove(tmpk)
    os.remove(tmps)
    os.remove(tmpc)
    if not ok then
        return nil, err
    end
    if ct == nil then
        return nil, 'could not read ciphertext'
    end
    return { ct = ct, ss = ss }
end

---PQC/hybrid KEM encapsulate through liboqs.
---@param key table
---@return table|nil out { ct: string, ss: string, eph_pub?: string }
---@return string|nil err
local function kem_encaps_pqc(key)
    local lib = liboqs()
    if lib == nil then
        return nil, 'liboqs unavailable'
    end
    local ffi = M._ffi
    local alg = key.strength == 'quantum' and 'ML-KEM-1024' or 'ML-KEM-768'
    local k = lib.OQS_KEM_new(alg)
    if k == nil then
        return nil, alg .. ' not available in this liboqs build'
    end
    local pk = ffi.new('uint8_t[?]', k.length_public_key)
    if type(key.public) ~= 'string' then
        lib.OQS_KEM_free(k)
        return nil, 'bad KEM public key'
    end
    local pub_raw = b64d_url(key.public)
    if #pub_raw ~= tonumber(k.length_public_key) then
        lib.OQS_KEM_free(k)
        return nil, 'KEM public key length mismatch'
    end
    ffi.copy(pk, pub_raw, #pub_raw)
    local ct = ffi.new('uint8_t[?]', k.length_ciphertext)
    local ssb = ffi.new('uint8_t[?]', k.length_shared_secret)
    local rc = lib.OQS_KEM_encaps(k, ct, ssb, pk)
    local out = nil
    if rc == 0 then
        out = {
            ct = ffi.string(ct, tonumber(k.length_ciphertext)),
            ss = ffi.string(ssb, tonumber(k.length_shared_secret)),
        }
    end
    lib.OQS_KEM_free(k)
    if out == nil then
        return nil, 'encapsulation failed'
    end
    if key.strength == 'hybrid' then
        -- Add the X25519 ECDH share; final secret = SHA256(x_ss || kem_ss).
        local eph = vim.fn.tempname()
        local ok, err = openssl({ 'genpkey', '-algorithm', 'X25519', '-out', eph })
        if not ok then
            return nil, err
        end
        local ok2, ephpub = openssl({ 'pkey', '-in', eph, '-pubout' })
        if not ok2 then
            os.remove(eph)
            return nil, ephpub
        end
        local peerk = vim.fn.tempname()
        write_pem(peerk, key.x_public_pem)
        local xss = vim.fn.tempname()
        local ok3, err3 = openssl({ 'pkeyutl', '-derive', '-inkey', eph, '-peerkey', peerk, '-out', xss })
        os.remove(eph)
        os.remove(peerk)
        if not ok3 then
            os.remove(xss)
            return nil, err3
        end
        local x_ss = read_raw(xss)
        os.remove(xss)
        if x_ss == nil then
            return nil, 'could not read X25519 secret'
        end
        local hex, err4 = sha256_hex(x_ss .. out.ss)
        if hex == nil then
            return nil, err4
        end
        out.ss = hex
        out.eph_pub = ephpub
    end
    return out
end

---KEM encapsulate against a public key. Returns ciphertext + shared secret.
---@param key table public halves used; secret halves ignored
---@return table|nil out { ct: string, ss: string }
---@return string|nil err
function M.kem_encaps(key)
    assert(type(key) == 'table', 'key must be a table')
    if key.strength == 'classic' then
        return kem_encaps_classic(key)
    end
    if key.strength == 'hybrid' or key.strength == 'quantum' then
        return kem_encaps_pqc(key)
    end
    return nil, 'unknown strength: ' .. tostring(key.strength)
end

---Classic KEM decapsulate: RSA-OAEP-4096 unwrap.
---@param key table
---@param ct string ciphertext bytes
---@return string|nil ss shared secret bytes
---@return string|nil err
local function kem_decaps_classic(key, ct)
    if type(key.private_pem) ~= 'string' then
        return nil, 'bad RSA private key'
    end
    local tmpk = vim.fn.tempname()
    local tmpc = vim.fn.tempname()
    local tmps = vim.fn.tempname()
    write_pem(tmpk, key.private_pem)
    write_raw(tmpc, ct)
    local ok, err = openssl({
        'pkeyutl',
        '-decrypt',
        '-inkey',
        tmpk,
        '-in',
        tmpc,
        '-out',
        tmps,
        '-pkeyopt',
        'rsa_padding_mode:oaep',
        '-pkeyopt',
        'rsa_oaep_md:sha256',
        '-pkeyopt',
        'rsa_mgf1_md:sha256',
    })
    local ss = nil
    if ok then
        ss = read_raw(tmps)
    end
    os.remove(tmpk)
    os.remove(tmpc)
    os.remove(tmps)
    if not ok then
        return nil, err
    end
    if ss == nil then
        return nil, 'could not read shared secret'
    end
    return ss
end

---PQC/hybrid KEM decapsulate through liboqs.
---@param key table
---@param ct string ciphertext bytes
---@param eph_pub string|nil ephemeral X25519 public PEM (hybrid only)
---@return string|nil ss shared secret bytes
---@return string|nil err
local function kem_decaps_pqc(key, ct, eph_pub)
    local lib = liboqs()
    if lib == nil then
        return nil, 'liboqs unavailable'
    end
    local ffi = M._ffi
    local alg = key.strength == 'quantum' and 'ML-KEM-1024' or 'ML-KEM-768'
    local k = lib.OQS_KEM_new(alg)
    if k == nil then
        return nil, alg .. ' not available in this liboqs build'
    end
    local sk = ffi.new('uint8_t[?]', k.length_secret_key)
    if type(key.secret) ~= 'string' then
        lib.OQS_KEM_free(k)
        return nil, 'bad KEM secret key'
    end
    local sec_raw = b64d_url(key.secret)
    if #sec_raw ~= tonumber(k.length_secret_key) then
        lib.OQS_KEM_free(k)
        return nil, 'KEM secret key length mismatch'
    end
    ffi.copy(sk, sec_raw, #sec_raw)
    if #ct ~= tonumber(k.length_ciphertext) then
        lib.OQS_KEM_free(k)
        return nil, 'ciphertext length mismatch'
    end
    local ctb = ffi.new('uint8_t[?]', k.length_ciphertext)
    ffi.copy(ctb, ct, #ct)
    local ssb = ffi.new('uint8_t[?]', k.length_shared_secret)
    local rc = lib.OQS_KEM_decaps(k, ssb, ctb, sk)
    local ss = nil
    if rc == 0 then
        ss = ffi.string(ssb, tonumber(k.length_shared_secret))
    end
    lib.OQS_KEM_free(k)
    if ss == nil then
        return nil, 'decapsulation failed'
    end
    if key.strength == 'hybrid' then
        if type(eph_pub) ~= 'string' then
            return nil, 'hybrid decaps needs the ephemeral X25519 public key'
        end
        local tmpk = vim.fn.tempname()
        local tmpp = vim.fn.tempname()
        local xss = vim.fn.tempname()
        write_pem(tmpk, key.x_private_pem)
        write_pem(tmpp, eph_pub)
        local ok, err = openssl({ 'pkeyutl', '-derive', '-inkey', tmpk, '-peerkey', tmpp, '-out', xss })
        os.remove(tmpk)
        os.remove(tmpp)
        if not ok then
            os.remove(xss)
            return nil, err
        end
        local x_ss = read_raw(xss)
        os.remove(xss)
        if x_ss == nil then
            return nil, 'could not read X25519 secret'
        end
        local hex, err2 = sha256_hex(x_ss .. ss)
        if hex == nil then
            return nil, err2
        end
        ss = hex
    end
    return ss
end

---KEM decapsulate. Needs the full keypair (secret halves).
---@param key table
---@param ct string ciphertext bytes
---@param eph_pub string|nil ephemeral X25519 public PEM (hybrid only)
---@return string|nil ss shared secret bytes
---@return string|nil err
function M.kem_decaps(key, ct, eph_pub)
    assert(type(key) == 'table' and type(ct) == 'string', 'bad args')
    if key.strength == 'classic' then
        return kem_decaps_classic(key, ct)
    end
    if key.strength == 'hybrid' or key.strength == 'quantum' then
        return kem_decaps_pqc(key, ct, eph_pub)
    end
    return nil, 'unknown strength: ' .. tostring(key.strength)
end

---Reset backend detection (tests only).
function M._reset()
    ffi_lib = nil
    ffi_tried = false
    M._ffi = nil
end

---Cryptographically secure random bytes for non-PQC uses (jti, nonces).
---@param n integer 1..1024
---@return string|nil bytes, string|nil err
function M.random(n)
    assert(type(n) == 'number' and n >= 1 and n <= 1024, 'n out of range')
    local bytes = random_bytes(n)
    if bytes == nil then
        return nil, 'CSPRNG failure'
    end
    return bytes
end

return M
