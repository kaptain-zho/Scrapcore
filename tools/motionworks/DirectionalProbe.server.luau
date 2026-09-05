--!strict
-- Explicit MCP-only runtime fixture. NOT a synchronized source root.
-- Copy into a temporary ServerScriptService Script during a Studio playtest.
-- Invoke workspace.MotionWorksQA.Command from SERVER MCP only; no RemoteEvent.
-- Stop the playtest to discard everything. A 15-minute watchdog also cleans up.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then script:Destroy(); return end
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Session = require(ServerScriptService.Server.PlayerSessionService)
local player = Players:GetPlayers()[1]
-- Clear one isolated measurement lane; restore all placements on cleanup/Stop.
local laneOriginals: {[Model]: CFrame} = {}
for _,model in workspace:GetDescendants() do
	if model:IsA("Model") and model:GetAttribute("BreakableType") and model.PrimaryPart then
		local position=model:GetPivot().Position
		if math.abs(position.X)<190 and math.abs(position.Z)<190 then
			laneOriginals[model]=model:GetPivot();model:PivotTo(model:GetPivot()+Vector3.new(0,1000,0))
		end
	end
end
local folder = Instance.new("Folder")
folder.Name = "MotionWorksQA"
folder.Parent = workspace
local command = Instance.new("BindableFunction")
command.Name = "Command"
command.Parent = folder
local current: any = nil
local targets: {any} = {}
local function cleanupTargets()
	for _, target in targets do
		if target.connection then target.connection:Disconnect() end
		if target.parts then for part,collides in target.parts do part.CanCollide=collides end end
		if target.original then target.model:PivotTo(target.original) else target.model:Destroy() end
	end
	table.clear(targets)
end
local function health(target: any): number
	return if target.humanoid then target.humanoid.Health else target.model:GetAttribute("BreakableHealth") or 0
end
local function addHumanoid(offset: Vector3)
	local model = Instance.new("Model")
	model.Name = "TemporaryHumanoidTarget"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"; root.Size = Vector3.new(1, 1, 1)
	root.Anchored = true; root.CanCollide = false; root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false; humanoid.MaxHealth = 1000; humanoid.Health = 1000
	humanoid.Parent = model; model.PrimaryPart = root; model.Parent = folder
	table.insert(targets, {model=model, humanoid=humanoid, offset=offset, initial=1000})
end
command.OnInvoke = function(action: string, options: any)
	if action == "Prepare" then
		current = nil; cleanupTargets()
		assert(player:GetAttribute("EvolutionCurrentNode")=="MotionWorks", "Set up Motion Works before measurement")
		assert(Session.TeleportForStudioTest(player, CFrame.new(options.x or 0, 2, options.z or 0)))
		task.wait(.7)
		return true
	elseif action == "Begin" then
		cleanupTargets()
		if options.target == "Humanoid" then addHumanoid(Vector3.new(0, 0, options.offset or -5)) end
		if options.target and options.target ~= "Humanoid" then
			for _, model in workspace:GetDescendants() do
				if model:IsA("Model") and model:GetAttribute("BreakableType") == options.target and model:GetAttribute("BreakableActive") ~= false and (model:GetAttribute("BreakableHealth") or 0) > 0 then
					local parts={}
					for _,part in model:GetDescendants() do if part:IsA("BasePart") then parts[part]=part.CanCollide;part.CanCollide=false end end
					table.insert(targets,{model=model,parts=parts,original=model:GetPivot(),offset=Vector3.new(0,0,options.offset or -5),initial=model:GetAttribute("BreakableHealth")})
					break
				end
			end
			assert(#targets > 0, "No registered target category")
		end
		current = {name=options.name, started=os.clock(), phases={}, damageEvents={}, invalidDirectionDamage=0, beforeCorrections=player:GetAttribute("MotionWorksMovementViolationCount") or 0, beforeRejects=player:GetAttribute("MotionWorksRejectedRequestCount") or 0, beforeAffected=player:GetAttribute("MotionWorksAffectedTargetCount") or 0, beforePulses=player:GetAttribute("MotionWorksPulseCount") or 0}
		local case=current
		for _,target in targets do
			local previous=health(target)
			local signal=if target.humanoid then target.humanoid.HealthChanged else target.model:GetAttributeChangedSignal("BreakableHealth")
			target.connection=signal:Connect(function()
				local nextHealth=health(target);local damage=previous-nextHealth;previous=nextHealth
				if damage<=0 or current~=case then return end
				local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not root then return end
				local velocity=root.AssemblyLinearVelocity*Vector3.new(1,0,1)
				local forward=root.CFrame.LookVector*Vector3.new(1,0,1)
				local dot=if velocity.Magnitude>.01 then velocity.Unit:Dot(forward.Unit) else 0
				local delta=(target.model.PrimaryPart.Position-root.Position)*Vector3.new(1,0,1)
				local closing=if delta.Magnitude>.01 then velocity:Dot(delta.Unit) else 0
				table.insert(case.damageEvents,{damage=damage,speed=velocity.Magnitude,dot=dot,closing=closing,phase=player:GetAttribute("MotionWorksAttackPhase")})
				if dot<.48 or velocity:Dot(forward.Unit)<8 or closing<8 then case.invalidDirectionDamage+=damage end
			end)
		end
		return true
	elseif action == "Finish" then
		local result = current; current = nil
		result.duration = os.clock()-result.started; result.started=nil
		result.corrections=(player:GetAttribute("MotionWorksMovementViolationCount") or 0)-result.beforeCorrections
		result.rejected=(player:GetAttribute("MotionWorksRejectedRequestCount") or 0)-result.beforeRejects
		result.affected=(player:GetAttribute("MotionWorksAffectedTargetCount") or 0)-result.beforeAffected
		result.pulses=(player:GetAttribute("MotionWorksPulseCount") or 0)-result.beforePulses
		result.damage=0
		for _,target in targets do result.damage+=target.initial-health(target) end
		cleanupTargets(); return result
	end
	return nil
end
local connection = RunService.Heartbeat:Connect(function()
	if current == nil then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local forward = root.CFrame.LookVector * Vector3.new(1,0,1)
	if forward.Magnitude < .01 then return end
	forward=forward.Unit
	local velocity=root.AssemblyLinearVelocity*Vector3.new(1,0,1)
	local speed=velocity.Magnitude
	local dot=if speed>.5 then velocity.Unit:Dot(forward) else 0
	local closing=velocity:Dot(forward)
	for _,target in targets do
		target.model:PivotTo(root.CFrame*CFrame.new(target.offset))
		local delta=(target.model.PrimaryPart.Position-root.Position)*Vector3.new(1,0,1)
		if delta.Magnitude>.01 then closing=velocity:Dot(delta.Unit) end
	end
	local phase=player:GetAttribute("MotionWorksAttackPhase") or "Idle"
	local record=current.phases[phase]
	if not record then record={samples=0,speedMax=0,dotMin=1,dotMax=-1,closingMin=math.huge,closingMax=-math.huge,yMin=math.huge,yMax=-math.huge};current.phases[phase]=record end
	record.samples+=1;record.speedMax=math.max(record.speedMax,speed)
	if speed>.5 then record.dotMin=math.min(record.dotMin,dot);record.dotMax=math.max(record.dotMax,dot) end
	record.closingMin=math.min(record.closingMin,closing);record.closingMax=math.max(record.closingMax,closing)
	record.yMin=math.min(record.yMin,root.Position.Y);record.yMax=math.max(record.yMax,root.Position.Y)
end)
task.delay(900,function() connection:Disconnect();cleanupTargets();for model,pivot in laneOriginals do if model.Parent then model:PivotTo(pivot) end end;folder:Destroy();script:Destroy() end)
