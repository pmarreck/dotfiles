# Passphrase dictionary provenance

`dictionary-american.txt` and `dictionary.txt` are the American and British
SCOWL 2020.12.07 level-60 word lists. Level 60 contains words found in at
least two of the twelve dictionaries used by SCOWL.

Both files are generated from SCOWL's `wamerican.60` and `wbritish.60` by
rejecting apostrophe-bearing and non-ASCII records, then sorting under
`en_US.UTF-8`. The ASCII restriction keeps the files valid UTF-8 even though
the SCOWL inputs in this release use ISO-8859 encoding.

Reproduction command, with `VARIANT` set to `american` or `british`:

```bash
LC_ALL=C awk \
	'index($0, sprintf("%c", 39)) == 0 && $0 !~ /[^ -~]/' \
	"share/dict/w${VARIANT}.60" |
	LC_ALL=en_US.UTF-8 sort >"dictionary-${VARIANT}.txt"
```

The British output retains its historical filename, `dictionary.txt`.

| Artifact | SHA-256 |
|---|---|
| SCOWL `wamerican.60` input | `2d85306ee69f0b01925d703299efc67d4830aef72e990d816a0ab040d2fb55b2` |
| SCOWL `wbritish.60` input | `0cf7c8f8550ea55c40f9be5af241164da12644f84b31701a85a2ca96c9c663b2` |
| `dictionary-american.txt` | `9947b976af3aeaff3219ebf79027f3883c5acd90df62d005906161e88d9431da` |
| `dictionary.txt` | `886a036660a71f2eeb940a9a13a70cd992d1b7613e9c169895a6b1d683cb863a` |

See `SCOWL-COPYRIGHT` for the source licenses and notices.
