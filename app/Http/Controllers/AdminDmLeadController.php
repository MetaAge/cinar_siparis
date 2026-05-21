<?php

namespace App\Http\Controllers;

use App\Models\DmLead;
use App\Services\Dm\DmLeadEventService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDmLeadController extends Controller
{
    public function __construct(private DmLeadEventService $leadEventService) {}

    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status');
        $q = DmLead::with(['customer', 'conversation'])->latest();
        if ($status) $q->where('status', $status);

        return response()->json(['data' => $q->paginate(20)]);
    }

    public function show(int $id): JsonResponse
    {
        $lead = DmLead::with(['customer', 'conversation.messages', 'events'])->findOrFail($id);
        return response()->json(['data' => $lead]);
    }

    public function updateStatus(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate(['status' => 'required|in:new,waiting,approved,cancelled']);
        $lead = DmLead::findOrFail($id);
        $oldStatus = $lead->status;
        $lead->update(['status' => $validated['status']]);
        $this->leadEventService->log($lead, 'status_changed', null, [
            'old_status' => $oldStatus,
            'new_status' => $validated['status'],
        ]);

        return response()->json(['ok' => true, 'data' => $lead]);
    }

    public function addNote(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate(['note' => 'required|string|max:5000']);
        $lead = DmLead::findOrFail($id);
        $existing = trim((string) $lead->staff_notes);
        $lead->staff_notes = trim($existing."\n".$validated['note']);
        $lead->save();
        $this->leadEventService->log($lead, 'note_added', $validated['note']);

        return response()->json(['ok' => true, 'data' => $lead]);
    }

    public function suggestReply(int $id): JsonResponse
    {
        $lead = DmLead::with('customer')->findOrFail($id);
        $msg = 'Merhaba '.($lead->customer->name ?? '').', talebinizi aldık. Net fiyat ve uygunluk personel onayı sonrası bildirilecektir.';

        return response()->json(['ok' => true, 'suggested_reply' => trim($msg)]);
    }
}
