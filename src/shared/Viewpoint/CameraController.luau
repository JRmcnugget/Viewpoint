-- {[ Viewpoint Module ]}
-- ver 0.82.0
-- By josiahgame/JRmcnugget

-- pwease do not look at me! i am unfinished, owo

local root = script.Parent
local libs = root.Library
local settings = require(root:FindFirstChild("Settings"))
local utils = require(libs:FindFirstChild("Utils"))

local camController = {}

camController.IsInitialized = false

camController.debugRender = false

local players = game:GetService("Players")
local userInput = game:GetService("UserInputService")
local collectionServ = game:GetService("CollectionService")
local runServ = game:GetService("RunService")
local tweenServ = game:GetService("TweenService")
local world = workspace

local cameraOcclusionForcedZoom = nil
local cameraTarget = CFrame.new(0, 0, 0)
local actionPerformTick = os.clock() - settings.cameraFreeRoamThres
local mouseRayDistance = 5000

--player
local player = nil
local playerCharacter = nil
local playerHRP = nil
local playerIsDead = false
local playerHumanoid = nil
local playerParts = {}

local playerIsPinching = nil

local playerInstancingConnections = {}

--camera
local camera = nil
local cameraRoot = nil
local cameraRootDebugOutline = nil

local cameraYRotCap = 75
local cameraY = 0
local cameraYLastGroundedPos = 0
local cameraYVel = 0
local cameraYSpd = 0
local cameraYExitedBounds = false

local cameraRotX = 0
local cameraRotY = 0
local cameraRotCF = CFrame.new(0, 0, 0)

local cameraHorizontalPos = Vector3.new(0, 0, 0)
local cameraHorizontalVel = Vector3.new(0, 0, 0)

local cameraColliderRadius = 0.15
local cameraRootColliderRadius = 0.5
-- for whatever reason, even though the sphere should be perfectly flush against the surface from a spherecast, it somehow catches lower ceilings of parts that form a uniform surface and etc. for whatever reason it is somehow slightly IN the surface
-- really does not make any sense, maybe floating point issue? regardless, the solution is to pull it back inward and out of the surface
-- shouldn't really be touched.
local cameraRootCollideDistScale = 0.99
local cameraRootOccluded = nil

local zoomSmooth = settings.cameraZoom

local invisHighlight = nil

local cameraMouseLocked = true
local cameraOverride = false

--occlusion check params
local rayParams = RaycastParams.new()
local rayExclude = {}
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true

if settings.debugger then
	debugger = require(settings.debugger)
end

--init
function camController:Init(plr)
	player = plr

	self:instanceNewPlayer(plr)

	for c, i in pairs(players:GetPlayers()) do
		if i ~= plr then
			self:instanceNewPlayer(i)
		end
	end

	players.PlayerAdded:Connect(function(player)
		self:instanceNewPlayer(player)
	end)

	userInput.InputBegan:Connect(function(input, processed)
		self:readInput(input, processed)
	end)
	userInput.InputChanged:Connect(function(input, processed)
		self:readInput(input, processed)
	end)
	userInput.InputEnded:Connect(function(input, processed)
		self:readInput(input, processed)
	end)
	userInput.TouchPinch:Connect(function(pos, scale, vel, inputstate, processed)
		local falseInput = {
			touchPositions = pos,
			scale = scale,
			velocity = vel,
			state = inputstate,
			gameProcessedEvent = processed
		}
		self:handleZoom(true, false, falseInput)
	end)

	local alreadyTagged = collectionServ:GetTagged(settings.ignoreTag)
	for c, i in pairs(alreadyTagged) do
		table.insert(rayExclude, i)
	end

	collectionServ:GetInstanceAddedSignal(settings.ignoreTag):Connect(function(obj)
		self:instanceNew(obj)
	end)
	collectionServ:GetInstanceRemovedSignal(settings.ignoreTag):Connect(function(obj)
		self:instanceRemove(obj)
	end)

	runServ:BindToRenderStep("updCamera", Enum.RenderPriority.Camera.Value, function(dt)
		self:updateCam(dt)
	end)

	if debugger then
		debugger:Init(plr)
		debugger:createWatcher("cameraRootPos", function()
			return string.format(
				"%.2f, %.2f, %.2f",
				cameraRoot.Position.X,
				cameraRoot.Position.Y,
				cameraRoot.Position.Z
			)
		end)
		debugger:createWatcher("cameraIsFreeroam", function()
			return settings.cameraIsFreeroam
		end)
		debugger:createWatcher("cameraMouseLocked", function()
			return cameraMouseLocked
		end)
		debugger:createWatcher("cameraZoom", function()
			return settings.cameraZoom
		end)
		debugger:createWatcher("cameraOcclusionForcedZoom", function()
			return cameraOcclusionForcedZoom
		end)
		debugger:createWatcher("cameraExccededYBounds", function()
			return cameraYExitedBounds
		end)
	end
end

--main
function camController:updateCam(dt)
	if self.IsInitialized then
		self:createCamTarget() -- create camera reference to avoid issues with using real camera's position with interpolation

		self:updateCamRoot(dt)

		camera.CFrame = self:createCameraFinal(dt)

		self:applyInvis(dt)

		self:playerLookAt(dt)

		self:debugRenderer()
	end
end

--methods
function camController:instanceNewPlayer(plr)
	local localPlrCheck = plr == player
	local instanceWatcher = nil
	plr.CharacterAdded:Connect(function(char)
		local loaded = plr:HasAppearanceLoaded()

		while not loaded do
			--if char.Parent ~= world then return end
			loaded = plr:HasAppearanceLoaded()
			task.wait()
		end

		if localPlrCheck then
			playerIsDead = false

			playerCharacter = char
			playerHumanoid = char:WaitForChild("Humanoid")
			playerHRP = char:WaitForChild("HumanoidRootPart")
			camera = world.CurrentCamera

			cameraRoot = Instance.new("Part")
			cameraRoot.Parent = playerCharacter
			cameraRoot.Anchored = true
			cameraRoot.CanCollide = false
			cameraRoot.CanTouch = false
			cameraRoot.CanQuery = false
			cameraRoot.Name = "CameraRoot"
			cameraRoot.Position = Vector3.new(playerHRP.Position.X, playerHRP.Position.Y, playerHRP.Position.Z)
			cameraRoot.Transparency = 1
			cameraRoot.CastShadow = false
			cameraRoot.Size = Vector3.new(1, 1, 1)
			cameraRoot.Material = Enum.Material.Plastic
			cameraRoot.Color = Color3.fromRGB(255, 255, 255)

			cameraRootDebugOutline = Instance.new("SelectionSphere")
			cameraRootDebugOutline.Color3 = Color3.fromRGB(255, 255, 255)
			cameraRootDebugOutline.Adornee = cameraRoot
			cameraRootDebugOutline.Parent = cameraRoot
			cameraRootDebugOutline.Transparency = 1

			cameraY = playerHRP.Position.Y + settings.cameraYOffsetFreeRoam
			cameraHorizontalPos = utils:getHorizontalDir(playerHRP.Position)
			cameraYLastGroundedPos = cameraY

			invisHighlight = Instance.new("Highlight")
			invisHighlight.Parent = playerCharacter
			invisHighlight.FillColor = Color3.fromRGB(255, 255, 255)
			invisHighlight.FillTransparency = 1
			invisHighlight.OutlineTransparency = 1

			playerHumanoid.Died:Connect(function()
				playerIsDead = true
			end)
			camera.CameraSubject = cameraRoot
			camera.CameraType = Enum.CameraType.Scriptable
			rayParams.FilterDescendantsInstances = rayExclude
			userInput.MouseBehavior = Enum.MouseBehavior.LockCenter

			table.clear(playerParts) -- remove stale references
		end

		--instance all playerparts that are added upon the character's immediate creation
		for c, i in pairs(char:GetDescendants()) do
			if i.ClassName == "MeshPart" or i.ClassName == "Part" then
				if localPlrCheck then
					table.insert(playerParts, i)
				elseif not settings.shouldIgnoreOtherPlrs then
					break
				end
				i:AddTag(settings.ignoreTag)
			end
		end

		--instance any parts that are added further to the character
		instanceWatcher = char.DescendantAdded:Connect(function(obj)
			if obj:IsA("BasePart") then
				if localPlrCheck then
					table.insert(playerParts, obj)
				elseif not settings.shouldIgnoreOtherPlrs then
					return
				end
				obj:AddTag(settings.ignoreTag)
			end
		end)
		table.insert(playerInstancingConnections, instanceWatcher) -- does not automatically disconnect so we have to keep track

		if localPlrCheck then
			self.IsInitialized = true
		end
	end)

	player.CharacterRemoving:Connect(function(char)
		if localPlrCheck then
			self.IsInitialized = false

			playerCharacter = nil
			playerHumanoid = nil
			playerHRP = nil
			camera = nil

			if cameraRoot then
				cameraRoot:Destroy()
				cameraRoot = nil
			end
		end

		local pos = table.find(playerInstancingConnections, instanceWatcher)
		if pos then table.remove(playerInstancingConnections, pos) end
	end)
end

function camController:createCameraFinal(dt)
	local occluded = self:checkOcclusion()
	local max = settings.cameraIsFreeroam and settings.zoomMax or settings.zoomMaxLocked
	local zoomAmount = math.clamp((occluded and cameraOcclusionForcedZoom or settings.cameraZoom), settings.zoomAbsoluteMin, max) -- if occluded, use occluded zoom, else use user zoom. capped from first person zoom and max camera zoom
	local isZoomOut = (zoomAmount > zoomSmooth) and true or false -- if player zoom is bigger than zoomSmooth they are zoooming out (as zoomSmooth will trail behind due to lerp)
	local zoomSmoothSpd = not isZoomOut and settings.zoomSmoothBaseSpd * settings.zoomSpdIn or settings.zoomSmoothBaseSpd * settings.zoomSpdOut -- if camera is in first person, use the first person zoom speed. else, if player is not zooming out use zoominspeed, if zooming out use zoomout speed
	zoomSmooth = (not occluded or isZoomOut or (not settings.cameraIsFreeroam and zoomSmooth > max))
			and utils:lerp(zoomSmooth, zoomAmount, zoomSmoothSpd, dt)
		or zoomAmount -- if camera is not occluded or not zooming out, or the camera is forced first person, use lerp, otherwise snap to zoomamount without lerp. allows the camera to smooth out in all situations

	local cameraSmoothOffset = cameraRotCF * Vector3.new(0, 0, zoomSmooth)
	return CFrame.new(cameraRoot.Position + cameraSmoothOffset, cameraRoot.Position)
end

function camController:updateCamRoot(dt)
	if not playerIsDead then
		local freeroamCheck = (settings.cameraIsFreeroam or utils:isSeated(playerHumanoid))

		-- desiredPosition calculation
		local radial = freeroamCheck and settings.cameraHorizontalFreeroamRadial or settings.cameraHorizontalLockedRadial
		local baseSpd = freeroamCheck and settings.cameraHorizontalFreeroamSpd or settings.cameraHorizontalLockedSpd
		local spdIncrement = freeroamCheck and settings.cameraHorizontalFreeroamSpdDistInc
			or settings.cameraHorizontalLockedSpdDistInc
		local maxDist = freeroamCheck and settings.cameraHorizontalMaxDistFreeroam or settings.cameraHorizontalMaxDistLocked

		self:updateRootHorizontal(dt, radial, baseSpd, spdIncrement, maxDist)

		local offset = math.abs(freeroamCheck and settings.cameraYOffsetFreeRoam or settings.cameraYOffsetShiftLock)
		local rootTargetY = playerHRP.Position.Y + offset

		self:updateRootY(dt, rootTargetY)

		local targetHorizontal = freeroamCheck and cameraHorizontalPos
			or cameraHorizontalPos + (cameraRotCF.RightVector * settings.cameraHorizontalOffsetShiftLock)
		local desiredPos = Vector3.new(targetHorizontal.X, cameraY, targetHorizontal.Z)

		-- occlusion checking
		local finalPos = self:updateRootOcclusion(dt, desiredPos, offset)

		cameraRoot.Position = finalPos
	end
end

function camController:updateRootHorizontal(dt, radial, baseSpd, spdInc, maxDist)
	local hrpPos = utils:getHorizontalDir(playerHRP.Position)
	if settings.cameraSmoothingHorizontalEnabled then
		local dir = (hrpPos - cameraHorizontalPos)
		if dir then
			local target
			local dist = 0

			if dir.Magnitude > maxDist then
				dist = (dir.Magnitude - maxDist)
				cameraHorizontalPos = cameraHorizontalPos + (dir.Unit * dist)
			end

			if dir.Magnitude > radial then
				dist = (dir.Magnitude - radial)
				target = cameraHorizontalPos + (dir.Unit * dist)
			end

			if not target then
				target = cameraHorizontalPos
			end

			local spd = math.clamp(baseSpd - math.abs(dist * spdInc), settings.cameraHorizontalMinSpd, baseSpd)

			cameraHorizontalPos, cameraHorizontalVel =
				tweenServ:SmoothDamp(cameraHorizontalPos, target, cameraHorizontalVel, spd, nil, dt)
		end
	else
		cameraHorizontalPos = hrpPos
	end
end

function camController:updateRootY(dt, targetY)
	local isGrounded = utils:isGrounded(playerHumanoid)

	if settings.cameraSmoothingYEnabled then
		local YUpThres = settings.cameraIsFreeroam and settings.cameraYUpThres or settings.cameraLockedYUpThres
		local YDownThres = settings.cameraIsFreeroam and settings.cameraYDownThres or settings.cameraLockedYDownThres
		local YBoundsUp = cameraYLastGroundedPos + math.abs(YUpThres)
		local YBoundsDown = cameraYLastGroundedPos - math.abs(YDownThres)

		local distanceY = targetY - cameraY
		local isAscending = (distanceY > 0)

		if isGrounded then
			cameraYSpd = settings.cameraYGrndSpdBase
			cameraYLastGroundedPos = targetY
			cameraYExitedBounds = false
		elseif distanceY ~= 0 then
			cameraYSpd = isAscending and (settings.cameraYAsnSpdBase - (math.abs(distanceY) * settings.cameraYAsnSpdInc))
				or (settings.cameraYDsnSpdBase - (math.abs(distanceY) * settings.cameraYDsnSpdInc))
			if (targetY > YBoundsUp) or (targetY < YBoundsDown) then
				cameraYExitedBounds = true
			end
		end

		cameraYSpd = math.clamp(cameraYSpd, settings.cameraYSpdMin, settings.cameraYSpdMax)

		local absUp = settings.cameraIsFreeroam and math.abs(settings.cameraYMaxDistUp) or math.abs(settings.cameraLockedYMaxDistUp)
		local absDown = settings.cameraIsFreeroam and math.abs(settings.cameraYMaxDistDown)
			or math.abs(settings.cameraLockedYMaxDistDown)
		if distanceY > absUp then
			cameraY = cameraY + (distanceY - absUp)
		elseif distanceY < -absDown then
			cameraY = cameraY + (distanceY + absDown)
		end

		if not cameraYExitedBounds then
			cameraY, cameraYVel = tweenServ:SmoothDamp(cameraY, cameraYLastGroundedPos, cameraYVel, cameraYSpd, nil, dt)
		else
			cameraY, cameraYVel = tweenServ:SmoothDamp(cameraY, targetY, cameraYVel, cameraYSpd, nil, dt)
		end
	else
		cameraY = targetY
		cameraYVel = 0
	end
end

function camController:updateRootOcclusion(dt, desiredPos, offsetY)
	local origin = playerHRP.Position
	local dir = (desiredPos - origin)
	local rootOccludeCheck = world:Spherecast(origin, cameraRootColliderRadius, dir, rayParams)
	local rootOccludePos = rootOccludeCheck
			and (playerHRP.Position + (dir.Unit * (rootOccludeCheck.Distance * cameraRootCollideDistScale)))
		or nil

	local occludedY
	if rootOccludePos then
		local origin2 = utils:getHorizontalDir(rootOccludePos) + Vector3.new(0, playerHRP.Position.Y, 0)
		local final = utils:getHorizontalDir(rootOccludePos) + Vector3.new(0, desiredPos.Y, 0)
		local dir2 = (final - origin2)
		local rootOccludeYCheck = world:Spherecast(origin2, cameraRootColliderRadius, dir2, rayParams)
		occludedY = rootOccludeYCheck and (origin2 + (dir2.Unit * rootOccludeYCheck.Distance)).Y or cameraY
	end

	local finalPos = desiredPos
	if rootOccludeCheck then
		local scale = utils:getExponentialScale(settings.rootOccludedSpd, dt)
		local target = Vector3.new(rootOccludePos.X, occludedY, rootOccludePos.Z)
		finalPos = cameraRoot.Position:lerp(target, scale)
		cameraRootOccluded = finalPos
	elseif cameraRootOccluded then
		local scale = utils:getExponentialScale(settings.rootOccludeRetrunSpd, dt)
		finalPos = cameraRoot.Position:lerp(desiredPos, scale)
		if (finalPos - desiredPos).Magnitude < settings.rootOccludeForgetThres then
			cameraRootOccluded = nil
		end
	end
	return finalPos
end

function camController:readInput(inputObj, gameProcessed)
	print(inputObj.UserInputType)
	local isBegin = inputObj.UserInputState == Enum.UserInputState.Begin and true or false
	if not gameProcessed then
		if inputObj.UserInputType == Enum.UserInputType.MouseMovement or inputObj.UserInputType == Enum.UserInputType.Touch then
			if playerIsPinching then
				if inputObj.UserInputState ~= Enum.UserInputState.Change then
					playerIsPinching = false
				end
				return
			end
			local deltaRaw = userInput:GetMouseDelta()
			local inverterX = settings.cameraInvertedHorizontal and -1 or 1
			local inverterY = settings.cameraInvertedY and -1 or 1
			local deltaNew = Vector2.new(
				math.rad((deltaRaw.X * inverterX) * settings.cameraSensitivityX),
				math.rad((deltaRaw.Y * inverterY) * settings.cameraSensitivityY)
			)
			cameraRotX = math.clamp(cameraRotX + deltaNew.Y, math.rad(-cameraYRotCap), math.rad(cameraYRotCap))
			cameraRotY = cameraRotY + deltaNew.X
		elseif inputObj.UserInputType == Enum.UserInputType.MouseWheel then
			self:handleZoom(false, false, inputObj)
		elseif
			(
				inputObj.UserInputType == Enum.UserInputType.MouseButton1
				or inputObj.UserInputType == Enum.UserInputType.MouseButton2
			) and isBegin
		then
			actionPerformTick = os.clock()
		elseif inputObj.KeyCode == Enum.KeyCode.LeftShift and isBegin then
			settings.cameraIsFreeroam = not settings.cameraIsFreeroam
		elseif inputObj.KeyCode == Enum.KeyCode.LeftAlt then
			cameraMouseLocked = not isBegin
			userInput.MouseBehavior = isBegin and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
		elseif inputObj.KeyCode == Enum.KeyCode.KeypadEight and isBegin then
			self.debugRender = not self.debugRender
		end
	end
end

function camController:checkOcclusion()
	local dir = (cameraTarget.Position - cameraRoot.Position)
	if dir.Magnitude > 1024 then
		return
	end
	local ray = world:Spherecast(cameraRoot.Position, cameraColliderRadius, dir, rayParams)
	if ray then
		cameraOcclusionForcedZoom = (math.round(ray.Distance * 1000) / 1000)
		return true
	else
		cameraOcclusionForcedZoom = nil
		return false
	end
end

function camController:applyInvis(dt)
	local targetTransparency = 1

	for c, i in pairs(playerParts) do
		if i.Name ~= "HumanoidRootPart" and i.Name ~= "CameraRoot" then -- ignore parts supposed to remain invis
			local dist = (camera.CFrame.Position - playerHRP.Position).Magnitude
			local invisPrecentile = (not playerIsDead and dist < settings.plrInvisThreshold)
					and math.clamp(math.abs(settings.plrFullInvisThreshold / dist), settings.plrInvisMin, settings.plrInvisMax)
				or settings.plrInvisMin

			targetTransparency = i.Transparency ~= invisPrecentile
					and utils:lerp(i.Transparency, invisPrecentile, settings.playerInvisSmoothSpd, dt)
				or invisPrecentile
			i.Transparency = ((targetTransparency >= 0.99) and 1 or (targetTransparency <= 0.01) and 0)
				or targetTransparency -- spooky ghost sound
		end
	end

	local invisFill = settings.useInvisHighlight
			and (settings.invisHighlightMax - math.clamp(
				targetTransparency - settings.invisHighlightFillMin,
				0,
				settings.invisHighlightMax
			))
		or settings.invisHighlightMax
	local invisOutline = settings.useInvisHighlight
			and (settings.invisHighlightMax - math.clamp(
				targetTransparency - settings.invisHighlightOutlineMin,
				0,
				settings.invisHighlightMax
			))
		or settings.invisHighlightMax

	invisHighlight.FillTransparency = math.clamp(invisFill, settings.invisHighlightFillMin, settings.invisHighlightMax)
	invisHighlight.OutlineTransparency = math.clamp(invisOutline, settings.invisHighlightOutlineMin, settings.invisHighlightMax)
end

function camController:debugRenderer()
	if self.debugRender and cameraRootDebugOutline.Transparency == 1 then
		cameraRootDebugOutline.Transparency = 0
	elseif not self.debugRender and cameraRootDebugOutline.Transparency == 0 then
		cameraRootDebugOutline.Transparency = 1
	end
end

--helper
function camController:playerLookAt(dt)
	if not playerIsDead then
		if
			((os.clock() - actionPerformTick) <= settings.cameraFreeRoamThres or not settings.cameraIsFreeroam)
			and not (utils:isSeated(playerHumanoid))
		then
			local mouseRay = self:queryMouse()
			playerHumanoid.AutoRotate = false
			local spd = settings.cameraIsFreeroam and settings.playerLookAtSpd or settings.playerLookAtSpdLocked
			local scale = utils:getExponentialScale(spd, dt)
			local mouseRayPos = (mouseRay and settings.cameraIsFreeroam) and mouseRay.Position or nil
			local lookVector = (not mouseRayPos) and (utils:getHorizontalDir(camera.CFrame.LookVector) + playerHRP.Position)
				or (Vector3.new(mouseRayPos.X, playerHRP.Position.Y, mouseRayPos.Z))
			local plrLookAt = CFrame.lookAt(playerHRP.Position, lookVector)
			playerHRP.CFrame = playerHRP.CFrame:lerp(plrLookAt, scale)
		else
			playerHumanoid.AutoRotate = true
		end
	end
end

function camController:createCamTarget()
	cameraRotCF = CFrame.fromEulerAnglesYXZ(cameraRotX, cameraRotY, 0)
	local cameraOffset = cameraRotCF * Vector3.new(0, 0, settings.cameraZoom)
	cameraTarget = CFrame.new((cameraRoot.Position + cameraOffset), cameraRoot.Position)
end

function camController:queryMouse()
	local pos = userInput:GetMouseLocation()
	local mouseViewportRay = camera:ViewportPointToRay(pos.X, pos.Y)
	local raycast = world:Raycast(mouseViewportRay.Origin, mouseViewportRay.Direction * mouseRayDistance, rayParams)
	return raycast
end

function camController:handleZoom(isPinch, isController, inputObj)
	local min = settings.cameraIsFreeroam and settings.zoomMin or settings.zoomMinLocked
	local max = settings.cameraIsFreeroam and settings.zoomMax or settings.zoomMaxLocked
	local scroll
	if not inputObj.gameProcessedEvent then
		if isPinch then
			local pinchAmount = inputObj.scale * (inputObj.velocity > 0 and 1 or -1)
			scroll = settings.zoomInverted and -pinchAmount or pinchAmount
			scroll *= settings.zoomSenseMobile
		elseif isController then
		else
			scroll = settings.zoomInverted and -inputObj.Position.Z or inputObj.Position.Z
			scroll *= settings.zoomSens
		end
	end
	if scroll == nil then
		return
	end
	playerIsPinching = isPinch
	settings.cameraZoom = math.clamp(settings.cameraZoom + scroll, min, max)
end

function camController:instanceNew(obj)
	if obj:IsA("BasePart") then
		table.insert(rayExclude, obj)
	end
	rayParams.FilterDescendantsInstances = rayExclude
end

function camController:instanceRemove(obj)
	if obj:IsA("BasePart") then
		local tablePos = table.find(rayExclude, obj)
		table.remove(rayExclude, tablePos)
	end
	rayParams.FilterDescendantsInstances = rayExclude
end

return camController