# StateService
A lazy-initialized, hierarchical state tree wrapper for [Charm](https://github.com/littensy/charm)

## Functions
### `:Ready(Callback)`
Fires immediately if the value already exists, or as soon as it is initially assigned.

```luau
  Node:Ready(function(Value: any)
    print(Value)
  end)

  local Atom = Node()
  Atom(5) -- 5
```

### `:WhenReady(Callback)`
Fires immediately if the value is already assigned, and subscribes to subsequent changes.

```luau
  local Atom = Node()
  Atom(5)

  Node:WhenReady(function(newValue: any, oldValue: any)
    print(Value)
  end)

  Atom(6) -- 5 6
```

### `:Expect()`
Synchronously returns the value as soon as it is assigned or if it already exists.

```luau
  -- Script 1:
  local Coins = Node:expect()
  print(Coins)

  -- Script 2:
  local Atom = Node()
  Atom(100) -- 100
```

### `:Destroy()`
Destroys the current node and all of its descendants, setting their atoms to nil.

```luau
  local NodeAtom = Node()
  NodeAtom(10)
  print(NodeAtom()) -- 10
  Node:destroy()
  print(NodeAtom()) -- nil
```

### `:OnDestroy(Callback)`
Fires when the node is destroyed, returning the atom's last value or nil.

```luau
  local NodeAtom = Node()
  NodeAtom("Hello World")

  Node:OnDestroy(function(lastValue: any)
    print(lastValue)
  end)

  Node:destroy() -- "Hello World"
```

### `:ClearDescendants()`
Destroys all descendants of the current node.

```luau
  local Child = Node.Something
  local Descendant = Child.Anything
  local DescendantAtom = Descendant()

  DescendantAtom(3)

  Descendant:OnDestroy(function(lastValue: any)
    print(lastValue)
  end)

  Node:clearDescendants() -- 3
```
