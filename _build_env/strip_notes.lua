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
-- _instructor_rendered/ and `site` publishes it at docs/teachers/wkNN/).
-- Referenced from each deck's YAML as
--   filters: [../../_build_env/strip_notes.lua]

local keep = os.getenv("ST313_KEEP_NOTES")

function Div(el)
  if keep == nil and el.classes:includes("notes") then
    return {}
  end
  return nil
end

-- Progress bar (convenor, 20 October 2026; copied from ST310's version of 19 October). In the
-- instructor's render only, the speaker note of every slide starts with one line, a progress bar:
-- the share of the deck's estimated minutes completed before this slide, e.g.
--   [#########-----------] 44%  34 of 78 min
-- 20 characters wide, in inline code. Estimates, on the spine's timing scale: 2 minutes a content
-- slide; 1 a dark (.inverse) slide or a divider (a level-1 "# Part ..." heading); 3 a derivation or
-- a slide with a substantial pause for the room, marked on its heading,
--   ## Who bears the error {minutes="3"}
-- Any slide can carry its own estimate the same way ({minutes="0"} for a slide that is not
-- presented). A slide without a note gets a note holding only the bar. Computed at render time,
-- so it follows the deck as it changes. The public render, which has no notes, is unchanged.
--
-- One change from ST310's logic: if a slide's note is not the first block under its heading,
-- the bar goes into that note rather than into a second one (reveal.js shows only the first
-- note of a slide).

local function slide_minutes(h)
  local m = h.attributes["minutes"]
  if m ~= nil and tonumber(m) ~= nil then return tonumber(m) end
  if h.classes:includes("inverse") then return 1 end
  if h.level == 1 then return 1 end
  return 2
end

local function is_slide(b) return b.t == "Header" and b.level <= 2 end
local function is_notes(b) return b.t == "Div" and b.classes:includes("notes") end

local function fmt(x)
  if x == math.floor(x) then return string.format("%d", math.floor(x)) end
  return string.format("%.1f", x)
end

function Pandoc(doc)
  if keep == nil then return nil end
  local blocks = doc.blocks
  local total = 0
  for _, b in ipairs(blocks) do if is_slide(b) then total = total + slide_minutes(b) end end
  if total == 0 then return nil end
  local width = 20
  local out = pandoc.List()
  local done = 0
  for i, b in ipairs(blocks) do
    out:insert(b)
    if is_slide(b) then
      local filled = math.floor(width * done / total + 0.5)
      local bar = "[" .. string.rep("#", filled) .. string.rep("-", width - filled) .. "]"
      local line = pandoc.Para({pandoc.Code(bar), pandoc.Space(),
        pandoc.Str(string.format("%d%%  %s of %s min", math.floor(100 * done / total + 0.5), fmt(done), fmt(total)))})
      -- the slide's first note, if it has one before the next slide
      local note = nil
      local j = i + 1
      while j <= #blocks and not is_slide(blocks[j]) do
        if is_notes(blocks[j]) then note = blocks[j]; break end
        j = j + 1
      end
      if note ~= nil then
        local c = note.content
        c:insert(1, line)
        note.content = c
      else
        out:insert(pandoc.Div({line}, pandoc.Attr("", {"notes"})))
      end
      done = done + slide_minutes(b)
    end
  end
  doc.blocks = out
  return doc
end
