local replitStorage = game.ReplicatedStorage
local plr = game.Players.LocalPlayer

local controller = require(replitStorage.CameraController)

controller:Init(plr)