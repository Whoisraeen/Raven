use std::ffi::c_char;
use std::ffi::CString;

#[cfg(target_os = "windows")]
mod sys {
    use std::ffi::c_void;
    use std::sync::atomic::{AtomicBool, AtomicPtr, Ordering};
    use std::sync::Mutex;
    use windows_sys::Win32::Foundation::{HWND, LRESULT, WPARAM, LPARAM};
    use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
    use windows_sys::Win32::UI::Shell::{
        Shell_NotifyIconW, NOTIFYICONDATAW, NIM_ADD, NIM_DELETE, NIF_ICON, NIF_MESSAGE,
        NIF_TIP,
    };
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        CreateWindowExW, DefWindowProcW, DestroyIcon, DestroyWindow, DispatchMessageW,
        GetMessageW, LoadImageW, RegisterClassW, TranslateMessage, HWND_MESSAGE, IMAGE_ICON,
        LR_LOADFROMFILE, MSG, WM_USER, WNDCLASSW,
    };
    use std::os::windows::ffi::OsStrExt;
    use std::ffi::OsStr;

    static TRAY_WINDOW: AtomicPtr<c_void> = AtomicPtr::new(std::ptr::null_mut());
    static HAS_TRAY: AtomicBool = AtomicBool::new(false);
    static CALLBACK: Mutex<Option<extern "C" fn()>> = Mutex::new(None);

    const WM_TRAYICON: u32 = WM_USER + 1;
    const WM_LBUTTONUP: u32 = 0x0202;
    const WM_RBUTTONUP: u32 = 0x0205;

    fn encode_wide(s: &str) -> Vec<u16> {
        let mut v: Vec<u16> = OsStr::new(s).encode_wide().collect();
        v.push(0);
        v
    }

    unsafe extern "system" fn toggle_wnd_proc(
        hwnd: HWND,
        msg: u32,
        wparam: WPARAM,
        lparam: LPARAM,
    ) -> LRESULT {
        if msg == WM_TRAYICON {
            let event = (lparam & 0xFFFF) as u32;
            if event == WM_LBUTTONUP || event == WM_RBUTTONUP {
                if let Ok(guard) = CALLBACK.lock() {
                    if let Some(cb) = *guard {
                        cb();
                    }
                }
            }
            return 0;
        }
        DefWindowProcW(hwnd, msg, wparam, lparam)
    }

    pub fn add(title: &str, icon_path: &str, cb: Option<extern "C" fn()>) {
        if HAS_TRAY.load(Ordering::SeqCst) {
            return;
        }
        
        match CALLBACK.lock() {
            Ok(mut guard) => { *guard = cb; }
            Err(poisoned) => { *poisoned.into_inner() = cb; }
        }

        let title_w = encode_wide(title);
        let icon_path_w = encode_wide(icon_path);

        std::thread::spawn(move || {
            unsafe {
                let hinstance = GetModuleHandleW(std::ptr::null());

                let class_name = encode_wide("RavenTrayClass");
                let wnd_class = WNDCLASSW {
                    style: 0,
                    lpfnWndProc: Some(toggle_wnd_proc),
                    cbClsExtra: 0,
                    cbWndExtra: 0,
                    hInstance: hinstance,
                    hIcon: 0,
                    hCursor: 0,
                    hbrBackground: 0,
                    lpszMenuName: std::ptr::null(),
                    lpszClassName: class_name.as_ptr(),
                };
                RegisterClassW(&wnd_class);

                let hwnd = CreateWindowExW(
                    0,
                    class_name.as_ptr(),
                    std::ptr::null(),
                    0,
                    0,
                    0,
                    0,
                    0,
                    HWND_MESSAGE,
                    0,
                    hinstance,
                    std::ptr::null(),
                );

                if hwnd != 0 {
                    TRAY_WINDOW.store(hwnd as *mut c_void, Ordering::SeqCst);
                    HAS_TRAY.store(true, Ordering::SeqCst);

                    let hicon = LoadImageW(
                        0,
                        icon_path_w.as_ptr(),
                        IMAGE_ICON,
                        0,
                        0,
                        LR_LOADFROMFILE,
                    );

                    let mut nid: NOTIFYICONDATAW = std::mem::zeroed();
                    nid.cbSize = std::mem::size_of::<NOTIFYICONDATAW>() as u32;
                    nid.hWnd = hwnd;
                    nid.uID = 1;
                    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
                    nid.uCallbackMessage = WM_TRAYICON;
                    nid.hIcon = hicon as _;
                    
                    for (i, &c) in title_w.iter().take(127).enumerate() {
                        nid.szTip[i] = c;
                    }

                    Shell_NotifyIconW(NIM_ADD, &nid);

                    let mut msg: MSG = std::mem::zeroed();
                    while GetMessageW(&mut msg, 0, 0, 0) > 0 {
                        TranslateMessage(&msg);
                        DispatchMessageW(&msg);
                    }

                    Shell_NotifyIconW(NIM_DELETE, &nid);
                    if hicon != 0 {
                        DestroyIcon(hicon as _);
                    }
                    DestroyWindow(hwnd);
                }
            }
        });
    }

    pub fn remove() {
        if !HAS_TRAY.swap(false, Ordering::SeqCst) {
            return;
        }
        
        let hwnd = TRAY_WINDOW.swap(std::ptr::null_mut(), Ordering::SeqCst) as HWND;
        if hwnd != 0 {
            unsafe {
                use windows_sys::Win32::UI::WindowsAndMessaging::{PostMessageW, WM_QUIT};
                PostMessageW(hwnd, WM_QUIT, 0, 0);
            }
        }
    }
}

pub fn add(title: *const c_char, icon_path: *const c_char, cb: Option<extern "C" fn()>) {
    #[cfg(target_os = "windows")]
    {
        let t = if title.is_null() { "" } else {
            unsafe { std::ffi::CStr::from_ptr(title).to_str().unwrap_or("") }
        };
        let p = if icon_path.is_null() { "" } else {
            unsafe { std::ffi::CStr::from_ptr(icon_path).to_str().unwrap_or("") }
        };
        sys::add(t, p, cb);
    }

    #[cfg(not(target_os = "windows"))]
    {
        let _ = (title, icon_path, cb);
        crate::set_last_error("tray::add not implemented on this platform");
    }
}

pub fn remove() {
    #[cfg(target_os = "windows")]
    sys::remove();

    #[cfg(not(target_os = "windows"))]
    crate::set_last_error("tray::remove not implemented on this platform");
}
