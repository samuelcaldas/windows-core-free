# Design System & Visual Authority: Windows CoreOS (WCOS)

## Aesthetic World: Midnight Terminal Neon
The design language of Windows CoreOS reflects a high-tech, hyper-efficient server and developer workstation. It combines deep server room darkness with vibrant cyber cyan terminal luminescence and official Windows Core blue branding.

## Color Tokens & Palette

| Token | Hex | RGB | Semantic Usage |
| :--- | :--- | :--- | :--- |
| `surface-primary` | `#0B132B` | `rgb(11, 19, 43)` | Primary background, terminal canvas, dark mode page body |
| `surface-elevated`| `#101B38` | `rgb(16, 27, 56)` | Elevated cards, navigation dropdowns, code block backgrounds |
| `surface-border`  | `#1E293B` | `rgb(30, 41, 59)` | Component dividers, subtle card borders, table outlines |
| `accent-neon`     | `#00F5D4` | `rgb(0, 245, 212)` | Hero gradients, active cursors, CTA highlights, badges |
| `brand-blue`      | `#0078D4` | `rgb(0, 120, 212)` | Primary CTA buttons, official Windows ecosystem accents |
| `brand-azure`     | `#00D2FF` | `rgb(0, 210, 255)` | Secondary gradients, active link focus states |
| `status-emerald`  | `#10B981` | `rgb(16, 185, 129)`| Online node indicators, passing checks, RAM reduction bars |

## Typography Hierarchy
* **Monospace / Code**: `Cascadia Code`, `JetBrains Mono`, `Consolas`, `monospace`
  - Used for terminal outputs, commands, file paths, and syntax highlighting.
* **Proportional / Body**: `Segoe UI`, `Inter`, `-apple-system`, `sans-serif`
  - Used for documentation text, headings, navigation items, and feature cards.

## UI Craft Standards (VitePress & Web Portals)
* **Contrast Floor**: All text elements must achieve at least 4.5:1 contrast against their respective backgrounds.
* **Component Elevation**: Feature cards use subtle border glows (`0 10px 30px rgba(0, 245, 212, 0.08)`) on hover without jarring layout shifts.
* **Hero Section**: Displays a high-resolution SVG isometric server core glyph with dynamic multi-stop gradient typography (`#00F5D4` -> `#00D2FF` -> `#0078D4`).
* **Responsive Layout**: Full fluid grid scaling across mobile screens (<640px), tablets, and ultrawide displays.
