# Genereert main.typ uit de .cook-bestanden in de bovenliggende map.
# Gebruik: python3 genereer.py && typst compile --root .. main.typ ../Indisch-Kookboek.pdf
import glob, os, re
here = os.path.dirname(os.path.abspath(__file__))
rows = []
for f in glob.glob(os.path.join(here, "..", "*.cook")):
    t = open(f, encoding="utf-8").read()
    cat = re.search(r"^categorie:\s*(.+)$", t, re.M)
    b = os.path.basename(f)
    m = re.match(r"(\d+)(\w*)", b)
    rows.append(((int(m.group(1)), m.group(2)), cat.group(1).strip() if cat else "Overig", b))
rows.sort()
chapters = {}
for key, cat, b in rows:
    chapters.setdefault(cat, []).append(b)
esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"')
out = ['#import "cookbook.typ": cookbook, contents-page, chapter, cooklang-recipe', "",
       "#show: cookbook.with(",
       '  title: "Groot Nieuw Volledig Indisch Kookboek",',
       '  subtitle: "1381 recepten voor de volledige Indische rijsttafel — in hedendaags Nederlands",',
       '  author: "J.M.J. Catenius-van der Meijden",',
       '  paper: "a4",',
       '  colophon: [Naar de zesde druk (Van Goor Zonen, Den Haag). Spelling gemoderniseerd; Indonesische benamingen zoals in het boek. Tenzij anders vermeld gerekend op vier à vijf personen. 1 pond = 500 g, 1 ons = 100 g, een lepel is een gewone eetlepel. Recepten 6–8, 783–786, 988 en 1156 ontbreken door ontbrekende pagina\'s in de scan.],',
       ")", "", "#contents-page(depth: 2)", ""]
for cat, files in chapters.items():
    n = len(files)
    out.append(f'#chapter("{esc(cat)}", description: "{n} recept{"en" if n != 1 else ""}")')
    for b in files:
        out.append(f'#cooklang-recipe("/{esc(b)}")')
    out.append("")
open(os.path.join(here, "main.typ"), "w", encoding="utf-8").write("\n".join(out))
print(len(rows), "recepten,", len(chapters), "hoofdstukken")
