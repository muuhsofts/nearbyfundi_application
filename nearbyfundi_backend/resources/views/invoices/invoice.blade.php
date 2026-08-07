<!-- resources/views/invoices/invoice.blade.php -->
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Invoice #{{ $invoice->invoice_number }}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #333;
            margin: 40px;
        }
        .invoice-header {
            text-align: center;
            border-bottom: 3px solid #002B49;
            padding-bottom: 20px;
            margin-bottom: 25px;
        }
        .invoice-header .company-name {
            font-size: 32px;
            font-weight: bold;
            color: #002B49;
            letter-spacing: 3px;
        }
        .invoice-header .company-tagline {
            color: #7f8c8d;
            font-size: 14px;
            margin-top: 5px;
        }
        .invoice-header h1 {
            font-size: 28px;
            margin: 15px 0 0 0;
            color: #004472;
        }
        .invoice-header .subtitle {
            color: #7f8c8d;
            font-size: 16px;
            font-weight: bold;
        }
        .invoice-details {
            display: flex;
            justify-content: space-between;
            margin-bottom: 30px;
            background: #f8f9fa;
            padding: 20px;
            border-radius: 5px;
        }
        .invoice-details .left, .invoice-details .right {
            flex: 1;
        }
        .invoice-details .right {
            text-align: right;
        }
        .invoice-details strong {
            color: #002B49;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 30px;
        }
        table th {
            background: #002B49;
            color: white;
            padding: 12px 10px;
            text-align: left;
        }
        table td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        table tr:last-child td {
            border-bottom: none;
        }
        table tr:hover td {
            background: #f5f5f5;
        }
        .total-row {
            font-weight: bold;
            font-size: 16px;
            background: #e9ecef;
        }
        .total-row td {
            border-top: 2px solid #002B49;
            padding: 12px 10px;
        }
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
        }
        .status-pending { background: #f39c12; color: white; }
        .status-paid { background: #27ae60; color: white; }
        .status-cancelled { background: #e74c3c; color: white; }
        .status-expired { background: #95a5a6; color: white; }
        .payment-details {
            background: #f0f7ff;
            padding: 20px;
            border-radius: 5px;
            margin-top: 20px;
            border-left: 4px solid #004472;
        }
        .payment-details h3 {
            margin-top: 0;
            color: #002B49;
        }
        .payment-details p {
            margin: 5px 0;
        }
        .payment-details strong {
            color: #002B49;
        }
        .paid-badge {
            margin-top: 20px;
            padding: 15px;
            background: #d4edda;
            border-radius: 5px;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .paid-badge strong {
            color: #155724;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            color: #7f8c8d;
            font-size: 12px;
        }
        .footer .company-name {
            font-weight: bold;
            color: #002B49;
            font-size: 14px;
        }
        .text-right {
            text-align: right;
        }
        .text-center {
            text-align: center;
        }
        .mt-10 {
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <!-- ========================================== -->
    <!-- HEADER WITH COMPANY NAME                   -->
    <!-- ========================================== -->
    <div class="invoice-header">
        <div class="company-name">NETSAF FINTECH</div>
        <div class="company-tagline"></div>
        <h1>INVOICE</h1>
        <div class="subtitle">#{{ $invoice->invoice_number }}</div>
    </div>

    <!-- ========================================== -->
    <!-- INVOICE DETAILS                            -->
    <!-- ========================================== -->
    <div class="invoice-details">
        <div class="left">
            <strong>Bill To:</strong><br>
            {{ $invoice->user->name }}<br>
            {{ $invoice->user->email }}<br>
            {{ $invoice->user->phone ?? 'N/A' }}
        </div>
        <div class="right">
            <strong>Invoice Date:</strong> {{ $invoice->created_at->format('M d, Y H:i') }}<br>
            <strong>Due Date:</strong> {{ $invoice->due_date ? $invoice->due_date->format('M d, Y') : 'N/A' }}<br>
            <strong>Status:</strong>
            <span class="status-badge status-{{ $invoice->status }}">
                {{ $invoice->status_label }}
            </span>
        </div>
    </div>

    <!-- ========================================== -->
    <!-- ITEMS TABLE                                -->
    <!-- ========================================== -->
    <table>
        <thead>
            <tr>
                <th style="width: 50%;">Description</th>
                <th style="width: 25%;">Duration</th>
                <th style="width: 25%; text-align: right;">Amount</th>
            </tr>
        </thead>
        <tbody>
            @foreach($invoice->items as $item)
            <tr>
                <td>{{ $item['description'] }}</td>
                <td>{{ $item['duration'] ?? 'N/A' }}</td>
                <td style="text-align: right;">{{ number_format($item['amount'], 0) }} {{ $invoice->currency }}</td>
            </tr>
            @endforeach
            <tr class="total-row">
                <td colspan="2" style="text-align: right; font-size: 16px;">Total:</td>
                <td style="text-align: right; font-size: 18px; color: #002B49;">
                    <strong>{{ $invoice->formatted_amount }}</strong>
                </td>
            </tr>
        </tbody>
    </table>

    <!-- ========================================== -->
    <!-- PAYMENT DETAILS                            -->
    <!-- ========================================== -->
    @if($invoice->payment_details)
    <div class="payment-details">
        <h3>💳 Payment Instructions</h3>
        <p><strong>Method:</strong> {{ $invoice->payment_details['payment_method'] ?? 'N/A' }}</p>
        <p><strong>Phone Number:</strong> {{ $invoice->payment_details['phone_number'] ?? 'N/A' }}</p>
        <p><strong>Account Name:</strong> {{ $invoice->payment_details['account_name'] ?? 'N/A' }}</p>
        <p><strong>Amount:</strong> {{ $invoice->formatted_amount }}</p>
        @if($invoice->notes)
        <p><strong>Notes:</strong> {{ $invoice->notes }}</p>
        @endif
    </div>
    @endif

    <!-- ========================================== -->
    <!-- PAID BADGE (if paid)                       -->
    <!-- ========================================== -->
    @if($invoice->paid_at)
    <div class="paid-badge">
        <strong>✅ Payment Received</strong><br>
        Paid on: {{ $invoice->paid_at->format('M d, Y H:i') }}
    </div>
    @endif

    <!-- ========================================== -->
    <!-- FOOTER                                     -->
    <!-- ========================================== -->
    <div class="footer">
        <p>
            <span class="company-name">NETSAF FINTECH</span> &bull; 
            
        </p>
        <p>Thank you for your business!</p>
        <p style="font-size: 11px; color: #aaa; margin-top: 10px;">
            This invoice was generated automatically. For any queries, please contact support.
        </p>
    </div>
</body>
</html>