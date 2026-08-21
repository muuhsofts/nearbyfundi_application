type Props = { screen: "home" | "request" | "chat"; label: string };

const data = {
  home: { title: "Find a fundi", sub: "Services near you", icon: "⌖", items: ["Electrician", "Plumber", "Appliance repair"] },
  request: { title: "Service request", sub: "Fundi is on the way", icon: "✓", items: ["Distance 2.4 km", "Arrival 12 min", "Request #NF2048"] },
  chat: { title: "Chat with fundi", sub: "Online now", icon: "•••", items: ["Hello, I am on my way.", "I have arrived nearby.", "Thank you."] }
};

export default function PhoneMockup({ screen, label }: Props) {
  const d = data[screen];
  return (
    <div className="mx-auto w-[230px] rounded-[36px] border-[7px] border-slate-950 bg-slate-950 p-1.5 shadow-2xl">
      <div className="overflow-hidden rounded-[28px] bg-slate-50">
        <div className="mx-auto mt-2 h-5 w-20 rounded-full bg-slate-950" />
        <div className="px-4 pb-5 pt-4">
          <div className="flex items-center justify-between text-[10px] font-bold text-slate-500"><span>NearbyFundi</span><span>9:41</span></div>
          <div className="mt-4 rounded-2xl bg-bolt-500 p-4">
            <div className="text-3xl">{d.icon}</div>
            <p className="mt-3 text-base font-black text-slate-950">{d.title}</p>
            <p className="text-[10px] font-medium text-slate-800">{d.sub}</p>
          </div>
          <div className="mt-3 space-y-2">
            {d.items.map((item, i) => (
              <div key={i} className="rounded-xl border border-slate-200 bg-white p-2.5 text-[10px] font-bold text-slate-700">{item}</div>
            ))}
          </div>
          <div className="mt-4 rounded-xl bg-slate-950 p-3 text-center text-[10px] font-bold text-white">{label}</div>
        </div>
      </div>
    </div>
  );
}