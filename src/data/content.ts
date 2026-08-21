export type Lang = "en" | "sw";

export const copy = {
  en: {
    nav: {
      home: "Home",
      about: "About",
      services: "Services",
      blog: "Blog",
      partners: "Partners",
      careers: "Careers",
      faq: "FAQ",
      support: "Support",
      contact: "Contact"
    },
    heroEyebrow: "Your trusted service marketplace",
    heroTitle: "Find a trusted fundi. Right when you need one.",
    heroText:
      "NearbyFundi connects customers with nearby technicians and service providers for home, electrical, plumbing, appliance, construction, automotive and maintenance services.",
    find: "Get started",
    explore: "Explore how it works",
    aboutEyebrow: "Built for Tanzania",
    aboutTitle: "Local service discovery, made simple.",
    aboutText:
      "NearbyFundi is a digital platform that makes it easier to discover, request and communicate with skilled technicians. Customers get convenience. Fundis get visibility and new jobs.",
    serviceEyebrow: "What you can book",
    serviceTitle: "One app for everyday services.",
    blogEyebrow: "Product stories",
    blogTitle: "See the app in action.",
    partnersEyebrow: "Trusted partners",
    partnersTitle: "Powering payments & growth across Africa.",
    partnersText:
      "We work with leading African technology companies to deliver reliable payments, messaging and infrastructure for NearbyFundi.",
    contactEyebrow: "Talk to NearbyFundi",
    contactTitle: "Questions, partnerships or support?",
    contactText:
      "Reach our team in Dar es Salaam for product support, partnerships and business enquiries.",
    careersTitle: "Build the future of local services with us.",
    careersText:
      "We are building technology that creates opportunity for skilled people and makes everyday services easier to access.",
    faqTitle: "Frequently asked questions",
    supportTitle: "Need help?",
    supportText:
      "Our support team can help with accounts, service requests, technician onboarding and general product questions.",
    darkMode: "Dark",
    lightMode: "Light"
  },
  sw: {
    nav: {
      home: "Mwanzo",
      about: "Kuhusu",
      services: "Huduma",
      blog: "Blogu",
      partners: "Washirika",
      careers: "Ajira",
      faq: "Maswali",
      support: "Msaada",
      contact: "Mawasiliano"
    },
    heroEyebrow: "Soko la huduma unaloweza kuamini",
    heroTitle: "Mpate fundi unayemwamini, pale unapomhitaji.",
    heroText:
      "NearbyFundi inaunganisha wateja na mafundi na watoa huduma walio karibu kwa huduma za nyumbani, umeme, mabomba, vifaa, ujenzi, magari na matengenezo.",
    find: "Anza sasa",
    explore: "Jinsi inavyofanya kazi",
    aboutEyebrow: "Imejengwa kwa Tanzania",
    aboutTitle: "Kupata huduma za karibu, kwa urahisi.",
    aboutText:
      "NearbyFundi ni jukwaa la kidijitali linalorahisisha kutafuta, kuomba na kuwasiliana na mafundi wenye ujuzi. Wateja wanapata urahisi; mafundi wanapata wateja na kazi zaidi.",
    serviceEyebrow: "Huduma unazoweza kuomba",
    serviceTitle: "Programu moja kwa huduma za kila siku.",
    blogEyebrow: "Hadithi za bidhaa",
    blogTitle: "Tazama programu ikifanya kazi.",
    partnersEyebrow: "Washirika wa kuaminika",
    partnersTitle: "Tunasaidia malipo na ukuaji Afrika.",
    partnersText:
      "Tunafanya kazi na makampuni ya teknolojia yanayoongoza Afrika kutoa malipo, ujumbe na miundombinu ya kuaminika kwa NearbyFundi.",
    contactEyebrow: "Wasiliana na NearbyFundi",
    contactTitle: "Una swali, ushirikiano au unahitaji msaada?",
    contactText:
      "Wasiliana na timu yetu Dar es Salaam kwa msaada, ushirikiano na maswali ya biashara.",
    careersTitle: "Jenga nasi mustakabali wa huduma za ndani.",
    careersText:
      "Tunajenga teknolojia inayowawezesha mafundi wenye ujuzi kupata fursa na kurahisisha upatikanaji wa huduma.",
    faqTitle: "Maswali yanayoulizwa mara kwa mara",
    supportTitle: "Unahitaji msaada?",
    supportText:
      "Timu yetu inaweza kusaidia kuhusu akaunti, maombi ya huduma, usajili wa mafundi na maswali ya bidhaa.",
    darkMode: "Giza",
    lightMode: "Mwanga"
  }
};

export const blogSlides = [
  {
    img: "/screenshots/login.png",
    titleEn: "Sign in & welcome",
    titleSw: "Ingia na karibu",
    descEn: "Clean sign-in experience with map preview of nearby fundis.",
    descSw: "Uzoefu safi wa kuingia na muonekano wa ramani ya mafundi wa karibu."
  },
  {
    img: "/screenshots/map-fundis.png",
    titleEn: "Find fundis on the map",
    titleSw: "Tafuta mafundi kwenye ramani",
    descEn: "Live map of technicians in Ubungo, Dar es Salaam with distance and ETA.",
    descSw: "Ramani ya moja kwa moja ya mafundi Ubungo, Dar es Salaam yenye umbali na ETA."
  },
  {
    img: "/screenshots/search.png",
    titleEn: "Search & filter services",
    titleSw: "Tafuta na chuja huduma",
    descEn: "Filter by service category — car diagnostics, electrical, repairs and more.",
    descSw: "Chuja kwa aina ya huduma — uchunguzi wa gari, umeme, matengenezo na zaidi."
  },
  {
    img: "/screenshots/dashboard.png",
    titleEn: "Technician dashboard",
    titleSw: "Dashibodi ya fundi",
    descEn: "Track total, pending and completed requests at a glance.",
    descSw: "Fuatilia maombi yote, yanayosubiri na yaliyokamilika kwa haraka."
  },
  {
    img: "/screenshots/services-pricing.png",
    titleEn: "Services & pricing",
    titleSw: "Huduma na bei",
    descEn: "Technicians select services and set price ranges during onboarding.",
    descSw: "Mafundi huchagua huduma na kuweka bei wakati wa usajili."
  },
  {
    img: "/screenshots/pick-location.png",
    titleEn: "Pick location on map",
    titleSw: "Chagua eneo kwenye ramani",
    descEn: "Precise location picker for service requests across Dar es Salaam.",
    descSw: "Kichagua eneo sahihi kwa maombi ya huduma kote Dar es Salaam."
  },
  {
    img: "/screenshots/registration.png",
    titleEn: "Registration submitted",
    titleSw: "Usajili umewasilishwa",
    descEn: "Pending admin verification with clear next steps for new fundis.",
    descSw: "Inasubiri uthibitishaji wa admin na hatua zifuatazo wazi kwa mafundi wapya."
  },
  {
    img: "/screenshots/verify-otp.png",
    titleEn: "OTP verification",
    titleSw: "Uthibitishaji wa OTP",
    descEn: "Secure email OTP flow to verify accounts quickly.",
    descSw: "Mtiririko salama wa OTP kwa barua pepe ili kuthibitisha akaunti haraka."
  },
  {
    img: "/screenshots/email-otp.png",
    titleEn: "Email verification",
    titleSw: "Uthibitishaji wa barua pepe",
    descEn: "Clear OTP delivery and expiry messaging for a smooth onboarding.",
    descSw: "Ujumbe wazi wa OTP na muda wa kuisha kwa usajili laini."
  }
];

export const partners = [
  {
    name: "Selcom",
    url: "https://www.selcom.net/",
    descriptionEn: "Leading payments and financial technology partner in Tanzania and East Africa.",
    descriptionSw: "Mshirika wa malipo na teknolojia ya fedha anayeongoza Tanzania na Afrika Mashariki.",
    logoText: "Selcom"
  },
  {
    name: "Beem Africa",
    url: "https://beem.africa/",
    descriptionEn: "Messaging, SMS and communication infrastructure powering African apps.",
    descriptionSw: "Miundombinu ya ujumbe, SMS na mawasiliano inayoendesha programu za Afrika.",
    logoText: "Beem"
  }
];
