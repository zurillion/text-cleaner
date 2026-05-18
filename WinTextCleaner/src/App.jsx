import { useState, useEffect } from "react";
import { Equal, Eraser, CaseUpper, CaseLower, Baseline, Code, Link } from "lucide-react";
import { invoke } from "@tauri-apps/api/core";
import { readText, writeText } from "@tauri-apps/plugin-clipboard-manager";
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

const appWindow = getCurrentWindow();

function App() {
  const [selectedIndex, setSelectedIndex] = useState(0);

  useEffect(() => {
    // Registra lo shortcut globale
    let isRegistered = false;
    register("CommandOrControl+Shift+C", async () => {
      const isVisible = await appWindow.isVisible();
      if (isVisible) {
        await appWindow.hide();
      } else {
        await appWindow.show();
      }
    }).then(() => {
      isRegistered = true;
    }).catch(console.error);

    const handleKeyDown = (e) => {
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
      } else {
        const num = parseInt(e.key);
        if (!isNaN(num) && num > 0 && num <= actions.length) {
          e.preventDefault();
          setSelectedIndex(num - 1);
          handleSelect(actions[num - 1]);
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [selectedIndex]);

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
        <div className="hint-item">
          <span className="hint-key">⇥</span>
          <span>Edit</span>
        </div>
      </div>
    </>
  );
}

export default App;
