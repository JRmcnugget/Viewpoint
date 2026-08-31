local camControllerSettings = {}

-- -- ⚙️ SETTINGS
-- -- anything not local are defaults which can be overwritten by external scripts

-- -- debugHUD integration
camControllerSettings.debugger = game.ReplicatedStorage:FindFirstChild("DebugMenu")

-- -- camera
camControllerSettings.ignoreTag = "CameraIgnore"
camControllerSettings.shouldIgnoreOtherPlrs = true

-- sensitivity
camControllerSettings.cameraSensitivityX = 0.5
camControllerSettings.cameraSensitivityY = 0.5
camControllerSettings.zoomSens = 2.25
camControllerSettings.zoomSenseMobile = 0.85

-- zoom
camControllerSettings.zoomInverted = true
camControllerSettings.cameraZoom = 15
camControllerSettings.zoomAbsoluteMin = 0.5

camControllerSettings.zoomMax = 100
camControllerSettings.zoomMin = 12
camControllerSettings.zoomMaxLocked = 9
camControllerSettings.zoomMinLocked = 5

camControllerSettings.zoomSmoothBaseSpd = 10
camControllerSettings.zoomSpdIn = 1.1
camControllerSettings.zoomSpdOut = 1.3

-- freeroam / shift lock
camControllerSettings.cameraIsFreeroam = true

camControllerSettings.cameraFreeRoamThres = 2

-- horizontal settings
camControllerSettings.cameraInvertedHorizontal = true
camControllerSettings.cameraSmoothingHorizontalEnabled = true

camControllerSettings.cameraHorizontalOffsetShiftLock = 3.8

camControllerSettings.cameraHorizontalMinSpd = 0.12
camControllerSettings.cameraHorizontalMaxDistFreeroam = 6
camControllerSettings.cameraHorizontalMaxDistLocked = 3

camControllerSettings.cameraHorizontalFreeroamRadial = 1
camControllerSettings.cameraHorizontalFreeroamSpd = 0.5
camControllerSettings.cameraHorizontalFreeroamSpdDistInc = 0.1

camControllerSettings.cameraHorizontalLockedRadial = 0.5
camControllerSettings.cameraHorizontalLockedSpd = 0.3
camControllerSettings.cameraHorizontalLockedSpdDistInc = 0.25

camControllerSettings.cameraHorizontalPredict = false

-- vertical settings
camControllerSettings.cameraInvertedY = true
camControllerSettings.cameraSmoothingYEnabled = true

camControllerSettings.cameraYOffsetFreeRoam = 3.5
camControllerSettings.cameraYOffsetShiftLock = 3

camControllerSettings.cameraYSpdMax = 0.65
camControllerSettings.cameraYSpdMin = 0.05

camControllerSettings.cameraYGrndSpdBase = 0.2

camControllerSettings.cameraYAsnSpdBase = 0.35
camControllerSettings.cameraYAsnSpdInc = 0.008

camControllerSettings.cameraYDsnSpdBase = 0.4
camControllerSettings.cameraYDsnSpdInc = 0.005

camControllerSettings.cameraYUpThres = 10
camControllerSettings.cameraYDownThres = 3.5
camControllerSettings.cameraLockedYUpThres = 9
camControllerSettings.cameraLockedYDownThres = 2

camControllerSettings.cameraYMaxDistUp = 10
camControllerSettings.cameraYMaxDistDown = 8
camControllerSettings.cameraLockedYMaxDistUp = 9
camControllerSettings.cameraLockedYMaxDistDown = 5

-- -- player
-- smoothing speeds
camControllerSettings.playerLookAtSpd = 8
camControllerSettings.playerLookAtSpdLocked = 20
camControllerSettings.playerInvisSmoothSpd = 15

-- distance invisibility
camControllerSettings.plrInvisThreshold = 6
camControllerSettings.plrFullInvisThreshold = 3
camControllerSettings.plrInvisMax = 0.99
camControllerSettings.plrInvisMin = 0

camControllerSettings.useInvisHighlight = true
camControllerSettings.invisHighlightFillMin = 0.8
camControllerSettings.invisHighlightOutlineMin = 0.4
camControllerSettings.invisHighlightMax = 1

-- -- cameraRoot
camControllerSettings.rootOccludedSpd = 40
camControllerSettings.rootOccludeRetrunSpd = 15
camControllerSettings.rootOccludeForgetThres = 0.2

return camControllerSettings