<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Request Completed - NearbyFundi</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        * {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
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
        }
        .success-icon {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 64px;
            height: 64px;
            border-radius: 50%;
            background: #d1fae5;
            color: #006B5E;
            margin-bottom: 16px;
        }
        .success-icon svg {
            width: 32px;
            height: 32px;
        }
        .footer {
            padding: 16px 24px;
            text-align: center;
            border-top: 1px solid #e5e7eb;
            font-size: 12px;
            color: #9ca3af;
        }
        .highlight-box {
            background: #f0fdf4;
            border-left: 4px solid #006B5E;
            padding: 16px;
            border-radius: 8px;
            margin-top: 16px;
        }
        .highlight-box p {
            color: #065f46;
            font-size: 14px;
            margin: 0;
        }
        .btn {
            display: inline-block;
            padding: 10px 24px;
            background: linear-gradient(135deg, #006B5E 0%, #00897B 100%);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s ease;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 107, 94, 0.3);
        }
        .request-details {
            background: #f8fafc;
            border-radius: 8px;
            padding: 16px;
            margin: 16px 0;
            text-align: left;
        }
        .request-details p {
            margin: 4px 0;
            font-size: 14px;
            color: #1f2937;
        }
        .request-details .label {
            color: #6b7280;
            font-weight: 500;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .request-details .value {
            font-weight: 600;
            color: #1a1a2e;
        }
        .rating-section {
            background: #fffbeb;
            border: 1px solid #fcd34d;
            border-radius: 8px;
            padding: 16px;
            margin: 16px 0;
            text-align: center;
        }
        .rating-section .stars {
            font-size: 28px;
            letter-spacing: 4px;
            color: #f59e0b;
        }
        .rating-section p {
            color: #92400e;
            font-size: 14px;
            margin: 4px 0 0;
        }
        .divider {
            border: none;
            border-top: 1px solid #e5e7eb;
            margin: 16px 0;
        }
        .btn-outline {
            display: inline-block;
            padding: 10px 24px;
            background: transparent;
            color: #006B5E;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 14px;
            border: 2px solid #006B5E;
            transition: all 0.3s ease;
        }
        .btn-outline:hover {
            background: #006B5E;
            color: white;
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 107, 94, 0.15);
        }
        .btn-group {
            display: flex;
            flex-direction: column;
            gap: 10px;
            margin-top: 16px;
        }
        .btn-group .btn {
            width: 100%;
            box-sizing: border-box;
            text-align: center;
        }
        .btn-group .btn-outline {
            width: 100%;
            box-sizing: border-box;
            text-align: center;
        }
        @media (min-width: 480px) {
            .btn-group {
                flex-direction: row;
            }
            .btn-group .btn,
            .btn-group .btn-outline {
                width: auto;
                flex: 1;
            }
        }
    </style>
</head>
<body style="margin: 0; padding: 0; background: #f5f7fa;">

    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>NearbyFundi</h1>
            <p>Request Completed</p>
        </div>

        <!-- Body -->
        <div class="body-content">
            <!-- Success Icon -->
            <div style="text-align: center;">
                <div class="success-icon">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                </div>
                <h2 style="font-size: 20px; font-weight: 600; color: #1a1a2e; margin: 0 0 8px;">
                    Request Completed! ✅
                </h2>
                <p style="color: #4b5563; margin: 0 0 4px; font-size: 15px;">
                    Your request has been successfully completed by
                </p>
                <p style="color: #006B5E; font-size: 17px; font-weight: 600; margin: 0 0 16px;">
                    {{ $technicianName }}
                </p>
            </div>

            <!-- Request Details -->
            <div class="request-details">
                <p><span class="label">Service</span><br><span class="value">{{ $serviceName }}</span></p>
                <p><span class="label">Request ID</span><br><span class="value">#{{ $request->id }}</span></p>
                <p><span class="label">Completed On</span><br><span class="value">{{ $request->updated_at->format('F d, Y') }} at {{ $request->updated_at->format('g:i A') }}</span></p>
            </div>

            <!-- Rating Section -->
            <div class="rating-section">
                <p style="font-weight: 600; color: #92400e; margin: 0 0 4px;">How was your experience?</p>
                <div class="stars">★★★★★</div>
                <p style="font-size: 13px;">Rate your experience with {{ $technicianName }}</p>
                <p style="font-size: 12px; color: #92400e; margin-top: 8px;">
                    You can rate the technician on the NearbyFundi app
                </p>
            </div>

            <div class="highlight-box">
                <p>💚 Thank you for choosing NearbyFundi! We hope you enjoyed the service.</p>
            </div>


           
        </div>

        <!-- Footer -->
        <div class="footer">
            &copy; {{ date('Y') }} NearbyFundi. All rights reserved.<br>
            You are receiving this email because you requested a service through NearbyFundi.
        </div>
    </div>

</body>
</html>