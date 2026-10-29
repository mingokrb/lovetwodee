local BAR_HEIGHT = 24

local BAR_MENUS = {
   { name = "Difficulty", options = {
      "Easy", "Medium", "Hard", "EXTREME"
   }}
}

-----------------------

local TopBar = {}

function TopBar.draw()
   local w,h = love.window.getMode()
   love.graphics.setColor(0.5,0.5,0.51)

   love.graphics.rectangle('fill', 0,0, w,BAR_HEIGHT)
   local mx,my = love.mouse.getPosition()

   --for s,submenu in pairs(BAR_MENUS) do
   --   local sx,sy = 8 + (i-1)*BAR_MENUS,8
   --end
   
   love.graphics.setColor(1,1,1)
end

return TopBar
