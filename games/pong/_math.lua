function clamp(v, min, max)
   return math.min(math.max(v, min), max)
end

function int(v)
   if type(v) == 'boolean' then
      return v and 1 or 0
   end
   -- return capped string len (empty = 0)
   if type(v) == 'string' then
      return math.min(#v,1)
   end
   return 0
end

function lerp(a,b,t)
   return a+(b-a)*t
end

-------------------------

function randomDirection(float)
   local sign = math.floor(math.random()*2) == 0 and -1 or 1
   if float then
      return math.random()*sign
   end
   return sign
end

