local utilities = {}

function utilities:isGrounded(humanoid)
	return not (
		humanoid:GetState() == Enum.HumanoidStateType.Jumping
		or humanoid:GetState() == Enum.HumanoidStateType.Freefall
	)
end

function utilities:isSeated(humanoid)
	return (humanoid:GetState() == Enum.HumanoidStateType.Seated)
end

function utilities:getExponentialScale(scale, dt)
	return 1 - math.exp(-scale * dt)
end

-- exponential math to keep consistent scale across framerates. smaller framerate = bigger scale to match, and vise versa
function utilities:lerp(val, goal, scale, dt)
	scale = self:getExponentialScale(scale, dt)
	return val + (goal - val) * scale
end

function utilities:getHorizontalDir(vec)
	return Vector3.new(vec.X, 0, vec.Z)
end

return utilities