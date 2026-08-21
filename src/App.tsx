import { useEffect, useState } from "react";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Sections from "./components/Sections";
import Footer from "./components/Footer";
import type { Lang } from "./data/content";

export default function App() {
  const [lang, setLang] = useState<Lang>("en");
  const [dark, setDark] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("nf-theme");
    if (stored === "dark" || (!stored && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
      setDark(true);
      document.documentElement.classList.add("dark");
    }
  }, []);

  const toggleDark = () => {
    setDark((d) => {
      const next = !d;
      document.documentElement.classList.toggle("dark", next);
      localStorage.setItem("nf-theme", next ? "dark" : "light");
      return next;
    });
  };

  return (
    <div className="min-h-screen bg-white text-slate-900 transition-colors dark:bg-slate-950 dark:text-slate-100">
      <Navbar lang={lang} setLang={setLang} dark={dark} toggleDark={toggleDark} />
      <main>
        <Hero lang={lang} />
        <Sections lang={lang} />
      </main>
      <Footer lang={lang} />
    </div>
  );
}
