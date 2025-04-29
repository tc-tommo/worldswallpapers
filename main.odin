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

    pfd : win.PIXELFORMATDESCRIPTOR = {
        nSize = size_of(win.PIXELFORMATDESCRIPTOR),
        nVersion = 1,
        dwFlags = win.PFD_DRAW_TO_WINDOW | win.PFD_SUPPORT_OPENGL | win.PFD_DOUBLEBUFFER,
        iPixelType = win.PFD_TYPE_RGBA,
        cColorBits = 32,
    }   
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

    hdc := win.GetDC(hwnd)
    assert(hdc != nil, "Failed to get device context")

    pixel_format := win.ChoosePixelFormat(hdc, &pfd)
    assert(pixel_format != 0, "Failed to choose pixel format")
    win.SetPixelFormat(hdc, pixel_format, &pfd)

    hglrc := win.wglCreateContext(hdc)
    assert(hglrc != nil, "Failed to create OpenGL context")

    win.wglMakeCurrent(hdc, hglrc)
    defer win.wglMakeCurrent(nil, nil)
    defer win.wglDeleteContext(hglrc)

    set_proc_address :: proc(p: rawptr, name: cstring) {
        (cast(^rawptr)p)^ = win.wglGetProcAddress(&name[0]);
    }

    gl.load_up_to(3, 3, set_proc_address)

    gl.Viewport(0, 0, i32(width), i32(height))

    win.ShowWindow(hwnd, win.SW_HIDE)


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

