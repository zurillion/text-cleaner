# TextMagician — Guida d'uso

TextMagician è un'utility per la barra dei menu di macOS con tre strumenti
indipendenti, ciascuno legato a una propria scorciatoia globale:

| Strumento                  | Scorciatoia di default | Cosa fa                                                                                                       |
| -------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------- |
| Trasformatore della clipboard | `⌃⌥⌘V`              | Applica una trasformazione (cambio di case, pulizia URL, "font" Unicode, …) a qualunque cosa hai copiato      |
| Selettore Unicode          | `⌃⌥⌘U`                 | Sfoglia e inserisci glifi da un catalogo curato di simboli Unicode                                            |
| Selettore Emoji            | `⌃⌥⌘E`                 | Stessa UI del selettore Unicode, limitata agli emoji                                                          |

Tutti e tre finiscono allo stesso modo: il risultato scelto viene incollato
alla posizione attuale del cursore nell'app che era in primo piano quando
hai premuto la scorciatoia, e il contenuto originale della clipboard viene
ripristinato.

---

## Primo avvio

Dopo aver installato l'app dal DMG e averla lanciata, due cose vanno fatte
una volta sola:

1. **Concedi il permesso Accessibilità.** Per simulare la pressione di
   `⌘V` su altre app serve quel permesso. La prima volta che lanci
   un'azione, macOS ti chiede di aprire Impostazioni di Sistema → Privacy
   e Sicurezza → Accessibilità e di attivare l'interruttore per
   TextMagician.
2. **Esci dall'app e rilanciala** dopo aver concesso il permesso. Un
   processo già in esecuzione non vede il grant finché non riparte. Usa
   l'icona nella barra dei menu → Quit, poi rilancia l'app.

Se l'incolla non funziona, il permesso Accessibilità è il primo posto dove
guardare (basta una vecchia voce nella lista per rompere tutto
silenziosamente).

---

## Il trasformatore della clipboard

Questo è lo strumento principale. Copia del testo (da Safari, da un editor,
da Note, ovunque), poi premi `⌃⌥⌘V`. Una popup fluttuante appare davanti
a qualsiasi cosa tu stessi facendo.

### Navigazione

| Tasto                          | Azione                                                  |
| ------------------------------ | ------------------------------------------------------- |
| `↑` / `↓`                      | Sposta la selezione di una riga                         |
| `⇧↑` / `⇧↓`                    | Salta alla prima / ultima riga                          |
| `1`–`9`, poi `a`–`z`           | Scegli una riga direttamente dal suo badge              |
| `↩` (Invio)                    | Conferma l'azione selezionata                           |
| `␣` (Spazio)                   | Mostra/nasconde il pannello di anteprima                |
| `⇥` (Tab)                      | Entra in modalità di modifica (vedi sotto)              |
| `⎋` (Esc)                      | Annulla e chiudi                                        |

Passare col mouse evidenzia una riga senza scrollare la lista; un click
esegue immediatamente l'azione. La lista stessa si scorre col trackpad o
la rotellina quando ha più righe di quante ne entrano.

### Pannello di anteprima

Premi `␣` (Spazio) per aprire o chiudere un pannello laterale che mostra
cosa produrrebbe l'azione selezionata, dato il contenuto attuale della
clipboard. Utile quando non sei sicuro di quale trasformazione vuoi.

### Modalità di modifica

Premi `⇥` (Tab) per aprire l'anteprima come buffer modificabile. Puoi:

- Scrivere, cancellare, riorganizzare.
- Applicare grassetto / corsivo / sottolineato con `⌘B` / `⌘I` / `⌘U`.
- Aprire il pannello Font di sistema con `⌘T` per cambiare font /
  dimensione / colore.
- `⇧↩` conferma (incolla il risultato modificato), `⎋` annulla.

L'incolla è intelligente: se le modifiche contengono davvero formattazione
(grassetto, corsivo, font o dimensione o colore non di default), la
clipboard riceve sia RTF sia testo semplice, così le app di destinazione
che supportano il rich text mantengono la formattazione. Altrimenti, solo
testo semplice.

### Trascinamento e ricentratura

Trascina la popup dalla sua barra del titolo per posizionarla dove vuoi
sullo schermo. Il pannello di anteprima (se aperto) la segue. Premi la
scorciatoia di ricentratura (di default `⌥C`, configurabile) mentre la
popup è aperta per riportarla al centro.

### Azioni integrate

La popup viene fornita con 36 azioni, tutte attive di default e raggruppate
con separatori orizzontali tra i blocchi logici. Le disattivi, le
riordini o sposti i separatori dalle Preferenze.

**Azioni originali di elaborazione del testo**

| Nome              | Risultato                                                                            |
| ----------------- | ------------------------------------------------------------------------------------ |
| Unvaried          | Reincolla il contenuto della clipboard senza modifiche                              |
| Remove formatting | Toglie tutta la formattazione, mantiene il testo semplice                            |
| UPPERCASE         | Tutto maiuscolo                                                                      |
| lowercase         | Tutto minuscolo                                                                      |
| camelCase         | `helloWorld` a partire da qualsiasi tokenizzazione (spazi, trattini, underscore, cambio di case) |
| snake_case        | `hello_world` a partire da qualsiasi tokenizzazione                                  |
| Clean URL         | Toglie i parametri di tracciamento (`utm_*`, `fbclid`, `gclid`, Amazon `pf_rd_*`/`ref`, ecc.) e ricostruisce i link "multi-permalinks" dei gruppi Facebook nella forma diretta `/groups/<id>/posts/<id>/` |

**Stili "font" Unicode** (funzionano solo su testo semplice; eventuale
formattazione in ingresso viene tolta prima del mapping)

`Bold (serif)`, `Italic (serif)`, `Bold italic (serif)`, `Bold (sans)`,
`Italic (sans)`, `Bold italic (sans)`, `Double-struck`, `Monospace`,
`Sans serif`, `Cursive script`, `Bold cursive script`, `Fraktur`,
`Bold fraktur`, `Short strikethrough`, `Long strikethrough`, `Underline
(double macron)`, `Upper squiggles and hooks`, `Lower squiggles and
hooks`, `Alternating squiggles and hooks`, `Upside down`, `Reverse`,
`Large Cherokee letterlike`, `Small Cherokee letterlike`, `Fullwidth`,
`Vaporwave` (fullwidth con A→Λ e E→Ξ), `Small caps`.

**Trucchi per i ritorni a capo sui social network**

| Nome              | Risultato                                                            |
| ----------------- | -------------------------------------------------------------------- |
| Force line break  | Riempie le righe vuote con `U+2800` così Facebook e Instagram non le collassano |
| Tabbed paragraph  | Antepone `U+3000` (spazio full-width) a ogni riga come indent visibile |
| Double tabbed     | Idem ma con due indent per riga                                      |

---

## Il selettore di caratteri Unicode

Premi `⌃⌥⌘U`. Si apre una finestra fluttuante separata — indipendente dalla
clipboard. Scegli un glifo, viene incollato al cursore.

### Layout

- **Barra superiore** mostra un'anteprima ingrandita del glifo selezionato,
  la sua descrizione (quando c'è) e il codepoint Unicode.
- **Campo di ricerca** filtra l'intero catalogo (vedi sotto).
- **Griglia** con una sezione per categoria: Greek Alphabet, Superscript /
  Subscript, Marks, Mathematical Symbols, Differential Calculus, Set Theory,
  Logic, Math Letters, Arrows, Music – Notes / Accidentals / Clefs /
  Barlines / Fermata / Dynamics.
- **Recent** appare in cima dopo che hai fatto almeno una scelta. Fino a 15
  glifi più recenti, dal più nuovo al più vecchio, deduplicati. Sopravvive
  al riavvio dell'app.

### Navigazione

| Tasto           | Azione                                                  |
| --------------- | ------------------------------------------------------- |
| `←` `→` `↑` `↓` | Sposta la selezione                                     |
| `↩`             | Inserisce il glifo selezionato e chiude                 |
| `⎋`             | Se il campo di ricerca contiene testo, lo svuota; altrimenti chiude |

Il campo di ricerca prende il focus all'apertura della finestra, così puoi
digitare subito. Le frecce e Invio funzionano anche con il focus nel
campo, quindi non devi cambiare focus.

### Ricerca

Digitando nel campo di ricerca filtri per, in ordine:

1. La descrizione custom inclusa con la voce (`"xor"`, `"therefore"`,
   `"treble clef"`, …).
2. Il nome ufficiale Unicode dello scalare. Cercando "alpha" trovi α anche
   se α non ha descrizione custom, perché il suo nome Unicode è
   "GREEK SMALL LETTER ALPHA".
3. Il carattere letterale.

Confronto substring case-insensitive in tutti e tre i casi.

### Ridimensionamento

Trascina i bordi della finestra — la griglia si riadatta per usare la
larghezza nuova (più colonne = più glifi per riga). Quando rilasci il
trascinamento la finestra si ricentra automaticamente sullo schermo.

---

## Il selettore Emoji

Premi `⌃⌥⌘E`. Stessa UI del selettore Unicode, limitata agli emoji.
Categorie: Smileys, Gestures, People, Animals, Nature, Food & Drink,
Activities, Travel & Places, Objects, Symbols, Flags.

La ricerca lavora sul nome Unicode più, per le bandiere, sul nome del
paese (cercare "italy" trova 🇮🇹).

I Recent sono tracciati separatamente da quelli del selettore Unicode,
così i due non si contaminano.

---

## Preferenze

Si aprono dall'icona nella barra dei menu → Settings, oppure con `⌘,` da
dentro qualsiasi popup.

### General

- **Launch at login** — auto-avvio quando ti logghi su macOS. Usa
  `SMAppService`, quindi il toggle resta sincronizzato con quanto mostra
  Impostazioni di Sistema → Elementi di login.
- **Show icon in Dock** — disattiva per far girare TextMagician solo come
  app della barra dei menu.

### Shortcuts

Ogni scorciatoia globale ha il suo campo. Clicca dentro il campo e premi
la combinazione che vuoi; il recorder si aggiorna. Il bottone Reset
accanto a ciascuna riporta al default.

| Campo            | Default | Ambito                                  |
| ---------------- | ------- | --------------------------------------- |
| Invoke           | `⌃⌥⌘V`  | Apre la popup del trasformatore         |
| Unicode picker   | `⌃⌥⌘U`  | Apre la finestra del selettore Unicode  |
| Emoji picker     | `⌃⌥⌘E`  | Apre la finestra del selettore Emoji    |
| Re-center popup  | `⌥C`    | Locale alla popup — solo a popup aperta |

Le combinazioni devono includere almeno un modificatore (`⌃`, `⌥`, `⇧`,
`⌘`).

### Theme

Otto temi per la grafica della popup e dei selettori: System, Light,
Dark, Solarized Light / Dark, Nord, Dracula, High Contrast. Click su
uno swatch.

### Actions

Tutta la lista del trasformatore, nell'ordine in cui appare nella popup.
Per ogni riga:

- **Handle di drag** (l'icona `≡` a sinistra) riordina la riga.
  Trascinala in un nuovo spazio; una linea orizzontale di accent indica
  dove andrà a finire.
- **Toggle** a destra abilita / disabilita. Le righe disabilitate
  scendono sotto quelle abilitate; l'unico modo per rimetterle nella
  popup è riattivare il toggle.
- **Badge** davanti è la scorciatoia da tastiera che la riga riceverà
  nella popup. Le posizioni 1–9 usano i tasti numerici; le posizioni
  10–35 usano le lettere `a`–`z`; oltre la 35ª nessun badge (l'azione è
  comunque raggiungibile con frecce + Invio o col mouse).
- **⌥-click tra due righe** aggiunge un separatore visivo in quel
  punto — disegnato sia nelle Preferenze sia nella popup. ⌥-click di
  nuovo sullo stesso spazio lo rimuove. Di default ci sono già due
  separatori, uno dopo Clean URL e uno dopo Reverse.

Il bottone **Reset** ripristina l'ordine di default, lo stato di default
(tutto attivo) e i separatori di default.

---

## Suggerimenti

- **Pulizia veloce di un URL Facebook** — copia l'URL, `⌃⌥⌘V`, premi
  il badge di Clean URL. I parametri di tracciamento spariscono; i link
  "multi-permalinks" dei gruppi si ricostruiscono nella forma diretta
  `/groups/<id>/posts/<id>/`.
- **Grassetto e corsivo su Facebook / Twitter** — copia il testo,
  `⌃⌥⌘V`, scegli lo stile desiderato. Il risultato sono caratteri Unicode
  reali, che sopravvivono al copia-incolla anche dove la formattazione
  viene strippata.
- **Forzare una riga vuota su Facebook** — scrivi il post, lancia la
  popup, scegli Force line break. Le righe vuote ora contengono un
  carattere invisibile non-whitespace, e Facebook smette di collassarle.
- **Unicode più veloce** — qualunque cosa tu abbia usato di recente si
  trova nella sezione Recent in cima al selettore; di solito non hai
  bisogno di ri-cercarlo.

---

## Risoluzione dei problemi

**L'incolla non fa niente, o senti un bip.** Quasi sempre è
Accessibilità.

1. Apri Impostazioni di Sistema → Privacy e Sicurezza → Accessibilità.
2. Rimuovi qualsiasi voce TextMagician presente (potrebbe essercene più
   di una se hai testato build diverse).
3. Esci da TextMagician dall'icona nella barra dei menu.
4. Rilancia l'app, scatena un'azione, accetta il prompt del permesso.
5. **Esci e rilancia una seconda volta.** Un processo in esecuzione non
   vede un permesso concesso mentre era già attivo.

**Alcuni glifi nel selettore appaiono come quadrati vuoti.** Il font di
sistema sul tuo Mac non ha quei codepoint. Aggiorna macOS oppure accetta
che quei glifi specifici non sono usabili; il resto del catalogo non è
influenzato.

**La scorciatoia non si attiva.** Apri Impostazioni di Sistema →
Tastiera → Scorciatoie da tastiera e verifica se qualcos'altro è
collegato alla stessa combinazione. Disabilita il conflitto o cambia
la scorciatoia di TextMagician dalle Preferenze.

**La finestra Settings mostra il nome dell'app sbagliato.** Esci e
rilancia da una build pulita. La cache di Launch Services di macOS è
appiccicosa dopo un rinome.

---

## Privacy

TextMagician lavora solo in locale:

- Nessuna richiesta di rete di alcun tipo.
- La clipboard viene letta solo quando invochi la popup, su richiesta.
- I Recent (Unicode / emoji) sono salvati nei `UserDefaults` locali, non
  sincronizzati da nessuna parte.
- Il permesso Accessibilità è usato unicamente per inviare la pressione
  `⌘V` all'app in primo piano dopo che il nuovo valore è in clipboard.
