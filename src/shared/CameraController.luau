-- {[ Viewpoint Module ]}
-- ver 0.79.0
-- By josiahgame/JRmcnugget

-- pwease do not look at me! i am unfinished, owo

local camController = {}

camController.IsInitialized = false

-- -- ⚙️ SETTINGS
-- -- anything not local are defaults which can be overwritten by external scripts

-- -- debugHUD integration
local debugger = game.ReplicatedStorage:FindFirstChild("DebugMenu")

camController.debugRender = false

-- -- camera
local ignoreTag = "CameraIgnore"

-- sensitivity
camController.cameraSensitivityX = 0.5
camController.cameraSensitivityY = 0.5
camController.zoomSens = 1

-- zoom
camController.zoomInverted = true
local cameraZoom = 15
local zoomAbsoluteMin = 0.5

camController.zoomMax = 100
camController.zoomMin = 12
camController.zoomMaxLocked = 9
camController.zoomMinLocked = 5

local zoomSmoothBaseSpd = 10
camController.zoomSpdIn = 1.1
camController.zoomSpdOut = 1.3

-- freeroam / shift lock
local cameraIsFreeroam = true

camController.cameraFreeRoamThres = 2

-- horizontal settings
camController.cameraInvertedHorizontal = true
camController.cameraSmoothingHorizontalEnabled = true

camController.cameraHorizontalOffsetShiftLock = 3.5

camController.cameraHorizontalMinSpd = 0.12
camController.cameraHorizontalMaxDistFreeroam = 6
camController.cameraHorizontalMaxDistLocked = 2

camController.cameraHorizontalFreeroamRadial = 1
camController.cameraHorizontalFreeroamSpd = 0.5
camController.cameraHorizontalFreeroamSpdDistInc = 0.1

camController.cameraHorizontalLockedRadial = 0.5
camController.cameraHorizontalLockedSpd = 0.3
camController.cameraHorizontalLockedSpdDistInc = 0.25

camController.cameraHorizontalPredict = false

-- vertical settings
camController.cameraInvertedY = true
camController.cameraSmoothingYEnabled = true

camController.cameraYOffsetFreeRoam = 3.5
camController.cameraYOffsetShiftLock = 3

local cameraYSpdMax = 0.65
local cameraYSpdMin = 0.05

camController.cameraYGrndSpdBase = 0.2

camController.cameraYAsnSpdBase = 0.35
camController.cameraYAsnSpdInc = 0.008

camController.cameraYDsnSpdBase = 0.4
camController.cameraYDsnSpdInc = 0.005

camController.cameraYUpThres = 10
camController.cameraYDownThres = 3.5
camController.cameraLockedYUpThres = 9
camController.cameraLockedYDownThres = 2

camController.cameraYMaxDistUp = 10
camController.cameraYMaxDistDown = 8
camController.cameraLockedYMaxDistUp = 9
camController.cameraLockedYMaxDistDown = 5

-- -- player
-- smoothing speeds
camController.playerLookAtSpd = 8
camController.playerLookAtSpdLocked = 20
camController.playerInvisSmoothSpd = 15

-- distance invisibility
camController.plrInvisThreshold = 6
camController.plrFullInvisThreshold = 3
camController.plrInvisMax = 0.99
camController.plrInvisMin = 0

camController.useInvisHighlight = true
camController.invisHighlightFillMin = 0.8
camController.invisHighlightOutlineMin = 0.4
camController.invisHighlightMax = 1

-- -- cameraRoot
camController.rootOccludedSpd = 35

-- -- SETTINGS END

local players = game:GetService("Players")
local userInput = game:GetService("UserInputService")
local collectionServ = game:GetService("CollectionService")
local runServ = game:GetService("RunService")
local tweenServ = game:GetService("TweenService")
local world = workspace

local cameraOcclusionForcedZoom = nil
local cameraTarget = CFrame.new(0, 0, 0)
local actionPerformTick = os.clock() - camController.cameraFreeRoamThres
local mouseRayDistance = 5000

--player
local player = nil
local playerCharacter = nil
local playerHRP = nil
local playerIsDead = false
local playerHumanoid = nil
local playerParts = {}

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

local zoomSmooth = cameraZoom

local invisHighlight = nil

local cameraMouseLocked = true
local cameraOverride = false

--occlusion check params
local rayParams = RaycastParams.new()
local rayExclude = {}
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true

if debugger then
	debugger = require(debugger)
end

-- local helpers
local function isGrounded(humanoid)
	return not (humanoid:GetState() == Enum.HumanoidStateType.Jumping or humanoid:GetState() == Enum.HumanoidStateType.Freefall)
end

local function isSeated(humanoid)
	return (humanoid:GetState() == Enum.HumanoidStateType.Seated)
end

local function getExponentialScale(scale, dt)
	return 1 - math.exp(-scale * dt)
end

-- exponential math to keep consistent scale across framerates. smaller framerate = bigger scale to match, and vise versa
local function lerp(val, goal, scale, dt)
	scale = getExponentialScale(scale, dt)
	return val + (goal - val) * scale
end

local function getHorizontalDir(vec)
	return Vector3.new(vec.X, 0, vec.Z)
end

--init
function camController:Init(plr)
	player = plr

	self:instanceNewPlayer(plr)

	player.CharacterRemoving:Connect(function(char)
		self.IsInitialized = false

		playerCharacter = nil
		playerHumanoid = nil
		playerHRP = nil
		camera = nil

		if cameraRoot then
			cameraRoot:Destroy()
			cameraRoot = nil
		end

		print(playerInstancingConnections)
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

	local alreadyTagged = collectionServ:GetTagged(ignoreTag)
	for c, i in pairs(alreadyTagged) do
		table.insert(rayExclude, i)
	end

	collectionServ:GetInstanceAddedSignal(ignoreTag):Connect(function(obj)
		self:instanceNew(obj)
	end)
	collectionServ:GetInstanceRemovedSignal(ignoreTag):Connect(function(obj)
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
			return cameraIsFreeroam
		end)
		debugger:createWatcher("cameraMouseLocked", function()
			return cameraMouseLocked
		end)
		debugger:createWatcher("cameraZoom", function()
			return cameraZoom
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
		self:updateCamRot()

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
	if plr == player then
		player.CharacterAdded:Connect(function(char)
			local loaded = plr:HasAppearanceLoaded()

			while not loaded do
				--if char.Parent ~= world then return end
				loaded = plr:HasAppearanceLoaded()
				task.wait()
			end

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

			cameraY = playerHRP.Position.Y + self.cameraYOffsetFreeRoam
			cameraHorizontalPos = getHorizontalDir(playerHRP.Position)
			cameraYLastGroundedPos = cameraY

			invisHighlight = Instance.new("Highlight")
			invisHighlight.Parent = playerCharacter
			invisHighlight.FillColor = Color3.fromRGB(255, 255, 255)
			invisHighlight.FillTransparency = 1
			invisHighlight.OutlineTransparency = 1

			playerHumanoid.Died:Connect(function()
				playerIsDead = true
			end)

			table.clear(playerParts) -- remove stale references

			--instance all playerparts that are added upon the character's immediate creation
			for c, i in pairs(char:GetDescendants()) do
				if i.ClassName == "MeshPart" or i.ClassName == "Part" then
					table.insert(playerParts, i)
					i:AddTag(ignoreTag)
				end
			end

			--instance any parts that are added further to the character
			local instanceWatcher = playerCharacter.DescendantAdded:Connect(function(obj)
				if obj:IsA("BasePart") then
					table.insert(playerParts, obj)
					obj:AddTag(ignoreTag)
				end
			end)
			table.insert(playerInstancingConnections, instanceWatcher) -- does not automatically disconnect so we have to keep track

			camera.CameraSubject = cameraRoot
			camera.CameraType = Enum.CameraType.Scriptable
			rayParams.FilterDescendantsInstances = rayExclude
			userInput.MouseBehavior = Enum.MouseBehavior.LockCenter

			self.IsInitialized = true
		end)
	end
end

function camController:createCameraFinal(dt)
	local occluded = self:checkOcclusion()
	local max = cameraIsFreeroam and self.zoomMax or self.zoomMaxLocked
	local zoomAmount = math.clamp((occluded and cameraOcclusionForcedZoom or cameraZoom), zoomAbsoluteMin, max) -- if occluded, use occluded zoom, else use user zoom. capped from first person zoom and max camera zoom
	local isZoomOut = (zoomAmount > zoomSmooth) and true or false -- if player zoom is bigger than zoomSmooth they are zoooming out (as zoomSmooth will trail behind due to lerp)
	local zoomSmoothSpd = not isZoomOut and zoomSmoothBaseSpd * self.zoomSpdIn or zoomSmoothBaseSpd * self.zoomSpdOut -- if camera is in first person, use the first person zoom speed. else, if player is not zooming out use zoominspeed, if zooming out use zoomout speed
	zoomSmooth = (not occluded or isZoomOut or (not cameraIsFreeroam and zoomSmooth > max))
			and lerp(zoomSmooth, zoomAmount, zoomSmoothSpd, dt)
		or zoomAmount -- if camera is not occluded or not zooming out, or the camera is forced first person, use lerp, otherwise snap to zoomamount without lerp. allows the camera to smooth out in all situations

	local cameraSmoothOffset = cameraRotCF * Vector3.new(0, 0, zoomSmooth)
	return CFrame.new(cameraRoot.Position + cameraSmoothOffset, cameraRoot.Position)
end

function camController:updateCamRoot(dt)
	if not playerIsDead then
		local freeroamCheck = (cameraIsFreeroam or isSeated(playerHumanoid))

		local radial = freeroamCheck and self.cameraHorizontalFreeroamRadial or self.cameraHorizontalLockedRadial
		local baseSpd = freeroamCheck and self.cameraHorizontalFreeroamSpd or self.cameraHorizontalLockedSpd
		local spdIncrement = freeroamCheck and self.cameraHorizontalFreeroamSpdDistInc
			or self.cameraHorizontalLockedSpdDistInc
		local maxDist = freeroamCheck and self.cameraHorizontalMaxDistFreeroam or self.cameraHorizontalMaxDistLocked

		self:updateRootHorizontal(dt, radial, baseSpd, spdIncrement, maxDist)

		local offset = math.abs(freeroamCheck and self.cameraYOffsetFreeRoam or self.cameraYOffsetShiftLock)
		local rootTargetY = playerHRP.Position.Y + offset

		self:updateRootY(dt, rootTargetY)

		local targetHorizontal = freeroamCheck and cameraHorizontalPos or cameraHorizontalPos + (cameraRotCF.RightVector * self.cameraHorizontalOffsetShiftLock)
		local desiredPos = Vector3.new(targetHorizontal.X, cameraY, targetHorizontal.Z)

		local Ypos = cameraYExitedBounds and playerHRP.Position.Y or (cameraYLastGroundedPos-offset)

		local origin = getHorizontalDir(playerHRP.Position) + Vector3.new(0,Ypos,0)
		local dir = (desiredPos-origin)
		local rootOccludeCheck = world:Spherecast(origin, cameraRootColliderRadius, dir, rayParams)
		local rootOccludePos = rootOccludeCheck and (playerHRP.Position+(dir.Unit*(rootOccludeCheck.Distance*cameraRootCollideDistScale))) or nil

		local occludedY
		if rootOccludePos then
			local origin2 = getHorizontalDir(rootOccludePos) + Vector3.new(0,Ypos,0)
			local final = getHorizontalDir(rootOccludePos) + Vector3.new(0,desiredPos.Y,0)
			local dir2 = (final-origin2)
			local rootOccludeYCheck = world:Spherecast(origin2, cameraRootColliderRadius, dir2, rayParams)
			occludedY = rootOccludeYCheck and (origin2+(dir2.Unit*rootOccludeYCheck.Distance)).Y or (cameraYExitedBounds and rootTargetY or cameraY) 
		end

		local finalPos = desiredPos
		if rootOccludeCheck then
			local target = Vector3.new(rootOccludePos.X, occludedY, rootOccludePos.Z)
			finalPos = cameraRoot.Position:lerp(target, getExponentialScale(self.rootOccludedSpd, dt))
		end
		
		cameraRoot.Position = finalPos
	end
end

function camController:updateRootHorizontal(dt, radial, baseSpd, spdInc, maxDist)
	local lastPos = cameraHorizontalPos
	local hrpPos = getHorizontalDir(playerHRP.Position)
	if self.cameraSmoothingHorizontalEnabled then
		local rootPos = getHorizontalDir(cameraRoot.Position)
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

			local spd = math.clamp(baseSpd - math.abs(dist * spdInc), self.cameraHorizontalMinSpd, baseSpd)

			cameraHorizontalPos, cameraHorizontalVel =
				tweenServ:SmoothDamp(cameraHorizontalPos, target, cameraHorizontalVel, spd, nil, dt)
		end
	else
		cameraHorizontalPos = hrpPos
	end
end

function camController:updateRootY(dt, targetY)
	local isGrounded = isGrounded(playerHumanoid)

	if self.cameraSmoothingYEnabled then
		local YUpThres = cameraIsFreeroam and self.cameraYUpThres or self.cameraLockedYUpThres
		local YDownThres = cameraIsFreeroam and self.cameraYDownThres or self.cameraLockedYDownThres
		local YBoundsUp = cameraYLastGroundedPos + math.abs(YUpThres)
		local YBoundsDown = cameraYLastGroundedPos - math.abs(YDownThres)

		local distanceY = targetY - cameraY
		local isAscending = (distanceY > 0)

		if isGrounded then
			cameraYSpd = self.cameraYGrndSpdBase
			cameraYLastGroundedPos = targetY
			cameraYExitedBounds = false
		elseif distanceY ~= 0 then
			cameraYSpd = isAscending and (self.cameraYAsnSpdBase - (math.abs(distanceY) * self.cameraYAsnSpdInc))
				or (self.cameraYDsnSpdBase - (math.abs(distanceY) * self.cameraYDsnSpdInc))
			if (targetY > YBoundsUp) or (targetY < YBoundsDown) then
				cameraYExitedBounds = true
			end
		end

		cameraYSpd = math.clamp(cameraYSpd, cameraYSpdMin, cameraYSpdMax)

		local absUp = cameraIsFreeroam and math.abs(self.cameraYMaxDistUp) or math.abs(self.cameraLockedYMaxDistUp)
		local absDown = cameraIsFreeroam and math.abs(self.cameraYMaxDistDown)
			or math.abs(self.cameraLockedYMaxDistDown)
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

function camController:readInput(inputObj, gameProcessed)
	local isBegin = inputObj.UserInputState == Enum.UserInputState.Begin and true or false
	if inputObj.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		local scroll = self.zoomInverted and -inputObj.Position.Z or inputObj.Position.Z
		scroll *= self.zoomSens
		local min = cameraIsFreeroam and self.zoomMin or self.zoomMinLocked
		local max = cameraIsFreeroam and self.zoomMax or self.zoomMaxLocked
		cameraZoom = math.clamp(cameraZoom + scroll, min, max)
	elseif
		(
			inputObj.UserInputType == Enum.UserInputType.MouseButton1
			or inputObj.UserInputType == Enum.UserInputType.MouseButton2
		) and not gameProcessed
	then
		if isBegin then
			actionPerformTick = os.clock()
		end
	elseif inputObj.KeyCode == Enum.KeyCode.LeftShift and isBegin and not gameProcessed then
		cameraIsFreeroam = not cameraIsFreeroam
	elseif inputObj.KeyCode == Enum.KeyCode.LeftAlt and not gameProcessed then
		cameraMouseLocked = not isBegin
		userInput.MouseBehavior = isBegin and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
	elseif inputObj.KeyCode == Enum.KeyCode.KeypadEight and isBegin then
		self.debugRender = not self.debugRender
	end
end

function camController:checkOcclusion()
	local dir = (cameraTarget.Position - cameraRoot.Position)
	if dir.Magnitude > 1024 then
		return
	end
	local pos = cameraRoot.Position
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
			local invisPrecentile = (not playerIsDead and dist < self.plrInvisThreshold)
					and math.clamp(math.abs(self.plrFullInvisThreshold / dist), self.plrInvisMin, self.plrInvisMax)
				or self.plrInvisMin

			targetTransparency = i.Transparency ~= invisPrecentile
					and lerp(i.Transparency, invisPrecentile, self.playerInvisSmoothSpd, dt)
				or invisPrecentile
			i.Transparency = ((targetTransparency >= 0.99) and 1 or (targetTransparency <= 0.01) and 0)
				or targetTransparency -- spooky ghost sound
		end
	end

	local invisFill = self.useInvisHighlight
			and (self.invisHighlightMax - math.clamp(
				targetTransparency - self.invisHighlightFillMin,
				0,
				self.invisHighlightMax
			))
		or self.invisHighlightMax
	local invisOutline = self.useInvisHighlight
			and (self.invisHighlightMax - math.clamp(
				targetTransparency - self.invisHighlightOutlineMin,
				0,
				self.invisHighlightMax
			))
		or self.invisHighlightMax

	invisHighlight.FillTransparency = math.clamp(invisFill, self.invisHighlightFillMin, self.invisHighlightMax)
	invisHighlight.OutlineTransparency = math.clamp(invisOutline, self.invisHighlightOutlineMin, self.invisHighlightMax)
end

function camController:updateCamRot()
	if cameraMouseLocked then
		local delta = self:queryDelta()
		cameraRotX = math.clamp(cameraRotX + delta.Y, math.rad(-cameraYRotCap), math.rad(cameraYRotCap))
		cameraRotY = cameraRotY + delta.X
	end
end

function camController:debugRenderer()
	if self.debugRender and cameraRootDebugOutline.Transparency == 1 then
		cameraRootDebugOutline.Transparency = 0
	elseif not self.debugRender and cameraRootDebugOutline.Transparency == 0 then
		cameraRootDebugOutline.Transparency = 1
	end

	if debugger and self.debugRender then
	end
end

--helper
function camController:playerLookAt(dt)
	if not playerIsDead then
		if
			((os.clock() - actionPerformTick) <= self.cameraFreeRoamThres or not cameraIsFreeroam)
			and not (isSeated(playerHumanoid))
		then
			local mouseRay = self:queryMouse()
			playerHumanoid.AutoRotate = false
			local spd = cameraIsFreeroam and self.playerLookAtSpd or self.playerLookAtSpdLocked
			local scale = getExponentialScale(spd, dt)
			local mouseRayPos = (mouseRay and cameraIsFreeroam) and mouseRay.Position or nil
			local lookVector = (not mouseRayPos) and (getHorizontalDir(camera.CFrame.LookVector) + playerHRP.Position)
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
	local cameraOffset = cameraRotCF * Vector3.new(0, 0, cameraZoom)
	cameraTarget = CFrame.new((cameraRoot.Position + cameraOffset), cameraRoot.Position)
end

function camController:queryDelta()
	local deltaRaw = userInput:GetMouseDelta()
	local inverterX = self.cameraInvertedHorizontal and -1 or 1
	local inverterY = self.cameraInvertedY and -1 or 1
	local deltaNew = Vector2.new(
		math.rad((deltaRaw.X * inverterX) * self.cameraSensitivityX),
		math.rad((deltaRaw.Y * inverterY) * self.cameraSensitivityY)
	)
	return deltaNew
end

function camController:queryMouse()
	local pos = userInput:GetMouseLocation()
	local mouseViewportRay = camera:ViewportPointToRay(pos.X, pos.Y)
	local raycast = world:Raycast(mouseViewportRay.Origin, mouseViewportRay.Direction * mouseRayDistance, rayParams)
	return raycast
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

local Debris = game:GetService("Debris")

-- Draws a part representing a vector from `origin` in the direction/magnitude of `vector`
-- origin: Vector3 (start point)
-- vector: Vector3 (direction + magnitude, e.g. part.Velocity or (target - origin))
-- duration: number (seconds before it's destroyed)
-- color: optional Color3 (defaults to bright yellow)
function camController:debugDrawVector(origin, vector, duration, color)
	duration = duration or 3
	color = color or Color3.fromRGB(255, 255, 0)

	local magnitude = vector.Magnitude
	if magnitude < 1e-4 then
		return -- nothing meaningful to draw
	end

	local part = Instance.new("Part")
	part.Name = "DebugVector"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.1, 0.1, magnitude)

	-- Position at the midpoint, oriented so the part's Z axis points along the vector
	local midpoint = origin + vector / 2
	part.CFrame = CFrame.new(midpoint, midpoint + vector.Unit)

	part.Parent = workspace

	-- Auto-cleanup
	Debris:AddItem(part, duration)

	return part
end

return camController
