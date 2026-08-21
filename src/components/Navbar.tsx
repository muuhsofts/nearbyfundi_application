import { Menu, X, ArrowUpRight } from "lucide-react";
import { useState } from "react";
import type { Lang } from "../data/content";
import { copy } from "../data/content";

type Props = { lang: Lang; setLang: (l: Lang) => void };

export default function Navbar({ lang, setLang }: Props) {
  const [open, setOpen] = useState(false);
  const t = copy[lang];
  const links = [
    ["home", "#home"], ["about", "#about"], ["services", "#services"],
    ["blog", "#blog"], ["careers", "#careers"], ["faq", "#faq"],
    ["support", "#support"], ["contact", "#contact"]
  ] as const;

  return (
    <header className="fixed left-0 right-0 top-0 z-50 border-b border-slate-200/70 bg-white/90 backdrop-blur-xl">
      <div className="container-page flex h-[74px] items-center justify-between">
        <a href="#home" className="flex items-center gap-2 font-black tracking-tight" onClick={() => setOpen(false)}>
          <span className="grid h-9 w-9 place-items-center rounded-xl bg-nf-primary text-lg text-slate-950">N</span>
          <span className="text-xl">Nearby<span className="text-nf-primary">Fundi</span></span>
        </a>

        <nav className="hidden items-center gap-6 lg:flex">
          {links.map(([key, href]) => (
            <a key={key} href={href} className="text-sm font-semibold text-slate-600 transition hover:text-slate-950">
              {t.nav[key]}
            </a>
          ))}
        </nav>

        <div className="hidden items-center gap-3 lg:flex">
          <button onClick={() => setLang(lang === "en" ? "sw" : "en")} className="rounded-full border border-slate-200 px-3.5 py-2 text-xs font-extrabold">
            {lang === "en" ? "SW" : "EN"}
          </button>
          <a href="#contact" className="btn-dark py-2.5">
            {t.find} <ArrowUpRight size={16} />
          </a>
        </div>

        <button className="rounded-xl p-2 lg:hidden" onClick={() => setOpen(!open)} aria-label="Menu">
          {open ? <X /> : <Menu />}
        </button>
      </div>

      {open && (
        <div className="border-t border-slate-100 bg-white px-5 pb-6 pt-3 lg:hidden">
          <div className="container-page flex flex-col gap-1">
            {links.map(([key, href]) => (
              <a key={key} href={href} onClick={() => setOpen(false)} className="rounded-xl px-3 py-3 font-semibold text-slate-700 hover:bg-slate-50">
                {t.nav[key]}
              </a>
            ))}
            <button onClick={() => setLang(lang === "en" ? "sw" : "en")} className="mt-2 w-fit rounded-full border border-slate-200 px-4 py-2 text-xs font-bold">
              {lang === "en" ? "Switch to Swahili" : "Switch to English"}
            </button>
          </div>
        </div>
      )}
    </header>
  );
}