import { Menu, X, ArrowUpRight, Moon, Sun } from "lucide-react";
import { useState } from "react";
import type { Lang } from "../data/content";
import { copy } from "../data/content";

type Props = {
  lang: Lang;
  setLang: (l: Lang) => void;
  dark: boolean;
  toggleDark: () => void;
};

export default function Navbar({ lang, setLang, dark, toggleDark }: Props) {
  const [open, setOpen] = useState(false);
  const t = copy[lang];
  const links = [
    ["home", "#home"],
    ["about", "#about"],
    ["services", "#services"],
    ["blog", "#blog"],
    ["partners", "#partners"],
    ["careers", "#careers"],
    ["faq", "#faq"],
    ["support", "#support"],
    ["contact", "#contact"]
  ] as const;

  return (
    <header className="fixed left-0 right-0 top-0 z-50 border-b border-slate-200/70 bg-white/90 backdrop-blur-xl dark:border-slate-800 dark:bg-slate-950/90">
      <div className="container-page flex h-[74px] items-center justify-between">
        <a
          href="#home"
          className="flex items-center gap-2 font-black tracking-tight"
          onClick={() => setOpen(false)}
        >
          <span className="grid h-9 w-9 place-items-center rounded-xl bg-bolt-500 text-lg text-slate-950">
            N
          </span>
          <span className="text-xl">
            Nearby<span className="text-bolt-600">Fundi</span>
          </span>
        </a>

        <nav className="hidden items-center gap-5 xl:flex">
          {links.map(([key, href]) => (
            <a
              key={key}
              href={href}
              className="text-sm font-semibold text-slate-600 transition hover:text-slate-950 dark:text-slate-300 dark:hover:text-white"
            >
              {t.nav[key]}
            </a>
          ))}
        </nav>

        <div className="hidden items-center gap-2 lg:flex">
          {/* Language switcher with flags */}
          <div className="flex items-center gap-1 rounded-full border border-slate-200 bg-slate-50 p-1 dark:border-slate-700 dark:bg-slate-900">
            <button
              onClick={() => setLang("en")}
              className={`flex items-center gap-1.5 rounded-full px-2.5 py-1.5 text-xs font-bold transition ${
                lang === "en"
                  ? "bg-white shadow-sm dark:bg-slate-700"
                  : "opacity-70 hover:opacity-100"
              }`}
              title="English"
            >
              <img src="/uk-flag.png" alt="English" className="h-4 w-4 rounded-sm object-cover" />
              EN
            </button>
            <button
              onClick={() => setLang("sw")}
              className={`flex items-center gap-1.5 rounded-full px-2.5 py-1.5 text-xs font-bold transition ${
                lang === "sw"
                  ? "bg-white shadow-sm dark:bg-slate-700"
                  : "opacity-70 hover:opacity-100"
              }`}
              title="Kiswahili"
            >
              <img src="/tz-flag.jpg" alt="Swahili" className="h-4 w-4 rounded-sm object-cover" />
              SW
            </button>
          </div>

          <button
            onClick={toggleDark}
            className="rounded-full border border-slate-200 p-2.5 transition hover:bg-slate-100 dark:border-slate-700 dark:hover:bg-slate-800"
            aria-label="Toggle dark mode"
            title={dark ? t.lightMode : t.darkMode}
          >
            {dark ? <Sun size={18} /> : <Moon size={18} />}
          </button>

          <a href="#contact" className="btn-dark py-2.5">
            {t.find} <ArrowUpRight size={16} />
          </a>
        </div>

        <button
          className="rounded-xl p-2 lg:hidden dark:text-white"
          onClick={() => setOpen(!open)}
          aria-label="Menu"
        >
          {open ? <X /> : <Menu />}
        </button>
      </div>

      {open && (
        <div className="border-t border-slate-100 bg-white px-5 pb-6 pt-3 dark:border-slate-800 dark:bg-slate-950 lg:hidden">
          <div className="container-page flex flex-col gap-1">
            {links.map(([key, href]) => (
              <a
                key={key}
                href={href}
                onClick={() => setOpen(false)}
                className="rounded-xl px-3 py-3 font-semibold text-slate-700 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-slate-900"
              >
                {t.nav[key]}
              </a>
            ))}
            <div className="mt-3 flex flex-wrap items-center gap-3">
              <div className="flex items-center gap-1 rounded-full border border-slate-200 bg-slate-50 p-1 dark:border-slate-700 dark:bg-slate-900">
                <button
                  onClick={() => setLang("en")}
                  className={`flex items-center gap-1.5 rounded-full px-3 py-2 text-xs font-bold ${
                    lang === "en" ? "bg-white shadow-sm dark:bg-slate-700" : ""
                  }`}
                >
                  <img src="/uk-flag.png" alt="EN" className="h-4 w-4 rounded-sm object-cover" />
                  English
                </button>
                <button
                  onClick={() => setLang("sw")}
                  className={`flex items-center gap-1.5 rounded-full px-3 py-2 text-xs font-bold ${
                    lang === "sw" ? "bg-white shadow-sm dark:bg-slate-700" : ""
                  }`}
                >
                  <img src="/tz-flag.jpg" alt="SW" className="h-4 w-4 rounded-sm object-cover" />
                  Kiswahili
                </button>
              </div>
              <button
                onClick={toggleDark}
                className="flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-xs font-bold dark:border-slate-700"
              >
                {dark ? <Sun size={14} /> : <Moon size={14} />}
                {dark ? t.lightMode : t.darkMode}
              </button>
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
