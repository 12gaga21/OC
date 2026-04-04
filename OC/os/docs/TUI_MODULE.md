# TUI MODULE - GOLD-EMERALD RITUAL STYLE

## Overview
The Text User Interface (TUI) module implements a unique visual style combining:
- **Warhammer 40k Mechanicus** aesthetic (green phosphor terminal)
- **Russian Imperial Church** design (golden borders, orthodox crosses)
- **Pre-revolutionary Russian orthography** (ѣ, і, ъ, ѣ)

## Visual Style Specification

### Color Palette
| Element | Color Code | RGB Equivalent | Description |
|---------|-----------|----------------|-------------|
| Background | `0x01` | Dark Blue | Deep blue background |
| Main Text | `0x0A` | Bright Green | Emerald phosphor (Mechanicus) |
| Borders | `0x1E` | Gold on Blue | Golden frames (Imperial Church) |
| Errors | `0x0C` | Red | Critical alerts |
| Highlights | `0x1F` | White on Blue | Special accents |

### Border Symbols
- Top-Left/Right Corner: `†` (Orthodox Cross)
- Bottom-Left: `⌊`, Bottom-Right: `⌋`
- Horizontal Line: `═`
- Vertical Line: `║`
- Cross Point: `╬`

## API Reference

### Initialization
```asm
call tui_init           ; Initialize TUI subsystem
```

### Window Management
```asm
; Create new window
mov esi, window_struct
mov edi, title_string
mov eax, X_coord
mov ebx, Y_coord
mov ecx, width
mov edx, height
call tui_create_window  ; Returns window ID in EAX

; Draw window with border
mov esi, window_struct
call tui_draw_window

; Destroy window
mov eax, window_id
call tui_destroy_window
```

### Text Output
```asm
; Print at specific position
mov eax, X_coord
mov ebx, Y_coord
mov esi, text_string
mov ecx, color_attribute
call tui_print_at

; Print centered on screen
mov esi, text_string
mov eax, Y_coord
mov ecx, color_attribute
call tui_print_centered
```

### System Functions
```asm
call tui_clear_screen   ; Clear screen with default colors
call tui_shutdown       ; Shutdown TUI subsystem

; Show error message (red)
mov esi, error_text
call tui_show_error

; Show normal message (green)
mov esi, message_text
mov eax, Y_coord
call tui_show_message
```

## Window Structure
```asm
struc WINDOW
    .x: resd 1          ; X coordinate
    .y: resd 1          ; Y coordinate
    .width: resd 1      ; Width in characters
    .height: resd 1     ; Height in characters
    .title_ptr: resd 1  ; Pointer to title string
    .border_color: resb 1 ; Border color attribute
    .text_color: resb 1   ; Text color attribute
endstruc
```

## Example Usage
```asm
section .data
    my_window: times 20 db 0
    window_title: db 'Системная Информация', 0

section .text
    ; Initialize TUI
    call tui_init
    
    ; Create window structure
    mov dword [my_window + WINDOW.x], 5
    mov dword [my_window + WINDOW.y], 3
    mov dword [my_window + WINDOW.width], 70
    mov dword [my_window + WINDOW.height], 15
    mov dword [my_window + WINDOW.title_ptr], window_title
    mov byte [my_window + WINDOW.border_color], COLOR_BORDER_GOLD
    mov byte [my_window + WINDOW.text_color], COLOR_TEXT_GREEN
    
    ; Draw the window
    mov esi, my_window
    call tui_draw_window
    
    ; Display content
    mov esi, content_text
    mov eax, 10
    mov ebx, 5
    mov ecx, COLOR_TEXT_GREEN
    call tui_print_at
```

## Integration Notes

### Required Dependencies
- `vga.asm` - VGA text mode driver (provides `vga_put_char_attr`)
- `keyboard.asm` - Keyboard driver for input handling
- `encoding.asm` - Character encoding support (CP866 Cyrillic)

### Memory Requirements
- Static data: ~512 bytes
- Stack usage: ~128 bytes per function call
- Maximum windows: 16 simultaneous

### Performance Considerations
- All functions use `PUSHA/POPA` for register preservation
- Box drawing optimized for minimal BIOS calls
- Double-buffering not implemented (direct VGA memory writes recommended for production)

## Stylistic Guidelines

### Message Format
All system messages should follow the pattern:
```
[КОМПОНЕНТЪ] Сообщеніе...
```

### Error Messages
```
† ОШИБКА †: Текстъ ошибки
Требуется покаяніе и повтореніе ритуала
```

### Success Messages
```
† УСПѢХЪ †: Операция завершена во славу Царя и Отечества
```

## Future Enhancements
- [ ] Double-buffering for flicker-free rendering
- [ ] Mouse cursor support integration
- [ ] Scrollable text regions
- [ ] Custom color palette configuration
- [ ] Unicode support (UTF-8)
- [ ] Animated transitions
- [ ] Menu system with keyboard navigation

## Legal Notice
This visual style is an original creation inspired by:
- Retro terminal aesthetics (1970s-1980s)
- Historical Russian Imperial design elements
- Generic "techno-ritual" themes

All symbols and text are either public domain or originally created.
No copyrighted material from Warhammer 40k or other franchises is used.

## Version History
- **v1.0** (2026): Initial implementation with Gold-Emerald Ritual style
  - Basic window management
  - Orthodox cross borders
  - Pre-revolutionary orthography
  - Green/Gold/Red color scheme
