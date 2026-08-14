<?php

namespace App\Http\Controllers\Api;

use App\Models\PrivacyPolicy;
use Illuminate\Http\Request;

class PrivacyPolicyController extends BaseApiController
{
    public function show()
    {
        $policy = PrivacyPolicy::first();
        return $this->successResponse($policy, 'Privacy policy retrieved.');
    }

    public function update(Request $request)
    {
        $this->checkPermission('privacy.edit');
        $data = $request->validate(['content' => 'required|string']);
        $policy = PrivacyPolicy::first();
        if ($policy) {
            $policy->update($data);
        } else {
            $policy = PrivacyPolicy::create($data);
        }
        $this->logAudit('update_privacy_policy', 'privacy_policy', $policy->id, 'Privacy policy updated');
        return $this->successResponse($policy, 'Privacy policy updated.');
    }
}