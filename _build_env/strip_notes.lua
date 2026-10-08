-- strip_notes.lua: drop reveal.js speaker notes (::: {.notes} blocks) from the
-- public render of a deck. The public site is what students see, and the site
-- search indexes the notes, so timing lines, cut orders and worked answers to
-- the retrieval questions must not be in them.
--
-- The instructor's own render keeps the notes: set the environment variable
-- ST313_KEEP_NOTES to any value, e.g.
--
--   ST313_KEEP_NOTES=1 quarto render weeks/wk01/slides.qmd -M embed-resources:true
--
-- (the output lands in docs/; `_build_env/build.sh instructor` moves it to
-- _instructor_rendered/ and `site` publishes it at docs/decks-notes/wkNN/).
-- Referenced from each deck's YAML as
--   filters: [../../_build_env/strip_notes.lua]

local keep = os.getenv("ST313_KEEP_NOTES")

function Div(el)
  if keep == nil and el.classes:includes("notes") then
    return {}
  end
  return nil
end
