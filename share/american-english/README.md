# Spelling data provenance

`british-to-american.tsv` is a derived subset of VarCon 2020.12.07 by Kevin
Atkinson and Benjamin Titze, distributed with the upstream permissions in
`LICENSE-VarCon`. The extraction is a modification of that dataset.

Pinned source: [en-wl/wordlist, commit 5ef55f9c42730ebe4394a78b77855468a6f15dd2](https://github.com/en-wl/wordlist/blob/5ef55f9c42730ebe4394a78b77855468a6f15dd2/varcon/varcon.txt).
Source file SHA-256: `340858b990255ec409adcf7faaf2b992aa2a76a16f30b4b9e2663863191dba33`.
Retrieved 2026-10-28. The upstream [format reference](https://wordlist.aspell.net/varcon-readme/)
explains dialect tags, verification markers and inflected entries.

The offline generator selects lowercase alphabetic British preferred/equal
forms (`B`, `B.`) with a different preferred American (`A`) form, from verified
clusters at SCOWL level 70 or below. It excludes archaic annotations and every
word also tagged American preferred/equal anywhere in the source. Plurals,
past tenses and other inflections are explicit source rows, not guessed suffixes.
Possessives are matched at the base-word boundary by the checker.

Regenerate from a locally downloaded, hash-verified source file:

```sh
luajit bin/src/generate-american-english-dictionary.lua varcon.txt > share/american-english/british-to-american.tsv
```

No download or generation happens during commits or PR submissions. This is a
bounded style dictionary, not a complete natural-language classifier. Some
American dictionaries accept regional alternatives; this policy favors the
dataset's preferred American spelling. Proper names, external identifiers,
quotations and deliberate non-US locales require explicit exceptions. Unverified,
rare, nonalphabetic and ambiguous American-preferred forms are deliberately
excluded, so the gate cannot promise to detect every British usage.
