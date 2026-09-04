<!DOCTYPE html>
<html>
<head>
    <title>Verify Your Account</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .otp-code { font-size: 32px; font-weight: bold; color: #2563eb; padding: 20px; background: #f3f4f6; text-align: center; border-radius: 8px; letter-spacing: 4px; }
        .footer { margin-top: 30px; font-size: 14px; color: #6b7280; border-top: 1px solid #e5e7eb; padding-top: 20px; }
        .expiry { color: #dc2626; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Verify Your Fundi App Account</h1>
        <p>Hello {{ $user->name }},</p>
        <p>Thank you for registering with Fundi App. Use the OTP code below to verify your account:</p>
        <div class="otp-code">{{ $otp }}</div>
        <p>This OTP is valid for <span class="expiry">{{ $expiresIn }} minutes</span>.</p>
        <p>If you did not create an account, please ignore this email.</p>
        <div class="footer">
            <p>Regards,<br>Fundi App Team</p>
            <p style="font-size: 12px; color: #9ca3af;">This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>