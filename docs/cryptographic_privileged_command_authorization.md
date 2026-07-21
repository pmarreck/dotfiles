# Cryptographically Authorizing Specific Privileged Commands

## Goal

Allow a small, explicit set of *complete* operations that would normally need
`sudo` to run without granting a caller general root access or a general
passwordless-`sudo` escape hatch.

The intended user experience is roughly:

```text
privileged-op disk-io-report
    -> asks the device-backed signer to approve this exact request
    -> a root-owned broker verifies that approval
    -> broker executes one fixed, audited operation as root
```

The key phrase is **specific complete command**.  The authorization must name
an operation from a small allow-list, not authorize an arbitrary executable,
shell fragment, or caller-supplied argv.

## Non-goals and important distinctions

This is an authorization design, not a way to make unprivileged code become
root merely by possessing a hash.

- A hardware serial number identifies hardware; it is not a secret.
- `hash(product_serial || salt)` is not a secure password unless `salt` is
  itself a protected high-entropy secret.  In that case the secret, not the
  serial, is what provides security.
- FFI does not bypass kernel permissions.  LuaJIT can call `open(2)` through
  FFI, but it receives the same permission check as every other process.
- A device-backed signing key proves possession of that key.  It does not by
  itself prove that Peter, rather than malware running as Peter, intended a
  command to run.
- A signature alone does not grant a process privilege.  A root-owned verifier
  must decide that the signed request is permitted, then perform the operation.

There are three separate properties to choose deliberately:

| Property | Meaning | Typical mechanism |
| --- | --- | --- |
| Device identity | This enrolled machine holds the key. | TPM / Secure Enclave private key |
| Human approval | A person consciously approved this action now. | Secure Enclave user presence, FIDO2 touch + PIN, or Polkit UI |
| OS privilege | A narrowly scoped root process performs the action. | Root-owned broker or tiny native setuid helper |

Do not assume that obtaining one of these automatically obtains the others.

## Recommended default architecture

For nontrivial operations, use a root-owned, native **privileged-command
broker** behind a local Unix-domain socket.  Keep the device signing key in the
login user's hardware-backed key store; the root broker only stores the
corresponding public key and policy.

```text
unprivileged CLI / user agent
        |
        | request: command ID, exact permitted inputs, broker challenge
        v
hardware-backed signer (user keychain / TPM provider)
        |
        | signature over canonical request
        v
root-owned privileged-command broker
        |
        | verify key, challenge, expiry, policy, caller identity
        v
execve() of one exact root operation, without a shell
```

Why a broker instead of a setuid script:

- The broker can verify signatures, reject replays, log decisions, and retain
  a deliberately tiny fixed operation policy.
- Unix-socket permissions and peer credentials provide a useful additional
  identity check.
- A root daemon is substantially easier to harden correctly than a complex
  setuid program.
- Shell, LuaJIT, and every other interpreted script must **never** be made
  setuid.  Setuid interpreters are unsafe by design.

A tiny root-owned *native* setuid executable remains reasonable for a very
small operation with no complex protocol, such as reading one fixed protected
file and printing a fixed-format result.  It is not the recommended place to
put the full cryptographic authorization protocol.

On NixOS, a native helper can be installed through `security.wrappers`, which
creates root-owned wrappers under `/run/wrappers/bin`.  For example, the
wrapper policy may set `owner = "root"` and `setuid = true`.  That is a
packaging mechanism, not an authorization policy: the helper still has to
accept only safe, fixed actions.

## The operation policy: exact means exact

Each approved operation should be a stable ID mapped by the broker to a policy
entry.  For the strongest version, the mapping fixes all of the following:

- absolute executable path;
- exact argument vector;
- working directory, preferably fixed or absent;
- a minimal fixed environment;
- expected stdin/stdout/stderr handling;
- which Unix UID(s) may request it; and
- an expiration and logging policy.

Illustratively, `disk-io-report-v1` would map to one specific monitoring
invocation.  It must not mean “run `iotop` with whatever arguments the caller
supplies,” and certainly not “run this string through `sh -c`.”

`diskhogs` is the motivating candidate for this design.  Today it prompts for
`sudo` solely to inspect system-wide disk I/O through the platform monitoring
tool; it should not need general administrative authority.  The first broker
operation should therefore be a read-only, one-second `disk-io-report-v1` with
the platform executable and every argument fixed by the broker.  If different
intervals prove useful, add a small named/typed interval allow-list later;
never forward a caller's general-purpose monitoring argv as root.

Some actions genuinely need input.  Give those actions a narrow typed schema,
then have the broker construct the final argv itself.  For example, an enum
with three named report durations is far safer than accepting a command-line
string.  Reject unknown fields; do not make room for a future arbitrary `args`
field by accident.

The broker must use `execve`, never `system`, `popen`, `sh -c`, a shell
expansion, inherited `PATH`, or an inherited general-purpose environment.

## A signed request protocol

Use a portable asymmetric signing algorithm supported on both platforms,
normally ECDSA P-256 with SHA-256.  The private key remains non-exportable;
the broker stores an enrolled public key and key identifier.

A request should canonicalize at least:

```text
protocol_version
key_id
requesting_uid
operation_id
operation_version
typed_operation_inputs
broker_issued_nonce
issued_at
expires_at
```

Sign a domain-separated digest, for example:

```text
SHA-256("dotfiles privileged command authorization v1\\0" || canonical_request)
```

The exact binary serialization needs a specification and test vectors.  It
must be unambiguous: deterministic field ordering, explicit lengths/types, and
no multiple textual spellings of the same request.  CBOR in deterministic mode
or a small fixed binary encoding are sensible choices.  Do not hand-wave this
as “sign some JSON” unless the JSON canonicalization is precisely defined.

The broker should:

1. Authenticate the Unix-socket peer using OS peer credentials and ensure the
   UID matches the signed request.
2. Issue a fresh, unpredictable challenge nonce for each authorization attempt.
3. Verify the enrolled public key, signature, operation ID/version, typed
   inputs, nonce, issue time, and very short expiry.
4. Mark the nonce consumed in a replay cache before executing the operation.
5. Construct and execute only the policy-defined argv, then write an audit
   record with no secret material.

The nonce and expiry stop a captured approval from being replayed.  They do
*not* stop malicious local software from requesting a new signature if that
software can invoke the signer without an approval gesture.

## Where the key should live

### macOS

Create an elliptic-curve signing key in the Secure Enclave and retain it in the
Keychain.  Configure it as non-exportable, `ThisDeviceOnly`, private-key use
only, and require user presence when the operation should require a conscious
approval.  `SecKeyCreateSignature` then signs the broker challenge digest
without exposing private-key bytes.

The Secure Enclave key should be owned by the login-user side of the design,
not handed to a root daemon.  The CLI or a small user agent obtains Keychain
authorization and sends only a signature to the broker.  A root process having
unrestricted access to the signing credential would erase much of the point of
the approval boundary.

`userPresence` normally permits biometric *or* passcode authentication.  A
more restrictive current-biometry policy can be appropriate when invalidating
the credential after biometric changes is desired; that is a product decision,
not a default to select casually.

### Linux

Create a non-exportable TPM 2.0 ECC signing key.  Access can be exposed through
TPM2-TSS directly or a PKCS#11 provider such as `tpm2-pkcs11`; the broker needs
only the enrolled public key.

The TPM supplies machine-bound non-exportability, but ordinary TPM signing does
not inherently require a person to be present.  If a meaningful human-approval
boundary is required, add one of:

- a FIDO2 authenticator requiring PIN and touch;
- a Polkit-mediated desktop approval flow; or
- a TPM policy arrangement designed for the specific assurance goal.

PCR binding can bind a TPM key to a measured boot state, but it also means OS
updates can invalidate access.  Treat it as an explicit high-assurance policy
choice, not a free default.  `PolicySigned` is useful when a policy authority
needs to authorize policy changes without replacing the key.

## Local authorization versus remote authorization

There are two useful modes, with different security properties:

| Mode | What verifies approval | Good for | Main limitation |
| --- | --- | --- | --- |
| Local device approval | Local broker verifies an enrolled hardware-key signature. | Offline, convenient exact actions. | Malware running as the same user may request signatures unless user presence is enforced. |
| Remote grant | A remote policy service verifies the device/user and issues a short-lived signed grant; the local broker verifies that grant. | Centrally controlled privileged actions and revocation. | Needs service availability, enrollment, and a recovery story. |

The remote version is the stronger answer when “via crypto” means “only an
externally authorized policy may unlock this root action.”  A local hardware key
is still valuable: it can authenticate the device to that service and make its
credential non-exportable.

For either mode, the local root broker remains the final enforcement point.  It
never runs a command merely because an unprivileged client asks.

## Do not derive a credential from a serial number

Product serials are often readable, are not designed as high-entropy secrets,
can be replaced or emulated, and can leak through inventory/support channels.
A public salt only prevents precomputation; it does not turn the serial into a
secret.  A secret salt is simply a secret key that needs secure storage.

If machine metadata is useful, include a non-secret device identifier as
associated data or enrollment metadata.  It may help detect accidental key
movement, but it must never be the sole authenticator.  Generate a random
hardware-protected signing key instead.

For server-side password verification, use a proper password KDF such as
Argon2id.  That is a separate problem from local privileged-command
authorization.

## Hardening checklist

- Keep the root component small, native, root-owned, and not writable by the
  requesting user.
- Prefer a system service and restrictive Unix socket to a setuid program for
  the cryptographic protocol.
- Never use a setuid shell, LuaJIT, Python, Perl, or any interpreter/script.
- Bind signatures to a fresh broker nonce, requester UID, operation version,
  exact typed inputs, and a short expiration; maintain replay protection.
- Resolve every executed program by absolute path, construct a clean
  environment, and call `execve` directly.
- Do not accept arbitrary argv, environment variables, working directories,
  file descriptors, command paths, shell fragments, or glob patterns.
- Treat command output and file paths as untrusted too: avoid writing root-owned
  files through attacker-controlled paths or following attacker-controlled
  symlinks.
- Log accepted and rejected authorization decisions with operation ID, UID,
  key ID, timestamps, and exit status, but never signatures, private data, or
  secrets unnecessarily.
- Rate-limit repeated failures and make the socket inaccessible to other local
  accounts.
- Design key rotation, lost-device revocation, and recovery before relying on
  the mechanism.  Non-exportable keys generally cannot be backed up.
- Test negative cases: altered argv, altered UID, stale/used nonce, expired
  request, wrong key, malformed serialization, environment injection, and
  concurrent replay attempts.

## Suggested implementation path

1. Write down the initial allow-list of one or two operations.  Make each one
   genuinely complete and stable; postpone operations requiring broad dynamic
   arguments.  Start with `disk-io-report-v1`, the read-only capability behind
   `diskhogs` that currently requires an interactive sudo password.
2. Build a non-privileged prototype of the request encoding, signing adapter,
   and verifier.  Give it deterministic test vectors before adding root.
3. Implement one root-owned native broker operation with a local Unix socket,
   fixed argv, and full negative tests.  Use a harmless read-only operation
   first.
4. Add the macOS Secure Enclave adapter and Linux TPM adapter behind the same
   `enroll` / `sign` interface.
5. Decide whether local user-presence approval is enough.  If it is not, add a
   FIDO2/Polkit approval flow or a remote signed-grant authority before adding
   higher-impact commands.
6. Only then consider a tiny NixOS `security.wrappers` helper for any operation
   too small to justify the broker.  Keep it native and fixed-purpose.

This progression deliberately avoids turning a speculative key derivation into
a permanent root bypass.

## References

- Apple: [Protecting keys with the Secure Enclave](https://developer.apple.com/documentation/Security/protecting-keys-with-the-secure-enclave?changes=la), [restricting Keychain item accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility?changes=_9), and [SecKeyCreateSignature](https://developer.apple.com/documentation/security/1643916-seckeycreatesignature?changes=l__4).
- TPM2 tools: [`tpm2_create`](https://tpm2-tools.readthedocs.io/en/latest/man/tpm2_create.1/), [`tpm2_sign`](https://tpm2-tools.readthedocs.io/en/latest/man/tpm2_sign.1/), and [`tpm2_policysigned`](https://tpm2-tools.readthedocs.io/en/latest/man/tpm2_policysigned.1/).
- Linux: [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) and [no_new_privs](https://docs.kernel.org/userspace-api/no_new_privs.html).
- NixOS: [`security.wrappers` module](https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/security/wrappers/default.nix).
- Password-storage background: [RFC 9106, Argon2](https://www.rfc-editor.org/rfc/rfc9106.html) and [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html).
