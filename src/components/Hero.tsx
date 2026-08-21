import { ArrowDownRight, CheckCircle2, ShieldCheck, Smartphone, type LucideIcon } from "lucide-react";
import type { Lang } from "../data/content";
import { copy } from "../data/content";
import PhoneMockup from "./PhoneMockup";

export default function Hero({ lang }: { lang: Lang }) {
  const t = copy[lang];

  const features: [LucideIcon, string][] = [
    [ShieldCheck, lang === "en" ? "Trusted profiles" : "Wasifu wa kuamini"],
    [Smartphone, lang === "en" ? "Mobile-first" : "Imejengwa kwa simu"],
    [CheckCircle2, lang === "en" ? "Simple requests" : "Maombi rahisi"],
  ];

  return (
      <section id="home" className="overflow-hidden bg-[#f6fbf9] pt-[74px]">
        <div className="container-page grid min-h-[760px] items-center gap-14 py-20 lg:grid-cols-[1.05fr_.95fr] lg:py-24">
          <div>
          <span className="eyebrow">
            <span className="h-2 w-2 rounded-full bg-nf-primary" />
            {t.heroEyebrow}
          </span>

            <h1 className="max-w-3xl text-5xl font-black leading-[.98] tracking-[-0.055em] text-slate-950 sm:text-6xl lg:text-7xl">
              {t.heroTitle}
            </h1>

            <p className="mt-7 max-w-2xl text-lg leading-8 text-slate-600">
              {t.heroText}
            </p>

            <div className="mt-9 flex flex-wrap gap-3">
              <a href="#services" className="btn-primary">
                {t.find} <ArrowDownRight size={18} />
              </a>
              <a href="#about" className="btn-dark">
                {t.explore}
              </a>
            </div>

            <div className="mt-9 grid max-w-xl grid-cols-1 gap-3 sm:grid-cols-3">
              {features.map(([Icon, text]) => (
                  <div
                      key={text}
                      className="flex items-center gap-2 text-sm font-bold text-slate-700"
                  >
                    <Icon size={17} className="text-nf-primary" />
                    {text}
                  </div>
              ))}
            </div>
          </div>

          <div className="relative mx-auto w-full max-w-xl">
            <div className="absolute -inset-10 rounded-full bg-nf-primary/20 blur-3xl" />
            <div className="relative rounded-[42px] bg-slate-950 p-7 shadow-2xl">
              <div className="mb-6 flex items-center justify-between text-white">
                <div>
                  <p className="text-xs font-bold text-nf-salat">NearbyFundi</p>
                  <p className="mt-1 text-2xl font-black">Services, nearby.</p>
                </div>
                <div className="rounded-full bg-white/10 px-3 py-1.5 text-xs font-bold">
                  Dar es Salaam
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <PhoneMockup screen="home" label="Browse services" />
                <div className="hidden sm:block">
                  <PhoneMockup screen="request" label="Track request" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
  );
}