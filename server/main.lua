---@class ServiceNotification
---@field title string
---@field subject string
---@field msg string
---@field iconType number

---@param serviceNotification unknown
local function isServiceNotification(serviceNotification)
    if type(serviceNotification) ~= "table" then
        return false
    end
    if type(serviceNotification.title) ~= "string" then
        return false
    end
    if type(serviceNotification.subject) ~= "string" then
        return false
    end
    if type(serviceNotification.msg) ~= "string" then
        return false
    end
    if type(serviceNotification.iconType) ~= "number" then
        return false
    end

    return true
end

---@param src number
---@param onDuty boolean
---@param serviceName string
---@return nil
local function setPlayerJobDuty(src, onDuty, serviceName)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return
    end

    local currentJob = xPlayer.getJob()

    if currentJob.name ~= serviceName then
        return
    end

    xPlayer.setJob(currentJob.name, currentJob.grade, onDuty)
end


---@class Service
---@field serviceName string
---@field maxPlayers number
---@field players table<number, boolean>
---@field new fun(self:Service, serviceName: string, maxPlayers: number): Service
---@field getPlayerCount fun(self:Service): number
---@field getPlayers fun(self:Service): table<number, boolean>
---@field addPlayer fun(self:Service, src: number, force:boolean): boolean
---@field removePlayer fun(self:Service, src: number): nil
---@field hasPlayer fun(self:Service, src: number): boolean
---@field notifyAll fun(self:Service, serviceNotification: ServiceNotification, src: number): nil
local Service = {}
Service.__index = Service

---@type table<string, Service>
local services = {}

function Service:new(serviceName, maxPlayers)
    if services[serviceName] then
        return services[serviceName]
    end

    local obj = setmetatable({}, self)
    obj.serviceName = serviceName
    obj.maxPlayers = maxPlayers
    obj.players = {}
    GlobalState[serviceName] = 0

    return obj
end

function Service:getPlayerCount()
    return ESX.Table.SizeOf(self.players)
end

function Service:getPlayers()
    return self.players
end

function Service:addPlayer(src, force)
    if self:hasPlayer(src) then
        return true
    end

    local servicePlayerCount = self:getPlayerCount()
    if not force then
        if servicePlayerCount >= self.maxPlayers then
            return false
        end
    end

    self.players[src] = true
    GlobalState[self.serviceName] = servicePlayerCount + 1
    setPlayerJobDuty(src, true, self.serviceName)

    return true
end

function Service:removePlayer(src)
    if self:hasPlayer(src) then
        self.players[src] = nil
        GlobalState[self.serviceName] = self:getPlayerCount()
        setPlayerJobDuty(src, false, self.serviceName)
    end
end

function Service:hasPlayer(src)
    return self.players[src] or false
end

function Service:notifyAll(serviceNotification, src)
    local targets = {}
    for targetSrc, _ in pairs(self.players) do
        if src ~= targetSrc then
            table.insert(targets, targetSrc)
        end
    end

    ESX.TriggerClientEvent("esx_service:notifyAllInService", targets, serviceNotification, src)
end

---@param serviceName string
---@param maxPlayers number
AddEventHandler("esx_service:activateService", function(serviceName, maxPlayers)
    if type(serviceName) ~= "string" then
        print(("[^3WARNING^7] Attempted To Activate Service With Invalid Name - ^5%s^7"):format(serviceName))
        return
    end
    if services[serviceName] then
        print(("[^3WARNING^7] Attempted To Activate Service That Is Already Active - ^5%s^7"):format(serviceName))
        return
    end
    if type(maxPlayers) ~= "number" or maxPlayers <= 0 then
        print(("[^3WARNING^7] Attempted To Activate Service With Invalid Max Players - ^5%s^7"):format(maxPlayers))
        return
    end

    services[serviceName] = Service:new(serviceName, maxPlayers)
end)

---@param src number
---@param cb function
---@param serviceName string
ESX.RegisterServerCallback("esx_service:enableService", function(src, cb, serviceName)
    local service = services[serviceName]
    if not service then
        print(("[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7"):format(serviceName))
        return
    end

    local servicePlayerCount = service:getPlayerCount()
    local success = service:addPlayer(src, false)

    cb(success, service.maxPlayers, servicePlayerCount)
end)

---@param serviceName string
RegisterNetEvent("esx_service:disableService", function(serviceName)
    ---@type number
    local src <const> = source

    local service = services[serviceName]
    if not service then
        print(("[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7"):format(serviceName))
        return
    end

    service:removePlayer(src)
end)

---@param src number
---@param cb function
---@param serviceName string
ESX.RegisterServerCallback("esx_service:isInService", function(src, cb, serviceName)
    local service = services[serviceName]
    if not service then
        print(("[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7"):format(serviceName))
        return
    end

    cb(service:hasPlayer(src))
end)

---@param src number
---@param cb function
---@param serviceName string
---@param targetSrc number
ESX.RegisterServerCallback("esx_service:isPlayerInService", function(src, cb, serviceName, targetSrc)
    if type(targetSrc) ~= "number" then
        print(("[^3WARNING^7] Attempted To Get Service With Invalid Target Source - ^5%s^7"):format(targetSrc))
        return
    end

    local service = services[serviceName]
    if not service then
        print(("[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7"):format(serviceName))
        return
    end

    cb(service:hasPlayer(targetSrc))
end)

---@param src number
---@param cb function
---@param serviceName string
ESX.RegisterServerCallback("esx_service:getInServiceList", function(src, cb, serviceName)
    local service = services[serviceName]
    if not service then
        print(("[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7"):format(serviceName))
        return
    end

    cb(service:getPlayers())
end)

---@param serviceNotification ServiceNotification
---@param serviceName string
---@param src number
AddEventHandler("esx_service:notifyAllInService", function(serviceNotification, serviceName, src)
    if not isServiceNotification(serviceNotification) then
        print(("[^3WARNING^7] Attempted To Notify Service With Invalid Notification - ^5%s^7"):format(json.encode(serviceNotification)))
        return
    end

    local service = services[serviceName]
    if not service then
        print(("[^3WARNING^7] Attempted To Use Inactive Service - ^5%s^7"):format(serviceName))
        return
    end

    service:notifyAll(serviceNotification, src)
end)

---@param src number
---@param reason string
AddEventHandler("esx:playerDropped", function(src, reason)
    for _, service in pairs(services) do
        if service:hasPlayer(src) then
            service:removePlayer(src)
        end
    end
end)

---@param src number
---@param job table
---@param lastJob table
AddEventHandler("esx:setJob", function(src, job, lastJob)
    local lastJobService = services[lastJob.name]
    if lastJobService and lastJob.onDuty then
        lastJobService:removePlayer(src)
    end

    local currentJobService = services[job.name]
    if currentJobService and job.onDuty then
        currentJobService:addPlayer(src, true)
    end
end)

---@param src number
---@param xPlayer table
---@param isNew boolean
AddEventHandler("esx:playerLoaded", function(src, xPlayer, isNew)
    local playerJob = xPlayer.getJob()
    local jobService = services[playerJob.name]

    if jobService and playerJob.onDuty then
        jobService:addPlayer(src, true)
    end
end)
