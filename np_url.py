# Map current media-session title -> source URL via Firefox places.sqlite (read-only snapshot).
# Usage: python np_url.py "<GSMTCS title>" "<out-file>"
import glob, os, shutil, sqlite3, sys, tempfile

def find_db():
    best = None
    for root in (os.environ.get("LOCALAPPDATA", ""), os.environ.get("APPDATA", "")):
        if not root:
            continue
        for p in glob.glob(os.path.join(root, "Mozilla", "Firefox", "Profiles", "*", "places.sqlite")):
            try:
                size = os.path.getsize(p)
            except OSError:
                continue
            if best is None or size > best[0]:
                best = (size, p)
    return best[1] if best else None

def lookup(t):
    src = find_db()
    if not src:
        return ""
    tmp = os.path.join(tempfile.gettempdir(), "np_places.sqlite")
    try:
        shutil.copy(src, tmp)
        for ext in ("-wal", "-shm"):
            if os.path.isfile(src + ext):
                shutil.copy(src + ext, tmp + ext)
    except OSError:
        pass
    try:
        con = sqlite3.connect("file:" + tmp + "?mode=ro", uri=True)
    except sqlite3.Error:
        return ""
    cur = con.cursor()
    row = None
    cands = [t]
    if " - " in t:
        tail = t.split(" - ", 1)[1].strip()
        if tail:
            cands.append(tail)
    queries = []
    for c in cands:
        queries.append(("select url,title from moz_places where title=? or title=? order by last_visit_date desc limit 1", (c, c + " - YouTube")))
        queries.append(("select url,title from moz_places where title like ? order by last_visit_date desc limit 1", (c + "%",)))
        queries.append(("select url,title from moz_places where title like ? order by last_visit_date desc limit 1", ("%" + c + "%",)))
    for q, args in queries:
        try:
            cur.execute(q, args)
            row = cur.fetchone()
        except sqlite3.Error:
            row = None
        if row and row[0]:
            break
    con.close()
    return row[0] if row and row[0] else ""

def main():
    t = sys.argv[1] if len(sys.argv) > 1 else ""
    outf = sys.argv[2] if len(sys.argv) > 2 else None
    url = lookup(t.strip()) if t.strip() else ""
    if outf:
        with open(outf, "w", encoding="utf-8") as f:
            f.write(url)
    else:
        sys.stdout.buffer.write(url.encode("utf-8"))

if __name__ == "__main__":
    main()
