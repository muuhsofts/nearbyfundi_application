import { useState } from "react";
import { ArrowRight, BriefcaseBusiness, Check, ChevronDown, Headphones, MessageCircle, Search, ShieldCheck, Wrench, Zap, Droplets, Hammer, CarFront, Smartphone } from "lucide-react";
import type { Lang } from "../data/content";
import { copy } from "../data/content";
import PhoneMockup from "./PhoneMockup";

const services = [
  { icon: Wrench, en: "Home repairs", sw: "Matengenezo ya nyumbani", text: "General maintenance and skilled home services." },
  { icon: Zap, en: "Electrical", sw: "Umeme", text: "Connect with electricians for installation and repair." },
  { icon: Droplets, en: "Plumbing", sw: "Mabomba", text: "Find plumbers for leaks, fittings and installations." },
  { icon: Hammer, en: "Construction", sw: "Ujenzi", text: "Skilled workers for construction and finishing." },
  { icon: CarFront, en: "Automotive", sw: "Magari", text: "Automotive support and maintenance services." },
  { icon: Smartphone, en: "Appliances & electronics", sw: "Vifaa na elektroniki", text: "Technicians for appliances and electronic devices." }
];

const faqs = [
  ["What is NearbyFundi?", "NearbyFundi is a platform that helps customers discover nearby technicians, request services and communicate with fundis."],
  ["Can technicians join the platform?", "Yes. Technicians can create a profile, add their services and working area, then go through the platform's verification process."],
  ["Does NearbyFundi support Swahili?", "Yes. The product and website are designed with English and Swahili support."],
  ["Can I chat with a technician?", "Yes. The app includes chat so customers and technicians can communicate around a service request."]
];

export default function Sections({ lang }: { lang: Lang }) {
  const t = copy[lang];
  const [faq, setFaq] = useState<number | null>(0);

  return <>
    <section id="about" className="section-pad bg-white">
      <div className="container-page grid items-center gap-14 lg:grid-cols-2">
        <div>
          <span className="eyebrow">{t.aboutEyebrow}</span>
          <h2 className="text-4xl font-black tracking-tight sm:text-5xl">{t.aboutTitle}</h2>
          <p className="mt-6 max-w-xl text-lg leading-8 text-slate-600">{t.aboutText}</p>
          <div className="mt-8 grid gap-4 sm:grid-cols-2">
            {[
              ["01", lang === "en" ? "Discover" : "Tafuta", lang === "en" ? "Browse services and technicians around your area." : "Tazama huduma na mafundi waliopo karibu."],
              ["02", lang === "en" ? "Request" : "Omba huduma", lang === "en" ? "Describe your job and send a service request." : "Eleza kazi yako na tuma ombi la huduma."],
              ["03", lang === "en" ? "Connect" : "Wasiliana", lang === "en" ? "Chat and coordinate directly with your technician." : "Wasiliana na kuratibu moja kwa moja na fundi."],
              ["04", lang === "en" ? "Complete" : "Maliza kazi", lang === "en" ? "Get the job done and build trust through reviews." : "Kamilisha kazi na jenga uaminifu kupitia tathmini."]
            ].map(([n, title, text]) => <div key={n} className="rounded-2xl border border-slate-200 p-5"><span className="text-xs font-black text-nf-primary">{n}</span><h3 className="mt-2 font-black">{title}</h3><p className="mt-1 text-sm leading-6 text-slate-500">{text}</p></div>)}
          </div>
        </div>
        <div className="rounded-[40px] bg-slate-950 p-8 text-white sm:p-12">
          <div className="flex items-start justify-between"><div className="rounded-2xl bg-nf-primary p-3 text-slate-950"><Search /></div><span className="rounded-full bg-white/10 px-3 py-1 text-xs font-bold">Product flow</span></div>
          <h3 className="mt-12 text-3xl font-black">From “I need help” to “job done.”</h3>
          <div className="mt-8 space-y-5">
            {["Choose a service", "View suitable technicians", "Send a request", "Chat & track progress", "Complete and review"].map((x, i) => <div key={x} className="flex items-center gap-4 border-b border-white/10 pb-5"><span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-nf-primary text-xs font-black text-slate-950">{i+1}</span><span className="font-bold">{x}</span></div>)}
          </div>
        </div>
      </div>
    </section>

    <section id="services" className="section-pad bg-[#f6fbf9]">
      <div className="container-page">
        <span className="eyebrow">{t.serviceEyebrow}</span>
        <div className="flex flex-col justify-between gap-5 md:flex-row md:items-end"><h2 className="max-w-2xl text-4xl font-black tracking-tight sm:text-5xl">{t.serviceTitle}</h2><a href="#contact" className="font-black text-nf-primary">Talk to us <ArrowRight size={16} className="inline" /></a></div>
        <div className="mt-12 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {services.map(({ icon: Icon, en, sw, text }) => <article key={en} className="card group p-7 transition hover:-translate-y-1 hover:border-nf-accent">
            <div className="grid h-12 w-12 place-items-center rounded-2xl bg-emerald-50 text-nf-primary"><Icon size={23}/></div>
            <h3 className="mt-6 text-xl font-black">{lang === "en" ? en : sw}</h3><p className="mt-2 text-sm leading-6 text-slate-500">{text}</p>
            <div className="mt-6 flex items-center gap-2 text-xs font-black text-slate-800">Explore service <ArrowRight size={14}/></div>
          </article>)}
        </div>
      </div>
    </section>

    <section id="blog" className="section-pad bg-white">
      <div className="container-page">
        <span className="eyebrow">{t.blogEyebrow}</span>
        <h2 className="max-w-3xl text-4xl font-black tracking-tight sm:text-5xl">{t.blogTitle}</h2>
        <div className="mt-12 grid gap-6 lg:grid-cols-3">
          <article className="card overflow-hidden lg:col-span-2">
            <div className="grid items-center gap-8 bg-slate-950 p-8 text-white sm:grid-cols-[.9fr_1.1fr] sm:p-10">
              <PhoneMockup screen="chat" label="Chat module" />
              <div><span className="text-xs font-black uppercase tracking-[.16em] text-nf-salat">Featured build</span><h3 className="mt-4 text-3xl font-black">How we build a NearbyFundi service journey</h3><p className="mt-4 leading-7 text-slate-300">From the customer request screen to technician matching, live request status and chat. This product story explains the architecture and the user experience behind the app.</p><a href="#contact" className="mt-7 inline-flex items-center gap-2 font-black text-nf-salat">Read product story <ArrowRight size={16}/></a></div>
            </div>
          </article>
          {[
            ["App architecture", "Flutter mobile + Laravel API + Firebase notifications.", "01"],
            ["Technician onboarding", "Profiles, service categories, working areas and verification.", "02"],
            ["Chat & requests", "A clear request lifecycle from pending to completion.", "03"]
          ].map(([title, text, n]) => <article key={n} className="card p-7"><span className="text-xs font-black text-nf-primary">ARTICLE {n}</span><h3 className="mt-5 text-2xl font-black">{title}</h3><p className="mt-3 leading-7 text-slate-500">{text}</p><a href="#contact" className="mt-6 inline-flex items-center gap-2 text-sm font-black">Read more <ArrowRight size={15}/></a></article>)}
        </div>
      </div>
    </section>

    <section id="careers" className="section-pad bg-nf-primary">
      <div className="container-page grid gap-10 lg:grid-cols-[1fr_auto] lg:items-end">
        <div><span className="eyebrow bg-slate-950 text-nf-salat"><BriefcaseBusiness size={14}/> Careers</span><h2 className="max-w-3xl text-4xl font-black tracking-tight text-slate-950 sm:text-6xl">{t.careersTitle}</h2><p className="mt-6 max-w-2xl text-lg leading-8 text-slate-800">{t.careersText}</p></div>
        <a href="mailto:info.nearbyfundi@gmail.com?subject=Careers%20at%20NearbyFundi" className="btn-dark">Send your CV <ArrowRight size={17}/></a>
      </div>
    </section>

    <section id="faq" className="section-pad bg-white">
      <div className="container-page grid gap-12 lg:grid-cols-[.8fr_1.2fr]">
        <div><span className="eyebrow">{t.nav.faq}</span><h2 className="text-4xl font-black tracking-tight sm:text-5xl">{t.faqTitle}</h2><p className="mt-5 text-slate-500">Everything you need to understand the platform.</p></div>
        <div className="space-y-3">{faqs.map(([q, a], i) => <div key={q} className="rounded-2xl border border-slate-200">
          <button className="flex w-full items-center justify-between gap-4 p-5 text-left font-black" onClick={() => setFaq(faq === i ? null : i)}>{q}<ChevronDown size={19} className={faq === i ? "rotate-180 transition" : "transition"}/></button>
          {faq === i && <p className="px-5 pb-5 leading-7 text-slate-500">{a}</p>}
        </div>)}</div>
      </div>
    </section>

    <section id="support" className="section-pad bg-slate-50">
      <div className="container-page">
        <div className="rounded-[36px] bg-slate-950 p-8 text-white sm:p-12 lg:flex lg:items-center lg:justify-between">
          <div><span className="inline-flex items-center gap-2 text-sm font-bold text-nf-salat"><Headphones size={16}/> Support</span><h2 className="mt-4 text-4xl font-black">{t.supportTitle}</h2><p className="mt-4 max-w-xl leading-7 text-slate-300">{t.supportText}</p></div>
          <div className="mt-8 flex flex-wrap gap-3 lg:mt-0"><a className="btn-primary" href="mailto:info.nearbyfundi@gmail.com"><MessageCircle size={17}/> Email support</a><a className="rounded-full border border-white/20 px-6 py-3.5 font-bold hover:bg-white/10" href="tel:0682131140">Call 0682131140</a></div>
        </div>
      </div>
    </section>

    <section id="contact" className="section-pad bg-white">
      <div className="container-page grid gap-12 lg:grid-cols-2">
        <div><span className="eyebrow">{t.contactEyebrow}</span><h2 className="text-4xl font-black tracking-tight sm:text-5xl">{t.contactTitle}</h2><p className="mt-5 max-w-xl text-lg leading-8 text-slate-500">{t.contactText}</p>
          <div className="mt-8 space-y-3 text-sm"><p><b>Office:</b> Morocco, Dar es Salaam, Tanzania</p><p><b>Email:</b> info.nearbyfundi@gmail.com</p><p><b>Phone:</b> 0682131140 · 0679117297</p></div>
        </div>
        <form className="card p-7 sm:p-9" onSubmit={(e) => e.preventDefault()}>
          <div className="grid gap-5 sm:grid-cols-2"><label className="text-sm font-bold">Name<input className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3.5 outline-none focus:border-nf-primary" placeholder="Your name"/></label><label className="text-sm font-bold">Email<input type="email" className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3.5 outline-none focus:border-nf-primary" placeholder="you@example.com"/></label></div>
          <label className="mt-5 block text-sm font-bold">Message<textarea className="mt-2 min-h-36 w-full rounded-xl border border-slate-200 px-4 py-3.5 outline-none focus:border-nf-primary" placeholder="How can we help?"/></label>
          <button className="btn-primary mt-5 w-full">Send message <ArrowRight size={17}/></button>
        </form>
      </div>
    </section>
  </>;
}