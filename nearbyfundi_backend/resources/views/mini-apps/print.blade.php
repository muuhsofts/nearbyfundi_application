<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>OG ONE GROUP - App QR Codes</title>
<style>
  body { font-family: Arial, sans-serif; margin: 24px; color: #1A2B4A; }
  h1 { margin: 0 0 4px; }
  p.sub { margin: 0 0 24px; color: #5B6B82; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 20px; }
  .card { border: 2px solid #1A2B4A22; border-radius: 16px; padding: 16px; text-align: center; page-break-inside: avoid; }
  .card img { width: 220px; height: 220px; }
  .name { font-size: 18px; font-weight: 800; margin-top: 8px; }
  .sub2 { font-size: 13px; color: #5B6B82; }
  .code { font-family: monospace; font-size: 12px; margin-top: 6px; color: #8A6500; }
  .soon { display: inline-block; background: #FFB300; color: #1A2B4A; font-size: 11px; font-weight: 800; padding: 2px 8px; border-radius: 10px; }
  @media print { body { margin: 8mm; } }
</style>
</head>
<body>
  <h1>OG ONE GROUP</h1>
  <p class="sub">Scan with the scan button inside the OG ONE GROUP app.</p>
  <div class="grid">
    @foreach ($apps as $app)
      <div class="card">
        <img src="{{ url('/api/v24/mini-apps/' . $app->slug . '/qr?format=svg&size=512') }}" alt="{{ $app->name }}">
        <div class="name">{{ $app->name }}</div>
        <div class="sub2">{{ $app->subtitle }}</div>
        @if ($app->is_coming_soon)<span class="soon">Soon</span>@endif
        <div class="code">{{ $app->qr_payload }}</div>
      </div>
    @endforeach
  </div>
</body>
</html>