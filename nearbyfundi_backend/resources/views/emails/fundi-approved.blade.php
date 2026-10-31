<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your {{ $appName }} account is approved</title>
</head>
<body style="margin:0; padding:0; background-color:#f3f4f6; font-family:Arial, Helvetica, sans-serif; color:#1f2937;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6; padding:24px 12px;">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px; background-color:#ffffff; border-radius:12px; overflow:hidden;">

                    {{-- Header --}}
                    <tr>
                        <td align="center" style="background-color:#16a34a; padding:28px 24px;">
                            <div style="font-size:40px; line-height:1;">🎉</div>
                            <h1 style="margin:12px 0 0; font-size:22px; color:#ffffff;">Account Approved</h1>
                        </td>
                    </tr>

                    {{-- Body --}}
                    <tr>
                        <td style="padding:28px 28px 8px; font-size:15px; line-height:1.6;">
                            <p style="margin:0 0 14px;">Hello {{ $name }},</p>

                            <p style="margin:0 0 14px;">
                                Congratulations! Your <strong>{{ $appName }}</strong> fundi account has been
                                approved. Customers can now find you and send you job requests.
                            </p>

                            <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                                   style="background-color:#f0fdf4; border:1px solid #bbf7d0; border-radius:8px; margin:18px 0;">
                                <tr>
                                    <td style="padding:14px 16px; font-size:14px;">
                                        <strong>{{ $trialDays }}-day free trial</strong><br>
                                        Expires on {{ $expiresAt->format('M d, Y, H:i') }}
                                    </td>
                                </tr>
                            </table>

                            <p style="margin:0 0 14px;">
                                Open the app, go online, and start getting jobs.
                            </p>

                        
                        </td>
                    </tr>

                    {{-- Swahili --}}
                    <tr>
                        <td style="padding:0 28px 24px; font-size:14px; line-height:1.6; color:#4b5563;">
                            <hr style="border:none; border-top:1px solid #e5e7eb; margin:0 0 16px;">
                            <p style="margin:0;">
                                <strong>Hongera {{ $name }}!</strong> Akaunti yako ya {{ $appName }} imeidhinishwa.
                                Una majaribio ya bure ya siku {{ $trialDays }} (hadi {{ $expiresAt->format('d/m/Y') }}).
                                Fungua programu ili uanze kupata kazi.
                            </p>
                        </td>
                    </tr>

                    {{-- Footer --}}
                    <tr>
                        <td align="center" style="background-color:#f9fafb; padding:16px 24px; font-size:12px; color:#9ca3af;">
                            &copy; {{ date('Y') }} {{ $appName }}. All rights reserved.
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>