local FIELD_POS   = {x=0,y=0}
local FIELD_MINES = 10

local FIELD_WIDTH     = 8
local FIELD_HEIGHT    = 10
local FIELD_SLOT_SIZE = 32

local VERITY_POS  = {x=0,y=0}
local VERITY_SIZE = 64

---------------------

local SPRITESHEET
local DIGIT_QUADS = {}
local SHEET_QUADS = {}

local MARK_NONE     = 0
local MARK_FLAG     = 1
local MARK_QUESTION = 2

local TIMER_QUIT_SECS = 0.8

---------------------

local flags_used   = 0
local verity_face  = "smile"
local time_elapsed = 0

local game_ended = false
local last_click = {x=0, y=0}

local game_won = false

local timer_quit_elapsed = 0

---------------------

local minefield = {}

local function field_forEachSlot(func)
   local r
   for y,line in ipairs(minefield) do
      for x,slot in ipairs(line) do
         r = func(slot, x,y)
         if r == 1 then break end
      end
      if r == 1 then break end
   end
end
local function field_getSlotNeighbors(slot)
   local neighbors = {}
   for fy = -1, 1 do
      for fx = -1, 1 do
         local s = (minefield[slot.pos.y + fy] or {})[slot.pos.x + fx]
         if s and (fy ~= 0 or fx ~= 0) then
            table.insert(neighbors, s)
         end
      end
   end
   return neighbors
end
local function field_getUsedFlags()
   local n = 0
   field_forEachSlot(function(slot)
      if slot.mark == MARK_FLAG then
         n = n + 1
      end
   end)
   return n
end

local function startfield()
   minefield = {}
   game_ended = false
   game_won = false

   flags_used   = 0
   verity_face  = "smile"
   time_elapsed = 0

   -- initialize empty field
   local slot_i = 0
   for y = 1, FIELD_HEIGHT do
      minefield[y] = {}
      for x = 1, FIELD_WIDTH do
         slot_i = slot_i + 1
         minefield[y][x] = {
            pos = { x = x, y = y },
            i       = slot_i,
            num     = 0,
            mark    = 0,
            clicked = false
         }
      end
   end

   -- add mines
   for i = 1, FIELD_MINES do
      if i > FIELD_WIDTH*FIELD_HEIGHT then break end
   
      local slot = { num = -1 }
      while slot.num == -1 do
         slot = minefield[love.math.random(1, FIELD_HEIGHT)][love.math.random(1, FIELD_WIDTH)]
      end
      slot.num = -1
   end
   
   -- check for mines around each slot and add 1 to num
   field_forEachSlot(function(slot, x,y)
      if slot.num ~= -1 then
         for fy = -1, 1 do
            for fx = -1, 1 do
               local s = (minefield[y + fy] or {})[x + fx]
               if s and s.num == -1 then
                  slot.num = slot.num + 1
               end
            end
         end
      end
   end)
end

local function fieldwipe(from)
   local queue,seen = {from},{[from.i] = true}
   local count,countAll = 1,1
   while #queue > 0 do
      local slot = queue[#queue]
      table.remove(queue, #queue)
      for i,neighbor in ipairs(field_getSlotNeighbors(slot)) do
         if not neighbor.clicked and neighbor.mark ~= MARK_FLAG and not seen[neighbor.i] and neighbor.num >= 0 then
            neighbor.clicked = true
            countAll = countAll + 1
            if neighbor.num == 0 then
               table.insert(queue, neighbor)
               seen[neighbor.i] = true
               count = count + 1
            end
         end
      end
   end
   return count, countAll
end

---------------------

local function drawdigits(value, x,y, sx,sy)
   local str = tostring(value)
   for i = 1,#str do
      local num = str:sub(i,i)
      love.graphics.draw(SPRITESHEET, DIGIT_QUADS[num], x + (i-1)*(13*(sx or 1)),y, 0, sx or 1,sy or 1)
   end
end

---------------------

function love.load()
   love.graphics.setDefaultFilter('nearest', 'nearest', 0)
   local w,h = love.window.getMode()

   FIELD_POS.x = (w/2) - (FIELD_SLOT_SIZE*(FIELD_WIDTH/2))
   FIELD_POS.y = (h/2) - (FIELD_SLOT_SIZE*(FIELD_HEIGHT/2)) + 32

   VERITY_POS.x = (w/2) - (VERITY_SIZE/2)
   VERITY_POS.y = 32

   startfield()

   ---------------------------------

   SPRITESHEET = love.graphics.newImage('assets/sheet.png')
   local sw,sh = 160,112

   -- red numbers
   for i = 0,9 do
      DIGIT_QUADS[tostring(i)] = love.graphics.newQuad(i*13, 32, 13,23, sw,sh)
   end
   DIGIT_QUADS["-"] = love.graphics.newQuad(13*10, 32, 13,23, sw,sh)
   DIGIT_QUADS[" "] = love.graphics.newQuad(13*11, 32, 13,23, sw,sh)

   -- verity
   for i,face in ipairs({"smile", "wow", "cool", "dead"}) do
      SHEET_QUADS["face."..face] = love.graphics.newQuad((i-1)*24, 55, 24,24, sw,sh)
      SHEET_QUADS["face."..face..".pressed"] = love.graphics.newQuad((i-1)*24, 55+24, 24,24, sw,sh)
   end

   -- slot marks
   SHEET_QUADS["slot:0"]         = love.graphics.newQuad(0,0,  16,16, sw,sh)
   SHEET_QUADS["slot:0.pressed"] = love.graphics.newQuad(0,16, 16,16, sw,sh)
   SHEET_QUADS["slot:1"] = love.graphics.newQuad(16,0, 16,16, sw,sh) -- flag
   SHEET_QUADS["slot:2"]         = love.graphics.newQuad(32,0, 16,16, sw,sh)
   SHEET_QUADS["slot:2.pressed"] = love.graphics.newQuad(48,0, 16,16, sw,sh)

   -- slot nums
   for i = 0,8 do
      SHEET_QUADS["slot"..i] = love.graphics.newQuad(i*16,16, 16,16, sw,sh)
   end

   -- mine
   SHEET_QUADS["mine"] = love.graphics.newQuad(64,0, 16,16, sw,sh)
   SHEET_QUADS["mine.pressed"] = love.graphics.newQuad(64+16,0, 16,16, sw,sh)
   SHEET_QUADS["mine.crossed"] = love.graphics.newQuad(64+32,0, 16,16, sw,sh)
end

function love.update(dt)
   if not game_ended then
      time_elapsed = time_elapsed + dt
   end

   if love.keyboard.isDown('escape') then
      timer_quit_elapsed = timer_quit_elapsed + dt
      if timer_quit_elapsed >= TIMER_QUIT_SECS then
         print("minesweeper: Manual exit triggered, no error")
         love.event.quit(0)
      end
   end
end

function love.draw()
   --love.timer.sleep(0.1)
   love.graphics.clear(0.68,0.68,0.69)
   local w,h = love.window.getMode()

   -- FLAGS LEFT
   drawdigits(string.format("%2d", FIELD_MINES - flags_used), FIELD_POS.x, VERITY_POS.y+10, 2,2)
   -- TIME ELAPSED
   drawdigits(string.format("%3d", math.min(math.floor(time_elapsed), 999)), (w-FIELD_POS.x) - (26*3), VERITY_POS.y+10, 2,2)

   local mx,my = love.mouse.getPosition()

   -- VERITY
   if verity_face then
      local x,y = VERITY_POS.x,VERITY_POS.y
      local q = "face."..verity_face
      if love.mouse.isDown({1,2}) and
         ((mx >= x and mx <= x+VERITY_SIZE) and (my >= y and my <= y+VERITY_SIZE)) then
         q = q..".pressed"
      end
      love.graphics.draw(SPRITESHEET, SHEET_QUADS[q], x,y, 0, VERITY_SIZE/24)
   end

   -- MINEFIELD
   field_forEachSlot(function(slot, sx,sy)
      local x,y = FIELD_POS.x + (sx-1)*FIELD_SLOT_SIZE, FIELD_POS.y + (sy-1)*FIELD_SLOT_SIZE
      local q
      if not slot.clicked then
         q = "slot:"..slot.mark
      else
         if slot.num == -1 then
            -- mine
            if game_won or slot.mark == MARK_FLAG then
               q = "mine.crossed"
            else
               q = (sx == last_clicked.x and sy == last_clicked.y) and "mine.pressed" or "mine"
            end
         else
            q = "slot"..slot.num
         end
      end

      -- mouse clicked
      if not game_ended and slot.mark ~= MARK_FLAG and not slot.clicked and love.mouse.isDown(1) and
         ((mx >= x and mx < x+FIELD_SLOT_SIZE) and (my >= y and my < y+FIELD_SLOT_SIZE)) then
         q = q..".pressed"
      end

      love.graphics.draw(SPRITESHEET, SHEET_QUADS[q], x,y, 0, (FIELD_SLOT_SIZE/16), (FIELD_SLOT_SIZE/16))
      --love.graphics.print(num, x * FIELD_SLOT_SIZE * 2, y * FIELD_SLOT_SIZE * 2, 0, 2,2)
   end)
end

---------------------

function love.mousereleased(x,y, mb)
   if mb >= 3 then return end

   if (x >= VERITY_POS.x and x <= VERITY_POS.x+VERITY_SIZE) and
      (y >= VERITY_POS.y and y <= VERITY_POS.y+VERITY_SIZE) then
      startfield()
      return
   end

   if game_ended then return end

   x,y = x-FIELD_POS.x, y-FIELD_POS.y
   local w,h = FIELD_SLOT_SIZE*FIELD_WIDTH, FIELD_SLOT_SIZE*FIELD_HEIGHT
   if (x < 0 or x >= w) or (y < 0 or y >= h) then return end

   local mpos = {
      x = math.floor(x / FIELD_SLOT_SIZE)+1,
      y = math.floor(y / FIELD_SLOT_SIZE)+1
   }
   --print(string.format("x=%02d  y=%02d", mpos.x, mpos.y))
   local slot = minefield[mpos.y][mpos.x]
   if slot and not slot.clicked then
      -- right click
      if mb == 2 then
         verity_face = "smile"
         if (FIELD_MINES - flags_used) > 0 or slot.mark == MARK_FLAG then
            slot.mark = (slot.mark + 1) % 3
         else
            slot.mark = (slot.mark == 0) and 2 or 0
         end
         flags_used = field_getUsedFlags()
         return
      end
      -- is marked with flag
      if slot.mark == MARK_FLAG then
         return
      end

      last_clicked = mpos
      verity_face = "smile"
   
      slot.clicked = true
      -- not a mine
      if slot.num >= 0 then
         -- mega awesome wipe
         if slot.num == 0 then
            local wiped = fieldwipe(slot)
            if wiped > 8 then
               verity_face = "wow"
            end
         end

         local won
         field_forEachSlot(function(slot)
            if (slot.num >= 0) then won = slot.clicked
            else won = not slot.clicked end
            if not won then return 1 end
         end)
         if won then
            game_ended = true
            game_won = true
            verity_face = "cool"
         end

      -- mine clicked
      else
         game_ended = true
         verity_face = "dead"
      end

      -- reveal all mines on game end
      if game_ended then
         field_forEachSlot(function(slot)
            if slot.num == -1 then slot.clicked = true end
         end)
      end
   end
end

function love.keyreleased(key)
   if key == 'escape' then
      timer_quit_elapsed = 0
   end
end
