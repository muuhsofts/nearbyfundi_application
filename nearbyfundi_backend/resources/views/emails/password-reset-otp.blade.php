<!DOCTYPE html>
<html>
<head>
    <title>Reset Your Password</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .otp-code { font-size: 32px; font-weight: bold; color: #2563eb; padding: 20px; background: #f3f4f6; text-align: center; border-radius: 8px; letter-spacing: 4px; }
        .footer { margin-top: 30px; font-size: 14px; color: #6b7280; border-top: 1px solid #e5e7eb; padding-top: 20px; }
        .expiry { color: #dc2626; font-weight: bold; }
        .warning { background-color: #fef3c7; border: 1px solid #f59e0b; padding: 12px; border-radius: 6px; margin: 16px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Reset Your Password</h1>
        <p>Hello {{ $user->name }},</p>
        <p>We received a request to reset your password. Use the OTP code below to proceed:</p>
        <div class="otp-code">{{ $otp }}</div>
        <p>This OTP is valid for <span class="expiry">{{ $expiresIn }} minutes</span>.</p>
        <div class="warning">
            <strong>⚠️ Security Notice:</strong> If you did not request this password reset, please ignore this email.
        </div>
        <div class="footer">
            <p>Regards,<br>Fundi App Team</p>
            <p style="font-size: 12px; color: #9ca3af;">This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>