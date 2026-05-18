use tauri::{Manager, Emitter};
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

use serde::Serialize;

#[derive(Serialize)]
struct FontResult {
    family: String,
    size: i32,
    color: String,
    bold: bool,
    italic: bool,
    underline: bool,
}

#[tauri::command]
fn open_font_picker() -> Result<Option<FontResult>, String> {
    #[cfg(target_os = "windows")]
    {
        use windows::Win32::UI::Controls::Dialogs::{ChooseFontW, CHOOSEFONTW, CF_EFFECTS, CF_SCREENFONTS, CF_FORCEFONTEXIST};
        use windows::Win32::Graphics::Gdi::LOGFONTW;
        use std::mem;

        let mut lf: LOGFONTW = unsafe { mem::zeroed() };
        let mut cf: CHOOSEFONTW = unsafe { mem::zeroed() };
        cf.lStructSize = mem::size_of::<CHOOSEFONTW>() as u32;
        cf.lpLogFont = &mut lf;
        cf.Flags = CF_SCREENFONTS | CF_EFFECTS | CF_FORCEFONTEXIST;
        
        unsafe {
            if ChooseFontW(&mut cf).as_bool() {
                let family_name = String::from_utf16_lossy(&lf.lfFaceName);
                let family = family_name.trim_end_matches('\0').to_string();
                let size = cf.iPointSize / 10;
                let r = (cf.rgbColors.0 & 0xFF) as u8;
                let g = ((cf.rgbColors.0 >> 8) & 0xFF) as u8;
                let b = ((cf.rgbColors.0 >> 16) & 0xFF) as u8;
                let color_hex = format!("#{:02x}{:02x}{:02x}", r, g, b);
                
                let bold = lf.lfWeight >= 700;
                let italic = lf.lfItalic > 0;
                let underline = lf.lfUnderline > 0;
                
                return Ok(Some(FontResult {
                    family, size, color: color_hex, bold, italic, underline,
                }));
            } else {
                return Ok(None);
            }
        }
    }
    #[cfg(not(target_os = "windows"))]
    {
        Ok(None)
    }
}

#[tauri::command]
fn read_clipboard_html() -> Result<String, String> {
    #[cfg(target_os = "windows")]
    {
        use clipboard_win::{register_format, get_clipboard, formats::RawData};
        let html_format = register_format("HTML Format").ok_or_else(|| "Format not found".to_string())?;
        
        let _clip = clipboard_win::Clipboard::new_attempts(10).map_err(|e| e.to_string())?;
        
        let buffer_res: Result<Vec<u8>, _> = get_clipboard(RawData(html_format.get()));
        match buffer_res {
            Ok(buffer) => {
                let s = String::from_utf8_lossy(&buffer).into_owned();
                let start_marker = "StartFragment:";
                let end_marker = "EndFragment:";
                if let (Some(start_idx), Some(end_idx)) = (s.find(start_marker), s.find(end_marker)) {
                    let start_str = s[start_idx + start_marker.len()..].split('\n').next().unwrap_or("").trim();
                    let end_str = s[end_idx + end_marker.len()..].split('\n').next().unwrap_or("").trim();
                    if let (Ok(start), Ok(end)) = (start_str.parse::<usize>(), end_str.parse::<usize>()) {
                        if start < s.len() && end <= s.len() && start <= end {
                            return Ok(s[start..end].to_string());
                        }
                    }
                }
                Ok(s)
            }
            Err(_) => Err("No HTML data".to_string())
        }
    }
    #[cfg(not(target_os = "windows"))]
    {
        Err("Unsupported OS".to_string())
    }
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
            
            // System Tray setup
            use tauri::menu::{Menu, MenuItem};
            use tauri::tray::{TrayIconBuilder, TrayIconEvent, MouseButton, MouseButtonState};
            
            let quit_i = MenuItem::with_id(app, "quit", "Esci", true, None::<&str>)?;
            let settings_i = MenuItem::with_id(app, "settings", "Impostazioni...", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&settings_i, &quit_i])?;

            let _tray = TrayIconBuilder::new()
                .menu(&menu)
                .icon(app.default_window_icon().unwrap().clone())
                .on_menu_event(|app, event| {
                    match event.id.as_ref() {
                        "quit" => {
                            app.exit(0);
                        }
                        "settings" => {
                            if let Some(window) = app.get_webview_window("main") {
                                let _ = window.show();
                                let _ = window.set_focus();
                                let _ = app.emit("open-settings", ());
                            }
                        }
                        _ => {}
                    }
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;
                
            Ok(())
        })
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![inject_paste, hide_window, open_font_picker, read_clipboard_html])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
