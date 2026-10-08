#!/usr/bin/env python3
"""Build the offline dictionary database bundled with the app.

Output: assets/dict/dictionary.db.gz (gzipped SQLite; the app unpacks it on
first launch), one table:

    entries(lang, headword, alt, reading, target, definition, rank)

`lang` is the language of `headword`; `target` is the language `definition`
is written in. Every row has Chinese on one side.

Sources:
  * CC-CEDICT  (zh -> en), CC BY-SA 4.0, via the `cc-cedict` npm package.
  * ECDICT     (en -> zh), MIT, https://github.com/skywind3000/ECDICT
  * Wiktionary (zh <-> fr/ja/ko), CC BY-SA 4.0, translation tables of the
    English Wiktionary as extracted by https://kaikki.org (optional,
    enabled with --wiktionary because the dump is several GB).

Usage:
    python3 tools/build_dictionary.py                 # zh<->en only
    python3 tools/build_dictionary.py --wiktionary    # plus fr/ja/ko
"""

import argparse
import csv
import gzip
import io
import json
import os
import re
import sqlite3
import sys
import tarfile
import urllib.request
from collections import defaultdict

ECDICT_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"
CEDICT_NPM = "https://registry.npmjs.org/cc-cedict"
KAIKKI_URL = "https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl"

WIKTIONARY_LANGS = {"fr": "fr", "ja": "ja", "ko": "ko"}
CHINESE_CODES = {"cmn", "zh"}

csv.field_size_limit(sys.maxsize)


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def open_source(path_or_url):
    """Return a binary stream for a local path or an http(s) URL."""
    if re.match(r"^https?://", path_or_url):
        return urllib.request.urlopen(path_or_url)
    return open(path_or_url, "rb")


# --- Pinyin -----------------------------------------------------------------

_TONE_MARKS = {
    "a": "āáǎà", "e": "ēéěè", "i": "īíǐì",
    "o": "ōóǒò", "u": "ūúǔù", "ü": "ǖǘǚǜ",
}


def _syllable_to_marks(syl):
    m = re.match(r"^([a-zA-Zü:]+)([1-5])$", syl)
    if not m:
        return syl
    letters, tone = m.group(1).replace("u:", "ü").replace("U:", "Ü"), int(m.group(2))
    if tone == 5:
        return letters
    lower = letters.lower()
    # Standard placement: a/e take the mark, then the o of "ou",
    # otherwise the last vowel.
    if "a" in lower:
        idx = lower.index("a")
    elif "e" in lower:
        idx = lower.index("e")
    elif "ou" in lower:
        idx = lower.index("o")
    else:
        idx = max((i for i, c in enumerate(lower) if c in "iouü"), default=-1)
    if idx < 0:
        return letters
    vowel = lower[idx]
    marked = _TONE_MARKS[vowel][tone - 1]
    if letters[idx].isupper():
        marked = marked.upper()
    return letters[:idx] + marked + letters[idx + 1:]


def numbered_to_marks(pinyin):
    """'ni3 hao3' -> 'nǐ hǎo'."""
    return " ".join(_syllable_to_marks(s) for s in pinyin.split())


# --- Sources ----------------------------------------------------------------

def load_cedict(path_or_url):
    """Yield rows from the cc-cedict npm tarball (or its data/all.js)."""
    if path_or_url == CEDICT_NPM:
        meta = json.load(urllib.request.urlopen(CEDICT_NPM))
        latest = meta["dist-tags"]["latest"]
        path_or_url = meta["versions"][latest]["dist"]["tarball"]
    raw = open_source(path_or_url).read()
    if path_or_url.endswith((".tgz", ".tar.gz")):
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar:
            raw = tar.extractfile("package/data/all.js").read()
    text = raw.decode("utf-8")
    data = json.loads(text[text.index("{"):])
    for rank, item in enumerate(data["all"]):
        trad, simp, pinyin, meanings = item[0], item[1], item[2], item[3]
        if isinstance(meanings, str):
            meanings = [meanings]
        definition = "; ".join(m for m in meanings if m)
        if not definition:
            continue
        yield ("zh", simp, trad if trad != simp else None,
               numbered_to_marks(pinyin), "en", definition, rank)


def load_ecdict(path_or_url):
    stream = io.TextIOWrapper(open_source(path_or_url), encoding="utf-8")
    for row in csv.DictReader(stream):
        translation = row["translation"].strip()
        if not translation:
            continue
        frq = int(row["frq"] or 0)
        bnc = int(row["bnc"] or 0)
        common = (frq > 0 or bnc > 0 or row["collins"] not in ("", "0")
                  or row["oxford"] == "1" or row["tag"])
        if not common:
            continue
        rank = min(x for x in (frq, bnc, 10 ** 6) if x > 0)
        phonetic = row["phonetic"].strip()
        yield ("en", row["word"].strip(), None,
               f"/{phonetic}/" if phonetic else None, "zh",
               translation.replace("\\n", "\n"), rank)


def _translations_of(entry):
    yield from entry.get("translations") or []
    for sense in entry.get("senses") or []:
        yield from sense.get("translations") or []


def _is_traditional_only(tr):
    tags = tr.get("tags") or []
    return "Traditional-Chinese" in tags and "Simplified-Chinese" not in tags


def load_wiktionary(path_or_url):
    """Pair Chinese with fr/ja/ko words that translate the same English sense."""
    zh_to = defaultdict(lambda: defaultdict(dict))   # lang -> zh -> {word: None}
    to_zh = defaultdict(lambda: defaultdict(dict))   # lang -> word -> {zh: None}
    readings = {}
    for n, line in enumerate(io.TextIOWrapper(open_source(path_or_url), encoding="utf-8")):
        if n % 200000 == 0 and n:
            log(f"  wiktionary: {n} entries read")
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("lang_code") != "en":
            continue
        by_sense = defaultdict(lambda: defaultdict(list))
        for tr in _translations_of(entry):
            code, word = tr.get("code"), (tr.get("word") or "").strip()
            if not word:
                continue
            sense = tr.get("sense") or ""
            if code in CHINESE_CODES and not _is_traditional_only(tr):
                by_sense[sense]["zh"].append(word)
            elif code in WIKTIONARY_LANGS:
                by_sense[sense][code].append(word)
                if tr.get("roman"):
                    readings[(code, word)] = tr["roman"]
        for words in by_sense.values():
            for zh in words.get("zh", [])[:3]:
                for code in WIKTIONARY_LANGS:
                    for other in words.get(code, [])[:3]:
                        zh_to[code][zh][other] = None
                        to_zh[code][other][zh] = None
    for code in WIKTIONARY_LANGS:
        for zh, others in zh_to[code].items():
            yield ("zh", zh, None, None, code, "；".join(list(others)[:8]), 10 ** 6)
        for word, zhs in to_zh[code].items():
            yield (code, word, None, readings.get((code, word)), "zh",
                   "；".join(list(zhs)[:8]), 10 ** 6)


# --- Output -----------------------------------------------------------------

SCHEMA = """
CREATE TABLE entries (
  id INTEGER PRIMARY KEY,
  lang TEXT NOT NULL,
  headword TEXT NOT NULL,
  alt TEXT,
  reading TEXT,
  target TEXT NOT NULL,
  definition TEXT NOT NULL,
  rank INTEGER NOT NULL
);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""

INDEXES = """
CREATE INDEX idx_entries_lookup ON entries (lang, target, headword COLLATE NOCASE);
CREATE INDEX idx_entries_alt ON entries (alt) WHERE alt IS NOT NULL;
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default="assets/dict/dictionary.db.gz")
    parser.add_argument("--cedict", default=CEDICT_NPM,
                        help="cc-cedict npm tarball or data/all.js (path or URL)")
    parser.add_argument("--ecdict", default=ECDICT_URL, help="ecdict.csv (path or URL)")
    parser.add_argument("--wiktionary", nargs="?", const=KAIKKI_URL, default=None,
                        help="kaikki.org English JSONL dump (path or URL)")
    args = parser.parse_args()

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    tmp = args.out + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    db = sqlite3.connect(tmp)
    db.executescript(SCHEMA)
    insert = ("INSERT INTO entries (lang, headword, alt, reading, target, definition, rank)"
              " VALUES (?, ?, ?, ?, ?, ?, ?)")

    sources = [("CC-CEDICT", load_cedict(args.cedict)),
               ("ECDICT", load_ecdict(args.ecdict))]
    if args.wiktionary:
        sources.append(("Wiktionary", load_wiktionary(args.wiktionary)))
    for name, rows in sources:
        log(f"Loading {name}...")
        count = 0
        for row in rows:
            db.execute(insert, row)
            count += 1
        log(f"  {count} entries")

    languages = [r[0] for r in db.execute(
        "SELECT DISTINCT target FROM entries WHERE lang = 'zh' ORDER BY 1")]
    db.execute("INSERT INTO meta VALUES ('languages', ?)", (",".join(languages),))
    db.executescript(INDEXES)
    db.commit()
    db.execute("VACUUM")
    db.close()
    log(f"Database is {os.path.getsize(tmp) / 1e6:.1f} MB, compressing...")
    with open(tmp, "rb") as src, gzip.GzipFile(args.out, "wb", 9, mtime=0) as dst:
        while chunk := src.read(1 << 20):
            dst.write(chunk)
    os.remove(tmp)
    log(f"Wrote {args.out} ({os.path.getsize(args.out) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
