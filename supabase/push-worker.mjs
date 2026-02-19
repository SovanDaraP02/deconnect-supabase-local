// push-worker.mjs — Polls notifications table and sends FCM push via Edge Function

const SUPABASE_URL = "http://127.0.0.1:54321";

const SERVICE_ROLE_KEY =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

const EDGE_FN_URL = `${SUPABASE_URL}/functions/v1/send-push-notification`;

const sentIds = new Set();

/**
 * Sanitize strings to remove control characters that break JSON/FCM payloads.
 */
function sanitize(str) {
    if (!str || typeof str !== "string") return str || "";
    return str
        .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
        .replace(/\n/g, " ")
        .replace(/\r/g, "")
        .replace(/\t/g, " ")
        .trim();
}

/**
 * Main polling loop — fetches unread notifications and sends FCM push
 * via the Supabase Edge Function, then marks them as read.
 */
async function pollAndSend() {
    console.log("Push worker started - polling every 2 seconds...");
    console.log("Supabase: " + SUPABASE_URL);
    console.log("Edge Function: " + EDGE_FN_URL + "\n");

    while (true) {
        try {
            // 1. Fetch unread notifications
            const res = await fetch(
                SUPABASE_URL +
                "/rest/v1/notifications?is_read=eq.false&select=*&order=created_at.desc&limit=50", {
                    headers: {
                        apikey: SERVICE_ROLE_KEY,
                        Authorization: "Bearer " + SERVICE_ROLE_KEY,
                    },
                }
            );

            if (!res.ok) {
                console.error("Failed to fetch notifications:", res.status);
                await sleep(2000);
                continue;
            }

            const notifications = await res.json();

            for (const notif of notifications) {
                // Skip already-processed notifications
                if (sentIds.has(notif.id)) continue;
                sentIds.add(notif.id);

                try {
                    // 2. Call Edge Function to send FCM push
                    const pushRes = await fetch(EDGE_FN_URL, {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json",
                            Authorization: "Bearer " + SERVICE_ROLE_KEY,
                        },
                        body: JSON.stringify({
                            user_id: notif.user_id,
                            title: sanitize(notif.title),
                            body: sanitize(notif.body),
                            channel: notif.channel,
                            room_id: notif.room_id,
                            sender_id: notif.sender_id,
                            id: notif.id,
                        }),
                    });

                    const result = await pushRes.json();

                    if (result.success && !result.skipped) {
                        console.log(
                            "PUSH SENT -> " +
                            sanitize(notif.title) +
                            ": " +
                            sanitize(notif.body)
                        );
                    } else if (result.skipped) {
                        console.log(
                            "Skipped (" +
                            result.reason +
                            ") -> " +
                            sanitize(notif.title) +
                            ": " +
                            sanitize(notif.body)
                        );
                    } else {
                        console.log(
                            "Failed -> " +
                            sanitize(notif.title) +
                            ": " +
                            JSON.stringify(result.error || result)
                        );
                    }

                    // 3. Mark notification as read regardless of push result
                    await fetch(
                        SUPABASE_URL + "/rest/v1/notifications?id=eq." + notif.id, {
                            method: "PATCH",
                            headers: {
                                "Content-Type": "application/json",
                                apikey: SERVICE_ROLE_KEY,
                                Authorization: "Bearer " + SERVICE_ROLE_KEY,
                                Prefer: "return=minimal",
                            },
                            body: JSON.stringify({ is_read: true }),
                        }
                    );
                } catch (pushErr) {
                    console.error(
                        "Push error for " + notif.id + ":",
                        pushErr.message
                    );
                    // Allow retry on next poll
                    sentIds.delete(notif.id);
                }
            }

            // Prevent sentIds from growing unbounded
            if (sentIds.size > 500) {
                const arr = [...sentIds];
                arr.slice(0, arr.length - 500).forEach(function(id) {
                    sentIds.delete(id);
                });
            }
        } catch (err) {
            console.error("Poll error:", err.message);
        }

        await sleep(2000);
    }
}

function sleep(ms) {
    return new Promise(function(r) {
        setTimeout(r, ms);
    });
}

// Start the worker
pollAndSend();