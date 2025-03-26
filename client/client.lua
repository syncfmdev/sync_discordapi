CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    TriggerServerEvent('sync_discord:playerConnected')
end)