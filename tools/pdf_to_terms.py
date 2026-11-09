"""PDF 용어집 → assets/data/terms.json 에 합치기

사용:
  python tools/pdf_to_terms.py data/pdf/용어집.pdf            # 미리보기(검토용 CSV 만 만든다)
  python tools/pdf_to_terms.py data/pdf/용어집.pdf --apply    # terms.json 에 합친다
  python tools/pdf_to_terms.py data/pdf/용어집.pdf --cat rx   # 분류를 못 맞출 때 전부 이 분류로
  python tools/pdf_to_terms.py data/pdf/review.csv --apply   # 검토해서 고친 CSV 를 그대로 넣는다

흐름
  1) PyMuPDF 로 글자를 뽑는다 (표가 있으면 표 칸 그대로, 없으면 줄 단위)
  2) 한 줄에서 [약어] [영어 용어] [한국어 뜻] 을 찾는다
       예)  BP  blood pressure  혈압
            blood pressure (BP) : 혈압
            혈압 - blood pressure, BP
  3) data/pdf/review_<파일명>.csv 로 써서 사람이 훑어보게 한다 (abbr,term,ko,cat)
  4) --apply 면 seed_terms.TERMS + CSV 를 합쳐 terms.json 을 다시 만든다

⚠️ PDF 글자 배치가 제각각이라 100% 못 맞춘다. review CSV 를 열어 틀린 줄을 고친 뒤
   그 CSV 를 다시 --apply 로 넣는 것이 가장 정확하다.
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import seed_terms  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

HANGUL = re.compile(r"[가-힣]")
LATIN = re.compile(r"[A-Za-z]")
# 약어: 대문자 섞인 2~8자, 숫자·/·-·& 허용 (BP, SpO2, I/O, q4h, C&S, D5W, L-tube)
ABBR = re.compile(r"^(?=.*[A-Za-z])[A-Za-z0-9/&\-\.']{1,10}$")

CAT_KEYWORDS = {
    "rx": ["투여", "주사", "약", "처방", "시간마다", "식전", "식후", "필요시", "수액", "mg", "ml", "정제", "캡슐"],
    "test": ["검사", "촬영", "초음파", "내시경", "심전도", "혈구", "수치", "농도", "지수", "검체", "배양"],
    "disease": ["염", "증후군", "질환", "병", "암", "경색", "출혈", "부전", "궤양", "결핵", "골절", "감염증"],
    "symptom": ["통", "열", "곤란", "구토", "오심", "설사", "변비", "마비", "부종", "출혈", "발작", "어지럼", "증상"],
    "anatomy": ["뼈", "골", "장", "관", "맥", "신경", "근육", "피부", "쪽의", "심방", "심실", "폐", "간", "위", "신장"],
    "care": ["간호", "처치", "소독", "드레싱", "관장", "체위", "자세", "삽관", "흡인", "수혈", "소생", "배액", "카테터", "도뇨"],
    "dept": ["실", "병동", "과", "간호사", "의사", "치료사", "약사", "부서"],
}


def guess_cat(ko: str, term: str) -> str:
    text = ko + " " + term.lower()
    best, score = "vital", 0
    for cat, kws in CAT_KEYWORDS.items():
        s = sum(1 for k in kws if k in text)
        if s > score:
            best, score = cat, s
    if term.lower().endswith(("itis", "oma", "osis", "emia")) and score == 0:
        return "disease"
    if term.lower().endswith(("pnea", "algia", "uria", "rrhea", "rrhage")) and score == 0:
        return "symptom"
    return best


def extract_rows(pdf_path: Path):
    import pymupdf

    rows = []
    doc = pymupdf.open(pdf_path)
    for page in doc:
        used_table = False
        try:
            tabs = page.find_tables()
            for t in tabs.tables:
                for r in t.extract():
                    cells = [(c or "").strip().replace("\n", " ") for c in r]
                    cells = [c for c in cells if c]
                    if len(cells) >= 2:
                        rows.append(cells)
                        used_table = True
        except Exception:
            pass
        if not used_table:
            for line in page.get_text("text").splitlines():
                line = line.strip()
                if len(line) < 3:
                    continue
                rows.append([line])
    return rows


def parse_cells(cells):
    """표 칸 → (abbr, term, ko). 칸이 하나면 줄 파싱."""
    if len(cells) == 1:
        return parse_line(cells[0])
    abbr, term, ko = "", "", ""
    for c in cells:
        if HANGUL.search(c):
            ko = (ko + ", " + c) if ko else c
        elif ABBR.match(c) and (c.upper() == c or len(c) <= 5) and not term:
            abbr = c
        elif LATIN.search(c):
            if term:
                # 두 번째 영어 칸: 짧으면 약어
                if ABBR.match(c) and len(c) <= 8:
                    abbr = c
                else:
                    term = term + " " + c
            else:
                term = c
    if not term and abbr:
        term, abbr = abbr, ""
    return abbr, term, ko


def parse_line(line: str):
    """한 줄에서 약어·용어·뜻을 찾는다."""
    line = re.sub(r"\s+", " ", line.replace("\t", " ")).strip(" -:·•∙▪◦")
    # 한글 덩어리와 영어 덩어리로 나눈다
    m = HANGUL.search(line)
    if not m or not LATIN.search(line):
        return "", "", ""
    first_hangul = m.start()
    # 영어가 앞, 한글이 뒤 (가장 흔함)
    if first_hangul > 0:
        eng, ko = line[:first_hangul], line[first_hangul:]
    else:
        # 한글이 앞: 뒤에 오는 영어
        m2 = LATIN.search(line)
        ko, eng = line[: m2.start()], line[m2.start():]
    ko = ko.strip(" -:()[]·,;")
    eng = eng.strip(" -:·,;")
    abbr = ""
    # 괄호 안 약어: blood pressure (BP)
    pm = re.search(r"\(([A-Za-z0-9/&\-\.']{1,10})\)", eng)
    if pm and ABBR.match(pm.group(1)):
        abbr = pm.group(1)
        eng = (eng[: pm.start()] + eng[pm.end():]).strip(" ,;")
    tokens = eng.split(" ")
    # 맨 앞 토큰이 약어처럼 생겼고(대문자 섞임, 뒤에 더 있음) 뒤가 소문자 용어면 약어
    if not abbr and len(tokens) >= 2 and ABBR.match(tokens[0]) and (tokens[0] != tokens[0].lower() or len(tokens[0]) <= 4):
        if tokens[1][:1].islower() or len(tokens) >= 3:
            abbr = tokens[0]
            tokens = tokens[1:]
    # 맨 뒤 토큰이 약어 (blood pressure BP)
    elif not abbr and len(tokens) >= 2 and ABBR.match(tokens[-1]) and tokens[-1].upper() == tokens[-1] and len(tokens[-1]) <= 6:
        abbr = tokens[-1]
        tokens = tokens[:-1]
    term = " ".join(tokens).strip(" ,;:-")
    term = re.sub(r"^\d+[\.\)]\s*", "", term)  # 번호 제거
    if not re.search(r"[A-Za-z]{2,}", term):
        return "", "", ""
    return abbr, term, ko


def rows_from_pdf(pdf_path: Path, force_cat: str | None):
    results = []
    for cells in extract_rows(pdf_path):
        abbr, term, ko = parse_cells(cells)
        if not term or not ko:
            continue
        if len(term) > 60 or len(ko) > 40:
            continue
        results.append((abbr, term, ko, force_cat or guess_cat(ko, term)))
    return results


def rows_from_csv(csv_path: Path):
    results = []
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            term = (r.get("term") or "").strip()
            ko = (r.get("ko") or "").strip()
            if not term or not ko:
                continue
            results.append(((r.get("abbr") or "").strip(), term, ko, (r.get("cat") or "vital").strip() or "vital"))
    return results


def merge(extra):
    """seed + extra. 같은 id(용어 슬러그) 는 extra 가 이긴다."""
    by_id = {}
    for row in seed_terms.TERMS:
        by_id[seed_terms.slug(row[1].split("|")[0])] = row
    added = replaced = 0
    for row in extra:
        key = seed_terms.slug(row[1].split("|")[0])
        if key in by_id:
            replaced += 1
        else:
            added += 1
        by_id[key] = row
    return list(by_id.values()), added, replaced


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    src = Path(argv[1])
    apply = "--apply" in argv
    force_cat = None
    if "--cat" in argv:
        force_cat = argv[argv.index("--cat") + 1]
    if src.suffix.lower() == ".csv":
        rows = rows_from_csv(src)
    else:
        rows = rows_from_pdf(src, force_cat)
        review = src.parent / f"review_{src.stem}.csv"
        with review.open("w", encoding="utf-8-sig", newline="") as f:
            w = csv.writer(f)
            w.writerow(["abbr", "term", "ko", "cat"])
            w.writerows(rows)
        print(f"{len(rows)}줄 추출 → 검토용 {review}")
        for r in rows[:15]:
            print("  ", r)
    if apply:
        merged, added, replaced = merge(rows)
        data = {
            "version": 1,
            "categories": [
                {"id": c[0], "name": c[1], "emoji": c[2], "guide": c[3], "color": c[4]} for c in seed_terms.CATEGORIES
            ],
            "terms": seed_terms.build(merged),
        }
        import json

        seed_terms.OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"terms.json 갱신: 새로 {added} · 덮어씀 {replaced} · 총 {len(merged)}")
    else:
        print("실제 반영하려면 --apply 를 붙이세요.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
