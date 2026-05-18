use tauri::Manager;
#[cfg(target_os = "windows")]
use windows::Win32::Foundation::HWND;
#[cfg(target_os = "windows")]
use windows::Win32::UI::WindowsAndMessaging::{GetWindowLongW, SetWindowLongW, GWL_EXSTYLE, WS_EX_NOACTIVATE};

#[tauri::command]
fn hide_window(app: tauri::AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        window.hide().unwrap();
    }
}

#[tauri::command]
fn inject_paste(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("main") {
        window.hide().unwrap();
    }
    
    std::thread::spawn(|| {
        use enigo::{Enigo, Key, Keyboard, Settings, Direction};
        std::thread::sleep(std::time::Duration::from_millis(50));
        if let Ok(mut enigo) = Enigo::new(&Settings::default()) {
            let _ = enigo.key(Key::Control, Direction::Press);
            let _ = enigo.key(Key::Unicode('v'), Direction::Click);
            let _ = enigo.key(Key::Control, Direction::Release);
        }
    });
    
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            #[cfg(target_os = "windows")]
            {
                if let Some(window) = app.get_webview_window("main") {
                    if let Ok(hwnd) = window.hwnd() {
                        unsafe {
                            // Extract raw pointer regardless of the windows_core version tauri uses
                            let hwnd_ptr: *mut core::ffi::c_void = std::mem::transmute_copy(&hwnd);
                            let win_hwnd = windows::Win32::Foundation::HWND(hwnd_ptr);
                            
                            let ex_style = GetWindowLongW(win_hwnd, GWL_EXSTYLE);
                            SetWindowLongW(win_hwnd, GWL_EXSTYLE, ex_style | WS_EX_NOACTIVATE.0 as i32);
                        }
                    }
                }
            }
            Ok(())
        })
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![inject_paste, hide_window])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
