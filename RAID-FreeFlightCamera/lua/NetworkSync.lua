-- Tells clients whether the host runs this mod and currently allows client
-- freecam. See FreeFlightCamera:can_be_activated().
--
-- The previous version hooked NetworkPeer:send and watched for the "lobby_info"
-- call to notice that a peer had joined. That ran on every single packet, keyed
-- off an unrelated message, never reset host_has_mod when the host changed, and
-- re-announced on every received packet. This uses the session hooks BLT
-- provides for exactly this purpose instead.

local network_id = "FreeFlyCameraSync"
local PROTOCOL = 1

FreeFlightCamera.Sync = FreeFlightCamera.Sync or {}

local Sync = FreeFlightCamera.Sync

local function host_peer_id()
    local session = managers.network and managers.network:session()
    local server = session and session:server_peer()

    return server and server:id() or 1
end

local function lobby_is_private()
    local matchmake = managers.network and managers.network.matchmake
    local handler = matchmake and matchmake.lobby_handler

    if not handler then
        return false
    end

    local perm = tonumber(handler:get_lobby_data("permission"))

    -- 2 = friends_only, 3 = private
    return perm == 2 or perm == 3
end

---Host -> client: our state. Sent on join and whenever the setting changes.
---@param peer_id integer|nil @single peer, or nil for everyone
function Sync:send_state(peer_id)
    if not (LuaNetworking:IsMultiplayer() and Network:is_server()) then
        return
    end

    local payload = json.encode({
        v = PROTOCOL,
        allow = FreeFlightCamera.settings.allow_client_freecam and true or false
    })

    if peer_id then
        if peer_id ~= LuaNetworking:LocalPeerID() then
            LuaNetworking:SendToPeer(peer_id, network_id, payload)
        end
    else
        LuaNetworking:SendToPeersExcept(LuaNetworking:LocalPeerID(), network_id, payload)
    end
end

---Client -> host: ask for the state, in case we joined before the host could
---tell us (or the host's hook ran first).
function Sync:request_state()
    if not (LuaNetworking:IsMultiplayer() and Network:is_client()) then
        return
    end

    LuaNetworking:SendToPeer(host_peer_id(), network_id, json.encode({ v = PROTOCOL, req = true }))
end

function Sync:reset()
    FreeFlightCamera.host_has_mod = false
    self._announced = false
end

function Sync:on_state_received(sender, allow)
    FreeFlightCamera.host_has_mod = allow

    if not allow then
        return
    end

    -- announce once per session, not on every packet
    if self._announced or not FreeFlightCamera.settings.announce_freecam_possible then
        return
    end

    if Network:is_server() or not lobby_is_private() then
        return
    end

    local peer = managers.network:session():peer(sender)

    if not peer then
        return
    end

    self._announced = true

    managers.chat:feed_system_message(
        ChatManager.GAME,
        managers.localization:text("ffc_local_announce_freecam_possible", {
            PLAYER = peer:name()
        })
    )
end

Hooks:Add("NetworkReceivedData", "FFCSyncReceive", function(sender, id, data)
    if id ~= network_id or not FreeFlightCamera then
        return
    end

    sender = tonumber(sender)

    if not sender then
        return
    end

    local msg = json.decode(data or "")

    -- 0.7 and older sent a plain "1" and only ever went host -> client
    if type(msg) ~= "table" then
        if sender == host_peer_id() then
            Sync:on_state_received(sender, true)
        end

        return
    end

    if msg.v ~= PROTOCOL then
        return
    end

    if msg.req then
        -- a client asking us for our state
        if Network:is_server() then
            Sync:send_state(sender)
        end

        return
    end

    if sender == host_peer_id() then
        Sync:on_state_received(sender, msg.allow and true or false)
    end
end)

Hooks:Add("BaseNetworkSessionOnPeerEnteredLobby", "FFCSyncPeerEntered", function(peer, peer_id)
    Sync:send_state(peer_id or (peer and peer:id()))
end)

Hooks:Add("BaseNetworkSessionOnEnteredLobby", "FFCSyncEnteredLobby", function(local_peer, id)
    -- new lobby: nothing carries over from the previous host
    Sync:reset()
    Sync:request_state()
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete", "FFCSyncLoadComplete", function(local_peer, id)
    -- second chance in case the lobby request went out before the host was ready
    if not FreeFlightCamera.host_has_mod then
        Sync:request_state()
    end
end)

Hooks:Add("BaseNetworkSessionOnPeerRemoved", "FFCSyncPeerRemoved", function(peer, peer_id, reason)
    -- host gone means our permission to use freecam is gone with it
    if peer_id == host_peer_id() then
        Sync:reset()
    end
end)
