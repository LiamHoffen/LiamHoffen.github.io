--[[ This poll board expects users to touch the face of a prim in a position indicated as a
        land mass.  Or, if the owner is touching the board, touching were there is no land mass
        will trigger report generation.
        
    The texture is to be displayed on face 1 of the prim, and touches on that face will be
    evaluated.
    
    If you wish to use a different face for the texture display, modify the local var named mapFace
]]

--[[
Assumption: more code execution is spent processing land mass touches than in processing reports
Reaction: try to develop code for less looping across array tables and more direct access when processing user touches
            To facilitate this, elements in the LandMasses are referenced by name because the touch location is a named value

Assumption: the order of the data output in the report is important
Reaction: provide just an array of land mass names in the desired reporting order.  Traverse this list, in index order, to
            generate the output information to the owner.
            Although the LandMasses table could have been an array of classes to help set ordering, that would have turned every
            touch operation into a loop, traversing the list to find the matching land mass name.
            
Problem: My lack of understanding of the metatables and class construction has resulted in a very weak class definition that seems prone to breaking.
            There has to be something wrong with my thinking about classes and the metatable that leads to this messy definition.
            Requires more explanation (further SLua classes) to resolve my misconceptions.
]]

local LandNames = {}    -- array of names of the land masses
local LandMasses = {}   -- dictionary of landmasses / land definitions (touch point limits and times selected)
local UserInfo = {}     -- dictionary of user UUIDs and the name of the touched land mass

local displayTexture = uuid("ef5a395c-af33-accd-ea11-b5f0040dbc49")
local mapFace = 1
local doAsserts = true

local ME

local Locations

Locations = {
    __tostring = function(self): string
        return `{self.minTP}, {self.maxTP}, {self.timesSelected}`
    end,

    --[[ prefer to keep class functions inside class, using the <fnname> = function format ]]
    new = function(minVec: vector, maxVec: vector)
        if (doAsserts) then
            assert(typeof(minVec) == "vector", "You must provide a vector as the 1st argument for the lower left coordinates of the touch point for a Location")
            assert(typeof(maxVec) == "vector", "You must provide a vector as the 2st argument for the upper right coordinates of the touch point for a Location")
        end
        
        local self = setmetatable({}, Locations)

        self.minTP = minVec
        self.maxTP = maxVec
        self.timesSelected = 0
        return self
    end,
    
    --[[ prefer to keep class functions inside class, using the <fnname> = function format ]]
    isTouched = function(self, testPt: vector): boolean
        if (doAsserts) then
            assert(typeof(self) == "table", "You must use the colon operator to access the isTouched method of a Location data type")
            assert(typeof(testPt) == "vector", "You must provide a vector as the argument to the isTouched method of a Location data type")
        end
        local isValBetween = function(value: number, min: number, max: number): boolean
            return value >= min and value <= max
        end
            
        return isValBetween(testPt.x, self.minTP.x, self.maxTP.x) and isValBetween(testPt.y, self.minTP.y, self.maxTP.y)
    end,
}

Locations.__index = Locations

--[[ ElementCount is a simple utility to assist the assertion during initialization. ]]
local function ElementCount(tbl): number
    local count = 0
    local key = next(tbl)
    
    while key do
        count += 1
        key = next(tbl, key)
    end
    return count
end


local function infoOwner()
    local messages = { "Here are the results of the poll:" }
    
    for idx, landName in ipairs(LandNames) do
        messages[idx] = landName .. ": " .. tostring(LandMasses[landName].timesSelected)
    end
    
    ll.OwnerSay(table.concat(messages, "\n"))
end


--[[ Work out where the touch occurred.  This routine is called by selectOption ]]
local function findOption(tpVec: vector): string | nil
    for name, landmass in pairs(LandMasses) do
        if landmass.isTouched(landmass, tpVec) then 
            return name
        end
    end
    return nil
end
        
--[[ selectOption is called from the touch_start event handler ]]
local function selectOption(toucher, tpVec: vector)
    local thisSelection = findOption(tpVec)
    local messages = {}
    local lastOption

    if UserInfo[toucher] and (thisSelection or toucher ~= ME) then
        messages[1] = " Previously you had selected " .. UserInfo[toucher] .. "."
        LandMasses[UserInfo[toucher]].timesSelected -= 1
        UserInfo[toucher] = nil
    end
    
    if thisSelection then
        table.insert(messages, 1, "You have selected " .. thisSelection .. ".")
        UserInfo[toucher] = thisSelection
        
        LandMasses[thisSelection].timesSelected += 1
    elseif toucher ~= ME then
        table.insert(messages, 1, "You haven't selected any place, please touch on a continent or on the earth.")
    else
        messages = {}
        infoOwner()
    end
    if messages[1] then
        ll.RegionSayTo(toucher, 0, table.concat(messages, "\n"))
    end
end

--[[ ********************* Event Handlers ********************* ]]
function touch_start(total_number)
    for num = 0, total_number - 1 do
        local touchedFace = ll.DetectedTouchFace(num)
        if (touchedFace == mapFace) then
            local touchIndex = ll.DetectedTouchST(num)
            selectOption(ll.DetectedKey(num), vector(touchIndex.x, 1 - touchIndex.y, 0))
        end
    end
end

function changed(change: number)
    if bit32.btest(change, bit32.bor(CHANGED_OWNER, CHANGED_INVENTORY)) then
        ME = ll.GetOwner()
    end
end


--[[ ********************* Initialization ********************* ]]
LandNames = { "NORTH AMERICA", "SOUTH AMERICA", "EUROPE", "AFRICA", "ASIA", "OCEANIA", "EARTH" }

LandMasses = {
    [LandNames[1]] = Locations.new(vector(0.024, 0.247, 0), vector(0.306, 0.651, 0)),
    [LandNames[2]] = Locations.new(vector(0.166, 0.667, 0), vector(0.285, 0.989, 0)),
    [LandNames[3]] = Locations.new(vector(0.318, 0.296, 0), vector(0.496, 0.552, 0)),
    [LandNames[4]] = Locations.new(vector(0.331, 0.572, 0), vector(0.494, 0.899, 0)),
    [LandNames[5]] = Locations.new(vector(0.506, 0.355, 0), vector(0.787, 0.775, 0)),
    [LandNames[6]] = Locations.new(vector(0.795, 0.717, 0), vector(0.929, 0.956, 0)),
    [LandNames[7]] = Locations.new(vector(0.789, 0.000, 0), vector(1.000, 0.389, 0)),
}

--[[ Since the data structure requires 2 parts to be defined, I want to assert that I have
        a matching number of elements in the 2 primary data structures ]]
assert(#LandNames == ElementCount(LandMasses), 
        "The number of named lands(" .. tostring(#LandNames) 
        .. ") must match the number of land mass definitions(" 
        .. tostring(ElementCount(LandMasses)) .. ")")

ME = ll.GetOwner()
ll.SetTexture(TEXTURE_BLANK, ALL_SIDES)
ll.SetTexture(displayTexture, mapFace)
