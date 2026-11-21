# Boek-PDF

`cookbook.typ` is een Typst-sjabloon dat de `.cook`-bestanden direct inleest (Cooklang-parser in Typst) en ze opmaakt; `genereer.py` maakt `main.typ` met alle recepten per hoofdstuk.

```sh
python3 genereer.py
typst compile --root .. --font-path <map met Playfair Display> main.typ ../Indisch-Kookboek.pdf
```

Lettertypen: Playfair Display (koppen) en Inter (tekst); zonder deze vallen ze terug op Georgia/Helvetica.
