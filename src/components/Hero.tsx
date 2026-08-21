import type { LucideIcon } from "lucide-react";
import {
  ArrowDownRight,
  CheckCircle2,
  ShieldCheck,
  Smartphone,
} from "lucide-react";
import type { Lang } from "../data/content";
import { copy } from "../data/content";

// ─── Feature item type ──────────────────────────────────────────────
type FeatureItem = {
  Icon: LucideIcon;
  label: string;
};

// ─── Component ──────────────────────────────────────────────────────
export default function Hero({ lang }: { lang: Lang }) {
  const t = copy[lang];

  const features: FeatureItem[] = [
    {
      Icon: ShieldCheck,
      label: lang === "en" ? "Trusted profiles" : "Wasifu wa kuamini",
    },
    {
      Icon: Smartphone,
      label: lang === "en" ? "Mobile-first" : "Imejengwa kwa simu",
    },
    {
      Icon: CheckCircle2,
      label: lang === "en" ? "Simple requests" : "Maombi rahisi",
    },
  ];

  return (
      <section
          id="home"
          className="overflow-hidden bg-[#f6fbf9] pt-[74px] dark:bg-slate-900/50"
      >
        <div className="container-page grid min-h-[720px] items-center gap-12 py-16 lg:grid-cols-[1.05fr_.95fr] lg:py-20">
          {/* ─── Left column ───────────────────────────────── */}
          <div>
                    <span className="eyebrow">
                        <span className="h-2 w-2 rounded-full bg-bolt-500" />
                      {t.heroEyebrow}
                    </span>

            <h1 className="max-w-3xl text-4xl font-black leading-[1.05] tracking-[-0.04em] text-slate-950 sm:text-5xl lg:text-6xl dark:text-white">
              {t.heroTitle}
            </h1>

            <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
              {t.heroText}
            </p>

            <div className="mt-8 flex flex-wrap gap-3">
              <a href="#services" className="btn-primary">
                {t.find} <ArrowDownRight size={18} />
              </a>
              <a href="#about" className="btn-dark">
                {t.explore}
              </a>
            </div>

            {/* ─── Feature badges ────────────────────────── */}
            <div className="mt-8 grid max-w-xl grid-cols-1 gap-3 sm:grid-cols-3">
              {features.map(({ Icon, label }) => (
                  <div
                      key={label}
                      className="flex items-center gap-2 text-sm font-bold text-slate-700 dark:text-slate-300"
                  >
                    <Icon
                        size={17}
                        className="text-bolt-600"
                        strokeWidth={2}
                    />
                    {label}
                  </div>
              ))}
            </div>
          </div>

          {/* ─── Right column (phone mockup) ──────────────── */}
          <div className="relative mx-auto w-full max-w-lg">
            <div className="absolute -inset-8 rounded-full bg-bolt-500/20 blur-3xl dark:bg-bolt-500/10" />

            <div className="relative overflow-hidden rounded-[32px] border border-slate-200 bg-slate-950 p-4 shadow-2xl dark:border-slate-700 sm:p-5">
              {/* header */}
              <div className="mb-4 flex items-center justify-between text-white">
                <div>
                  <p className="text-xs font-bold text-bolt-400">
                    NearbyFundi
                  </p>
                  <p className="mt-0.5 text-xl font-black">
                    Services, nearby.
                  </p>
                </div>
                <div className="rounded-full bg-white/10 px-3 py-1 text-xs font-bold">
                  Dar es Salaam
                </div>
              </div>

              {/* screenshot grid */}
              <div className="grid grid-cols-2 gap-3">
                <div className="overflow-hidden rounded-2xl border border-white/10 bg-slate-900">
                  <img
                      src="/screenshots/map-fundis.png"
                      alt="Find fundis map"
                      className="h-56 w-full object-cover object-top sm:h-64"
                  />
                </div>
                <div className="overflow-hidden rounded-2xl border border-white/10 bg-slate-900">
                  <img
                      src="/screenshots/dashboard.png"
                      alt="Dashboard"
                      className="h-56 w-full object-cover object-top sm:h-64"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
  );
}