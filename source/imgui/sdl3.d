module imgui.sdl3;
// dear imgui: Platform Backend for SDL3 (*EXPERIMENTAL*)
// This needs to be used along with a Renderer (e.g. DirectX11, OpenGL3, Vulkan..)
// (Info: SDL3 is a cross-platform general purpose library for handling windows, inputs, graphics context creation, etc.)

// SDL
import bindbc.sdl;

static if (SDL_MAJOR_VERSION == 3) {
// (**IMPORTANT: SDL 3.0.0 is NOT YET RELEASED AND CURRENTLY HAS A FAST CHANGING API. THIS CODE BREAKS OFTEN AS SDL3 CHANGES.**)

// Implemented features:
//  [X] Platform: Clipboard support.
//  [X] Platform: Mouse support. Can discriminate Mouse/TouchScreen.
//  [X] Platform: Keyboard support. Since 1.87 we are using the io.AddKeyEvent() function. Pass ImGuiKey values to all key functions e.g. ImGui.IsKeyPressed(ImGuiKey.Space). [Legacy SDL_SCANCODE_* values are obsolete since 1.87 and not supported since 1.91.5]
//  [X] Platform: Gamepad support. Enabled with 'io.ConfigFlags |= ImGuiConfigFlags.NavEnableGamepad'.
//  [X] Platform: Mouse cursor shape and visibility. Disable with 'io.ConfigFlags |= ImGuiConfigFlags.NoMouseCursorChange'.

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// Learn about Dear ImGui:
// - FAQ                  https://dearimgui.com/faq
// - Getting Started      https://dearimgui.com/getting-started
// - Documentation        https://dearimgui.com/docs (same as your local docs/ folder).
// - Introduction, links and more at the top of imgui.cpp

// CHANGELOG
// (minor and older changes stripped away, please see git history for details)
//  2024-10-24: Emscripten: SDL_EVENT_MOUSE_WHEEL event doesn't require dividing by 100.0f on Emscripten.
//  2024-09-03: Update for SDL3 api changes: SDL_GetGamepads() memory ownership revert. (#7918, #7898, #7807)
//  2024-08-22: moved some OS/backend related function pointers from ImGuiIO to ImGuiPlatformIO:
//               - io.GetClipboardTextFn    -> platform_io.Platform_GetClipboardTextFn
//               - io.SetClipboardTextFn    -> platform_io.Platform_SetClipboardTextFn
//               - io.PlatformSetImeDataFn  -> platform_io.Platform_SetImeDataFn
//  2024-08-19: Storing SDL_WindowID inside ImGuiViewport.PlatformHandle instead of SDL_Window*.
//  2024-08-19: ImGui_ImplSDL3_ProcessEvent() now ignores events intended for other SDL windows. (#7853)
//  2024-07-22: Update for SDL3 api changes: SDL_GetGamepads() memory ownership change. (#7807)
//  2024-07-18: Update for SDL3 api changes: SDL_GetClipboardText() memory ownership change. (#7801)
//  2024-07-15: Update for SDL3 api changes: SDL_GetProperty() change to SDL_GetPointerProperty(). (#7794)
//  2024-07-02: Update for SDL3 api changes: SDLK_x renames and SDLK_KP_x removals (#7761, #7762).
//  2024-07-01: Update for SDL3 api changes: SDL_SetTextInputRect() changed to SDL_SetTextInputArea().
//  2024-06-26: Update for SDL3 api changes: SDL_StartTextInput()/SDL_StopTextInput()/SDL_SetTextInputRect() functions signatures.
//  2024-06-24: Update for SDL3 api changes: SDL_EVENT_KEY_DOWN/SDL_EVENT_KEY_UP contents.
//  2024-06-03; Update for SDL3 api changes: SDL_SYSTEM_CURSOR_ renames.
//  2024-05-15: Update for SDL3 api changes: SDLK_ renames.
//  2024-04-15: Inputs: Re-enable calling SDL_StartTextInput()/SDL_StopTextInput() as SDL3 no longer enables it by default and should play nicer with IME.
//  2024-02-13: Inputs: Fixed gamepad support. Handle gamepad disconnection. Added ImGui_ImplSDL3_SetGamepadMode().
//  2023-11-13: Updated for recent SDL3 API changes.
//  2023-10-05: Inputs: Added support for extra ImGuiKey values: F13 to F24 function keys, app back/forward keys.
//  2023-05-04: Fixed build on Emscripten/iOS/Android. (#6391)
//  2023-04-06: Inputs: Avoid calling SDL_StartTextInput()/SDL_StopTextInput() as they don't only pertain to IME. It's unclear exactly what their relation is to IME. (#6306)
//  2023-04-04: Inputs: Added support for io.AddMouseSourceEvent() to discriminate ImGuiMouseSource.Mouse/ImGuiMouseSource.TouchScreen. (#2702)
//  2023-02-23: Accept SDL_GetPerformanceCounter() not returning a monotonically increasing value. (#6189, #6114, #3644)
//  2023-02-07: Forked "imgui_impl_sdl2" into "imgui_impl_sdl3". Removed version checks for old feature. Refer to imgui_impl_sdl2.cpp for older changelog.

import ImGui = d_imgui.imgui;
import d_imgui.imgui_h;

import core.stdc.stdint;
import std.string : fromStringz;

enum ImGui_ImplSDL3_GamepadMode { AutoFirst, AutoAll, Manual };

enum SDL_HAS_CAPTURE_AND_GLOBAL_MOUSE = 1;

// SDL Data
struct ImGui_ImplSDL3_Data
{
    SDL_Window*             Window;
    SDL_WindowID            WindowID;
    SDL_Renderer*           Renderer;
    ulong                  Time;
    char*                   ClipboardTextData;

    // IME handling
    SDL_Window*             ImeWindow;

    // Mouse handling
    uint                  MouseWindowID;
    int                     MouseButtonsDown;
    SDL_Cursor*[ImGuiMouseCursor.COUNT]             MouseCursors;
    SDL_Cursor*             MouseLastCursor;
    int                     MousePendingLeaveFrame;
    bool                    MouseCanUseGlobalState;

    // Gamepad handling
    SDL_Gamepad*[]      Gamepads;
    ImGui_ImplSDL3_GamepadMode  GamepadMode;
    bool                        WantUpdateGamepadsList;
}

// Backend data stored in io.BackendPlatformUserData to allow support for multiple Dear ImGui contexts
// It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
// FIXME: multi-context support is not well tested and probably dysfunctional in this backend.
// FIXME: some shared resources (mouse cursor shape, gamepad) are mishandled when using multi-context.
private ImGui_ImplSDL3_Data* ImGui_ImplSDL3_GetBackendData()
{
    return ImGui.GetCurrentContext() ? cast(ImGui_ImplSDL3_Data*)ImGui.GetIO().BackendPlatformUserData : null;
}

// Functions
private const(char)* ImGui_ImplSDL3_GetClipboardText(void*)
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    if (bd.ClipboardTextData)
        SDL_free(bd.ClipboardTextData);
    const char* sdl_clipboard_text = SDL_GetClipboardText();
    bd.ClipboardTextData = sdl_clipboard_text ? SDL_strdup(sdl_clipboard_text) : NULL;
    return bd.ClipboardTextData;
}

private void ImGui_ImplSDL3_SetClipboardText(void*, const char* text)
{
    SDL_SetClipboardText(text);
}

//private void ImGui_ImplSDL3_PlatformSetImeData(void*, ImGuiViewport* viewport, ImGuiPlatformImeData* data)
//{
//    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
//    SDL_WindowID window_id = cast(SDL_WindowID)cast(intptr_t)viewport.PlatformHandle;
//    SDL_Window* window = SDL_GetWindowFromID(window_id);
//    if ((data.WantVisible == false || bd.ImeWindow != window) && bd.ImeWindow != NULL)
//    {
//        SDL_StopTextInput(bd.ImeWindow);
//        bd.ImeWindow = null;
//    }
//    if (data.WantVisible)
//    {
//        SDL_Rect r;
//        r.x = cast(int)data.InputPos.x;
//        r.y = cast(int)data.InputPos.y;
//        r.w = 1;
//        r.h = cast(int)data.InputLineHeight;
//        SDL_SetTextInputArea(window, &r, 0);
//        SDL_StartTextInput(window);
//        bd.ImeWindow = window;
//    }
//}

// Not private to allow third-party code to use that if they want to (but undocumented)
ImGuiKey ImGui_ImplSDL3_KeyEventToImGuiKey(SDL_Keycode keycode, SDL_Scancode scancode);
ImGuiKey ImGui_ImplSDL3_KeyEventToImGuiKey(SDL_Keycode keycode, SDL_Scancode scancode)
{
    // Keypad doesn't have individual key values in SDL3
    switch (scancode)
    {
        case SDL_SCANCODE_KP_0: return ImGuiKey.Keypad0;
        case SDL_SCANCODE_KP_1: return ImGuiKey.Keypad1;
        case SDL_SCANCODE_KP_2: return ImGuiKey.Keypad2;
        case SDL_SCANCODE_KP_3: return ImGuiKey.Keypad3;
        case SDL_SCANCODE_KP_4: return ImGuiKey.Keypad4;
        case SDL_SCANCODE_KP_5: return ImGuiKey.Keypad5;
        case SDL_SCANCODE_KP_6: return ImGuiKey.Keypad6;
        case SDL_SCANCODE_KP_7: return ImGuiKey.Keypad7;
        case SDL_SCANCODE_KP_8: return ImGuiKey.Keypad8;
        case SDL_SCANCODE_KP_9: return ImGuiKey.Keypad9;
        case SDL_SCANCODE_KP_PERIOD: return ImGuiKey.KeypadDecimal;
        case SDL_SCANCODE_KP_DIVIDE: return ImGuiKey.KeypadDivide;
        case SDL_SCANCODE_KP_MULTIPLY: return ImGuiKey.KeypadMultiply;
        case SDL_SCANCODE_KP_MINUS: return ImGuiKey.KeypadSubtract;
        case SDL_SCANCODE_KP_PLUS: return ImGuiKey.KeypadAdd;
        case SDL_SCANCODE_KP_ENTER: return ImGuiKey.KeypadEnter;
        case SDL_SCANCODE_KP_EQUALS: return ImGuiKey.KeypadEqual;
        default: break;
    }
    switch (keycode)
    {
        case SDLK_TAB: return ImGuiKey.Tab;
        case SDLK_LEFT: return ImGuiKey.LeftArrow;
        case SDLK_RIGHT: return ImGuiKey.RightArrow;
        case SDLK_UP: return ImGuiKey.UpArrow;
        case SDLK_DOWN: return ImGuiKey.DownArrow;
        case SDLK_PAGEUP: return ImGuiKey.PageUp;
        case SDLK_PAGEDOWN: return ImGuiKey.PageDown;
        case SDLK_HOME: return ImGuiKey.Home;
        case SDLK_END: return ImGuiKey.End;
        case SDLK_INSERT: return ImGuiKey.Insert;
        case SDLK_DELETE: return ImGuiKey.Delete;
        case SDLK_BACKSPACE: return ImGuiKey.Backspace;
        case SDLK_SPACE: return ImGuiKey.Space;
        case SDLK_RETURN: return ImGuiKey.Enter;
        case SDLK_ESCAPE: return ImGuiKey.Escape;
        case SDLK_APOSTROPHE: return ImGuiKey.Apostrophe;
        case SDLK_COMMA: return ImGuiKey.Comma;
        case SDLK_MINUS: return ImGuiKey.Minus;
        case SDLK_PERIOD: return ImGuiKey.Period;
        case SDLK_SLASH: return ImGuiKey.Slash;
        case SDLK_SEMICOLON: return ImGuiKey.Semicolon;
        case SDLK_EQUALS: return ImGuiKey.Equal;
        case SDLK_LEFTBRACKET: return ImGuiKey.LeftBracket;
        case SDLK_BACKSLASH: return ImGuiKey.Backslash;
        case SDLK_RIGHTBRACKET: return ImGuiKey.RightBracket;
        case SDLK_GRAVE: return ImGuiKey.GraveAccent;
        case SDLK_CAPSLOCK: return ImGuiKey.CapsLock;
        case SDLK_SCROLLLOCK: return ImGuiKey.ScrollLock;
        case SDLK_NUMLOCKCLEAR: return ImGuiKey.NumLock;
        case SDLK_PRINTSCREEN: return ImGuiKey.PrintScreen;
        case SDLK_PAUSE: return ImGuiKey.Pause;
        case SDLK_LCTRL: return ImGuiKey.LeftCtrl;
        case SDLK_LSHIFT: return ImGuiKey.LeftShift;
        case SDLK_LALT: return ImGuiKey.LeftAlt;
        case SDLK_LGUI: return ImGuiKey.LeftSuper;
        case SDLK_RCTRL: return ImGuiKey.RightCtrl;
        case SDLK_RSHIFT: return ImGuiKey.RightShift;
        case SDLK_RALT: return ImGuiKey.RightAlt;
        case SDLK_RGUI: return ImGuiKey.RightSuper;
        case SDLK_APPLICATION: return ImGuiKey.Menu;
        case SDLK_0: return ImGuiKey._0;
        case SDLK_1: return ImGuiKey._1;
        case SDLK_2: return ImGuiKey._2;
        case SDLK_3: return ImGuiKey._3;
        case SDLK_4: return ImGuiKey._4;
        case SDLK_5: return ImGuiKey._5;
        case SDLK_6: return ImGuiKey._6;
        case SDLK_7: return ImGuiKey._7;
        case SDLK_8: return ImGuiKey._8;
        case SDLK_9: return ImGuiKey._9;
        case SDLK_A: return ImGuiKey.A;
        case SDLK_B: return ImGuiKey.B;
        case SDLK_C: return ImGuiKey.C;
        case SDLK_D: return ImGuiKey.D;
        case SDLK_E: return ImGuiKey.E;
        case SDLK_F: return ImGuiKey.F;
        case SDLK_G: return ImGuiKey.G;
        case SDLK_H: return ImGuiKey.H;
        case SDLK_I: return ImGuiKey.I;
        case SDLK_J: return ImGuiKey.J;
        case SDLK_K: return ImGuiKey.K;
        case SDLK_L: return ImGuiKey.L;
        case SDLK_M: return ImGuiKey.M;
        case SDLK_N: return ImGuiKey.N;
        case SDLK_O: return ImGuiKey.O;
        case SDLK_P: return ImGuiKey.P;
        case SDLK_Q: return ImGuiKey.Q;
        case SDLK_R: return ImGuiKey.R;
        case SDLK_S: return ImGuiKey.S;
        case SDLK_T: return ImGuiKey.T;
        case SDLK_U: return ImGuiKey.U;
        case SDLK_V: return ImGuiKey.V;
        case SDLK_W: return ImGuiKey.W;
        case SDLK_X: return ImGuiKey.X;
        case SDLK_Y: return ImGuiKey.Y;
        case SDLK_Z: return ImGuiKey.Z;
        case SDLK_F1: return ImGuiKey.F1;
        case SDLK_F2: return ImGuiKey.F2;
        case SDLK_F3: return ImGuiKey.F3;
        case SDLK_F4: return ImGuiKey.F4;
        case SDLK_F5: return ImGuiKey.F5;
        case SDLK_F6: return ImGuiKey.F6;
        case SDLK_F7: return ImGuiKey.F7;
        case SDLK_F8: return ImGuiKey.F8;
        case SDLK_F9: return ImGuiKey.F9;
        case SDLK_F10: return ImGuiKey.F10;
        case SDLK_F11: return ImGuiKey.F11;
        case SDLK_F12: return ImGuiKey.F12;
        //case SDLK_F13: return ImGuiKey.F13;
        //case SDLK_F14: return ImGuiKey.F14;
        //case SDLK_F15: return ImGuiKey.F15;
        //case SDLK_F16: return ImGuiKey.F16;
        //case SDLK_F17: return ImGuiKey.F17;
        //case SDLK_F18: return ImGuiKey.F18;
        //case SDLK_F19: return ImGuiKey.F19;
        //case SDLK_F20: return ImGuiKey.F20;
        //case SDLK_F21: return ImGuiKey.F21;
        //case SDLK_F22: return ImGuiKey.F22;
        //case SDLK_F23: return ImGuiKey.F23;
        //case SDLK_F24: return ImGuiKey.F24;
        //case SDLK_AC_BACK: return ImGuiKey.AppBack;
        //case SDLK_AC_FORWARD: return ImGuiKey.AppForward;
        default: break;
    }
    return ImGuiKey.None;
}

private void ImGui_ImplSDL3_UpdateKeyModifiers(SDL_Keymod sdl_key_mods)
{
    ImGuiIO* io = &ImGui.GetIO();
    io.AddKeyEvent(ImGuiMod.Ctrl, (sdl_key_mods & SDL_KMOD_CTRL) != 0);
    io.AddKeyEvent(ImGuiMod.Shift, (sdl_key_mods & SDL_KMOD_SHIFT) != 0);
    io.AddKeyEvent(ImGuiMod.Alt, (sdl_key_mods & SDL_KMOD_ALT) != 0);
    io.AddKeyEvent(ImGuiMod.Super, (sdl_key_mods & SDL_KMOD_GUI) != 0);
}


private ImGuiViewport* ImGui_ImplSDL3_GetViewportForWindowID(SDL_WindowID window_id)
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    return (window_id == bd.WindowID) ? ImGui.GetMainViewport() : NULL;
}

// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
// If you have multiple SDL events and some of them are not meant to be used by dear imgui, you may need to filter events based on their windowID field.
bool ImGui_ImplSDL3_ProcessEvent(const SDL_Event* event)
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    IM_ASSERT(bd != null && "Context or backend not initialized! Did you call ImGui_ImplSDL3_Init()?");
    ImGuiIO* io = &ImGui.GetIO();

    switch (event.type)
    {
        case SDL_EVENT_MOUSE_MOTION:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.motion.windowID) == NULL)
                return false;
            auto mouse_pos = ImVec2(cast(float)event.motion.x, cast(float)event.motion.y);
            io.AddMouseSourceEvent(event.motion.which == SDL_TOUCH_MOUSEID ? ImGuiMouseSource.TouchScreen : ImGuiMouseSource.Mouse);
            io.AddMousePosEvent(mouse_pos.x, mouse_pos.y);
            return true;
        }
        case SDL_EVENT_MOUSE_WHEEL:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.wheel.windowID) == NULL)
                return false;
            //IMGUI_DEBUG_LOG("wheel %.2f %.2f, precise %.2f %.2f\n", (float)event.wheel.x, (float)event.wheel.y, event.wheel.preciseX, event.wheel.preciseY);
            float wheel_x = -event.wheel.x;
            float wheel_y = event.wheel.y;
            io.AddMouseSourceEvent(event.wheel.which == SDL_TOUCH_MOUSEID ? ImGuiMouseSource.TouchScreen : ImGuiMouseSource.Mouse);
            io.AddMouseWheelEvent(wheel_x, wheel_y);
            return true;
        }
        case SDL_EVENT_MOUSE_BUTTON_DOWN:
        case SDL_EVENT_MOUSE_BUTTON_UP:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.button.windowID) == NULL)
                return false;
            int mouse_button = -1;
            if (cast(ubyte)event.button.button == SDL_BUTTON_LEFT) { mouse_button = 0; }
            if (cast(ubyte)event.button.button == SDL_BUTTON_RIGHT) { mouse_button = 1; }
            if (cast(ubyte)event.button.button == SDL_BUTTON_MIDDLE) { mouse_button = 2; }
            if (cast(ubyte)event.button.button == SDL_BUTTON_X1) { mouse_button = 3; }
            if (cast(ubyte)event.button.button == SDL_BUTTON_X2) { mouse_button = 4; }
            if (mouse_button == -1)
                break;
            io.AddMouseSourceEvent(event.button.which == SDL_TOUCH_MOUSEID ? ImGuiMouseSource.TouchScreen : ImGuiMouseSource.Mouse);
            io.AddMouseButtonEvent(mouse_button, (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN));
            bd.MouseButtonsDown = (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN) ? (bd.MouseButtonsDown | (1 << mouse_button)) : (bd.MouseButtonsDown & ~(1 << mouse_button));
            return true;
        }
        case SDL_EVENT_TEXT_INPUT:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.text.windowID) == NULL)
                return false;
            io.AddInputCharactersUTF8(cast(immutable)event.text.text.fromStringz);
            return true;
        }
        case SDL_EVENT_KEY_DOWN:
        case SDL_EVENT_KEY_UP:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.key.windowID) == NULL)
                return false;
            //IMGUI_DEBUG_LOG("SDL_EVENT_KEY_%d: key=%d, scancode=%d, mod=%X\n", (event.type == SDL_EVENT_KEY_DOWN) ? "DOWN" : "UP", event.key.key, event.key.scancode, event.key.mod);
            ImGui_ImplSDL3_UpdateKeyModifiers(cast(SDL_Keymod)event.key.mod);
            ImGuiKey key = ImGui_ImplSDL3_KeyEventToImGuiKey(event.key.key, event.key.scancode);
            io.AddKeyEvent(key, (event.type == SDL_EVENT_KEY_DOWN));
            io.SetKeyEventNativeData(key, event.key.key, event.key.scancode, event.key.scancode); // To support legacy indexing (<1.87 user code). Legacy backend uses SDLK_*** as indices to IsKeyXXX() functions.
            return true;
        }
        case SDL_EVENT_WINDOW_MOUSE_ENTER:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.window.windowID) == NULL)
                return false;
            bd.MouseWindowID = event.window.windowID;
            bd.MousePendingLeaveFrame = 0;
            return true;
        }
        // - In some cases, when detaching a window from main viewport SDL may send SDL_WINDOWEVENT_ENTER one frame too late,
        //   causing SDL_WINDOWEVENT_LEAVE on previous frame to interrupt drag operation by clear mouse position. This is why
        //   we delay process the SDL_WINDOWEVENT_LEAVE events by one frame. See issue #5012 for details.
        // FIXME: Unconfirmed whether this is still needed with SDL3.
        case SDL_EVENT_WINDOW_MOUSE_LEAVE:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.window.windowID) == NULL)
                return false;
            bd.MousePendingLeaveFrame = ImGui.GetFrameCount() + 1;
            return true;
        }
        case SDL_EVENT_WINDOW_FOCUS_GAINED:
        case SDL_EVENT_WINDOW_FOCUS_LOST:
        {
            if (ImGui_ImplSDL3_GetViewportForWindowID(event.window.windowID) == NULL)
                return false;
            io.AddFocusEvent(event.type == SDL_EVENT_WINDOW_FOCUS_GAINED);
            return true;
        }
        case SDL_EVENT_GAMEPAD_ADDED:
        case SDL_EVENT_GAMEPAD_REMOVED:
        {
            bd.WantUpdateGamepadsList = true;
            return true;
        }
    	default: break;
    }
    return false;
}

private void ImGui_ImplSDL3_SetupPlatformHandles(ImGuiViewport* viewport, SDL_Window* window)
{
    //viewport.PlatformHandle = cast(void*)cast(intptr_t)SDL_GetWindowID(window);
    viewport.PlatformHandleRaw = null;
version(Windows) {
	import core.sys.windows.windows : HWND;
    viewport.PlatformHandleRaw = cast(HWND)SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_WIN32_HWND_POINTER, null);
} else version(macOS) {
    viewport.PlatformHandleRaw = SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, null);
}
}

private bool ImGui_ImplSDL3_Init(SDL_Window* window, SDL_Renderer* renderer, void* sdl_gl_context)
{
    ImGuiIO* io = &ImGui.GetIO();
    IMGUI_CHECKVERSION();
    IM_ASSERT(io.BackendPlatformUserData == null && "Already initialized a platform backend!");
    IM_UNUSED(sdl_gl_context); // Unused in this branch

    // Check and store if we are on a SDL backend that supports global mouse position
    // ("wayland" and "rpi" don't support it, but we chose to use a white-list instead of a black-list)
    bool mouse_can_use_global_state = false;
static if(SDL_HAS_CAPTURE_AND_GLOBAL_MOUSE) {
    const char* sdl_backend = SDL_GetCurrentVideoDriver();
    const string[] global_mouse_whitelist = ["windows", "cocoa", "x11", "DIVE", "VMAN"];
    for (int n = 0; n < global_mouse_whitelist.length; n++)
        if (sdl_backend.fromStringz == global_mouse_whitelist[n])
            mouse_can_use_global_state = true;
}

    // Setup backend capabilities flags
    ImGui_ImplSDL3_Data* bd = IM_NEW!ImGui_ImplSDL3_Data();
    io.BackendPlatformUserData = cast(void*)bd;
    io.BackendPlatformName = "imgui_impl_sdl3";
    io.BackendFlags |= ImGuiBackendFlags.HasMouseCursors;           // We can honor GetMouseCursor() values (optional)
    io.BackendFlags |= ImGuiBackendFlags.HasSetMousePos;            // We can honor io.WantSetMousePos requests (optional, rarely used)

    bd.Window = window;
    bd.WindowID = SDL_GetWindowID(window);
    bd.Renderer = renderer;
    bd.MouseCanUseGlobalState = mouse_can_use_global_state;

    //ImGuiPlatformIO* platform_io = &ImGui.GetPlatformIO();
    //platform_io.Platform_SetClipboardTextFn = ImGui_ImplSDL3_SetClipboardText;
    //platform_io.Platform_GetClipboardTextFn = ImGui_ImplSDL3_GetClipboardText;
    //platform_io.Platform_SetImeDataFn = ImGui_ImplSDL3_PlatformSetImeData;

    // Gamepad handling
    bd.GamepadMode = ImGui_ImplSDL3_GamepadMode.AutoFirst;
    bd.WantUpdateGamepadsList = true;

    // Load mouse cursors
    bd.MouseCursors[ImGuiMouseCursor.Arrow] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_DEFAULT);
    bd.MouseCursors[ImGuiMouseCursor.TextInput] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_TEXT);
    bd.MouseCursors[ImGuiMouseCursor.ResizeAll] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_MOVE);
    bd.MouseCursors[ImGuiMouseCursor.ResizeNS] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NS_RESIZE);
    bd.MouseCursors[ImGuiMouseCursor.ResizeEW] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_EW_RESIZE);
    bd.MouseCursors[ImGuiMouseCursor.ResizeNESW] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NESW_RESIZE);
    bd.MouseCursors[ImGuiMouseCursor.ResizeNWSE] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NWSE_RESIZE);
    bd.MouseCursors[ImGuiMouseCursor.Hand] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_POINTER);
    bd.MouseCursors[ImGuiMouseCursor.NotAllowed] = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NOT_ALLOWED);

    // Set platform dependent data in viewport
    // Our mouse update function expect PlatformHandle to be filled for the main viewport
    ImGuiViewport* main_viewport = ImGui.GetMainViewport();
    ImGui_ImplSDL3_SetupPlatformHandles(main_viewport, window);

    // From 2.0.5: Set SDL hint to receive mouse click events on window focus, otherwise SDL doesn't emit the event.
    // Without this, when clicking to gain focus, our widgets wouldn't activate even though they showed as hovered.
    // (This is unfortunately a global SDL setting, so enabling it might have a side-effect on your application.
    // It is unlikely to make a difference, but if your app absolutely needs to ignore the initial on-focus click:
    // you can ignore SDL_EVENT_MOUSE_BUTTON_DOWN events coming right after a SDL_WINDOWEVENT_FOCUS_GAINED)
    SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, "1");

    // From 2.0.22: Disable auto-capture, this is preventing drag and drop across multiple windows (see #5710)
    SDL_SetHint(SDL_HINT_MOUSE_AUTO_CAPTURE, "0");

    return true;
}

bool ImGui_ImplSDL3_InitForOpenGL(SDL_Window* window, void* sdl_gl_context)
{
    IM_UNUSED(sdl_gl_context); // Viewport branch will need this.
    return ImGui_ImplSDL3_Init(window, null, sdl_gl_context);
}

bool ImGui_ImplSDL3_InitForVulkan(SDL_Window* window)
{
    return ImGui_ImplSDL3_Init(window, null, null);
}

bool ImGui_ImplSDL3_InitForD3D(SDL_Window* window)
{
version(Windows) {} else {
    IM_ASSERT(0 && "Unsupported");
}
    return ImGui_ImplSDL3_Init(window, null, null);
}

bool ImGui_ImplSDL3_InitForMetal(SDL_Window* window)
{
    return ImGui_ImplSDL3_Init(window, null, null);
}

bool ImGui_ImplSDL3_InitForSDLRenderer(SDL_Window* window, SDL_Renderer* renderer)
{
    return ImGui_ImplSDL3_Init(window, renderer, null);
}

bool ImGui_ImplSDL3_InitForOther(SDL_Window* window)
{
    return ImGui_ImplSDL3_Init(window, null, null);
}

private void ImGui_ImplSDL3_CloseGamepads();

void ImGui_ImplSDL3_Shutdown()
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    IM_ASSERT(bd != null && "No platform backend to shutdown, or already shutdown?");
    ImGuiIO* io = &ImGui.GetIO();

    if (bd.ClipboardTextData)
        SDL_free(bd.ClipboardTextData);
    for (ImGuiMouseCursor cursor_n = cast(ImGuiMouseCursor)0; cursor_n < ImGuiMouseCursor.COUNT; cursor_n++)
        SDL_DestroyCursor(bd.MouseCursors[cursor_n]);
    ImGui_ImplSDL3_CloseGamepads();

    io.BackendPlatformName = null;
    io.BackendPlatformUserData = null;
    io.BackendFlags &= ~(ImGuiBackendFlags.HasMouseCursors | ImGuiBackendFlags.HasSetMousePos | ImGuiBackendFlags.HasGamepad);
    IM_DELETE(bd);
}

private void ImGui_ImplSDL3_UpdateMouseData()
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    ImGuiIO* io = &ImGui.GetIO();

    // We forward mouse input when hovered or captured (via SDL_EVENT_MOUSE_MOTION) or when focused (below)
static if (SDL_HAS_CAPTURE_AND_GLOBAL_MOUSE) {
    // SDL_CaptureMouse() let the OS know e.g. that our imgui drag outside the SDL window boundaries shouldn't e.g. trigger other operations outside
    SDL_CaptureMouse(bd.MouseButtonsDown != 0);
    SDL_Window* focused_window = SDL_GetKeyboardFocus();
    const bool is_app_focused = (bd.Window == focused_window);
} else {
    SDL_Window* focused_window = bd.Window;
    const bool is_app_focused = (SDL_GetWindowFlags(bd.Window) & SDL_WINDOW_INPUT_FOCUS) != 0; // SDL 2.0.3 and non-windowed systems: single-viewport only
}
    if (is_app_focused)
    {
        // (Optional) Set OS mouse position from Dear ImGui if requested (rarely used, only when io.ConfigNavMoveSetMousePos is enabled by user)
        if (io.WantSetMousePos)
            SDL_WarpMouseInWindow(bd.Window, io.MousePos.x, io.MousePos.y);

        // (Optional) Fallback to provide mouse position when focused (SDL_EVENT_MOUSE_MOTION already provides this when hovered or captured)
        if (bd.MouseCanUseGlobalState && bd.MouseButtonsDown == 0)
        {
            // Single-viewport mode: mouse position in client window coordinates (io.MousePos is (0,0) when the mouse is on the upper-left corner of the app window)
            float mouse_x_global, mouse_y_global;
            int window_x, window_y;
            SDL_GetGlobalMouseState(&mouse_x_global, &mouse_y_global);
            SDL_GetWindowPosition(focused_window, &window_x, &window_y);
            io.AddMousePosEvent(mouse_x_global - window_x, mouse_y_global - window_y);
        }
    }
}

private void ImGui_ImplSDL3_UpdateMouseCursor()
{
    ImGuiIO* io = &ImGui.GetIO();
    if (io.ConfigFlags & ImGuiConfigFlags.NoMouseCursorChange)
        return;
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();

    ImGuiMouseCursor imgui_cursor = ImGui.GetMouseCursor();
    if (io.MouseDrawCursor || imgui_cursor == ImGuiMouseCursor.None)
    {
        // Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        SDL_HideCursor();
    }
    else
    {
        // Show OS mouse cursor
        SDL_Cursor* expected_cursor = bd.MouseCursors[imgui_cursor] ? bd.MouseCursors[imgui_cursor] : bd.MouseCursors[ImGuiMouseCursor.Arrow];
        if (bd.MouseLastCursor != expected_cursor)
        {
            SDL_SetCursor(expected_cursor); // SDL function doesn't have an early out (see #6113)
            bd.MouseLastCursor = expected_cursor;
        }
        SDL_ShowCursor();
    }
}

private void ImGui_ImplSDL3_CloseGamepads()
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    if (bd.GamepadMode != ImGui_ImplSDL3_GamepadMode.Manual)
        foreach (gamepad; bd.Gamepads)
            SDL_CloseGamepad(gamepad);
    bd.Gamepads = [];
}

void ImGui_ImplSDL3_SetGamepadMode(ImGui_ImplSDL3_GamepadMode mode, SDL_Gamepad** manual_gamepads_array, int manual_gamepads_count)
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    ImGui_ImplSDL3_CloseGamepads();
    if (mode == ImGui_ImplSDL3_GamepadMode.Manual)
    {
        IM_ASSERT(manual_gamepads_array != null && manual_gamepads_count > 0);
        for (int n = 0; n < manual_gamepads_count; n++)
            bd.Gamepads ~= manual_gamepads_array[n];
    }
    else
    {
        IM_ASSERT(manual_gamepads_array == null && manual_gamepads_count <= 0);
        bd.WantUpdateGamepadsList = true;
    }
    bd.GamepadMode = mode;
}

private void ImGui_ImplSDL3_UpdateGamepadButton(ImGui_ImplSDL3_Data* bd, ref ImGuiIO io, ImGuiKey key, SDL_GamepadButton button_no)
{
    bool merged_value = false;
    foreach (gamepad; bd.Gamepads)
        merged_value |= SDL_GetGamepadButton(gamepad, button_no) != 0;
    io.AddKeyEvent(key, merged_value);
}

private float Saturate(float v) { return v < 0.0f ? 0.0f : v  > 1.0f ? 1.0f : v; }
private void ImGui_ImplSDL3_UpdateGamepadAnalog(ImGui_ImplSDL3_Data* bd, ref ImGuiIO io, ImGuiKey key, SDL_GamepadAxis axis_no, float v0, float v1)
{
    float merged_value = 0.0f;
    foreach (gamepad; bd.Gamepads)
    {
        float vn = Saturate((float)(SDL_GetGamepadAxis(gamepad, axis_no) - v0) / (float)(v1 - v0));
        if (merged_value < vn)
            merged_value = vn;
    }
    io.AddKeyAnalogEvent(key, merged_value > 0.1f, merged_value);
}

private void ImGui_ImplSDL3_UpdateGamepads()
{
    ImGuiIO* io = &ImGui.GetIO();
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();

    // Update list of gamepads to use
    if (bd.WantUpdateGamepadsList && bd.GamepadMode != ImGui_ImplSDL3_GamepadMode.Manual)
    {
        ImGui_ImplSDL3_CloseGamepads();
        int sdl_gamepads_count = 0;
        SDL_JoystickID* sdl_gamepads = SDL_GetGamepads(&sdl_gamepads_count);
        for (int n = 0; n < sdl_gamepads_count; n++)
            if (SDL_Gamepad* gamepad = SDL_OpenGamepad(sdl_gamepads[n]))
            {
                bd.Gamepads ~= gamepad;
                if (bd.GamepadMode == ImGui_ImplSDL3_GamepadMode.AutoFirst)
                    break;
            }
        bd.WantUpdateGamepadsList = false;
        SDL_free(sdl_gamepads);
    }

    // FIXME: Technically feeding gamepad shouldn't depend on this now that they are regular inputs.
    if ((io.ConfigFlags & ImGuiConfigFlags.NavEnableGamepad) == 0)
        return;
    io.BackendFlags &= ~ImGuiBackendFlags.HasGamepad;
    if (bd.Gamepads.length == 0)
        return;
    io.BackendFlags |= ImGuiBackendFlags.HasGamepad;

    // Update gamepad inputs
    const int thumb_dead_zone = 8000;           // SDL_gamepad.h suggests using this value.
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadStart,       SDL_GAMEPAD_BUTTON_START);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadBack,        SDL_GAMEPAD_BUTTON_BACK);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadFaceLeft,    SDL_GAMEPAD_BUTTON_WEST);           // Xbox X, PS Square
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadFaceRight,   SDL_GAMEPAD_BUTTON_EAST);           // Xbox B, PS Circle
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadFaceUp,      SDL_GAMEPAD_BUTTON_NORTH);          // Xbox Y, PS Triangle
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadFaceDown,    SDL_GAMEPAD_BUTTON_SOUTH);          // Xbox A, PS Cross
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadDpadLeft,    SDL_GAMEPAD_BUTTON_DPAD_LEFT);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadDpadRight,   SDL_GAMEPAD_BUTTON_DPAD_RIGHT);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadDpadUp,      SDL_GAMEPAD_BUTTON_DPAD_UP);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadDpadDown,    SDL_GAMEPAD_BUTTON_DPAD_DOWN);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadL1,          SDL_GAMEPAD_BUTTON_LEFT_SHOULDER);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadR1,          SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadL2,          SDL_GAMEPAD_AXIS_LEFT_TRIGGER,  0.0f, 32767);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadR2,          SDL_GAMEPAD_AXIS_RIGHT_TRIGGER, 0.0f, 32767);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadL3,          SDL_GAMEPAD_BUTTON_LEFT_STICK);
    ImGui_ImplSDL3_UpdateGamepadButton(bd, *io, ImGuiKey.GamepadR3,          SDL_GAMEPAD_BUTTON_RIGHT_STICK);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadLStickLeft,  SDL_GAMEPAD_AXIS_LEFTX,  -thumb_dead_zone, -32768);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadLStickRight, SDL_GAMEPAD_AXIS_LEFTX,  +thumb_dead_zone, +32767);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadLStickUp,    SDL_GAMEPAD_AXIS_LEFTY,  -thumb_dead_zone, -32768);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadLStickDown,  SDL_GAMEPAD_AXIS_LEFTY,  +thumb_dead_zone, +32767);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadRStickLeft,  SDL_GAMEPAD_AXIS_RIGHTX, -thumb_dead_zone, -32768);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadRStickRight, SDL_GAMEPAD_AXIS_RIGHTX, +thumb_dead_zone, +32767);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadRStickUp,    SDL_GAMEPAD_AXIS_RIGHTY, -thumb_dead_zone, -32768);
    ImGui_ImplSDL3_UpdateGamepadAnalog(bd, *io, ImGuiKey.GamepadRStickDown,  SDL_GAMEPAD_AXIS_RIGHTY, +thumb_dead_zone, +32767);
}

void ImGui_ImplSDL3_NewFrame()
{
    ImGui_ImplSDL3_Data* bd = ImGui_ImplSDL3_GetBackendData();
    IM_ASSERT(bd != null && "Context or backend not initialized! Did you call ImGui_ImplSDL3_Init()?");
    ImGuiIO* io = &ImGui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    int w, h;
    int display_w, display_h;
    SDL_GetWindowSize(bd.Window, &w, &h);
    if (SDL_GetWindowFlags(bd.Window) & SDL_WINDOW_MINIMIZED)
        w = h = 0;
    SDL_GetWindowSizeInPixels(bd.Window, &display_w, &display_h);
    io.DisplaySize = ImVec2(cast(float)w, cast(float)h);
    if (w > 0 && h > 0)
        io.DisplayFramebufferScale = ImVec2(cast(float)display_w / w, cast(float)display_h / h);

    // Setup time step (we don't use SDL_GetTicks() because it is using millisecond resolution)
    // (Accept SDL_GetPerformanceCounter() not returning a monotonically increasing value. Happens in VMs and Emscripten, see #6189, #6114, #3644)
    static ulong frequency;
    if (frequency == 0) {
    	frequency = SDL_GetPerformanceFrequency();
    }
    ulong current_time = SDL_GetPerformanceCounter();
    if (current_time <= bd.Time)
        current_time = bd.Time + 1;
    io.DeltaTime = bd.Time > 0 ? cast(float)(cast(double)(current_time - bd.Time) / frequency) : cast(float)(1.0f / 60.0f);
    bd.Time = current_time;

    if (bd.MousePendingLeaveFrame && bd.MousePendingLeaveFrame >= ImGui.GetFrameCount() && bd.MouseButtonsDown == 0)
    {
        bd.MouseWindowID = 0;
        bd.MousePendingLeaveFrame = 0;
        io.AddMousePosEvent(-FLT_MAX, -FLT_MAX);
    }

    ImGui_ImplSDL3_UpdateMouseData();
    ImGui_ImplSDL3_UpdateMouseCursor();

    // Update game controllers (if enabled and available)
    ImGui_ImplSDL3_UpdateGamepads();
}

//-----------------------------------------------------------------------------
}
