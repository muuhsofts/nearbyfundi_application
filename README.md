# NearbyFundi Website

A Bolt-inspired, static marketing website for NearbyFundi built with React, TypeScript, Vite and Tailwind CSS.

## Sections

- Home
- About
- Services
- Blog / product stories
- Careers
- FAQ
- Support
- Contact
- English / Swahili language toggle
- Responsive mobile navigation
- Dark footer
- Partner display: Selcom, Dohosting, Beam Africa
- NearbyFundi app UI mockups without a map

## Run

```bash
npm install
npm run dev
```

Build for production:

```bash
npm run build
npm run preview
```

## Project structure

```text
src/
  components/
    Footer.tsx
    Hero.tsx
    Navbar.tsx
    PhoneMockup.tsx
    Sections.tsx
  data/
    content.ts
  App.tsx
  index.css
  main.tsx
```

The contact form is intentionally static. Connect it to your Laravel/API endpoint when the backend is ready.
