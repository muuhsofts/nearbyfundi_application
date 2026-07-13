<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OTP Verification - NearbyFundi</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        * {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        .btn-reset {
            display: inline-block;
            padding: 12px 32px;
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 16px;
            transition: all 0.3s ease;
            border: none;
            cursor: pointer;
        }
        .btn-reset:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 107, 94, 0.3);
        }
        .otp-box {
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
            color: white;
            padding: 16px 32px;
            border-radius: 12px;
            font-size: 36px;
            font-weight: 700;
            letter-spacing: 12px;
            display: inline-block;
            margin: 16px 0;
            font-family: 'Courier New', monospace;
        }
        .container {
            max-width: 480px;
            margin: 40px auto;
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
            padding: 24px;
            text-align: center;
        }
        .header h1 {
            color: white;
            font-size: 24px;
            font-weight: 700;
            margin: 0;
        }
        .header p {
            color: rgba(255, 255, 255, 0.8);
            margin: 4px 0 0;
            font-size: 14px;
        }
        .body-content {
            padding: 32px 24px;
            text-align: center;
        }
        .footer {
            padding: 16px 24px;
            text-align: center;
            border-top: 1px solid #e5e7eb;
            font-size: 12px;
            color: #9ca3af;
        }
    </style>
</head>
<body style="margin: 0; padding: 0; background: #f5f7fa;">

    <div class="container">
        <div class="header">
            <h1>NearbyFundi</h1>
            <p>{{ $type === 'email_verification' ? 'Verify Your Email' : 'Password Reset' }}</p>
        </div>

        <div class="body-content">
            @if($type === 'password_reset')
                <h2 style="font-size: 20px; font-weight: 600; color: #1a1a2e; margin: 0 0 8px;">
                    Reset Your Password
                </h2>
                <p style="color: #6b7280; margin: 0 0 24px; font-size: 15px;">
                    We received a request to reset your password. Use the OTP below to proceed.
                </p>
                
                <p style="color: #4b5563; margin: 0 0 8px; font-size: 14px;">
                    Hello <strong style="color: #1a1a2e;">{{ $name }}</strong>,
                </p>
                
                <p style="color: #6b7280; margin: 0 0 16px; font-size: 14px;">
                    Your password reset OTP is:
                </p>

                <div class="otp-box">
                    {{ $otp }}
                </div>

                <p style="color: #6b7280; font-size: 13px; margin: 16px 0 0;">
                    This OTP expires in <strong>10 minutes</strong>.
                </p>

                @if($resetUrl)
                    <div style="margin: 24px 0 16px;">
                        <a href="{{ $resetUrl }}" class="btn-reset">
                            Reset Password
                        </a>
                    </div>
                @endif

                <p style="color: #9ca3af; font-size: 12px; margin-top: 24px;">
                    If you didn't request this, please ignore this email.
                </p>

            @else
                <h2 style="font-size: 20px; font-weight: 600; color: #1a1a2e; margin: 0 0 8px;">
                    Verify Your Email
                </h2>
                <p style="color: #6b7280; margin: 0 0 24px; font-size: 15px;">
                    Welcome to NearbyFundi! Please verify your email address.
                </p>
                
                <p style="color: #4b5563; margin: 0 0 8px; font-size: 14px;">
                    Hello <strong style="color: #1a1a2e;">{{ $name }}</strong>,
                </p>
                
                <p style="color: #6b7280; margin: 0 0 16px; font-size: 14px;">
                    Your verification OTP is:
                </p>

                <div class="otp-box">
                    {{ $otp }}
                </div>

                <p style="color: #6b7280; font-size: 13px; margin: 16px 0 0;">
                    This OTP expires in <strong>10 minutes</strong>.
                </p>

                @if($url)
                    <div style="margin: 24px 0 16px;">
                        <a href="{{ $url }}" class="btn-reset">
                            Verify Email
                        </a>
                    </div>
                @endif
            @endif
        </div>

        <div class="footer">
            &copy; {{ date('Y') }} NearbyFundi. All rights reserved.
        </div>
    </div>

</body>
</html>