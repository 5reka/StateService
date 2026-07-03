--!optimize 2
--!native

-->|---->>  Libraries  <<----|<--
local CHARM = require("@game/ReplicatedFirst/Libraries/Charm/Charm")

-->|---->>  Constants  <<----|<--
local SCRIPT = script.Name
local NODE_META

-->|---->>  Types  <<----|<--
export type Atom = CHARM.Atom
type DestructionCallbacks = {[Callback]: boolean?}
type Subscription = (newValue: any, oldValue: any) -> ()
type CurrentValue = (Value: any) -> ()
type ChildrenNodes = {[any]: Node}
type EmptyCallback = () -> ()
type Callback = (...any) -> any?

export type States = {
	_p: Node?,
	_k: any?,
	_a: Atom?,
	_c: ChildrenNodes?,
	_f: true?,
	_d: DestructionCallbacks?, 
}

export type Methods = {
	Get: (self: Node) -> any?,
	Destroy: (self: Node) -> (),
	Expect: (self: Node) -> any?,
	ClearDescendants: (self: Node) -> (),
	Ready: (self: Node, Callback: CurrentValue) -> (),
	WhenReady: (self: Node, Callback: Subscription) -> (),
	OnDestroy: (self: Node, Callback: CurrentValue) -> (),
	
	__call: (self: Node) -> Atom,
	__index: typeof(getmetatable({} :: Node)), --> Fixes typization
	__newindex: (self: Node, Key: any, Value: any) -> (),
	
	[any]: Node & Callback} --> Fixes typization

export type Node = typeof(
	getmetatable(setmetatable({} :: States, {} :: Methods))
)

-->|---->>  Private functions  <<----|<--
local NullifyAtom = function(
	self: Node
)
	local Atom = rawget(self, "_a") :: Atom?
	if Atom then
		Atom(nil)
	end
end

local FireDestroy = function(
	self: Node
)	
	local Callbacks: DestructionCallbacks? = rawget(self, "_d")
	if Callbacks then
		for Callback in Callbacks do
			task.spawn(Callback, self:Get())
		end
		table.clear(Callbacks)
	end
end

local Initialize = function(
	self: Node
)
	rawset(self, "_f", true)
end

local IsInitialized = function(
	self: Node
): true?
	
	return rawget(self, "_f")
end

local DestroyNode = function(
	self: Node
)
	FireDestroy(self)
	NullifyAtom(self)
	table.clear(self)
end

local ClearNodes
ClearNodes = function(
	self: Node
)
	local Children: ChildrenNodes? = rawget(self, "_c")
	if Children then
		for _, Node in Children do
			ClearNodes(Node)
			DestroyNode(Node)
		end
		table.clear(Children)
		rawset(self, "_c", nil)
	end
end

local ReceiveOnce = function(
	Atom: Atom,
	Callback: CurrentValue
)
	
	local Disconnect
	Disconnect = CHARM.subscribe(Atom, function(Value: any?)
		Disconnect()
		Callback(Value)
	end)
end

local CreateAtom = function(
	self: Node
): Atom
	
	local Atom = CHARM.atom()
	ReceiveOnce(Atom, function()
		Initialize(self)
	end)
	
	rawset(self, "_a", Atom)
	return Atom
end

local ReceiveAtom = function(
	self: Node
): Atom
	
	local Atom: Atom? = rawget(self, "_a")
	return Atom or CreateAtom(self)
end

local CreateNode = function(
	self: Node?,
	Key: any?
): Node
	
	return setmetatable({
		_p = self,
		_k = Key
	}, NODE_META) :: Node
end

local ReceiveNode = function(
	self: Node,
	Key: any
): Node
	
	local Children: ChildrenNodes? = rawget(self, "_c")
	
	local Node: Node
	if not Children then
		Children = {}
		rawset(self, "_c", Children)
	else
		Node = Children[Key]
		if Node then return Node end
	end
	
	Node = CreateNode(self, Key)
	Children[Key] = Node
	return Node
end

-->|---->>  Public Methods  <<----|<--
NODE_META = table.freeze({
	Get = function(
		self: Node
	): any?
		
		local Atom: Atom? = rawget(self, "_a")
		return Atom and Atom()
	end,
	
	Ready = function(
		self: Node, 
		Callback: CurrentValue
	)
		
		local Atom = ReceiveAtom(self)

		if IsInitialized(self) then
			task.spawn(Callback, Atom())
		else
			ReceiveOnce(Atom, Callback)
		end
	end,
	
	WhenReady = function(
		self: Node, Callback: Subscription
	): EmptyCallback
		
		local Atom = ReceiveAtom(self)

		if IsInitialized(self) then
			task.spawn(Callback, Atom())
		end
		
		local Disconnect = CHARM.subscribe(Atom, Callback)
		self:OnDestroy(Disconnect)

		return Disconnect
	end,
	
	Destroy = function(
		self: Node
	)
		
		ClearNodes(self)
		local Parent: Node? = rawget(self, "_p")
		if Parent then
			local Children: ChildrenNodes? = rawget(Parent, "_c")
			if Children then
				Children[rawget(self, "_k")] = nil
			end
		end
		DestroyNode(self)
	end,
	
	OnDestroy = function(
		self: Node, 
		Callback: CurrentValue
	)
		
		local Callbacks: DestructionCallbacks? = rawget(self, "_d")
		if not Callbacks then
			Callbacks = {
				[Callback] = true
			}
			rawset(self, "_d", Callbacks)
		else
			Callbacks[Callback] = true
		end

		return function()
			Callbacks[Callback] = nil
		end
	end,
	
	Expect = function(
		self: Node
	): any?
		
		local Atom = ReceiveAtom(self)

		if IsInitialized(self) then
			return Atom()
		end

		local Thread = coroutine.running()
		ReceiveOnce(Atom, function(Value: any?)
			task.spawn(Thread, Value)
		end)
		return coroutine.yield() 
	end,
	
	ClearDescendants = ClearNodes,
	
	__call = ReceiveAtom,
	
	__index = function(
		self: Node, 
		Key: any
	): Node?
		
		return NODE_META[Key] or ReceiveNode(self, Key)
	end,
	
	__newindex = function(
		self: Node, 
		Key: any, 
		Value: any
	)
		
		assert(not Key, `{SCRIPT}: Unallowed to rewrite internal node states! Passed: {Key} and {Value}.`)
	end
}) :: Methods

return CreateNode()
