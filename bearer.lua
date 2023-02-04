-----------------------
-- JWT Verification ---
-----------------------

local jwt = require "resty.jwt"

-- first try to find JWT token as url parameter e.g. ?token=BLAH
local token = ngx.var.arg_token

-- next try to find JWT token as Cookie e.g. token=BLAH
if token == nil then
    token = ngx.var.cookie_token
end

-- try to find JWT token in Authorization header Bearer string
if token == nil then
    local auth_header = ngx.var.http_Authorization
    if auth_header then
        local firstIndex, lastIndex, _token = string.find(auth_header, "Bearer%s+(.+)");
        token = _token;
    end
end

-- finally, if still no JWT token, kick out an error and exit
if token == nil then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.say("{\"error\": \"missing JWT token or Authorization header\"}")
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- validate any specific claims you need here
-- https://github.com/SkyLothar/lua-resty-jwt#jwt-validators
local validators = require "resty.jwt-validators"
local claim_spec = {
    -- validators.set_system_leeway(15), -- time in seconds
    -- exp = validators.is_not_expired(),
    -- iat = validators.is_not_before(),
    -- iss = validators.opt_matches("^http[s]?://yourdomain.auth0.com/$"),
    -- sub = validators.opt_matches("^[0-9]+$"),
    -- name = validators.equals_any_of({ "John Doe", "Mallory", "Alice", "Bob" }),
}


local jwt_obj = jwt:load_jwt(token)

-- make sure to set and put "env JWT_SECRET;" in nginx.conf
-- local jwt_obj = jwt:verify(os.getenv("JWT_SECRET"), token, claim_spec)
-- if not jwt_obj["verified"] then
--     ngx.status = ngx.HTTP_UNAUTHORIZED
--     ngx.log(ngx.WARN, jwt_obj.reason)
--     ngx.header.content_type = "application/json; charset=utf-8"
--     ngx.say("{\"error\": \"" .. jwt_obj.reason .. "\"}")
--     ngx.exit(ngx.HTTP_UNAUTHORIZED)
-- end

-- optionally set Authorization header Bearer token style regardless of how token received
-- if you want to forward it by setting your nginx.conf something like:
--     proxy_set_header Authorization $http_authorization;`

-----------------
-- Debug Code ---
-----------------
-- if true then
--     ngx.header['J-Status'] = ngx.var.request_uri;
--     return
-- end

------------------------
-- Configurable vars ---
------------------------
local user = ${USER};
local password = ${PASSWORD};
local authorization = ${AUTHORIZATION};
local subscribe_uri = "wss://${MATERIALIZE_IP}:443/api/experimental/sql";
local queries = ${QUERIES};

local query = queries[ngx.var.arg_query];
local params = jwt_obj["payload"]["sub"];
local sub = jwt_obj["payload"]["sub"];
local snapshot = queries[ngx.var.arg_snapshot];
local progress = queries[ngx.var.arg_progress];

if string.find(ngx.var.request_uri, "^/subscribe") ~= nil then
    -----------------------
    -- Set Up Subscribe ---
    -----------------------

    -----------------------
    -- WebSocket Client ---
    --------------------------------------------------------------------------------
    -- It creates a new WebSocket client and subscribes to a query in Materialize. |
    --------------------------------------------------------------------------------
    local client = require "resty.websocket.client"
    local wb, err = client:new()

    local ok, err = wb:connect(subscribe_uri)

    if not ok then
        ngx.header['X-Error'] = err;
        ngx.say("failed to connect: " .. err)
        return
    end

    local bytes, err = wb:send_text(string.format("{ \"user\": \"%s\", \"password\": \"%s\"}", user, password));
    if not bytes then
        ngx.say("failed to send frame: ", err)
        return
    end

    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to receive the frame: ", err)
        return
    end

    -- TODO: Params not working in WebSockets
    -- local subscribe_query = string.format("{ \"queries\" : [{ \"query\": \"SUBSCRIBE(%s)\", \"params\": [\"%s\"] }] }", query, params);

    --------------------------------------------------------------
    -- Format query. Replaces "$1" with the `sub` from the JWT ---
    --------------------------------------------------------------
    local replace_query, r = string.gsub(query, "$1", string.format("'%s'", sub));
    local subscribe_query = string.format("{ \"query\": \"SUBSCRIBE(%s) WITH (PROGRESS, SNAPSHOT)\" }", replace_query);

    local bytes, err = wb:send_text(subscribe_query)
    if not bytes then
        ngx.say("failed to send frame: ", err)
        return
    end

    ------------------------
    --- WebSocket Server ---
    ------------------------
    ----------------------------------------------------------------------------
    -- It communicates the results from the WebSocket client to the requester. |
    ----------------------------------------------------------------------------
    local server = require "resty.websocket.server"

    local function subscribe(ws)
    while true do
        local data, typ, err = wb:recv_frame()
        -- TODO: Error handling
        -- if not data then
            -- ngx.say("failed to receive the frame: ", err)
            -- continue
        -- end

        if data then
            ws:send_text(data, typ)
        end
    end
    end

    local ws, err = server:new{ timeout = 30000, max_payload_len = 65535 }

    ngx.thread.spawn(subscribe, ws)

    while true do
        local bytes, typ, err = ws:recv_frame()
        if ws.fatal then return
        elseif not bytes then
            ws:send_ping()
        elseif typ == "close" then
            ws:send_close()
        elseif typ == "text"  then
            wb:send_text(bytes)
        end
    end

    ws:send_close()
    return
else
    -------------------
    -- Set Up query ---
    -------------------
    local body = string.format("{ \"queries\": [{ \"query\": \"%s\", \"params\": [\"%s\"] }] }", query, params);

    -------------------------------
    -- Materialize Verification ---
    -------------------------------
    ngx.req.set_header("Authorization", authorization)
    ngx.req.set_header("Content-Type", "application/json")

    -- Must read the body before setting it
    ngx.req.read_body();
    ngx.req.set_body_data(body);
    return;
end
