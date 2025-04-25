--!strict

local ReportWithoutBroadcast = true
local ShowHoverText = false

local listenerSideLength = 12
local listenerHeight = 2.5

local classBoxLow:vector = vector(133, 2, 19)
local classBoxHigh:vector = vector(177, 45, 35)

local listeningLimits
local classroomLimits

local SEND_MAIL:number = 1
local AGENT_SELECTION:number = AGENT_LIST_PARCEL

local lastToucher: uuid = nil

local birthQueries = {}
local payQueries = {}
local people = {}

local BoundaryLimits = {}
BoundaryLimits.__index = BoundaryLimits

function BoundaryLimits:__tostring()
    local FormatVector = function(v: vector): string
        return "<" .. table.concat({string.format("%0.3f", v.x), 
                                    string.format("%0.3f", v.y),
                                    string.format("%0.3f", v.z) }, ", ") .. ">"
    end
    
    return "vecHigh=" .. FormatVector(self.vecHigh) .. "\n"
            .. "vecLow=" .. FormatVector(self.vecLow)
end
    
function BoundaryLimits.new(vLow: vector, vHigh: vector, range: number)
    local self = setmetatable({}, BoundaryLimits)
    self.vecLow = vLow
    self.vecHigh = vHigh
    self.range = range
        
    return self
end

function BoundaryLimits:isPointWithinLimits(testPt: vector, speakerPos: vector): boolean
    local isValBetween = function(value: number, min:number, max:number): boolean
        return value >= min and value <= max
    end
    
    return (not speakerPos or ll.VecDist(testPt, speakerPos) > 20.0)
        and isValBetween(testPt.x, self.vecLow.x, self.vecHigh.x)
        and isValBetween(testPt.y, self.vecLow.y, self.vecHigh.y)
        and isValBetween(testPt.z, self.vecLow.z, self.vecHigh.z)
end


function ProcessMessaging(speaker: uuid, msg: string, speakerPos: vector): ()
    local oldObjectName = ll.GetObjectName()
    ll.SetObjectName(ll.Key2Name(speaker))

    people = {}
    
    local scannedAvatars = ll.GetAgentList(AGENT_SELECTION, {})
    
    for _, uid in ipairs(scannedAvatars)
    do
        local personDetails = ll.GetObjectDetails(uid, { OBJECT_POS })
        if classroomLimits:isPointWithinLimits(personDetails[1], speakerPos) then
            if ReportWithoutBroadcast then
                ll.OwnerSay(ll.Key2Name(uid) .. ": " .. msg)
            else
                ll.RegionSayTo(uid, 0, msg)
            end
        end
    end
    
    ll.SetObjectName(oldObjectName)
end

local function initialize()

    local listLow = ll.GetPos() + vector(-listenerSideLength, -listenerSideLength, -listenerHeight)
    local listHigh = ll.GetPos() + vector(listenerSideLength, listenerSideLength, listenerHeight)
    listeningLimits = BoundaryLimits.new(listLow, listHigh)

    classroomLimits = BoundaryLimits.new(classBoxLow, classBoxHigh)
    
    local text = if ShowHoverText then "Class Room Repeater\nScan Area: " .. tostring(listeningLimits) else ""
    ll.SetText(text, vector(1,1,0), 1.0)

    ll.Listen(0, "", NULL_KEY, "")
end

-- ################   EVENT HANDLERS  ###############
function on_rez(startParam: number): ()
    ll.ResetScript()
end
   
function changed(change: number): ()
    if bit32.btest(change, bit32.bor(CHANGED_REGION, CHANGED_REGION_START, CHANGED_OWNER)) then
    end
end

function listen(channel: number, name: string, uid: uuid, msg: string): ()
    local info = ll.GetObjectDetails(uid, { OBJECT_POS } )
    if listeningLimits:isPointWithinLimits(info[1]) then
        ProcessMessaging(uid, msg, info[1])
    end
end

-- ################   INITIALIZATION  ###############
initialize()
