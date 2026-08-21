import { useState } from "react";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Sections from "./components/Sections";
import Footer from "./components/Footer";
import type { Lang } from "./data/content";

export default function App() {
  const [lang, setLang] = useState<Lang>("en");
  return <div className="min-h-screen bg-white">
    <Navbar lang={lang} setLang={setLang} />
    <main><Hero lang={lang}/><Sections lang={lang}/></main>
    <Footer lang={lang}/>
  </div>;
}