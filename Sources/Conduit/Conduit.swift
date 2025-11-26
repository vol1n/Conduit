@_exported import Core

@attached(peer)
public macro GET(_ path: String) = #externalMacro(module: "ConduitMacro", type: "GETMacro")

@attached(peer)
public macro POST(_ path: String) = #externalMacro(module: "ConduitMacro", type: "POSTMacro")

@attached(peer, names: suffixed(Client), suffixed(Params), suffixed(Routes), suffixed(PathBuilder))
public macro RPC() = #externalMacro(module: "ConduitMacro", type: "RPCMacro")
