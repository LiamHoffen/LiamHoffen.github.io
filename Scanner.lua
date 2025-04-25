--!strict

-- changes to script to allow other touchers, but the others won't trigger email

-- boundingBox info set for class area in Aditi
local boundingBoxLow:vector = vector(133, 2, 19)
local boundingBoxHigh:vector = vector(177, 45, 35)
local scanRange:number = 9999

local SEND_MAIL:number = 1
local AGENT_SELECTION:number = AGENT_LIST_PARCEL

local lastToucher: uuid = nil

local birthQueries = {}
local payQueries = {}
local people = {}

local BoundaryLimits = {}
BoundaryLimits.__index = BoundaryLimits

function BoundaryLimits:__tostring()
    --[[  FormatVector is used to get from <1.000000, 2.340000, 3.005000> to <1, 2.34, 3.005> on the coerced output ]]
    local FormatVector = function(v: vector): string
        return "<" .. table.concat({v.x, v.y, v.z}, ", ") .. ">"
    end
    
    return "vecLow=" .. FormatVector(self.vecLow)
            .. "  vecHigh=" .. FormatVector(self.vecHigh)
            .. "  range=" .. tostring(self.range)
end
    
function BoundaryLimits.new(vLow: vector, vHigh: vector, range: number)
    local self = setmetatable({}, BoundaryLimits)
    self.vecLow = vLow
    self.vecHigh = vHigh
    self.range = range
        
    return self
end

function BoundaryLimits:isPointWithinLimits(testPt: vector): boolean
    local isValBetween = function(value: number, min:number, max:number): boolean
        return value >= min and value <= max
    end
    
    local distance = vector.magnitude(ll.GetPos() - testPt)
    
    return distance <= self.range
        and isValBetween(testPt.x, self.vecLow.x, self.vecHigh.x)
        and isValBetween(testPt.y, self.vecLow.y, self.vecHigh.y)
        and isValBetween(testPt.z, self.vecLow.z, self.vecHigh.z)
end


local PersonData = {}
PersonData.__index = PersonData

function PersonData:__tostring(): string
    info1 = { tostring(self.key), self.userName, self.displayName,
            `\nShape: {self.shape}`, `Language: {self.language}`, `Rezzdate: {self.rezzDate}`, `Payinfo: {self.payInfo}`,
            `\nPosition: {self.position}`, `Rotation: {self.rotation}`, `Complexity: {self.complexity}`,
            `\nHover: {self.hover}`, `Height: {self.height}`, `Group tag: {self.group}`,
            }
    return table.concat(info1, ", ")
end

function PersonData.new(key: uuid, uName: string, dName: string, shape: number,
            language: string, pos: vector, rot: vector, weight: number,
            hover: number, height: number, group: string)
    -- Creating a person
    local self = setmetatable({
        key = key,
        userName = uName,
        displayName = dName,
        shape = shape,
        language = language,
        rezzDate = "",
        payInfo = 0,
        position = pos,
        rotation = rot,
        complexity = weight,
        hover = hover,
        height = height,
        group = group,
        }, PersonData)
    return self
end
    
function PersonData:SetRezzDate(rezzDate: string): ()
    self.rezzDate = rezzDate
end
    
function PersonData:SetPayInfo(payInfo: string): ()
    self.payInfo = payInfo
end

function sendInfo(): ()
    local subject = "Visitors in " .. ll.GetParcelDetails(ll.GetPos(),{ PARCEL_DETAILS_NAME })[1]
    
    local answers = {}
    for _, tbl in pairs(people) do
        answers[#answers + 1] = tostring(tbl)
        -- break up output to a record at a time in case the text is too large for a single "say" command
        ll.RegionSayTo(lastToucher, 0, answers[#answers] .. "\n\n")
    end
    
    if lastToucher == ll.GetOwner() then
        ll.MessageLinked(LINK_THIS, SEND_MAIL, table.concat(answers, "\n\n"), subject)
    end
end
    
function scanPeople(): ()
    people = {}
    
    local scannedAvatars = ll.GetAgentList(AGENT_SELECTION, {})
    
    for _, uid in ipairs(scannedAvatars)
    do
        local personDetails = ll.GetObjectDetails(uid, { 
                OBJECT_BODY_SHAPE_TYPE, OBJECT_POS, OBJECT_ROT,
                OBJECT_RENDER_WEIGHT, OBJECT_HOVER_HEIGHT,
                OBJECT_SCALE, OBJECT_GROUP_TAG })

        if bit32.band(ll.GetAgentInfo(uid), AGENT_AUTOMATED) == 0 and rangeLimits:isPointWithinLimits(personDetails[2])
        then
            people[uid] = PersonData.new(uid, ll.GetUsername(uid), ll.GetDisplayName(uid), math.floor(personDetails[1]),
                                        ll.GetAgentLanguage(uid), personDetails[2], ll.Rot2Euler(personDetails[3]) * RAD_TO_DEG,
                                        personDetails[4], math.round(personDetails[5] * 100) / 100.0, 
                                        math.round(personDetails[6].z * 100) / 100.0, personDetails[7])

            birthQueries[ll.RequestAgentData(uid, DATA_BORN)] = uid
            payQueries[ll.RequestAgentData(uid, DATA_PAYINFO)] = uid
        end
    end
end

-- ################   EVENT HANDLERS  ###############
function on_rez(startParam: number): ()
    ll.ResetScript()
end

function touch_start(numDetected: number): ()
    if not lastToucher then
        lastToucher = ll.DetectedKey(0)
        scanPeople()
    else
        ll.RegionSayTo(ll.DetectedKey(0), 0, "Please wait a moment, I'm processing a request from another user")
    end
end

function dataserver(id: uuid, data: string): ()
    if birthQueries[id] then
        people[birthQueries[id]]:SetRezzDate(data)
        birthQueries[id] = nil
    elseif payQueries[id] then
        people[payQueries[id]]:SetPayInfo(data)
        payQueries[id] = nil
    end
    
    if next(birthQueries) == nil and next(payQueries) == nil
    then 
        sendInfo() 
        lastToucher = nil
    end
end


-- ################   INITIALIZATION  ###############

rangeLimits = BoundaryLimits.new(boundingBoxLow, boundingBoxHigh, scanRange)
ll.SetText("Avi Scan Reporter SLua Class 3\nScan Area: " .. tostring(rangeLimits), vector(1,1,0), 1.0)

