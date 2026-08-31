local replitStorage = game.ReplicatedStorage
local plr = game.Players.LocalPlayer

local controller = require(replitStorage.Viewpoint.CameraController)

controller:Init(plr)