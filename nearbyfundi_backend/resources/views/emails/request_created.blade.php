<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Service Request - NearbyFundi</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        * {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            margin: 0;
            padding: 20px;
            background: #f5f7fa;
        }
        .container {
            max-width: 480px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.08);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
            padding: 28px 24px;
            text-align: center;
        }
        .header h1 {
            color: #ffffff;
            font-size: 22px;
            font-weight: 700;
            margin: 0;
            letter-spacing: -0.5px;
        }
        .header p {
            color: rgba(255, 255, 255, 0.85);
            margin: 4px 0 0;
            font-size: 14px;
            font-weight: 400;
        }
        .body-content {
            padding: 32px 24px;
        }
        .icon-wrapper {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 64px;
            height: 64px;
            border-radius: 50%;
            background: #dbeafe;
            color: #006B5E;
            margin-bottom: 16px;
        }
        .icon-wrapper svg {
            width: 32px;
            height: 32px;
        }
        .title {
            font-size: 20px;
            font-weight: 600;
            color: #1a1a2e;
            margin: 0 0 4px;
        }
        .subtitle {
            color: #6b7280;
            font-size: 14px;
            margin: 0 0 24px;
        }
        .details-card {
            background: #f8fafc;
            border-radius: 12px;
            padding: 16px;
            margin-bottom: 24px;
            border: 1px solid #e5e7eb;
        }
        .detail-row {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #e5e7eb;
        }
        .detail-row:last-child {
            border-bottom: none;
        }
        .detail-label {
            color: #6b7280;
            font-size: 13px;
            font-weight: 500;
        }
        .detail-value {
            color: #1a1a2e;
            font-size: 13px;
            font-weight: 600;
            text-align: right;
            max-width: 60%;
        }
        .detail-value.service {
            color: #006B5E;
        }
        .detail-value.description {
            font-weight: 400;
            text-align: right;
            word-break: break-word;
        }
        .btn-group {
            display: flex;
            flex-direction: column;
            gap: 10px;
            margin-top: 8px;
        }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
            color: #ffffff;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 14px;
            text-align: center;
            transition: all 0.3s ease;
            border: none;
            cursor: pointer;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 107, 94, 0.3);
        }
        .btn-secondary {
            background: transparent;
            color: #006B5E;
            border: 2px solid #006B5E;
        }
        .btn-secondary:hover {
            background: #006B5E;
            color: #ffffff;
            box-shadow: 0 8px 25px rgba(0, 107, 94, 0.15);
        }
        .btn-danger {
            background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
        }
        .btn-danger:hover {
            box-shadow: 0 8px 25px rgba(220, 38, 38, 0.3);
        }
        .btn-success {
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
        }
        .footer {
            padding: 16px 24px;
            text-align: center;
            border-top: 1px solid #e5e7eb;
            font-size: 12px;
            color: #9ca3af;
        }
        .footer a {
            color: #006B5E;
            text-decoration: none;
        }
        .footer a:hover {
            text-decoration: underline;
        }
        .note {
            color: #9ca3af;
            font-size: 12px;
            text-align: center;
            margin-top: 16px;
        }
        @media (max-width: 480px) {
            body {
                padding: 10px;
            }
            .body-content {
                padding: 24px 16px;
            }
            .detail-row {
                flex-direction: column;
                align-items: flex-start;
                gap: 2px;
            }
            .detail-value {
                text-align: left;
                max-width: 100%;
            }
            .detail-value.description {
                text-align: left;
            }
        }
    </style>
</head>
<body>

    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>NearbyFundi</h1>
            <p>New Service Request</p>
        </div>

        <!-- Body -->
        <div class="body-content">
            <div style="text-align: center;">
                <!-- Icon -->
                <div class="icon-wrapper">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"></path>
                    </svg>
                </div>

                <h2 class="title">New Service Request</h2>
                <p class="subtitle">A customer has requested your service.</p>
            </div>

            <!-- Request Details -->
            <div class="details-card">
                <div class="detail-row">
                    <span class="detail-label">Customer</span>
                    <span class="detail-value">{{ $customerName }}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Service</span>
                    <span class="detail-value service">{{ $service }}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Description</span>
                    <span class="detail-value description">{{ $description }}</span>
                </div>
            </div>

            <!-- Action Buttons -->
            <p style="color: #4b5563; font-size: 14px; text-align: center; margin: 0 0 12px; font-weight: 500;">
                Please respond to this request:
            </p>

            
        </div>

        <!-- Footer -->
        <div class="footer">
            &copy; {{ date('Y') }} <a href="{{ config('app.frontend_url') }}">NearbyFundi</a>. All rights reserved.
        </div>
    </div>

</body>
</html>