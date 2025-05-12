package win32_wallpaper_window

import win "core:sys/windows"
import gl "vendor:opengl"
import "core:fmt"

enum_func :: proc "stdcall" (hwnd: win.HWND, lparam: win.LPARAM) -> win.BOOL {
    defview := win.FindWindowExW(hwnd, nil, win.L("SHELLDLL_DefView"), nil)
    if defview != nil {
        workerw_ptr : ^win.HWND = auto_cast uintptr(lparam)
        workerw_ptr^ = win.FindWindowExW(nil, hwnd, win.L("WorkerW"), nil)
    }
    return true
}

main :: proc() {
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))
	assert(instance != nil, "Failed to fetch current instance")
	class_name := win.L("Windows Window")

	cls := win.WNDCLASSW {
		lpfnWndProc = win_proc,
		lpszClassName = class_name,
		hInstance = instance,
		hCursor = win.LoadCursorA(nil, win.IDC_ARROW),
	}

	class := win.RegisterClassW(&cls)
	assert(class != 0, "Class creation failed")

    width, height := win.GetSystemMetrics(win.SM_CXSCREEN), win.GetSystemMetrics(win.SM_CYSCREEN)

    hwnd := win.CreateWindowExW(
		win.WS_EX_TOOLWINDOW,
		class_name,
		win.L("Wallpaper Window"),
		win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
		0, 0, width, height,
		nil, nil, instance, nil)

    progman: win.HWND = win.FindWindowW(win.L("Progman"), nil)
    win.SendMessageW(progman, 0x052C, 0, 0)

    wallpaper_hwnd: win.HWND = nil
    win.EnumWindows(enum_func, win.LPARAM(uintptr(&wallpaper_hwnd)))

    win.SetParent(hwnd, wallpaper_hwnd)
    
	assert(hwnd != nil, "Window creation Failed")
	msg: win.MSG

	for	win.GetMessageW(&msg, nil, 0, 0) > 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
	}
}

win_proc :: proc "stdcall" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	switch(msg) {
	case win.WM_DESTROY:
		win.PostQuitMessage(0)
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}


load_wglCreateContextAttribsARB :: proc(hdc: win.HDC) -> (proc "c" (win.HDC, win.HGLRC, [^]int) -> win.HGLRC) {
    return cast(proc "c" (win.HDC, win.HGLRC, [^]int) -> win.HGLRC) win.wglGetProcAddress("wglCreateContextAttribsARB")
}

create_modern_opengl_context :: proc(hwnd: win.HWND) -> (hglrc: win.HGLRC, success: bool) {
    hdc := win.GetDC(hwnd)
    defer win.ReleaseDC(hwnd, hdc)

    // --- Add Pixel Format Setup ---
    pfd := win.PIXELFORMATDESCRIPTOR {
        nSize = size_of(win.PIXELFORMATDESCRIPTOR),
        nVersion = 1,
        dwFlags = win.PFD_DRAW_TO_WINDOW | win.PFD_SUPPORT_OPENGL | win.PFD_DOUBLEBUFFER,
        iPixelType = win.PFD_TYPE_RGBA,
        cColorBits = 32,
        cDepthBits = 24,
        cStencilBits = 8,
        iLayerType = win.PFD_MAIN_PLANE,
    }

    pixel_format := win.ChoosePixelFormat(hdc, &pfd)
    if pixel_format == 0 {
        fmt.println("Failed to choose pixel format")
        return nil, false
    }

    if !win.SetPixelFormat(hdc, pixel_format, &pfd) {
        fmt.println("Failed to set pixel format")
        return nil, false
    }
    // --- End Pixel Format Setup ---


    // Create a temporary context to load extensions
    temp_hglrc := win.wglCreateContext(hdc)
    if temp_hglrc == nil {
        fmt.println("Failed to create temporary OpenGL context")
        return nil, false
    }
    defer win.wglDeleteContext(temp_hglrc)

    win.wglMakeCurrent(hdc, temp_hglrc)

    // Load wglCreateContextAttribsARB
    wglCreateContextAttribsARB := load_wglCreateContextAttribsARB(hdc)
    if wglCreateContextAttribsARB == nil {
        fmt.println("Failed to load wglCreateContextAttribsARB")
        return nil, false
    }

    // Create modern context (e.g., OpenGL 3.3 core)
    attribs := [?]int{
        win.WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
        win.WGL_CONTEXT_MINOR_VERSION_ARB, 3,
        win.WGL_CONTEXT_PROFILE_MASK_ARB,  win.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    }

    hglrc = wglCreateContextAttribsARB(hdc, nil, &attribs[0])
    if hglrc == nil {
        fmt.println("Failed to create modern OpenGL context")
        return nil, false
    }

    win.wglMakeCurrent(hdc, hglrc)
    return hglrc, true
}