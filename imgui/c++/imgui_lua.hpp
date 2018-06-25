//
//  imgui_lua.hpp
//  imguix
//
//  Created by Jimmy Yin on 4/17/16.
//
// NOTE: This lua binding is using for cocos2d-x

#ifndef imgui_lua_hpp
#define imgui_lua_hpp

#include "CCIMGUI.h"

#if IMGUI_LUA > 0

#if __cplusplus
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#if __cplusplus
}
#endif
int luaopen_imgui(lua_State *L);

#endif // IMGUI_LUA

#endif /* imgui_lua_hpp */
