--!A cross-platform terminal ui library based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-2020, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        bit.lua
--

-- define module: bit
local bit = bit or {}

-- bit/and operation
function bit.band(a, b)
    return a & b
end

-- bit/or operation
function bit.bor(a, b)
    return a | b
end

-- bit/xor operation
function bit.bxor(a, b)
    return a ~ b
end

-- load bit module
return bit
