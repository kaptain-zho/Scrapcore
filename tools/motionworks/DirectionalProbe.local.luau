--!strict
-- Explicit temporary Studio playtest helper; never copy into synchronized roots.
local rs = game:GetService("RunService")
if not rs:IsStudio() then script:Destroy(); return end
local player = game.Players.LocalPlayer
local command = Instance.new("BindableFunction")
command.Name = "Command"; command.Parent = script
local yaw = 0
local forge: any = nil
local deadline = os.clock()+900
local aimConnection: RBXScriptConnection? = nil
local boundAim: AlignOrientation? = nil
local function enforceAim()
	if boundAim and os.clock()<deadline then
		local desired=CFrame.Angles(0,yaw,0)
		if boundAim.CFrame.LookVector:Dot(desired.LookVector)<0.999999 then boundAim.CFrame=desired end
	end
end
local connection = rs.PreSimulation:Connect(function()
	if os.clock()>deadline then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local aim = root:FindFirstChild("RobotAimOrientation")
	if aim and aim:IsA("AlignOrientation") then
		if aim~=boundAim then
			if aimConnection then aimConnection:Disconnect() end
			boundAim=aim;aimConnection=aim:GetPropertyChangedSignal("CFrame"):Connect(enforceAim)
		end
		enforceAim()
	end
	local mover = root:FindFirstChild("RobotMovementVelocity")
	if forge then
		if mover and mover:IsA("LinearVelocity") then mover.Enabled=false end
		local humanoid=player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:Move(Vector3.zero);humanoid.WalkSpeed=0;humanoid.PlatformStand=true end
		local direction=if forge.side then root.CFrame.RightVector else -root.CFrame.LookVector
		root.AssemblyLinearVelocity=direction*forge.speed+Vector3.new(0,root.AssemblyLinearVelocity.Y,0)
	elseif mover and mover:IsA("LinearVelocity") then
		mover.Enabled=true
		local humanoid=player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.PlatformStand=false end
	end
end)
command.OnInvoke=function(action: string, options: any)
	if action=="Aim" then yaw=options.yaw or 0;return true end
	if action=="Forge" then forge=options;task.wait(options.duration or .6);forge=nil;return true end
	if action=="Curve" then
		local start=os.clock();local initial=yaw;local duration=options.duration or 2
		repeat yaw=initial+(options.angle or math.pi/2)*math.min((os.clock()-start)/duration,1);rs.Heartbeat:Wait() until os.clock()-start>=duration
		return true
	end
	return false
end
task.delay(900,function() forge=nil;connection:Disconnect();if aimConnection then aimConnection:Disconnect() end;script:Destroy() end)
