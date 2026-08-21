import { Facebook, Instagram, Linkedin, Mail, Phone, Apple, Smartphone } from "lucide-react";
import type { Lang } from "../data/content";

function StoreBadge({ apple, href }: { apple: boolean; href: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="group flex min-w-[170px] items-center gap-3 rounded-xl border border-white/15 bg-white/[0.06] px-4 py-2.5 transition hover:-translate-y-0.5 hover:bg-white/10"
      aria-label={apple ? "Download on the App Store" : "Get it on Google Play"}
    >
      {apple ? <Apple size={27} fill="currentColor" /> : <Smartphone size={25} />}
      <span className="leading-tight">
        <span className="block text-[9px] font-semibold uppercase tracking-wide text-slate-400">
          {apple ? "Download on the" : "GET IT ON"}
        </span>
        <span className="block text-[18px] font-extrabold">
          {apple ? "App Store" : "Google Play"}
        </span>
      </span>
    </a>
  );
}

export default function Footer({ lang }: { lang: Lang }) {
  return (
    <footer className="bg-nf-black text-white">
      <div className="container-page grid gap-12 py-16 md:grid-cols-[1.35fr_repeat(3,1fr)]">
        <div>
          <div className="flex items-center gap-2 text-xl font-black">
            <span className="grid h-9 w-9 place-items-center rounded-xl bg-nf-primary text-white">N</span>
            Nearby<span className="text-nf-salat">Fundi</span>
          </div>
          <p className="mt-5 max-w-sm leading-7 text-slate-400">
            {lang === "en"
              ? "Connecting customers with trusted local technicians and service providers."
              : "Tunaunganisha wateja na mafundi na watoa huduma wa karibu wanaoaminika."}
          </p>
          <div className="mt-6 flex gap-2">
            <a href="#" className="rounded-full bg-white/10 p-2.5 hover:bg-white/20"><Instagram size={17}/></a>
            <a href="#" className="rounded-full bg-white/10 p-2.5 hover:bg-white/20"><Facebook size={17}/></a>
            <a href="#" className="rounded-full bg-white/10 p-2.5 hover:bg-white/20"><Linkedin size={17}/></a>
          </div>
        </div>

        <div>
          <h4 className="font-black">Product</h4>
          <div className="mt-5 space-y-3 text-sm text-slate-400">
            <a href="#about" className="block hover:text-white">About</a>
            <a href="#services" className="block hover:text-white">Services</a>
            <a href="#blog" className="block hover:text-white">Blog</a>
          </div>
        </div>

        <div>
          <h4 className="font-black">Company</h4>
          <div className="mt-5 space-y-3 text-sm text-slate-400">
            <a href="#careers" className="block hover:text-white">Careers</a>
            <a href="#faq" className="block hover:text-white">FAQ</a>
            <a href="#support" className="block hover:text-white">Support</a>
          </div>
        </div>

        <div>
          <h4 className="font-black">Contact</h4>
          <div className="mt-5 space-y-3 text-sm text-slate-400">
            <p className="flex gap-2"><Mail size={16}/>info.nearbyfundi@gmail.com</p>
            <p className="flex gap-2"><Phone size={16}/>0682131140</p>
            <p className="flex gap-2"><Phone size={16}/>0679117297</p>
            <p>Morocco, Dar es Salaam, Tanzania</p>
          </div>
        </div>
      </div>

      <div className="border-t border-white/10">
        <div className="container-page py-8">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <p className="text-sm font-extrabold text-white">
                {lang === "en" ? "Get the NearbyFundi app" : "Pakua NearbyFundi"}
              </p>
              <p className="mt-1 text-xs text-slate-500">
                {lang === "en"
                  ? "Find services, request a fundi and chat from your phone."
                  : "Tafuta huduma, omba fundi na wasiliana kupitia simu yako."}
              </p>
            </div>

            <div className="flex flex-wrap gap-3">
              {/* Replace # with your real store URLs when the apps are published. */}
              <StoreBadge apple href="#" />
              <StoreBadge apple={false} href="#" />
            </div>
          </div>

          <div className="mt-8 flex flex-col justify-between gap-3 border-t border-white/10 pt-5 text-xs text-slate-500 sm:flex-row">
            <span>© {new Date().getFullYear()} NearbyFundi. All rights reserved.</span>
            <span>Partners: Selcom · Dohosting · Beam Africa</span>
          </div>
        </div>
      </div>
    </footer>
  );
}