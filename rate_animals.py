"""
Animal Warfare – Animal Rater v7
==================================
Changes:
  - Speed weight reduced from 1.3 → 0.8 (being slow no longer tanks your score)
  - ATK/PWR/DEF/RES boosted so combat capability drives BST spread
  - Premium HTML: all 6 stat bars, clickable column sorting, ability+move chips,
    rich defensive type breakdown (Strong/Average/Fragile + weakness chips),
    score gauge bar, Prev/Next paginator
"""

import json, os
from datetime import datetime

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ORG1_PATH   = os.path.join(SCRIPT_DIR, "assets", "Organisms.json")
ORG2_PATH   = os.path.join(SCRIPT_DIR, "assets", "Organisms2.json")
MOVES_PATH  = os.path.join(SCRIPT_DIR, "assets", "moves.json")
OUTPUT_HTML = os.path.join(SCRIPT_DIR, "animal_report.html")

# ── Type chart ──────────────────────────────────────────────────────────────
CHART = {
    "electric": {"flying": 2, "aquatic": 2, "sound": 2, "electric": 0.5, "grass": 0.5, "drake": 0.5, "earth": 0},
    "sound":    {"flying": 2, "aquatic": 2, "aura": 2, "metal": 0.5, "rock": 0.5, "electric": 0.5, "spectral": 0},
    "arthropod":{"grass": 2, "darkness": 2, "aura": 2, "flying": 0.5, "martial": 0.5, "rock": 0.5, "blaze": 0.5, "toxic": 0.5, "metal": 0.5, "spectral": 0.5, "mystic": 0.5},
    "blaze":    {"arthropod": 2, "metal": 2, "grass": 2, "cryo": 2, "blaze": 0.5, "rock": 0.5, "aquatic": 0.5, "drake": 0.5},
    "rock":     {"flying": 2, "blaze": 2, "arthropod": 2, "cryo": 2, "earth": 0.5, "martial": 0.5, "metal": 0.5},
    "holy":     {"spectral": 2, "darkness": 2, "drake": 2, "metal": 0.5, "blaze": 0.5, "mystic": 0.5},
    "flying":   {"arthropod": 2, "grass": 2, "martial": 2, "rock": 0.5, "sound": 0.5, "electric": 0.5, "cryo": 0.5, "metal": 0.5},
    "aquatic":  {"earth": 2, "rock": 2, "blaze": 2, "aquatic": 0.5, "grass": 0.5, "sound": 0.5, "drake": 0.5, "cryo": 0.5},
    "metal":    {"cryo": 2, "rock": 2, "mystic": 2, "holy": 2, "aquatic": 0.5, "blaze": 0.5, "metal": 0.5, "electric": 0.5},
    "martial":  {"cryo": 2, "rock": 2, "basic": 2, "darkness": 2, "metal": 2, "arthropod": 0.5, "flying": 0.5, "toxic": 0.5, "aura": 0.5, "mystic": 0.5, "spectral": 0},
    "basic":    {"rock": 0.5, "metal": 0.5, "spectral": 0},
    "earth":    {"cryo": 2, "electric": 2, "sound": 2, "rock": 2, "toxic": 2, "blaze": 2, "flying": 0, "grass": 0.5, "arthropod": 0.5},
    "cryo":     {"flying": 2, "grass": 2, "drake": 2, "earth": 2, "sound": 2, "blaze": 0.5, "aquatic": 0.5, "cryo": 0.5, "metal": 0.5},
    "darkness": {"aura": 2, "holy": 2, "spectral": 2, "darkness": 0.5, "martial": 0.5, "mystic": 0.5},
    "drake":    {"drake": 2, "mystic": 0, "metal": 0.5, "holy": 0.5},
    "aura":     {"martial": 2, "toxic": 2, "metal": 0.5, "aura": 0.5, "darkness": 0},
    "mystic":   {"drake": 2, "martial": 2, "darkness": 2, "toxic": 0.5, "metal": 0.5, "blaze": 0.5, "sound": 0.5},
    "toxic":    {"grass": 2, "holy": 2, "mystic": 2, "toxic": 0.5, "earth": 0.5, "rock": 0.5, "spectral": 0.5, "metal": 0},
    "grass":    {"aquatic": 2, "earth": 2, "rock": 2, "blaze": 0.5, "grass": 0.5, "toxic": 0.5, "flying": 0.5, "arthropod": 0.5, "metal": 0.5, "drake": 0.5},
    "spectral": {"spectral": 2, "aura": 2, "basic": 0, "darkness": 0.5, "holy": 0},
}
ALL_ATKERS = list(CHART.keys())

def defensive_type_score(types):
    score = 100.0
    for atk in ALL_ATKERS:
        mult = 1.0
        for d in types:
            mult *= CHART.get(atk, {}).get(d, 1.0)
        if mult == 0:       score += 15
        elif mult <= 0.25:  score += 10
        elif mult < 1.0:    score += 5
        elif mult == 2.0:   score -= 20
        elif mult >= 4.0:   score -= 60
    return score

# ── Load data ────────────────────────────────────────────────────────────────
def load_json(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

organisms = load_json(ORG1_PATH)
if os.path.exists(ORG2_PATH):
    organisms += load_json(ORG2_PATH)

moves_raw = load_json(MOVES_PATH)
move_lookup = {}
for m in moves_raw:
    n = (m.get("name") or "").strip()
    if n:
        dmg = m.get("baseDamage") or m.get("power") or 0
        acc = m.get("accuracy") or 100
        move_lookup[n.lower()] = float(dmg) * (float(acc) / 100.0)

# ── Stat scoring ─────────────────────────────────────────────────────────────
STATS  = ["health","attack","defense","power","resistance","speed"]
# Speed downweighted: being fast is a BONUS, being slow doesn't tank your rank
STAT_W = {"health":1,"attack":1.5,"defense":0.5,"power":1.5,"resistance":0.5,"speed":1.3}

def bst(o):
    return sum(o.get(s,0) for s in STATS)

max_vals = {}   # filled after organisms loaded

def score_stats(o):
    total = 0.0
    for s in STATS:
        v = float(o.get(s, 0))
        raw = (v / max_vals[s]) ** 2       # quadratic: high stats score more
        compressed = raw ** 0.35            # log-compress so mythicals don't crush scale
        total += compressed * STAT_W[s]
    return total

def move_quality(mv_str):
    if not mv_str: return 0.0
    names = [n.strip() for n in mv_str.replace(";",",").split(",") if n.strip()]
    vals  = [move_lookup[n.lower()] for n in names if n.lower() in move_lookup]
    return sum(vals)/len(vals) if vals else 0.0

def parse_types(cat_str):
    return [c.strip().lower() for c in cat_str.split(",") if c.strip()]

def classify_role(o):
    hp  = o.get("health",0); atk = o.get("attack",0); df  = o.get("defense",0)
    pw  = o.get("power",0);  rs  = o.get("resistance",0); spd = o.get("speed",0)
    tot = bst(o) or 1; off = max(atk, pw); bulk = df + rs
    if tot > 520 and off > 120 and bulk > 160: return "Apex Predator"
    if hp  > 125 and bulk > 180:               return "Titan"
    if off > 115 and bulk < 115:               return "Glass Cannon"
    if off > 95  and spd > 95:                 return "Sweeper"
    if spd > 115:                              return "Speedster"
    if off > 105 and spd < 85 and bulk > 170:  return "Bruiser"
    if bulk > 175 and off < 95:                return "Wall"
    if hp  > 105 and bulk > 150 and off < 110: return "Tank"
    return "Balanced"

# role display
ROLE_ICON = {
    "Apex Predator":"👑 Apex Predator","Titan":"🏛️ Titan",
    "Glass Cannon":"💥 Glass Cannon","Sweeper":"⚔️ Sweeper",
    "Speedster":"⚡ Speedster","Bruiser":"🐂 Bruiser",
    "Wall":"🛡️ Wall","Tank":"🛡️ Tank","Balanced":"⚖️ Balanced"
}

# ── Compute values ────────────────────────────────────────────────────────────
max_vals = {s: max(o.get(s,0) for o in organisms) or 1 for s in STATS}

for o in organisms:
    types = parse_types(o.get("category",""))
    o["_types"]   = types
    o["_bst"]     = bst(o)
    o["_statraw"] = score_stats(o)
    o["_defraw"]  = defensive_type_score(types) if types else 100.0
    o["_mq"]      = move_quality(o.get("moves",""))
    o["_cats"]    = len(types)
    o["_role"]    = classify_role(o)
    o["_roleD"]   = ROLE_ICON.get(o["_role"], o["_role"])

max_s = max(o["_statraw"] for o in organisms) or 1
max_d = max(o["_defraw"]  for o in organisms) or 1
min_d = min(o["_defraw"]  for o in organisms)
rng_d = (max_d - min_d) or 1
max_m = max(o["_mq"]      for o in organisms) or 1
max_c = max(o["_cats"]    for o in organisms) or 1

for o in organisms:
    sn = (o["_statraw"] / max_s) * 100
    dn = ((o["_defraw"] - min_d) / rng_d) * 30
    mn = (o["_mq"]      / max_m) * 30
    cn = (o["_cats"]    / max_c) * 30
    o["_score"] = 0.98*sn + 0.05*dn + 0.1*mn + 0.05*cn

ranked = sorted(organisms, key=lambda x: x["_score"], reverse=True)
for i,o in enumerate(ranked,1): o["_rank"] = i

# ── Console top 100 ──────────────────────────────────────────────────────────
print(f"\n{'─'*75}")
print(f"  ANIMAL WARFARE — TOP 100 (v7)  {len(organisms)} animals")
print(f"  Stats 89% (SPD 0.8x) | Type 10% | Moves 5% | Coverage 5%")
print(f"{'─'*75}")
print(f"{'#':>4}  {'Animal':<30} {'Role':<18} {'BST':>5} {'Score':>7}")
print(f"{'─'*75}")
for o in ranked[:100]:
    print(f"{o['_rank']:>4}. {o.get('name','?'):<30} {o['_roleD']:<18} "
          f"{o['_bst']:>5}  {o['_score']:>6.1f}")
print(f"{'─'*75}\n")

# ── Build JS dataset ─────────────────────────────────────────────────────────
js_rows = []
for o in ranked:
    types = o["_types"]
    weaks=[]; resists=[]; immunes=[]
    for atk in ALL_ATKERS:
        mult = 1.0
        for d in types: mult *= CHART.get(atk,{}).get(d,1.0)
        if   mult == 0: immunes.append(atk)
        elif mult <  1: resists.append(f"{atk}({mult:g}x)")
        elif mult >  1: weaks.append(f"{atk}({mult:g}x)")

    js_rows.append({
        "rank":    o["_rank"],
        "name":    o.get("name","?"),
        "rarity":  (o.get("rarity") or "").lower(),
        "rarityD": o.get("rarity") or "",
        "cats":    o.get("category",""),
        "catList": [c.strip() for c in o.get("category","").split(",") if c.strip()],
        "abs":     [a.strip() for a in o.get("abilities","").split(",")  if a.strip()],
        "mvs":     [m.strip() for m in o.get("moves","").replace(";",",").split(",") if m.strip()],
        "sprite":  o.get("sprite",""),
        "role":    o["_roleD"],
        "hp":      o.get("health",0),   "atk": o.get("attack",0),
        "def":     o.get("defense",0),  "pwr": o.get("power",0),
        "res":     o.get("resistance",0),"spd": o.get("speed",0),
        "bst":     o["_bst"],
        "score":   round(o["_score"],1),
        "defNorm": round(((o["_defraw"]-min_d)/rng_d)*100, 1),
        "weaks":   weaks, "resists": resists, "immunes": immunes,
    })

DATA_JSON   = json.dumps(js_rows, ensure_ascii=False)
roles_set   = sorted(set(r["role"] for r in js_rows))
rarity_set  = sorted(set(r["rarity"] for r in js_rows if r["rarity"]))
role_opts   = "\n".join(f'<option value="{r}">{r}</option>' for r in roles_set)
rarity_opts = "\n".join(f'<option value="{r.lower()}">{r.capitalize()}</option>' for r in rarity_set)
total       = len(js_rows)

# ── HTML ──────────────────────────────────────────────────────────────────────
HTML = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Animal Warfare – Rankings</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:#060a0f;color:#e5e7eb;font-family:'Inter',system-ui,sans-serif;padding:20px;min-height:100vh}}

/* Header */
.header{{margin-bottom:18px}}
h1{{font-size:28px;font-weight:900;background:linear-gradient(90deg,#f97316,#ef4444,#a855f7);-webkit-background-clip:text;-webkit-text-fill-color:transparent;line-height:1.2}}
.sub{{color:#4b5563;font-size:12px;margin-top:4px}}

/* Legend */
.legend{{display:flex;gap:8px;flex-wrap:wrap;font-size:10px;color:#6b7280;margin-bottom:14px;padding:10px 14px;background:#0d1117;border-radius:10px;border:1px solid #161d2a;line-height:1.8}}
.legend b{{color:#9ca3af}}

/* Controls */
.ctrl-row{{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px}}
.sort-row{{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-bottom:14px;font-size:11px;color:#6b7280}}
input,select{{background:#0d1117;border:1px solid #1f2937;color:#e5e7eb;padding:8px 13px;border-radius:9px;font-size:12px;font-family:inherit;transition:border .2s,box-shadow .2s}}
input{{min-width:240px}}input:focus,select:focus{{outline:none;border-color:#f97316;box-shadow:0 0 0 3px rgba(249,115,22,.12)}}
.sbtn{{background:#0d1117;border:1px solid #1f2937;color:#6b7280;padding:5px 11px;border-radius:7px;cursor:pointer;font-size:11px;font-family:inherit;transition:all .2s}}
.sbtn:hover{{background:#1f2937;color:#f3f4f6}}.sbtn.on{{background:#f97316;color:#000;border-color:#f97316;font-weight:700}}
#cnt{{font-size:12px;color:#4b5563;margin-left:auto}}

/* Pager */
.pager{{display:flex;gap:4px;margin:12px 0;flex-wrap:wrap;align-items:center}}
.pager button{{background:#0d1117;border:1px solid #1f2937;color:#6b7280;padding:6px 13px;border-radius:8px;cursor:pointer;font-size:12px;font-family:inherit;transition:all .2s}}
.pager button:hover{{background:#1f2937;color:#e5e7eb}}
.pager button.active{{background:linear-gradient(135deg,#f97316,#ef4444);color:#fff;border-color:transparent;font-weight:700;box-shadow:0 2px 12px rgba(249,115,22,.35)}}
.pager button:disabled{{opacity:.25;cursor:not-allowed}}
#pginfo{{font-size:11px;color:#374151;margin-left:6px}}

/* Table */
table{{width:100%;border-collapse:collapse;font-size:12px}}
thead th{{background:#0a0e14;color:#4b5563;text-align:left;padding:10px 12px;font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.08em;border-bottom:2px solid #111827;position:sticky;top:0;z-index:10}}
tbody tr{{background:#080c10;border-bottom:1px solid #0d1117;transition:background .1s}}
tbody tr:nth-child(even){{background:#09090f}}
tbody tr:hover{{background:#0f1726}}
td{{padding:9px 12px;vertical-align:middle}}

/* Rank */
.rk{{font-size:16px;font-weight:900;color:#f59e0b;width:58px;text-align:center;white-space:nowrap}}
.rk small{{display:block;font-size:9px;color:#374151;font-weight:400;line-height:1}}

/* Sprite */
.sp img{{width:46px;height:46px;object-fit:contain;border-radius:8px;border:1px solid #1f2937;background:#111827;display:block}}
.sp-ph{{width:46px;height:46px;background:#111827;border-radius:8px}}

/* Name cell */
.nm{{font-size:13px;font-weight:700;color:#f3f4f6;margin-bottom:3px;line-height:1.3}}
.chips{{display:flex;flex-wrap:wrap;gap:2px;margin-top:3px}}
.chip{{padding:1px 7px;border-radius:10px;font-size:10px;white-space:nowrap}}
.cty{{background:#1e1b4b;color:#c4b5fd;border:1px solid #2e2a6a}}
.cab{{background:#0c1f3a;color:#93c5fd;border:1px solid #1e3a5f}}
.cmv{{background:#052e16;color:#86efac;border:1px solid #14532d}}

/* Badge */
.badge{{padding:3px 10px;border-radius:10px;font-size:10px;font-weight:700;white-space:nowrap;letter-spacing:.02em}}

/* Stats grid */
.sg{{display:grid;grid-template-columns:28px 1fr 26px;gap:2px 6px;align-items:center;font-size:10px;min-width:195px}}
.sg b{{color:#4b5563;font-size:9px;font-weight:600;text-align:right}}
.sg .v{{color:#9ca3af;font-variant-numeric:tabular-nums}}
.bw{{background:#1a2030;border-radius:3px;height:7px;overflow:hidden}}
.bb{{height:100%;border-radius:3px}}

/* Defense */
.def-cell{{min-width:185px}}
.dp{{display:inline-flex;align-items:center;padding:3px 10px;border-radius:10px;font-size:10px;font-weight:700;margin-bottom:4px}}
.wk-wrap,.rs-wrap,.im-wrap{{display:flex;flex-wrap:wrap;gap:2px;margin-top:2px}}
.cwk{{background:#3b0a0a;color:#fca5a5;border:1px solid #7f1d1d}}
.crs{{background:#052e16;color:#86efac;border:1px solid #14532d}}
.cim{{background:#1a1740;color:#a5b4fc;border:1px solid #2e2a6a}}

/* Score */
.sc-cell{{width:130px;text-align:center}}
.sc-n{{font-size:22px;font-weight:900;line-height:1.1}}
.sc-bw{{background:#1a2030;border-radius:4px;height:5px;width:100px;margin:4px auto 3px}}
.sc-bb{{height:100%;border-radius:4px}}
.sc-bst{{font-size:10px;color:#374151}}
</style>
</head>
<body>

<div class="header">
  <h1>🐾 Animal Warfare — Full Rankings</h1>
  <div class="sub">Generated {datetime.now().strftime('%Y-%m-%d %H:%M')} &nbsp;·&nbsp; {total:,} animals ranked &nbsp;·&nbsp; Stats 80% (SPD neutral) · Type Defense 10% · Moves 5% · Coverage 5%</div>
</div>

<div class="legend">
  <b>Roles ▸</b>
  <span>👑 Apex = high BST + offense + bulk</span>
  <span>🏛️ Titan = extreme HP/bulk</span>
  <span>💥 Glass Cannon = huge offense, low bulk</span>
  <span>⚔️ Sweeper = offense + speed</span>
  <span>⚡ Speedster = SPD &gt; 115</span>
  <span>🐂 Bruiser = heavy offense, slow</span>
  <span>🛡️ Wall = pure bulk, low offense</span>
  <span>🛡️ Tank = balanced bulk</span>
  <span>⚖️ Balanced</span>
  &nbsp;&nbsp;
  <span style="color:#fca5a5">●Weak</span>
  <span style="color:#86efac">●Resist</span>
  <span style="color:#a5b4fc">●Immune</span>
</div>

<div class="ctrl-row">
  <input id="qry" placeholder="🔍  Search name, type, ability or move…" oninput="doSearch()">
  <select id="rarF" onchange="doSearch()"><option value="">All Rarities</option>{rarity_opts}</select>
  <select id="rolF" onchange="doSearch()"><option value="">All Roles</option>{role_opts}</select>
  <span id="cnt">{total:,} animals</span>
</div>

<div class="sort-row">
  Sort&nbsp;by:
  <button class="sbtn on" data-k="score"  onclick="doSort(this)">Score</button>
  <button class="sbtn"    data-k="bst"    onclick="doSort(this)">BST</button>
  <button class="sbtn"    data-k="atk"    onclick="doSort(this)">ATK</button>
  <button class="sbtn"    data-k="pwr"    onclick="doSort(this)">PWR</button>
  <button class="sbtn"    data-k="def"    onclick="doSort(this)">DEF</button>
  <button class="sbtn"    data-k="res"    onclick="doSort(this)">RES</button>
  <button class="sbtn"    data-k="hp"     onclick="doSort(this)">HP</button>
  <button class="sbtn"    data-k="spd"    onclick="doSort(this)">SPD</button>
  <button class="sbtn"    data-k="defNorm" onclick="doSort(this)">Typing</button>
  <span id="sort-dir" style="color:#f97316"></span>
</div>

<div class="pager" id="tp"></div>
<span id="pginfo"></span>

<table>
<thead>
<tr>
  <th style="width:58px;text-align:center">Rank</th>
  <th style="width:54px"></th>
  <th>Animal &nbsp;/&nbsp; Types &nbsp;/&nbsp; Abilities &nbsp;/&nbsp; Moves</th>
  <th>Rarity</th>
  <th>Role</th>
  <th>Stats (all 6)</th>
  <th>Type Defense</th>
  <th style="width:130px;text-align:center">Score</th>
</tr>
</thead>
<tbody id="tb"></tbody>
</table>
<div class="pager" id="bp"></div>

<script>
const RAW={DATA_JSON};
const PS=50;
let F=RAW.slice(),P=0,SK='score',SD=-1;

const RC={{'👑 Apex Predator':'#b45309','🏛️ Titan':'#7f1d1d','💥 Glass Cannon':'#4c1d95',
 '⚔️ Sweeper':'#991b1b','⚡ Speedster':'#065f46','🐂 Bruiser':'#78350f',
 '🛡️ Wall':'#1e3a5f','🛡️ Tank':'#1e40af','⚖️ Balanced':'#1f2937'}};
const RARC={{'common':'#4b5563','uncommon':'#15803d','rare':'#1d4ed8',
 'epic':'#7e22ce','legendary':'#b45309','mythical':'#9d174d'}};

function bar(v,m,c){{
  return `<div class="bw"><div class="bb" style="width:${{Math.min(v/m*100,100).toFixed(0)}}%;background:${{c}}"></div></div>`;
}}

function row(o){{
  const med={{1:'🥇',2:'🥈',3:'🥉'}}[o.rank]||'';
  const sp=o.sprite
    ?`<img src="${{o.sprite}}" loading="lazy" onerror="this.style.display='none'">`
    :`<div class="sp-ph"></div>`;
  const ty=(o.catList||[]).map(t=>`<span class="chip cty">${{t}}</span>`).join('');
  const ab=(o.abs||[]).map(a=>`<span class="chip cab">${{a}}</span>`).join('');
  const mv=(o.mvs||[]).map(m=>`<span class="chip cmv">${{m}}</span>`).join('');
  const M=200;
  const st=`<div class="sg">
<b>HP</b>${{bar(o.hp,M,'#ef4444')}}<span class="v">${{o.hp}}</span>
<b>ATK</b>${{bar(o.atk,M,'#f97316')}}<span class="v">${{o.atk}}</span>
<b>DEF</b>${{bar(o.def,M,'#3b82f6')}}<span class="v">${{o.def}}</span>
<b>PWR</b>${{bar(o.pwr,M,'#a855f7')}}<span class="v">${{o.pwr}}</span>
<b>RES</b>${{bar(o.res,M,'#06b6d4')}}<span class="v">${{o.res}}</span>
<b>SPD</b>${{bar(o.spd,M,'#22c55e')}}<span class="v">${{o.spd}}</span>
</div>`;
  const dn=o.defNorm;
  const dcol=dn>=70?'#14532d':dn>=45?'#713f12':'#7f1d1d';
  const dlbl=dn>=70?'Strong':dn>=45?'Average':'Fragile';
  const wc=o.weaks.map(w=>`<span class="chip cwk">${{w}}</span>`).join('');
  const rc=o.resists.map(r=>`<span class="chip crs">${{r}}</span>`).join('');
  const ic=o.immunes.map(i=>`<span class="chip cim">${{i}}</span>`).join('');
  const sc=o.score;
  const scol=sc>=60?'#f97316':sc>=35?'#3b82f6':'#22c55e';
  const sp2=Math.min(sc,100).toFixed(0);
  return `<tr>
<td class="rk">${{med}}${{o.rank}}<small>#${{o.rank}}</small></td>
<td class="sp">${{sp}}</td>
<td><div class="nm">${{o.name}}</div>
  <div class="chips">${{ty}}</div>
  <div class="chips">${{ab}}</div>
  <div class="chips">${{mv}}</div></td>
<td><span class="badge" style="background:${{RARC[o.rarity]||'#4b5563'}};color:#fff">${{o.rarityD||'?'}}</span></td>
<td><span class="badge" style="background:${{RC[o.role]||'#1f2937'}};color:#fff">${{o.role}}</span></td>
<td>${{st}}</td>
<td class="def-cell"><span class="dp" style="background:${{dcol}};color:#fff">${{dlbl}} ${{dn}}</span>
  <div class="wk-wrap">${{wc}}</div>
  <div class="rs-wrap">${{rc}}</div>
  <div class="im-wrap">${{ic}}</div></td>
<td class="sc-cell">
  <div class="sc-n" style="color:${{scol}}">${{sc}}</div>
  <div class="sc-bw"><div class="sc-bb" style="width:${{sp2}}%;background:${{scol}}"></div></div>
  <div class="sc-bst">BST&nbsp;${{o.bst}}</div>
</td>
</tr>`;
}}

function pager(id){{
  const pg=Math.ceil(F.length/PS);let h='';
  h+=`<button onclick="go(${{P-1}})" ${{P<1?'disabled':''}}>‹&nbsp;Prev</button>`;
  const s=Math.max(0,P-3),e=Math.min(pg,P+4);
  if(s>0)h+=`<button onclick="go(0)">1</button><span style="color:#374151;padding:0 3px">…</span>`;
  for(let i=s;i<e;i++)h+=`<button class="${{i==P?'active':''}}" onclick="go(${{i}})">${{i+1}}</button>`;
  if(e<pg)h+=`<span style="color:#374151;padding:0 3px">…</span><button onclick="go(${{pg-1}})">${{pg}}</button>`;
  h+=`<button onclick="go(${{P+1}})" ${{P>=pg-1?'disabled':''}}>Next&nbsp;›</button>`;
  document.getElementById(id).innerHTML=h;
}}

function render(){{
  document.getElementById('tb').innerHTML=F.slice(P*PS,(P+1)*PS).map(row).join('');
  const s=P*PS+1,e=Math.min((P+1)*PS,F.length);
  document.getElementById('pginfo').textContent=`Showing ${{s}}–${{e}} of ${{F.length}}`;
  pager('tp');pager('bp');
  window.scrollTo({{top:0,behavior:'smooth'}});
}}

function go(n){{P=Math.max(0,Math.min(n,Math.ceil(F.length/PS)-1));render();}}

function applySort(){{
  F.sort((a,b)=>SD*(b[SK]-a[SK]));
}}

function doSort(btn){{
  const k=btn.dataset.k;
  if(SK==k) SD*=-1; else {{SK=k;SD=-1;}}
  document.querySelectorAll('.sbtn').forEach(b=>b.classList.remove('on'));
  btn.classList.add('on');
  document.getElementById('sort-dir').textContent=SD==-1?' ↓':' ↑';
  applySort();P=0;render();
}}

function doSearch(){{
  const q=document.getElementById('qry').value.toLowerCase();
  const r=document.getElementById('rarF').value;
  const l=document.getElementById('rolF').value;
  F=RAW.filter(o=>
    (!q||o.name.toLowerCase().includes(q)||
         (o.cats||'').toLowerCase().includes(q)||
         (o.abs||[]).some(a=>a.toLowerCase().includes(q))||
         (o.mvs||[]).some(m=>m.toLowerCase().includes(q)))&&
    (!r||o.rarity==r)&&(!l||o.role==l));
  applySort();
  document.getElementById('cnt').textContent=F.length.toLocaleString()+' animals';
  P=0;render();
}}

render();
</script>
</body>
</html>"""

with open(OUTPUT_HTML, "w", encoding="utf-8") as f:
    f.write(HTML)
print(f"✅  HTML → {OUTPUT_HTML} ({len(organisms):,} animals)")
