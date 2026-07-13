<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Verification - NearbyFundi</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 font-sans min-h-screen flex items-center justify-center">
    <div class="max-w-md w-full bg-white rounded-xl shadow-lg overflow-hidden mx-4">
        <div class="p-6 text-center">
            <!-- Logo / Brand -->
            <div class="mb-6">
                <h2 class="text-3xl font-bold" style="color: #006B5E;">NearbyFundi</h2>
                <p class="text-gray-500 mt-1">Email Verification</p>
            </div>

            <!-- Icon -->
            <div class="mb-4">
                @if($success)
                    <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-green-100 text-green-600">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                        </svg>
                    </div>
                @else
                    <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-100 text-red-600">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                        </svg>
                    </div>
                @endif
            </div>

            <!-- Message -->
            <h3 class="text-xl font-semibold text-gray-800 mb-2">
                {{ $success ? 'Email Verified!' : 'Verification Failed' }}
            </h3>
            <p class="text-gray-600 mb-6">
                {{ $message }}
            </p>

            @if($success)
                <a href="{{ url('/login') }}" class="text-white font-bold py-2 px-6 rounded-lg inline-block" style="background: linear-gradient(135deg, #006B5E, #00897B);">
                    Login Now
                </a>
            @endif

            <p class="text-xs text-gray-400 mt-6">
                &copy; {{ date('Y') }} NearbyFundi. All rights reserved.
            </p>
        </div>
    </div>
</body>
</html>