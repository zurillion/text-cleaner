import { useState, useEffect, useRef } from "react";
import { Equal, Eraser, CaseUpper, CaseLower, Baseline, Code, Link } from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { readText, writeText, writeHtml } from "@tauri-apps/plugin-clipboard-manager";
import { register } from "@tauri-apps/plugin-global-shortcut";
import "./App.css";

const actions = [
  { id: "unvaried", title: "Unvaried", icon: Equal },
  { id: "removeFormatting", title: "Remove formatting", icon: Eraser },
  { id: "uppercase", title: "UPPERCASE", icon: CaseUpper },
  { id: "lowercase", title: "lowercase", icon: CaseLower },
  { id: "camelCase", title: "camelCase", icon: Baseline },
  { id: "snakeCase", title: "snake_case", icon: Code },
  { id: "cleanURL", title: "Clean URL", icon: Link },
];

function toCamelCase(str) {
  return str.replace(/(?:^\w|[A-Z]|\b\w|\s+)/g, function(match, index) {
    if (+match === 0) return "";
    return index === 0 ? match.toLowerCase() : match.toUpperCase();
  }).replace(/[\s_.-]+/g, '');
}

function toSnakeCase(str) {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`)
            .replace(/[\s.-]+/g, '_')
            .replace(/^_/, '')
            .toLowerCase();
}

function cleanUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.origin + parsed.pathname;
  } catch (e) {
    return url;
  }
}

import { getCurrentWindow } from "@tauri-apps/api/window";
import { listen } from "@tauri-apps/api/event";

const appWindow = getCurrentWindow();

function App() {
  const [currentView, setCurrentView] = useState("main"); // "main", "edit", "settings"
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [clipboardHtml, setClipboardHtml] = useState("");
  const editorRef = useRef(null);

  useEffect(() => {
    // Listen for tray event
    const unlisten = listen("open-settings", () => {
      setCurrentView("settings");
    });
    return () => {
      unlisten.then(f => f());
    };
  }, []);

  useEffect(() => {
    // Registra lo shortcut globale
    let isRegistered = false;
    register("CommandOrControl+Shift+C", async () => {
      const isVisible = await appWindow.isVisible();
      if (isVisible) {
        await appWindow.hide();
      } else {
        // reload clipboard when showing
        try {
          const html = await invoke("read_clipboard_html");
          setClipboardHtml(html);
        } catch (e) {
          const text = await readText();
          setClipboardHtml(text ? text.replace(/\n/g, "<br>") : "");
        }
        await appWindow.show();
      }
    }).then(() => {
      isRegistered = true;
    }).catch(console.error);

    const handleKeyDown = async (e) => {
      if (currentView === "main") {
        if (e.key === "ArrowDown") {
          e.preventDefault();
          setSelectedIndex((prev) => (prev + 1) % actions.length);
        } else if (e.key === "ArrowUp") {
          e.preventDefault();
          setSelectedIndex((prev) => (prev - 1 + actions.length) % actions.length);
        } else if (e.key === "Enter") {
          e.preventDefault();
          handleSelect(actions[selectedIndex]);
        } else if (e.key === "Escape") {
          e.preventDefault();
          invoke("hide_window");
        } else if (e.key === "Tab") {
          e.preventDefault();
          setCurrentView("edit");
        } else {
          const num = parseInt(e.key);
          if (!isNaN(num) && num > 0 && num <= actions.length) {
            e.preventDefault();
            setSelectedIndex(num - 1);
            handleSelect(actions[num - 1]);
          }
        }
      } else if (currentView === "edit") {
        if (e.key === "Escape") {
          e.preventDefault();
          setCurrentView("main");
        } else if (e.key === "Enter" && e.shiftKey) {
          e.preventDefault();
          handleConfirmEdit();
        } else if (e.key === "t" && (e.ctrlKey || e.metaKey)) {
          e.preventDefault();
          handleFontPicker();
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [selectedIndex, currentView]);

  // Load clipboard on mount
  useEffect(() => {
    async function load() {
      try {
        const html = await invoke("read_clipboard_html");
        setClipboardHtml(html);
      } catch (e) {
        const text = await readText();
        setClipboardHtml(text ? text.replace(/\n/g, "<br>") : "");
      }
    }
    load();
  }, []);

  const handleSelect = async (action) => {
    try {
      const text = await readText();
      if (!text) {
        await invoke("hide_window");
        return;
      }
      
      let processed = text;
      switch (action.id) {
        case "uppercase": processed = text.toUpperCase(); break;
        case "lowercase": processed = text.toLowerCase(); break;
        case "camelCase": processed = toCamelCase(text); break;
        case "snakeCase": processed = toSnakeCase(text); break;
        case "cleanURL": processed = cleanUrl(text); break;
        case "unvaried": 
        case "removeFormatting":
        default: 
          processed = text; 
          break;
      }

      await writeText(processed);
      await invoke("inject_paste");
    } catch (e) {
      console.error("Error processing text", e);
      await invoke("hide_window");
    }
  };

  const handleFontPicker = async () => {
    const fontRes = await invoke("open_font_picker");
    if (fontRes && editorRef.current) {
      document.execCommand('styleWithCSS', false, true);
      document.execCommand('fontName', false, fontRes.family);
      document.execCommand('foreColor', false, fontRes.color);
      if (fontRes.bold) document.execCommand('bold', false, null);
      if (fontRes.italic) document.execCommand('italic', false, null);
      if (fontRes.underline) document.execCommand('underline', false, null);
    }
  };

  const handleConfirmEdit = async () => {
    if (!editorRef.current) return;
    const finalHtml = editorRef.current.innerHTML;
    try {
      await writeHtml(finalHtml, editorRef.current.innerText);
      await invoke("inject_paste");
      setCurrentView("main");
    } catch (e) {
      console.error(e);
    }
  };

  if (currentView === "settings") {
    return (
      <>
        <div data-tauri-drag-region className="titlebar">
          Settings
        </div>
        <div className="settings-panel">
          <div className="setting-item">
            <span className="setting-label">Shortcut per aprire App</span>
            <span className="hint-key">Ctrl+Shift+C</span>
          </div>
          <div className="setting-item">
            <span className="setting-label">Avvio al Login</span>
            <span className="hint-key">Predisposto</span>
          </div>
          <div className="settings-buttons">
            <button className="btn" onClick={() => setCurrentView("main")}>Indietro</button>
          </div>
        </div>
      </>
    );
  }

  if (currentView === "edit") {
    return (
      <>
        <div data-tauri-drag-region className="titlebar">
          Edit Text
        </div>
        <div 
          ref={editorRef}
          className="editor-area"
          contentEditable
          suppressContentEditableWarning
          dangerouslySetInnerHTML={{ __html: clipboardHtml }}
        />
        <div className="editor-buttons">
          <button className="btn" onClick={() => setCurrentView("main")}>Annulla (Esc)</button>
          <button className="btn primary" onClick={handleConfirmEdit}>Conferma (⇧↩)</button>
        </div>
        <div className="footer-hints" style={{marginTop: "8px", justifyContent: "flex-end"}}>
          <div className="hint-item">
            <span className="hint-key">Ctrl+T</span>
            <span>Style</span>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <div data-tauri-drag-region className="titlebar">
        Text Cleaner
      </div>
      
      <div className="action-list">
        {actions.map((action, index) => {
          const IconComponent = action.icon;
          const isSelected = index === selectedIndex;
          
          return (
            <div 
              key={action.id} 
              className={`action-item ${isSelected ? 'selected' : ''}`}
              onMouseEnter={() => setSelectedIndex(index)}
              onClick={() => handleSelect(action)}
            >
              <div className="shortcut-key">{index + 1}</div>
              <IconComponent className="action-icon" size={16} strokeWidth={2.5} />
              <div className="action-title">{action.title}</div>
            </div>
          );
        })}
      </div>

      <div className="footer-hints">
        <div className="hint-item">
          <span className="hint-key">⎵</span>
          <span>Preview</span>
        </div>
        <div className="hint-item" style={{cursor: "pointer"}} onClick={() => setCurrentView("edit")}>
          <span className="hint-key">⇥</span>
          <span>Edit</span>
        </div>
      </div>
    </>
  );
}

export default App;
