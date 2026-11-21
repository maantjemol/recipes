// cookbook.typ — Editorial Typst template with native Cooklang parsing
// (adapted for the Indisch kookboek: Dutch labels, recept/pagina/categorie metadata)

#let theme = (
  ink: rgb("#1D1B18"),
  muted: rgb("#6C665E"),
  accent: rgb("#B85332"),     // Terracotta for timers, numbers, kickers
  surface: rgb("#F6F3EE"),    // Warm paper tint for the ingredient column
  rule: rgb("#E2DCD3"),
  display-font: ("Playfair Display", "Georgia", "Linux Libertine"),
  body-font: ("Inter", "DM Sans", "Helvetica Neue", "Liberation Sans"),
)

// --- Cooklang parser ---

// Pretty-print quantities: 1/2 -> ½, 2.5 -> 2½ etc.
#let _fractions = ("1/2": "½", "1/4": "¼", "3/4": "¾", "1/3": "⅓", "2/3": "⅔", "1/8": "⅛")
#let _decimals = (".5": "½", ".25": "¼", ".75": "¾")

#let _pretty-amount(a) = {
  let s = a.trim()
  if s in _fractions { return _fractions.at(s) }
  for (d, f) in _decimals {
    if s.ends-with(d) and s.len() > d.len() {
      let whole = s.slice(0, s.len() - d.len())
      if whole.match(regex("^\\d+$")) != none {
        return if whole == "0" { f } else { whole + f }
      }
    }
  }
  s
}

#let _parse-qty(raw) = {
  let clean = raw.trim()
  if clean == "" { return "" }
  let parts = clean.split("%")
  if parts.len() >= 2 {
    _pretty-amount(parts.at(0)) + " " + parts.at(1).trim()
  } else {
    _pretty-amount(parts.at(0))
  }
}

#let _parse-token(raw) = {
  let kind = raw.slice(0, 1)
  let rest = raw.slice(1)

  let name = rest
  let qty = ""
  let note = ""

  if rest.contains("{") {
    let brace-parts = rest.split("{")
    name = brace-parts.at(0).trim()
    let after-open = brace-parts.slice(1).join("{")
    let close-parts = after-open.split("}")
    qty = _parse-qty(close-parts.at(0))
    let tail = close-parts.slice(1).join("}").trim()
    if tail.starts-with("(") and tail.ends-with(")") {
      note = tail.slice(1, tail.len() - 1).trim()
    }
  }

  (kind: kind, name: name.trim(), qty: qty, note: note)
}

#let _token-re = regex("(@[^@#~\n{}().,;:]+\\{[^}]*\\}(?:\\([^)]*\\))?|@[\\p{L}\\p{N}_-]+|#[^@#~\n{}().,;:]+\\{[^}]*\\}|#[\\p{L}\\p{N}_-]+|~[^@#~\n{}().,;:]*\\{[^}]*\\})")

#let parse-cooklang(source) = {
  let text = source.replace("\r\n", "\n").trim()
  let meta = (:)

  // 1. Extract YAML frontmatter (--- ... ---)
  if text.starts-with("---") {
    let after-first = text.slice(3)
    let split-fm = after-first.split("\n---")
    if split-fm.len() >= 2 {
      let fm-str = split-fm.at(0).trim()
      if fm-str != "" {
        let parsed = yaml(bytes(fm-str))
        if type(parsed) == dictionary { meta = parsed }
      }
      text = split-fm.slice(1).join("\n---").trim()
    }
  }

  // 2. Strip block comments [- ... -] and line comments -- ...
  text = text.replace(regex("(?s)\\[-.*?-\\]"), "")
  let clean-lines = ()
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.starts-with(">>") {
      let kv = trimmed.slice(2).split(":")
      if kv.len() >= 2 {
        meta.insert(kv.at(0).trim().lower(), kv.slice(1).join(":").trim())
      }
    } else if trimmed.starts-with("--") {
      // whole-line comment: drop
    } else {
      clean-lines.push(line.split(" -- ").at(0))
    }
  }
  text = clean-lines.join("\n").trim()

  // 3. Parse blocks into sections, notes, steps, ingredients, and cookware
  let ingredients = ()
  let cookware = ()
  let blocks = ()

  for para in text.split(regex("\n\\s*\n")) {
    let p = para.trim()
    if p == "" { continue }

    if p.starts-with("=") {
      let sec-title = p.trim("=").trim()
      blocks.push((type: "section", value: sec-title))
    } else if p.starts-with(">") {
      let note-lines = p.split("\n").map(l => l.trim().trim(">").trim())
      blocks.push((type: "note", value: note-lines.join(" ")))
    } else {
      let step-text = p.replace("\n", " ")
      let segments = ()
      let cursor = 0

      for m in step-text.matches(_token-re) {
        if m.start > cursor {
          segments.push((kind: "text", value: step-text.slice(cursor, m.start)))
        }
        let tok = _parse-token(m.text)
        segments.push(tok)
        if tok.kind == "@" {
          ingredients.push((name: tok.name, qty: tok.qty, note: tok.note))
        } else if tok.kind == "#" {
          if not cookware.contains(tok.name) {
            cookware.push(tok.name)
          }
        }
        cursor = m.end
      }
      if cursor < step-text.len() {
        segments.push((kind: "text", value: step-text.slice(cursor)))
      }
      blocks.push((type: "step", segments: segments))
    }
  }

  (meta: meta, ingredients: ingredients, cookware: cookware, blocks: blocks)
}

// --- Cookbook wrapper & book furniture ---

#let cookbook(
  title: "My Cookbook",
  subtitle: none,
  author: "",
  paper: "a4",
  colophon: none,
  body,
) = {
  set document(title: title, author: author)
  set page(
    paper: paper,
    margin: (top: 22mm, bottom: 20mm, x: 18mm),
    header: context {
      if counter(page).get().first() > 2 {
        set text(font: theme.body-font, size: 8pt, fill: theme.muted, tracking: 0.1em)
        grid(
          columns: (1fr, 1fr),
          align(left, upper(title)),
          align(right, upper(author)),
        )
        v(-5pt)
        line(length: 100%, stroke: 0.5pt + theme.rule)
      }
    },
    footer: context {
      if counter(page).get().first() > 1 {
        set text(font: theme.body-font, size: 8.5pt, fill: theme.muted, number-type: "lining")
        align(center, counter(page).display())
      }
    },
  )
  set text(
    font: theme.body-font,
    size: 10.5pt,
    fill: theme.ink,
    lang: "nl",
    number-width: "tabular",
    number-type: "lining",
  )
  set par(leading: 0.82em, justify: false)
  set outline.entry(fill: repeat(text(fill: theme.rule, " · ")))
  show outline.entry.where(level: 1): it => {
    v(10pt, weak: true)
    text(font: theme.display-font, size: 12pt, weight: "bold", it)
  }
  show outline.entry.where(level: 2): set text(size: 9pt)
  show heading.where(level: 1): set text(font: theme.display-font, size: 32pt, weight: "bold", fill: theme.ink)
  show heading.where(level: 2): set text(font: theme.display-font, size: 25pt, weight: "bold", fill: theme.ink)
  show heading: set block(above: 0.5em, below: 0.3em)

  // Minimalist title page
  page(header: none, footer: none)[
    #v(1fr)
    #line(length: 36pt, stroke: 2pt + theme.accent)
    #v(14pt)
    #text(font: theme.display-font, size: 38pt, weight: "bold", title)
    #if subtitle != none {
      v(8pt)
      text(size: 13pt, fill: theme.muted, style: "italic", subtitle)
    }
    #if author != "" {
      v(24pt)
      text(size: 10pt, tracking: 0.14em, fill: theme.muted, upper(author))
    }
    #v(2fr)
    #if colophon != none {
      block(width: 80%, text(size: 8.5pt, fill: theme.muted, colophon))
    }
  ]

  body
}

#let contents-page(title: "Inhoud", depth: 2) = {
  pagebreak(weak: true)
  text(font: theme.display-font, size: 22pt, weight: "bold", title)
  v(8pt)
  line(length: 100%, stroke: 0.6pt + theme.rule)
  v(12pt)
  columns(2, gutter: 18pt, outline(title: none, indent: 0pt, depth: depth))
}

#let chapter(title, description: none) = {
  pagebreak(weak: true)
  v(1fr)
  heading(level: 1, outlined: true, numbering: none, title)
  if description != none {
    v(8pt)
    block(width: 75%, text(size: 11pt, fill: theme.muted, style: "italic", description))
  }
  v(12pt)
  line(length: 48pt, stroke: 1.5pt + theme.accent)
  v(2fr)
}

#let photo-page(path) = {
  page(margin: 0pt, header: none, footer: none)[
    #image(path, width: 100%, height: 100%, fit: "cover")
  ]
}

// --- Recipe page renderer ---

#let cooklang-recipe(
  cook-path,
  title: none,
  photo: none,
  new-page: true,
) = {
  let data = parse-cooklang(read(cook-path))
  let meta = data.meta

  let r-title = if title != none { title } else { meta.at("title", default: "Zonder titel") }
  let headnote = meta.at("description", default: meta.at("introduction", default: none))
  let number = meta.at("recept", default: none)
  let page-ref = meta.at("pagina", default: none)
  let servings = meta.at("servings", default: meta.at("serves", default: none))
  let prep = meta.at("prep time", default: none)
  let cook = meta.at("cook time", default: none)
  let total = meta.at("time", default: meta.at("total time", default: none))

  if new-page { pagebreak(weak: true) }

  // Kicker: recipe number
  if number != none {
    text(size: 8pt, weight: "semibold", fill: theme.accent, tracking: 0.14em, upper("Recept " + str(number)))
    v(2pt)
  }

  heading(level: 2, outlined: true, numbering: none, str(r-title))

  if headnote != none {
    v(5pt)
    text(size: 10.5pt, fill: theme.muted, style: "italic", str(headnote))
  }

  // Metadata bar
  let pills = ()
  if servings != none { pills.push(("Personen", str(servings))) }
  if prep != none { pills.push(("Voorbereiding", str(prep))) }
  if cook != none { pills.push(("Bereiding", str(cook))) }
  if total != none and prep == none and cook == none { pills.push(("Tijd", str(total))) }
  if page-ref != none { pills.push(("Origineel", "blz. " + str(page-ref))) }

  v(10pt)
  line(length: 100%, stroke: 0.6pt + theme.rule)
  if pills.len() > 0 {
    v(6pt)
    grid(
      columns: pills.len() * (auto,),
      column-gutter: 24pt,
      ..pills.map(((k, v)) => stack(
        spacing: 2pt,
        text(size: 7.5pt, fill: theme.muted, tracking: 0.1em, upper(k)),
        text(size: 10pt, weight: "semibold", fill: theme.ink, v),
      ))
    )
    v(6pt)
    line(length: 100%, stroke: 0.6pt + theme.rule)
  }

  if photo != none {
    v(12pt)
    block(radius: 4pt, clip: true, width: 100%,
      image(photo, width: 100%, height: 6.5cm, fit: "cover")
    )
  }

  v(16pt)

  let method = {
    let step-num = 0
    for b in data.blocks {
      if b.type == "section" {
        v(4pt)
        text(font: theme.display-font, size: 13pt, weight: "bold", b.value)
        v(8pt)
      } else if b.type == "note" {
        block(
          inset: (left: 10pt, y: 4pt),
          stroke: (left: 2pt + theme.rule),
          text(size: 9.5pt, fill: theme.muted, style: "italic", b.value),
        )
        v(8pt)
      } else if b.type == "step" {
        if step-num == 0 {
          text(size: 8.5pt, weight: "bold", fill: theme.accent, tracking: 0.12em, upper("Bereiding"))
          v(8pt)
        }
        step-num += 1
        grid(
          columns: (20pt, 1fr),
          column-gutter: 6pt,
          text(font: theme.display-font, size: 13pt, weight: "bold", fill: theme.accent, str(step-num)),
          {
            for seg in b.segments {
              if seg.kind == "text" {
                seg.value
              } else if seg.kind == "@" {
                text(weight: "semibold", seg.name)
              } else if seg.kind == "#" {
                emph(seg.name)
              } else if seg.kind == "~" {
                let label = if seg.qty != "" { seg.qty } else { seg.name }
                box(
                  fill: theme.accent.lighten(88%),
                  inset: (x: 4pt, y: 1.5pt),
                  outset: (y: 1pt),
                  radius: 3pt,
                  text(size: 9pt, weight: "semibold", fill: theme.accent, label),
                )
              }
            }
          },
        )
        v(9pt)
      }
    }
  }

  if data.ingredients.len() == 0 {
    method
    if data.cookware.len() > 0 {
      v(6pt)
      text(size: 8pt, weight: "bold", fill: theme.muted, tracking: 0.12em, upper("Benodigdheden"))
      h(8pt)
      text(size: 9pt, fill: theme.muted, data.cookware.join(" · "))
    }
  } else {
    grid(
      columns: (32%, 1fr),
      column-gutter: 22pt,
      block(fill: theme.surface, inset: 14pt, radius: 4pt, width: 100%, breakable: true)[
        #text(size: 8.5pt, weight: "bold", fill: theme.accent, tracking: 0.12em, upper("Ingrediënten"))
        #v(8pt)
        #set text(size: 9.5pt)
        #set par(leading: 0.6em)
        #grid(
          columns: (auto, 1fr),
          column-gutter: 8pt,
          row-gutter: 7pt,
          ..data.ingredients.map(ing => (
            align(right, text(weight: "semibold", fill: theme.ink, ing.qty)),
            {
              ing.name
              if ing.note != "" { text(fill: theme.muted, ", " + ing.note) }
            },
          )).flatten()
        )

        #if data.cookware.len() > 0 {
          v(14pt)
          line(length: 100%, stroke: 0.5pt + theme.rule)
          v(10pt)
          text(size: 8pt, weight: "bold", fill: theme.muted, tracking: 0.12em, upper("Benodigdheden"))
          v(6pt)
          text(size: 9pt, fill: theme.muted, data.cookware.join(" · "))
        }
      ],
      method,
    )
  }
}
