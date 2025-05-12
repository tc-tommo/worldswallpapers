package win32_wallpaper_window

import win "core:sys/windows"
import d21 "vendor:directx/d3d12"
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


create_wallpaper_window :: proc() -> (hwnd: win.HWND) {
    // Todo add windows 11 support
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

    wallpaper : win.HWND = win.CreateWindowExW(
		win.WS_EX_TOOLWINDOW, // WS_EX_LAYERED for production
		class_name,
		win.L("Wallpaper Window"),
		win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
		0, 0, width, height,
		nil, nil, instance, nil)

    progman: win.HWND = win.FindWindowW(win.L("Progman"), nil)
    win.SendMessageW(progman, 0x052C, 0, 0)

    workerw: win.HWND = nil
    win.EnumWindows(enum_func, win.LPARAM(uintptr(&workerw)))

    win.SetParent(wallpaper, workerw)
    return wallpaper
}
    
    

main :: proc() {
	wallpaper_hwnd := create_wallpaper_window()
    if wallpaper_hwnd == nil {
        fmt.println("Failed to create wallpaper window")
        return
    }

	msg: win.MSG

	for	win.GetMessageW(&msg, nil, 0, 0) > 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
	}
}

win_proc :: proc "stdcall" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	ps: win.PAINTSTRUCT
    switch(msg) {
	case win.WM_PAINT:
	case win.WM_DESTROY:
		win.PostQuitMessage(0)
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}

