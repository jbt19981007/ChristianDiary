#!/usr/bin/env python3
"""把公有领域的圣经文本转换成 App 使用的数据文件。

数据来源：https://github.com/seven1m/open-bibles （固定到下面的提交）
  - chi-cuv-simp.usfx.xml  和合本（简体），公有领域
  - eng-kjv.osis.xml       King James Version，公有领域

输出：
  ChristianDiary/Resources/Bible/cuv.txt
  ChristianDiary/Resources/Bible/kjv.txt
      每行一节：书卷序号(1-66)<TAB>章<TAB>节<TAB>经文
  Packages/DevotionCore/Sources/DevotionCore/Generated/DailyVerseData.swift
      每日经文（中英文都直接取自上面的文本，保证与内置圣经一致）

用法：
  python3 tools/build_bible.py                 # 从 GitHub 下载源文件
  python3 tools/build_bible.py --source DIR    # 使用本地已下载的 open-bibles 目录
"""

import argparse
import html
import pathlib
import re
import sys
import urllib.request

COMMIT = "f257a3559025c3f873b48a75019f53a9354ed7de"
RAW = f"https://raw.githubusercontent.com/seven1m/open-bibles/{COMMIT}/"
ROOT = pathlib.Path(__file__).resolve().parent.parent

# (USFX 代号, OSIS 代号, 章数)
BOOKS = [
    ("GEN", "Gen", 50), ("EXO", "Exod", 40), ("LEV", "Lev", 27), ("NUM", "Num", 36), ("DEU", "Deut", 34),
    ("JOS", "Josh", 24), ("JDG", "Judg", 21), ("RUT", "Ruth", 4), ("1SA", "1Sam", 31), ("2SA", "2Sam", 24),
    ("1KI", "1Kgs", 22), ("2KI", "2Kgs", 25), ("1CH", "1Chr", 29), ("2CH", "2Chr", 36), ("EZR", "Ezra", 10),
    ("NEH", "Neh", 13), ("EST", "Esth", 10), ("JOB", "Job", 42), ("PSA", "Ps", 150), ("PRO", "Prov", 31),
    ("ECC", "Eccl", 12), ("SNG", "Song", 8), ("ISA", "Isa", 66), ("JER", "Jer", 52), ("LAM", "Lam", 5),
    ("EZK", "Ezek", 48), ("DAN", "Dan", 12), ("HOS", "Hos", 14), ("JOL", "Joel", 3), ("AMO", "Amos", 9),
    ("OBA", "Obad", 1), ("JON", "Jonah", 4), ("MIC", "Mic", 7), ("NAM", "Nah", 3), ("HAB", "Hab", 3),
    ("ZEP", "Zeph", 3), ("HAG", "Hag", 2), ("ZEC", "Zech", 14), ("MAL", "Mal", 4),
    ("MAT", "Matt", 28), ("MRK", "Mark", 16), ("LUK", "Luke", 24), ("JHN", "John", 21), ("ACT", "Acts", 28),
    ("ROM", "Rom", 16), ("1CO", "1Cor", 16), ("2CO", "2Cor", 13), ("GAL", "Gal", 6), ("EPH", "Eph", 6),
    ("PHP", "Phil", 4), ("COL", "Col", 4), ("1TH", "1Thess", 5), ("2TH", "2Thess", 3), ("1TI", "1Tim", 6),
    ("2TI", "2Tim", 4), ("TIT", "Titus", 3), ("PHM", "Phlm", 1), ("HEB", "Heb", 13), ("JAS", "Jas", 5),
    ("1PE", "1Pet", 5), ("2PE", "2Pet", 3), ("1JN", "1John", 5), ("2JN", "2John", 1), ("3JN", "3John", 1),
    ("JUD", "Jude", 1), ("REV", "Rev", 22),
]

# 每日经文：(书卷序号 1-66, 章, 起始节, 结束节)
DAILY_VERSES = [
    (19, 23, 1, 1), (43, 3, 16, 16), (20, 3, 5, 6), (50, 4, 13, 13), (23, 40, 31, 31),
    (45, 8, 28, 28), (24, 29, 11, 11), (40, 11, 28, 28), (19, 119, 105, 105), (50, 4, 6, 7),
    (6, 1, 9, 9), (47, 5, 17, 17), (19, 46, 1, 1), (48, 2, 20, 20), (23, 41, 10, 10),
    (49, 2, 8, 9), (25, 3, 22, 23), (58, 11, 1, 1), (19, 46, 10, 10), (40, 6, 33, 33),
    (20, 4, 23, 23), (59, 1, 5, 5), (19, 27, 1, 1), (60, 5, 7, 7), (5, 31, 6, 6),
    (62, 1, 9, 9), (19, 37, 5, 5), (40, 6, 34, 34), (23, 26, 3, 3), (43, 14, 6, 6),
    (19, 34, 8, 8), (43, 14, 27, 27), (33, 6, 8, 8), (43, 15, 5, 5), (19, 51, 10, 10),
    (45, 12, 2, 2), (36, 3, 17, 17), (45, 5, 8, 8), (19, 90, 12, 12), (45, 8, 38, 39),
    (4, 6, 24, 26), (46, 13, 4, 7), (19, 91, 1, 1), (46, 10, 13, 13), (20, 16, 3, 3),
    (47, 12, 9, 9), (19, 103, 2, 2), (48, 5, 22, 23), (23, 43, 1, 1), (49, 3, 20, 20),
    (19, 118, 24, 24), (50, 1, 6, 6), (20, 16, 9, 9), (50, 4, 4, 4), (19, 121, 1, 2),
    (51, 3, 23, 23), (21, 3, 1, 1), (52, 5, 16, 18), (19, 139, 23, 24), (55, 1, 7, 7),
    (23, 53, 5, 5), (55, 3, 16, 17), (19, 16, 11, 11), (58, 4, 16, 16), (19, 19, 14, 14),
    (58, 12, 2, 2), (23, 55, 8, 9), (58, 13, 8, 8), (19, 42, 1, 1), (59, 1, 2, 3),
    (35, 3, 17, 18), (62, 4, 19, 19), (19, 73, 26, 26), (62, 4, 18, 18), (19, 23, 4, 4),
    (66, 3, 20, 20), (19, 145, 18, 18), (40, 5, 16, 16), (1, 1, 1, 1), (40, 22, 37, 39),
    (19, 62, 1, 1), (40, 28, 20, 20), (19, 100, 4, 5), (40, 7, 7, 7), (40, 5, 8, 8),
    (42, 1, 37, 37), (43, 1, 14, 14), (43, 8, 12, 12), (43, 10, 10, 10), (43, 11, 25, 26),
    (43, 13, 34, 34), (43, 16, 33, 33), (44, 1, 8, 8), (45, 10, 17, 17), (45, 12, 12, 12),
    (45, 15, 13, 13), (49, 4, 32, 32), (49, 6, 10, 10),
]


def fetch(name, source):
    if source:
        return (pathlib.Path(source) / name).read_text(encoding="utf-8")
    print(f"下载 {name} …", file=sys.stderr)
    with urllib.request.urlopen(RAW + name, timeout=120) as resp:
        return resp.read().decode("utf-8")


def clean(text):
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def parse_cuv(xml):
    """USFX：<book id="GEN"> <c id="1"/> <v id="1"/>经文<ve/>"""
    usfx_index = {usfx: i + 1 for i, (usfx, _, _) in enumerate(BOOKS)}
    verses = {}
    for book_match in re.finditer(r'<book id="(\w+)">(.*?)</book>', xml, re.S):
        book = usfx_index.get(book_match.group(1))
        if book is None:
            continue
        for chapter_match in re.finditer(r'<c id="(\d+)"\s*/>(.*?)(?=<c id=|\Z)', book_match.group(2), re.S):
            chapter = int(chapter_match.group(1))
            for verse_match in re.finditer(r'<v id="(\d+)"\s*/>(.*?)<ve\s*/>', chapter_match.group(2), re.S):
                # 和合本原文中神、耶稣的称呼前常有全角空格（抬头），阅读时去掉
                text = clean(verse_match.group(2)).replace("　", "").replace(" ", "")
                verses[(book, chapter, int(verse_match.group(1)))] = text
    return verses


def parse_kjv(xml):
    """OSIS 里程碑格式：<verse osisID="Gen.1.1" sID="X"/>…<verse eID="X"/>"""
    osis_index = {osis: i + 1 for i, (_, osis, _) in enumerate(BOOKS)}
    xml = re.sub(r"<title[^>]*>.*?</title>", "", xml, flags=re.S)
    xml = re.sub(r"<note[^>]*>.*?</note>", "", xml, flags=re.S)
    verses = {}
    pattern = re.compile(r'<verse osisID="([\w]+)\.(\d+)\.(\d+)" sID="([^"]+)"[^>]*/>(.*?)<verse eID="\4"\s*/>', re.S)
    for m in pattern.finditer(xml):
        book = osis_index.get(m.group(1))
        if book is None:  # 跳过次经
            continue
        verses[(book, int(m.group(2)), int(m.group(3)))] = clean(m.group(5))
    return verses


def validate(name, verses):
    ok = True
    for index, (usfx, _, chapters) in enumerate(BOOKS, start=1):
        found = {c for (b, c, _) in verses if b == index}
        if found != set(range(1, chapters + 1)):
            print(f"[{name}] {usfx} 章数不符：期望 {chapters}，实际 {sorted(found)[-1:]}", file=sys.stderr)
            ok = False
    empty = [k for k, v in verses.items() if not v]
    if empty:
        print(f"[{name}] 空经文 {len(empty)} 节，例如 {empty[:5]}", file=sys.stderr)
    print(f"[{name}] 共 {len(verses)} 节", file=sys.stderr)
    return ok


def write_tsv(path, verses):
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{b}\t{c}\t{v}\t{t}" for (b, c, v), t in sorted(verses.items())]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"写入 {path.relative_to(ROOT)}（{path.stat().st_size / 1024 / 1024:.1f} MB）", file=sys.stderr)


def passage(verses, book, chapter, start, end, joiner):
    parts = []
    for v in range(start, end + 1):
        text = verses.get((book, chapter, v))
        if not text:
            raise SystemExit(f"每日经文缺失：{book} {chapter}:{v}")
        parts.append(text)
    return joiner.join(parts)


def swift_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_daily_verses(path, cuv, kjv):
    rows = []
    for book, chapter, start, end in DAILY_VERSES:
        # 诗篇标题（如「（大卫的诗）」）在和合本里算在第 1 节中，金句里去掉
        zh = re.sub(r"^（[^）]*）", "", passage(cuv, book, chapter, start, end, ""))
        en = passage(kjv, book, chapter, start, end, " ")
        rows.append(
            f"        DailyVerse(reference: BibleReference(book: {book}, chapter: {chapter}, verseStart: {start}, verseEnd: {end}),\n"
            f"                   chinese: {swift_string(zh)},\n"
            f"                   english: {swift_string(en)}),"
        )
    source = (
        "// 由 tools/build_bible.py 生成，请勿手动修改。\n"
        "// 经文取自和合本（简体）与 KJV，均为公有领域。\n\n"
        "extension DailyVerse {\n"
        "    public static let all: [DailyVerse] = [\n"
        + "\n".join(rows)
        + "\n    ]\n}\n"
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source, encoding="utf-8")
    print(f"写入 {path.relative_to(ROOT)}（{len(DAILY_VERSES)} 节）", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", help="本地 open-bibles 目录（不指定则从 GitHub 下载）")
    args = parser.parse_args()

    cuv = parse_cuv(fetch("chi-cuv-simp.usfx.xml", args.source))
    kjv = parse_kjv(fetch("eng-kjv.osis.xml", args.source))
    if not (validate("和合本", cuv) and validate("KJV", kjv)):
        raise SystemExit("校验失败")

    bible_dir = ROOT / "ChristianDiary" / "Resources" / "Bible"
    write_tsv(bible_dir / "cuv.txt", cuv)
    write_tsv(bible_dir / "kjv.txt", kjv)
    write_daily_verses(
        ROOT / "Packages" / "DevotionCore" / "Sources" / "DevotionCore" / "Generated" / "DailyVerseData.swift", cuv, kjv
    )


if __name__ == "__main__":
    main()
