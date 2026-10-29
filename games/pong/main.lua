require('_math')

local debugm = false
local function debugp(name, x,y, ...)
   love.graphics.print(name, x,y)
   for i,str in ipairs({...}) do
      love.graphics.print(str, x + (#name+1)*8, y + (i-1)*20)
   end
end

------------------------

local BALL_WIDTH  = 20
local BALL_HEIGHT = 20
local PADD_WIDTH  = BALL_WIDTH
local PADD_HEIGHT = BALL_HEIGHT*5

local BALL_SPEED = 450
local PADD_SPEED = BALL_SPEED*1.15

local BARS_HEIGHT   = 8
local PONGNET_COUNT = 47
local PONGNET_WIDTH = 3

local TIMER_COUNTDOWN_SECS = 0.8
local TIMER_QUIT_SECS      = 0.7

------------------------

local game_paused = false
local ai = true

local timer_countdown_elapsed = 0
local timer_quit_elapsed      = 0

------------------------

local BALL = {
   pos       = {x=0,y=0},
   direction = {x=0,y=0}
}
local function flipBall(axis)
   BALL.direction[axis] = -BALL.direction[axis]
end
local function resetBall()
   local w,h = love.window.getMode()
   BALL.pos.x = (w/2)-(BALL_WIDTH/2)
   BALL.pos.y = (h/2)-(BALL_HEIGHT/2)

   BALL.direction.x = 0.7 * randomDirection()
   BALL.direction.y = randomDirection(true)*0.75
end

-------

local P1 = {
   pos   = {x=0,y=0},
   input = 0,
   score = 0
}
local P2 = {
   pos   = {x=0,y=0},
   input = 0,
   score = 0
}
local function resetPlayers()
   local w,h = love.window.getMode()

   P1.pos.x = 40
   P1.pos.y = (h/2)-(PADD_HEIGHT/2)

   P2.pos.x = (w-40)-PADD_WIDTH
   P2.pos.y = P1.pos.y
end

-----------------------------

local KEY_P1_UP   = 'w'
local KEY_P1_DOWN = 's'
local KEY_P2_UP   = 'up'
local KEY_P2_DOWN = 'down'

-----------------------------

local NUMERICAL_DIGIT_SIZE    = 10
local NUMERICAL_DIGIT_SPACING = 4

local NUMERICAL_DIGITS = {
   [0] = {{1,1,1}, {1,0,1}, {1,0,1}, {1,0,1}, {1,1,1}},
   [1] = {{0,1,0}, {0,1,0}, {0,1,0}, {0,1,0}, {0,1,0}},
   [2] = {{1,1,1}, {0,0,1}, {1,1,1}, {1,0,0}, {1,1,1}},
   [3] = {{1,1,1}, {0,0,1}, {1,1,1}, {0,0,1}, {1,1,1}},
   [4] = {{1,0,1}, {1,0,1}, {1,1,1}, {0,0,1}, {0,0,1}},
   [5] = {{1,1,1}, {1,0,0}, {1,1,1}, {0,0,1}, {1,1,1}},
   [6] = {{1,1,1}, {1,0,0}, {1,1,1}, {1,0,1}, {1,1,1}},
   [7] = {{1,1,1}, {0,0,1}, {0,0,1}, {0,0,1}, {0,0,1}},
   [8] = {{1,1,1}, {1,0,1}, {1,1,1}, {1,0,1}, {1,1,1}},
   [9] = {{1,1,1}, {1,0,1}, {1,1,1}, {0,0,1}, {0,0,1}}
}

local function drawDigits(digits, x,y)
   local str = tostring(digits)
   for i = 1,#str do
      for cy,cells in ipairs(NUMERICAL_DIGITS[tonumber(str:sub(i,i))]) do
         for cx,cell in ipairs(cells) do
            if cell ~= 0 then
               love.graphics.rectangle('fill', x + ((cx-1) * NUMERICAL_DIGIT_SIZE) + ((i-1)*NUMERICAL_DIGIT_SIZE*4),y + ((cy-1) * NUMERICAL_DIGIT_SIZE), NUMERICAL_DIGIT_SIZE,NUMERICAL_DIGIT_SIZE)
            end
         end
      end
   end
end

local function score(direction)
   if direction >= 0 then
      P1.score = P1.score + 1
   else
      P2.score = P2.score + 1
   end

   timer_countdown_elapsed = 0
   resetPlayers()
   resetBall()
   BALL.direction.x = -direction
end

------------------------------

function love.load()
   resetPlayers()
   resetBall()
   BALL.direction.x = 1
end

-- logic
function love.update(dt)
   if game_paused then return end

   if timer_countdown_elapsed < TIMER_COUNTDOWN_SECS then
      timer_countdown_elapsed = timer_countdown_elapsed + dt
      return
   end

   local w,h = love.window.getMode()

   BALL.pos.x = BALL.pos.x + (BALL_SPEED*BALL.direction.x*dt)
   BALL.pos.y = BALL.pos.y + (BALL_SPEED*BALL.direction.y*dt)

   -- walls
   if BALL.pos.y < 0 or
      BALL.pos.y > h-BALL_HEIGHT then
      flipBall('y')
      BALL.pos.y = clamp(BALL.pos.y, 0, h-BALL_HEIGHT)
   end
   -- """goal""""
   if BALL.pos.x < 0 or
      BALL.pos.x > w-BALL_WIDTH then
      score(BALL.direction.x)
      return
      --flipBall('x')
      --BALL.pos.x = clamp(BALL.pos.x, 0, w-BALL_WIDTH)
   end

   -- input --
   -- P1
   P1.input = -int(love.keyboard.isDown(KEY_P1_UP))+int(love.keyboard.isDown(KEY_P1_DOWN))
   P1.pos.y = P1.pos.y + (PADD_SPEED*P1.input*dt)
   P1.pos.y = clamp(P1.pos.y, 0, h-PADD_HEIGHT)
   -- P2
   if not ai then
      -- human
      P2.input = -int(love.keyboard.isDown(KEY_P2_UP))+int(love.keyboard.isDown(KEY_P2_DOWN))
      P2.pos.y = P2.pos.y + (PADD_SPEED*P2.input*dt)
   elseif BALL.pos.x > (w/2)-24 and BALL.direction.x > 0 then
      -- ai
      P2.pos.y = lerp(P2.pos.y, BALL.pos.y - (PADD_HEIGHT/2), 0.05)
   end
   P2.pos.y = clamp(P2.pos.y, 0, h-PADD_HEIGHT)

   -- ball collision --
   -- P1
   if BALL.pos.y + BALL_HEIGHT >= P1.pos.y and
      BALL.pos.y <= P1.pos.y + PADD_HEIGHT then
      local wall = P1.pos.x + PADD_WIDTH
      if BALL.pos.x <= wall and
         BALL.pos.x + (BALL_WIDTH/2) >= P1.pos.x then
         flipBall('x')
         BALL.pos.x = wall
         BALL.direction.y = clamp(BALL.direction.y + (P1.input*0.2), -1, 1)
      end
   end
   -- P2
   if BALL.pos.y + BALL_HEIGHT >= P2.pos.y and
      BALL.pos.y <= P2.pos.y + PADD_HEIGHT then
      if BALL.pos.x + BALL_WIDTH >= P2.pos.x and
         BALL.pos.x <= P2.pos.x + (PADD_WIDTH/2) then
         flipBall('x')
         BALL.pos.x = P2.pos.x - BALL_WIDTH
         BALL.direction.y = clamp(BALL.direction.y + (P2.input*0.2), -1, 1)
      end
   end

   --------------------
   
   -- hold ESC to quit
   if love.keyboard.isDown('escape') then
      timer_quit_elapsed = timer_quit_elapsed + dt
      if timer_quit_elapsed >= TIMER_QUIT_SECS then
         print("pong: Manual exit triggered, no error")
         love.event.quit(0)
      end
   end
end

function love.draw()
   local w,h = love.window.getMode()
   love.graphics.clear(0x20/255, 0x1c/255, 0x18/255)

   -- PAUSE INDICATOR
   if game_paused then
      love.graphics.setColor(1,1,1,0.6)
      for i=0,1 do
         love.graphics.rectangle('fill', 20+(i*24), 20, 12,40)
      end
      love.graphics.setColor(1,1,1,1)
   end

   -- BARS
   love.graphics.setLineWidth(BARS_HEIGHT)
   love.graphics.line(0,0, w,0)
   love.graphics.line(0,h, w,h)
   -- NET
   love.graphics.setLineWidth(PONGNET_WIDTH)
   local pongnet_height = h/PONGNET_COUNT
   for i = 0,PONGNET_COUNT-1 do
      if (i%2) == 0 then
         love.graphics.line(w/2,i*pongnet_height, w/2,(i+1)*pongnet_height)
      end
   end

   -- BALL
   love.graphics.rectangle('fill', BALL.pos.x, BALL.pos.y, BALL_WIDTH, BALL_HEIGHT)

   -- PLAYERS
   love.graphics.rectangle('fill', P1.pos.x, P1.pos.y, PADD_WIDTH, PADD_HEIGHT)
   love.graphics.rectangle('fill', P2.pos.x, P2.pos.y, PADD_WIDTH, PADD_HEIGHT)

   -- SCORES
   drawDigits(P1.score, (w/2) - (#tostring(P1.score)*NUMERICAL_DIGIT_SIZE*4) - (20-NUMERICAL_DIGIT_SIZE), 20)
   drawDigits(P2.score, (w/2)+20, 20)

   ---------------------------------
   ---------------------------------
   -- debug --
   if not debugm then return end
   debugp("P1", 20,20,
      string.format("pos.x=%.2f", P1.pos.x),
      string.format("pos.y=%.2f", P1.pos.y),
      string.format("input=%d",   P1.input))
   debugp("P1", 160,20,
      string.format("pos.x=%.2f", P2.pos.x),
      string.format("pos.y=%.2f", P2.pos.y),
      string.format("input=%d",   P2.input))

   debugp("BALL", 300,20,
      string.format("pos.x=%.2f", BALL.pos.x),
      string.format("pos.y=%.2f", BALL.pos.x),
      string.format("direction.x=%.2f", BALL.direction.x),
      string.format("direction.y=%.2f", BALL.direction.y))
end

function love.keyreleased(key)
   --print(key)
   -- pause
   if key == 'escape' then
      timer_quit_elapsed = 0
      game_paused = not game_paused
   end

   -- toggle P2 AI
   if key == 'space' then
      ai = not ai
   end

   -- debug mode
   if key == 'f3' then
      debugm = not debugm
   end
end
