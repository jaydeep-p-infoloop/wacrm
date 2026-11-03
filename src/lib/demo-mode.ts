/**
 * Demo mode — lets OpsDeck be demonstrated without a Meta / WhatsApp
 * Business connection.
 *
 * Enabled with `NEXT_PUBLIC_DEMO_MODE=true` (inlined at build time, so
 * both server routes and client components see the same value; rebuild
 * after changing it). Off by default.
 *
 * What it does:
 *   - Outbound sends through `sendMessageToConversation` (inbox
 *     replies, `/api/v1/messages`) for an account that has NO WhatsApp
 *     config are recorded as sent with a synthetic `demo-<uuid>` id
 *     instead of failing with `whatsapp_not_configured`.
 *   - The inbox "WhatsApp not connected" banner shows a demo notice.
 *
 * Safety: an account that HAS a WhatsApp config always sends through
 * Meta for real, even with the flag on — demo mode only fills in where
 * there is no connection, so it can't silently swallow real messages.
 * Nothing about webhooks, auth or RLS changes.
 */
export function isDemoMode(): boolean {
  return process.env.NEXT_PUBLIC_DEMO_MODE === "true";
}

/** Prefix for synthetic WhatsApp message ids written in demo mode. */
export const DEMO_MESSAGE_ID_PREFIX = "demo-";

export function demoWhatsAppMessageId(): string {
  return `${DEMO_MESSAGE_ID_PREFIX}${crypto.randomUUID()}`;
}
