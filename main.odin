package win32_wallpaper_window

import win "core:sys/windows"
import gl "vendor:opengl"

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
		win.WS_EX_LAYERED,
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



    gl.load_3_3()

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


load_wglCreateContextAttribsARB :: proc(hdc: windows.HDC) -> (proc "c" (windows.HDC, windows.HGLRC, [^]c.int) -> windows.HGLRC) {
    return cast(proc "c" (windows.HDC, windows.HGLRC, [^]c.int) -> windows.HGLRC) windows.wglGetProcAddress("wglCreateContextAttribsARB")
}

create_modern_opengl_context :: proc(hwnd: windows.HWND) -> (hglrc: windows.HGLRC, success: bool) {
    hdc := windows.GetDC(hwnd)
    defer windows.ReleaseDC(hwnd, hdc)

    // Set pixel format as above...

    // Create a temporary context to load extensions
    temp_hglrc := windows.wglCreateContext(hdc)
    if temp_hglrc == nil {
        return nil, false
    }
    defer windows.wglDeleteContext(temp_hglrc)

    windows.wglMakeCurrent(hdc, temp_hglrc)

    // Load wglCreateContextAttribsARB
    wglCreateContextAttribsARB := load_wglCreateContextAttribsARB(hdc)
    if wglCreateContextAttribsARB == nil {
        return nil, false
    }

    // Create modern context (e.g., OpenGL 3.3 core)
    attribs := [?]c.int{
        windows.WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
        windows.WGL_CONTEXT_MINOR_VERSION_ARB, 3,
        windows.WGL_CONTEXT_PROFILE_MASK_ARB,  windows.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    }

    hglrc = wglCreateContextAttribsARB(hdc, nil, &attribs[0])
    if hglrc == nil {
        return nil, false
    }

    windows.wglMakeCurrent(hdc, hglrc)
    return hglrc, true
}