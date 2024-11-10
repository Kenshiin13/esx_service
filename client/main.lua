RegisterNetEvent("esx_service:notifyAllInService", function(notifyMessage, src)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(src))
    local mugshot, mugshotStr = ESX.Game.GetPedMugshot(targetPed)

    ESX.ShowAdvancedNotification(notifyMessage.title, notifyMessage.subject, notifyMessage.msg, mugshotStr, notifyMessage.iconType)
    UnregisterPedheadshot(mugshot)
end)
