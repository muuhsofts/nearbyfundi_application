import { Facebook, Instagram, Linkedin, Mail, Phone } from "lucide-react";
import type { Lang } from "../data/content";

export default function Footer({ lang }: { lang: Lang }) {
  return (
    <footer className="bg-slate-950 text-white">
      <div className="container-page grid gap-12 py-16 md:grid-cols-[1.5fr_repeat(3,1fr)]">
        <div>
          <div className="flex items-center gap-2 text-xl font-black">
            <span className="grid h-9 w-9 place-items-center rounded-xl bg-bolt-500 text-slate-950">
              N
            </span>
            Nearby<span className="text-bolt-400">Fundi</span>
          </div>
          <p className="mt-5 max-w-sm leading-7 text-slate-400">
            {lang === "en"
              ? "Connecting customers with trusted local technicians and service providers."
              : "Tunaunganisha wateja na mafundi na watoa huduma wa karibu wanaoaminika."}
          </p>
          <div className="mt-6 flex gap-2">
            <a href="#" className="rounded-full bg-white/10 p-2.5 hover:bg-white/20">
              <Instagram size={17} />
            </a>
            <a href="#" className="rounded-full bg-white/10 p-2.5 hover:bg-white/20">
              <Facebook size={17} />
            </a>
            <a href="#" className="rounded-full bg-white/10 p-2.5 hover:bg-white/20">
              <Linkedin size={17} />
            </a>
          </div>
        </div>
        <div>
          <h4 className="font-black">Product</h4>
          <div className="mt-5 space-y-3 text-sm text-slate-400">
            <a href="#about" className="block hover:text-white">
              About
            </a>
            <a href="#services" className="block hover:text-white">
              Services
            </a>
            <a href="#blog" className="block hover:text-white">
              Blog
            </a>
            <a href="#partners" className="block hover:text-white">
              Partners
            </a>
          </div>
        </div>
        <div>
          <h4 className="font-black">Company</h4>
          <div className="mt-5 space-y-3 text-sm text-slate-400">
            <a href="#careers" className="block hover:text-white">
              Careers
            </a>
            <a href="#faq" className="block hover:text-white">
              FAQ
            </a>
            <a href="#support" className="block hover:text-white">
              Support
            </a>
          </div>
        </div>
        <div>
          <h4 className="font-black">Contact</h4>
          <div className="mt-5 space-y-3 text-sm text-slate-400">
            <p className="flex gap-2">
              <Mail size={16} />
              info.nearbyfundi@gmail.com
            </p>
            <p className="flex gap-2">
              <Phone size={16} />
              0682131140
            </p>
            <p className="flex gap-2">
              <Phone size={16} />
              0679117297
            </p>
            <p>Morocco, Dar es Salaam, Tanzania</p>
          </div>
        </div>
      </div>
      <div className="border-t border-white/10">
        <div className="container-page flex flex-col justify-between gap-3 py-5 text-xs text-slate-500 sm:flex-row">
          <span>© {new Date().getFullYear()} NearbyFundi. All rights reserved.</span>
          <span>
            Partners:{" "}
            <a
              href="https://www.selcom.net/"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-bolt-400"
            >
              Selcom
            </a>{" "}
            ·{" "}
            <a
              href="https://beem.africa/"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-bolt-400"
            >
              Beem Africa
            </a>
          </span>
        </div>
      </div>
    </footer>
  );
}
